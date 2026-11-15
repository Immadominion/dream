import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/phoenix/phoenix_auth_service.dart';
import '../../../core/services/wallet/mwa_wallet_service.dart';
import '../../../core/services/wallet/privy_wallet_manager.dart';
import '../models/dream_models.dart';

final dreamApiServiceProvider = Provider<DreamApiService>((ref) {
  return DreamApiService(
    logger: ref.watch(loggerServiceProvider),
    privyWallet: ref.watch(privyWalletManagerProvider),
    mwaService: ref.watch(mwaWalletServiceProvider),
    phoenixAuthService: ref.watch(phoenixAuthServiceProvider),
  );
});

/// Error carrying the server's human-readable message.
class DreamApiException implements Exception {
  final String message;
  final int? statusCode;
  const DreamApiException(this.message, {this.statusCode});

  /// 404/409/503 right after an on-chain action usually means "not visible
  /// to the server's RPC yet" — worth retrying.
  bool get isNotYetVisible =>
      statusCode == 404 || statusCode == 409 || statusCode == 503;

  @override
  String toString() => message;
}

/// Client for dream-server's `/v1/dreams` API.
///
/// Auth: the wallet signs `dream-session:v1:<wallet>:<timestampMs>` once and
/// exchanges it for a short-lived bearer token (domain-separated from other
/// Dream services). One wallet prompt per session instead of per request.
class DreamApiService {
  final LoggerService _logger;
  final PrivyWalletManager _privyWallet;
  final MwaWalletService _mwaService;
  final PhoenixAuthService _phoenixAuthService;
  late final Dio _dio;

  String? _sessionToken;
  String? _sessionWallet;
  DateTime? _sessionExpiresAt;
  Future<String>? _sessionInFlight;

  DreamApiService({
    required LoggerService logger,
    required PrivyWalletManager privyWallet,
    required MwaWalletService mwaService,
    required PhoenixAuthService phoenixAuthService,
  }) : _logger = logger,
       _privyWallet = privyWallet,
       _mwaService = mwaService,
       _phoenixAuthService = phoenixAuthService {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.dreamServerUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  // ── Public ────────────────────────────────────────────────────────────────

  Future<DreamPage> listDreams({
    DreamSort sort = DreamSort.latest,
    DreamCategory? category,
    String? owner,
    int cursor = 0,
    int limit = 20,
  }) async {
    final data = await _request(
      () => _dio.get(
        '/v1/dreams',
        queryParameters: {
          'sort': sort.apiValue,
          'category': ?category?.name,
          'owner': ?owner,
          'cursor': cursor,
          'limit': limit,
        },
      ),
    );
    return DreamPage.fromJson(data);
  }

  Future<DreamDetail> getDream(String id) async {
    final data = await _request(() => _dio.get('/v1/dreams/$id'));
    return DreamDetail.fromJson(data);
  }

  // ── Authenticated ─────────────────────────────────────────────────────────

  /// The caller's dreams, including ones hidden for review.
  Future<List<Dream>> myDreams(String wallet) async {
    final data = await _authed(
      wallet,
      (o) => _dio.get('/v1/dreams/mine', options: o),
    );
    return DreamPage.fromJson(data).dreams;
  }

  Future<Dream> createDream({
    required String wallet,
    required String title,
    required String story,
    required DreamCategory category,
    required String goalUsdc,
  }) async {
    final data = await _authed(
      wallet,
      (o) => _dio.post(
        '/v1/dreams',
        options: o,
        data: {
          'title': title,
          'story': story,
          'category': category.name,
          'goalUsdc': goalUsdc,
        },
      ),
    );
    return Dream.fromJson(data['dream'] as Map<String, dynamic>);
  }

  Future<Dream> closeDream({required String wallet, required String id}) =>
      _dreamOf(
        _authed(
          wallet,
          (o) => _dio.patch(
            '/v1/dreams/$id',
            options: o,
            data: {'status': 'closed'},
          ),
        ),
      );

  /// Link the owner's X post. The server verifies the post is theirs (it
  /// must contain the dream id) before accepting it.
  Future<Dream> linkXPost({
    required String wallet,
    required String id,
    required String url,
  }) => _dreamOf(
    _authed(
      wallet,
      (o) => _dio.post('/v1/dreams/$id/x', options: o, data: {'url': url}),
    ),
  );

  /// Record a confirmed USDC transfer. The server reads the transaction at
  /// `finalized` commitment, which lags a confirmed tx by ~15s, so "not found
  /// yet" is retried with backoff.
  Future<Dream> recordContribution({
    required String wallet,
    required String id,
    required String txSignature,
  }) => _retryWhileNotVisible(
    () => _dreamOf(
      _authed(
        wallet,
        (o) => _dio.post(
          '/v1/dreams/$id/contributions',
          options: o,
          data: {'txSignature': txSignature},
        ),
      ),
    ),
  );

  Future<void> report({
    required String wallet,
    required String id,
    required String reason,
  }) async {
    await _authed(
      wallet,
      (o) => _dio.post(
        '/v1/dreams/$id/report',
        options: o,
        data: {'reason': reason},
      ),
    );
  }

  Future<ServerBuiltTx> prepareCoin({
    required String wallet,
    required String id,
    required String name,
    required String symbol,
  }) async {
    final data = await _authed(
      wallet,
      (o) => _dio.post(
        '/v1/dreams/$id/coin/prepare',
        options: o,
        data: {'name': name, 'symbol': symbol},
      ),
    );
    return ServerBuiltTx.fromJson(data);
  }

  /// Confirm a launch; the pool may take a moment to be visible server-side.
  Future<Dream> confirmCoin({
    required String wallet,
    required String id,
    required String mint,
    required String txSignature,
  }) => _retryWhileNotVisible(
    () => _dreamOf(
      _authed(
        wallet,
        (o) => _dio.post(
          '/v1/dreams/$id/coin/confirm',
          options: o,
          data: {'mint': mint, 'txSignature': txSignature},
        ),
      ),
    ),
  );

  Future<ServerBuiltTx> buildSwap({
    required String wallet,
    required String id,
    required bool buy,
    required BigInt amountIn,
    int slippageBps = 100,
  }) async {
    final data = await _authed(
      wallet,
      (o) => _dio.post(
        '/v1/dreams/$id/coin/swap',
        options: o,
        data: {
          'side': buy ? 'buy' : 'sell',
          'amountIn': amountIn.toString(),
          'slippageBps': slippageBps,
        },
      ),
    );
    return ServerBuiltTx.fromJson(data);
  }

  Future<ServerBuiltTx> buildClaim({
    required String wallet,
    required String id,
  }) async {
    final data = await _authed(
      wallet,
      (o) => _dio.post('/v1/dreams/$id/coin/claim', options: o),
    );
    return ServerBuiltTx.fromJson(data);
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<Dream> _dreamOf(Future<Map<String, dynamic>> response) async =>
      Dream.fromJson((await response)['dream'] as Map<String, dynamic>);

  Future<T> _retryWhileNotVisible<T>(Future<T> Function() call) async {
    DreamApiException? last;
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        return await call();
      } on DreamApiException catch (e) {
        if (!e.isNotYetVisible) rethrow;
        last = e;
        await Future<void>.delayed(Duration(seconds: 2 + attempt * 2));
      }
    }
    throw last!;
  }

