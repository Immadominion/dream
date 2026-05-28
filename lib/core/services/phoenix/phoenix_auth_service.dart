import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana/base58.dart';

import '../../constants/app_constants.dart';
import '../../models/phoenix/phoenix_models.dart';
import '../logger_service.dart';
import '../wallet/mwa_wallet_service.dart';
import '../wallet/privy_wallet_manager.dart';
import '../../../shared/services/storage_service.dart';

// Storage keys for persisting Phoenix JWT pair
const _kAccessToken = 'phoenix_access_token';
const _kRefreshToken = 'phoenix_refresh_token';
const _kExpiresAt = 'phoenix_token_expires_at';
const _kRefreshExpiresAt = 'phoenix_refresh_expires_at';

/// 'privy' | 'mwa' — persisted so wallet type survives app restarts
const _kWalletType = 'phoenix_wallet_type';

/// Handles Phoenix perpetual-futures API authentication.
///
/// Supports two wallet types:
/// - **Privy embedded wallet** – signing is transparent (no user interaction)
/// - **MWA external wallet** – signing triggers the installed wallet app (Android only)
///
/// Auth lifecycle:
/// 1. First login: fetch nonce → sign with wallet → POST /v1/auth/login/wallet → store JWT pair
/// 2. Access token expired: POST /v1/auth/refresh → store new JWT pair (no re-signing)
/// 3. Refresh token expired: repeat step 1 (re-sign; shows wallet prompt for MWA users)
class PhoenixAuthService {
  final PrivyWalletManager _privyWallet;
  final MwaWalletService _mwaService;
  final LoggerService _logger;
  late final Dio _dio;
  Future<PhoenixSession?>? _refreshInFlight;
  String? _refreshInFlightToken;

  PhoenixAuthService({
    required PrivyWalletManager privyWallet,
    required MwaWalletService mwaService,
    required LoggerService logger,
  }) : _privyWallet = privyWallet,
       _mwaService = mwaService,
       _logger = logger {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.phoenixApiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          _logger.error(
            'Phoenix HTTP error ${error.response?.statusCode}: '
            '${error.requestOptions.path}',
            error: error,
            tag: 'PhoenixAuth',
          );
          handler.next(error);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Return a valid [PhoenixSession] from storage (auto-refreshing if needed).
  ///
  /// Returns `null` when:
  /// - no session is stored yet
  /// - the refresh token has also expired (requires full re-authentication)
  Future<PhoenixSession?> getStoredSession() async {
    try {
      final accessToken = StorageService.getString(_kAccessToken);
      final expiresAtStr = StorageService.getString(_kExpiresAt);
      if (accessToken.isEmpty || expiresAtStr.isEmpty) return null;

      final expiresAt = DateTime.parse(expiresAtStr);
      final refreshToken = StorageService.getString(_kRefreshToken);
      final refreshExpiresAtStr = StorageService.getString(_kRefreshExpiresAt);
      final refreshExpiresAt = refreshExpiresAtStr.isNotEmpty
          ? DateTime.parse(refreshExpiresAtStr)
          : null;

      final session = PhoenixSession(
        accessToken: accessToken,
        refreshToken: refreshToken.isEmpty ? null : refreshToken,
        expiresAt: expiresAt,
        refreshExpiresAt: refreshExpiresAt,
      );

      // Access token still valid
      if (session.isValid) return session;

      // Try refreshing silently
      if (session.canRefresh) {
        return await _refreshOnce(session.refreshToken!);
      }

      _logger.info(
        'Phoenix session fully expired — needs re-auth',
        tag: 'PhoenixAuth',
      );
      await clearStoredSession();
      return null;
    } catch (e) {
      _logger.error(
        'Failed to load Phoenix session',
        error: e,
        tag: 'PhoenixAuth',
      );
      await clearStoredSession();
      return null;
    }
  }

  /// Authenticate with Phoenix by signing a nonce with [walletAddress].
  ///
  /// [usesMwa] controls which wallet type performs the signing:
  /// - `false` → Privy embedded wallet (transparent, no user prompt)
  /// - `true`  → MWA external wallet (triggers wallet app on Android)
  ///
  /// Throws if authentication fails.
  Future<PhoenixSession> authenticate({
    required String walletAddress,
    required bool usesMwa,
  }) async {
    _logger.info(
      'Authenticating with Phoenix [wallet=$walletAddress, mwa=$usesMwa]',
      tag: 'PhoenixAuth',
    );

    // 1. Fetch nonce
    final nonceResponse = await _fetchNonce(walletAddress);

    // 2. Sign the nonce with the correct wallet
    final signatureBase58 = usesMwa
        ? await _signWithMwa(nonceResponse.nonce)
        : await _signWithPrivy(nonceResponse.nonce);

    // 3. Submit signed nonce to Phoenix
    final session = await _submitLogin(
      walletPubkey: walletAddress,
      nonceId: nonceResponse.nonceId,
      signature: signatureBase58,
    );

    // 4. Persist for future use
    await _saveSession(session, usesMwa: usesMwa);

    _logger.info('Phoenix authentication complete', tag: 'PhoenixAuth');
    return session;
  }

  /// Ensure a valid session exists; refreshes or re-authenticates as needed.
  ///
  /// This is the main entry point called by API services before making
  /// authenticated Phoenix requests. It only throws when full re-auth is
  /// required (caller should re-invoke [authenticate]).
  Future<PhoenixSession?> ensureAuthenticated({
    required String walletAddress,
    required bool usesMwa,
  }) async {
    final stored = await getStoredSession();
    if (stored != null) return stored;

    // Need fresh authentication
    try {
      return await authenticate(walletAddress: walletAddress, usesMwa: usesMwa);
    } catch (e) {
      _logger.error('Phoenix auth failed', error: e, tag: 'PhoenixAuth');
      return null;
    }
  }

  /// Activate a new trader account with an invite code.
  Future<void> activateInviteCode({
    required String authority,
    required String inviteCode,
    String? referralCode,
  }) async {
    try {
      if (referralCode != null && referralCode.isNotEmpty) {
        await _dio.post(
          '/v1/invite/activate-with-referral',
          data: {'authority': authority, 'referral_code': referralCode},
        );
      } else {
        await _dio.post(
          '/v1/invite/activate',
          data: {'authority': authority, 'code': inviteCode},
        );
      }
      _logger.info('Invite code activated', tag: 'PhoenixAuth');
    } on DioException catch (e) {
      // 409 = already activated — not a fatal error
      if (e.response?.statusCode == 409) {
        _logger.info('Account already activated', tag: 'PhoenixAuth');
        return;
      }
      rethrow;
    }
  }

  /// Clear persisted Phoenix session (call on user logout).
  Future<void> clearStoredSession() async {
    await Future.wait([
      StorageService.setString(_kAccessToken, ''),
      StorageService.setString(_kRefreshToken, ''),
      StorageService.setString(_kExpiresAt, ''),
      StorageService.setString(_kRefreshExpiresAt, ''),
      StorageService.setString(_kWalletType, ''),
    ]);
    _logger.info('Phoenix session cleared', tag: 'PhoenixAuth');
  }

  /// Returns the persisted wallet type: 'mwa' or 'privy'.
  /// Empty string if no session has been authenticated yet.
  String get persistedWalletType => StorageService.getString(_kWalletType);

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<PhoenixNonceResponse> _fetchNonce(String walletPubkey) async {
    final response = await _dio.get(
      '/v1/auth/nonce',
      queryParameters: {'wallet_pubkey': walletPubkey},
    );
    return PhoenixNonceResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Sign [nonce] with Privy embedded wallet (transparent; no user prompt).
  Future<String> _signWithPrivy(String nonce) async {
    final wallet = await _privyWallet.getOrCreateWallet();
    if (wallet == null) {
      throw const PhoenixAuthException(
        'Privy embedded wallet not available. '
        'Ensure the user is authenticated with Privy.',
      );
    }

    final signatureBase64 = await _privyWallet.signMessage(wallet, nonce);
    if (signatureBase64 == null) {
      throw const PhoenixAuthException('Privy wallet signing returned null');
    }

    // Phoenix expects base58-encoded Ed25519 signature
    final signatureBytes = base64Decode(signatureBase64);
    return base58encode(signatureBytes);
  }

  /// Sign [nonce] via MWA (triggers the user's installed wallet app).
  Future<String> _signWithMwa(String nonce) async {
    final result = await _mwaService.signMessage(nonce);
    if (!result.success || result.signature == null) {
      throw PhoenixAuthException(result.error ?? 'MWA wallet signing failed');
    }
    return base58encode(result.signature!);
  }

  Future<PhoenixSession> _submitLogin({
    required String walletPubkey,
    required String nonceId,
    required String signature,
  }) async {
    final response = await _dio.post(
      '/v1/auth/login/wallet',
      data: {
        'wallet_pubkey': walletPubkey,
        'nonce_id': nonceId,
        'signature': signature,
      },
    );
    return _sessionFromAuthResponse(response.data as Map<String, dynamic>);
  }

  /// Refresh tokens without requiring the user to re-sign.
  Future<PhoenixSession?> _refreshOnce(String refreshToken) {
    final inFlight = _refreshInFlight;
    if (inFlight != null && _refreshInFlightToken == refreshToken) {
      return inFlight;
    }

    _refreshInFlightToken = refreshToken;
    final refreshFuture = _silentRefresh(refreshToken).whenComplete(() {
      if (_refreshInFlightToken == refreshToken) {
        _refreshInFlight = null;
        _refreshInFlightToken = null;
      }
    });
    _refreshInFlight = refreshFuture;
    return refreshFuture;
  }

  Future<PhoenixSession?> _silentRefresh(String refreshToken) async {
    try {
      _logger.info('Silently refreshing Phoenix tokens', tag: 'PhoenixAuth');
      final response = await _dio.post(
        '/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final session = _sessionFromAuthResponse(
        response.data as Map<String, dynamic>,
      );
      await _saveSession(
        session,
        usesMwa: null,
      ); // wallet type unchanged on refresh
      _logger.info('Phoenix tokens refreshed', tag: 'PhoenixAuth');
      return session;
    } catch (e) {
      _logger.error('Token refresh failed', error: e, tag: 'PhoenixAuth');

      if (StorageService.getString(_kRefreshToken) == refreshToken) {
        await clearStoredSession();
      } else {
        _logger.warning(
          'Ignoring stale Phoenix refresh failure; a newer token is stored',
          tag: 'PhoenixAuth',
        );
      }
      return null;
    }
  }

  PhoenixSession _sessionFromAuthResponse(Map<String, dynamic> json) {
    final auth = PhoenixAuthResponse.fromJson(json);
    return PhoenixSession(
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: auth.expiresIn)),
      refreshExpiresAt: DateTime.now().add(
        Duration(seconds: auth.refreshExpiresIn),
      ),
    );
  }