  Future<Map<String, dynamic>> _authed(
    String wallet,
    Future<Response<dynamic>> Function(Options options) send,
  ) async {
    Options opts(String token) =>
        Options(headers: {'Authorization': 'Bearer $token'});
    final token = await _session(wallet);
    try {
      return await _request(() => send(opts(token)));
    } on DreamApiException catch (e) {
      // Expired/rotated server secret: get a fresh session and retry once.
      if (e.statusCode != 401) rethrow;
      _sessionToken = null;
      return _request(() async => send(opts(await _session(wallet))));
    }
  }

  Future<String> _session(String wallet) {
    final valid =
        _sessionToken != null &&
        _sessionWallet == wallet &&
        _sessionExpiresAt != null &&
        DateTime.now().isBefore(
          _sessionExpiresAt!.subtract(const Duration(minutes: 2)),
        );
    if (valid) return Future.value(_sessionToken!);
    // Coalesce concurrent callers into one wallet prompt.
    return _sessionInFlight ??= _openSession(wallet).whenComplete(() {
      _sessionInFlight = null;
    });
  }

  Future<String> _openSession(String wallet) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final message = 'dream-session:v1:$wallet:$timestamp';

    final isMwa =
        _phoenixAuthService.persistedWalletType == 'mwa' &&
        _mwaService.connectedPublicKey == wallet;

    String? signature;
    if (isMwa) {
      final result = await _mwaService.signMessage(message);
      if (result.success && result.signature != null) {
        signature = _base64(result.signature!);
      }
    } else {
      final privyWallet = await _privyWallet.getOrCreateWallet();
      if (privyWallet != null && privyWallet.address == wallet) {
        signature = await _privyWallet.signMessage(privyWallet, message);
      }
    }
    if (signature == null || signature.isEmpty) {
      throw const DreamApiException('Your wallet didn’t sign in to Dreams');
    }

    final data = await _request(
      () => _dio.post(
        '/v1/dreams/session',
        data: {
          'wallet': wallet,
          'signature': signature,
          'timestamp': timestamp,
        },
      ),
    );
    final token = data['token'] as String?;
    final expiresAt = DateTime.tryParse(data['expiresAt'] as String? ?? '');
    if (token == null || expiresAt == null) {
      throw const DreamApiException('Couldn’t start a Dreams session');
    }
    _sessionToken = token;
    _sessionWallet = wallet;
    _sessionExpiresAt = expiresAt;
    return token;
  }

  static String _base64(List<int> bytes) => base64Encode(bytes);

  Future<Map<String, dynamic>> _request(
    Future<Response<dynamic>> Function() send,
  ) async {
    try {
      final resp = await send();
      final data = resp.data;
      if (data is Map<String, dynamic>) return data;
      throw const DreamApiException('Unexpected server response');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final message = body is Map && body['error'] is String
          ? body['error'] as String
          : (e.type == DioExceptionType.connectionError ||
                    e.type == DioExceptionType.connectionTimeout
                ? 'Can’t reach Dream right now. Check your connection.'
                : 'Something went wrong. Please try again.');
      _logger.warning('dreams API $status: $message', tag: '[DreamApi]');
      throw DreamApiException(message, statusCode: status);
    }
  }
}