  Future<void> _saveSession(
    PhoenixSession session, {
    required bool? usesMwa,
  }) async {
    await Future.wait([
      StorageService.setString(_kAccessToken, session.accessToken),
      StorageService.setString(
        _kExpiresAt,
        session.expiresAt.toIso8601String(),
      ),
      if (session.refreshToken != null)
        StorageService.setString(_kRefreshToken, session.refreshToken!),
      if (session.refreshExpiresAt != null)
        StorageService.setString(
          _kRefreshExpiresAt,
          session.refreshExpiresAt!.toIso8601String(),
        ),
      // Only write wallet type when explicitly provided (not on refresh)
      if (usesMwa != null)
        StorageService.setString(_kWalletType, usesMwa ? 'mwa' : 'privy'),
    ]);
  }
}

/// Thrown when Phoenix authentication fails for a recoverable reason.
class PhoenixAuthException implements Exception {
  final String message;
  const PhoenixAuthException(this.message);

  @override
  String toString() => 'PhoenixAuthException: $message';
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final phoenixAuthServiceProvider = Provider<PhoenixAuthService>((ref) {
  return PhoenixAuthService(
    privyWallet: ref.watch(privyWalletManagerProvider),
    mwaService: ref.watch(mwaWalletServiceProvider),
    logger: ref.watch(loggerServiceProvider),
  );
});
