import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/phoenix/phoenix_models.dart';
import '../../services/logger_service.dart';
import '../../services/phoenix/phoenix_auth_service.dart';
import '../../services/wallet/mwa_wallet_service.dart';
import '../auth/client_auth_provider.dart';
import '../../../shared/models/user.dart';

// =============================================================================
// State
// =============================================================================

enum PhoenixAuthStatus {
  /// Not yet checked — initial state before [PhoenixAuthNotifier.build] runs
  initial,

  /// Loading stored session or authenticating
  loading,

  /// Phoenix JWT is valid and ready to use
  authenticated,

  /// Not authenticated with Phoenix yet (but may be authenticated with Privy)
  unauthenticated,

  /// Wallet signature required — happens when both JWT and refresh token expire
  /// for MWA users who need to reconnect their wallet
  reauthRequired,

  /// Unrecoverable error (e.g. network failure during initial auth)
  error,
}

class PhoenixAuthState {
  final PhoenixAuthStatus status;
  final PhoenixSession? session;
  final String? error;

  const PhoenixAuthState({required this.status, this.session, this.error});

  /// `true` when a valid access token is available for API calls
  bool get isAuthenticated => status == PhoenixAuthStatus.authenticated;

  /// The bearer token to include in `Authorization: Bearer {token}` headers
  String? get accessToken => session?.accessToken;

  /// `true` when the user must reconnect their wallet (MWA refresh expired)
  bool get needsReauth => status == PhoenixAuthStatus.reauthRequired;

  PhoenixAuthState copyWith({
    PhoenixAuthStatus? status,
    PhoenixSession? session,
    String? error,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return PhoenixAuthState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  String toString() =>
      'PhoenixAuthState(status=$status, hasToken=${session != null})';
}

// =============================================================================
// Notifier
// =============================================================================

/// Manages the Phoenix perpetual-futures authentication session.
///
/// Responsibilities:
/// - Automatically authenticate when `clientAuthProvider` becomes authenticated
/// - Transparently refresh JWT tokens (no user interaction)
/// - Signal when wallet re-auth is needed (MWA refresh token expired)
/// - Expose [accessToken] for use in all Phoenix API service providers
///
/// Usage in feature providers:
/// ```dart
/// final token = ref.watch(phoenixAuthProvider).accessToken;
/// if (token == null) return; // not ready
/// ```
class PhoenixAuthNotifier extends Notifier<PhoenixAuthState> {
  late final PhoenixAuthService _authService;
  late final MwaWalletService _mwaService;
  late final LoggerService _logger;

  @override
  PhoenixAuthState build() {
    _authService = ref.watch(phoenixAuthServiceProvider);
    _mwaService = ref.watch(mwaWalletServiceProvider);
    _logger = ref.watch(loggerServiceProvider);

    // React to changes in the app-level auth state
    ref.listen<AuthStateData>(
      clientAuthProvider,
      (previous, next) => _onAppAuthChanged(previous, next),
      fireImmediately: true,
    );

    return const PhoenixAuthState(status: PhoenixAuthStatus.initial);
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Ensure a valid Phoenix session exists.
  ///
  /// Call this before making authenticated Phoenix API requests.
  /// Returns `true` if session is ready; `false` if re-auth is required.
  Future<bool> ensureAuthenticated() async {
    if (state.isAuthenticated) return true;

    final appAuth = ref.read(clientAuthProvider);
    if (!appAuth.isAuthenticated || appAuth.walletAddress == null) {
      return false;
    }

    await _initPhoenixSession(appAuth.walletAddress!);
    return state.isAuthenticated;
  }

  /// Trigger a fresh Phoenix authentication (signs nonce with wallet).
  ///
  /// Use when [needsReauth] is `true` — i.e., both JWT and refresh token have
  /// expired. For MWA users this will show the wallet app prompt.
  Future<void> authenticate() async {
    final appAuth = ref.read(clientAuthProvider);
    if (!appAuth.isAuthenticated || appAuth.walletAddress == null) {
      state = state.copyWith(
        status: PhoenixAuthStatus.error,
        error: 'App authentication required before Phoenix auth',
      );
      return;
    }

    await _initPhoenixSession(appAuth.walletAddress!, forceRefresh: true);
  }

  /// Clear the Phoenix session (call alongside app-level sign-out).
  Future<void> signOut() async {
    await _authService.clearStoredSession();
    state = const PhoenixAuthState(status: PhoenixAuthStatus.unauthenticated);
    _logger.info('Phoenix session cleared', tag: 'PhoenixAuthProvider');
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _onAppAuthChanged(
    AuthStateData? previous,
    AuthStateData next,
  ) async {
    if (next.state == AuthState.unauthenticated) {
      // App signed out — clear Phoenix session too
      await signOut();
      return;
    }

    if (next.state == AuthState.authenticated && next.walletAddress != null) {
      // Only run Phoenix init when the wallet address changes or we're still initial
      final addressChanged = previous?.walletAddress != next.walletAddress;
      final isInitial = state.status == PhoenixAuthStatus.initial;

      if (isInitial || addressChanged) {
        await _initPhoenixSession(next.walletAddress!);
      }
    }
  }

  Future<void> _initPhoenixSession(
    String walletAddress, {
    bool forceRefresh = false,
  }) async {
    state = state.copyWith(status: PhoenixAuthStatus.loading, clearError: true);

    try {
      // If not forcing a fresh auth, try stored/refreshed session first
      if (!forceRefresh) {
        final stored = await _authService.getStoredSession();
        if (stored != null) {
          _logger.info(
            'Phoenix session restored from storage',
            tag: 'PhoenixAuthProvider',
          );
          state = state.copyWith(
            status: PhoenixAuthStatus.authenticated,
            session: stored,
          );
          return;
        }
      }

      // Need to sign with the wallet — determine type
      final usesMwa = _detectWalletType(walletAddress);

      _logger.info(
        'Authenticating with Phoenix [mwa=$usesMwa]',
        tag: 'PhoenixAuthProvider',
      );

      final session = await _authService.authenticate(
        walletAddress: walletAddress,
        usesMwa: usesMwa,
      );

      state = state.copyWith(
        status: PhoenixAuthStatus.authenticated,
        session: session,
      );
    } on PhoenixAuthException catch (e) {
      _logger.error(
        'Phoenix auth exception: ${e.message}',
        tag: 'PhoenixAuthProvider',
      );
      // If MWA signing failed it may mean wallet is disconnected
      final isMwaError =
          e.message.toLowerCase().contains('mwa') ||
          e.message.toLowerCase().contains('wallet');
      state = state.copyWith(
        status: isMwaError
            ? PhoenixAuthStatus.reauthRequired
            : PhoenixAuthStatus.error,
        error: e.message,
        clearSession: true,
      );
    } catch (e, st) {
      _logger.error(
        'Unexpected Phoenix auth error',
        error: e,
        stackTrace: st,
        tag: 'PhoenixAuthProvider',
      );
      state = state.copyWith(
        status: PhoenixAuthStatus.error,
        error: e.toString(),
        clearSession: true,
      );
    }
  }

  /// Determine whether signing should go through MWA or Privy embedded wallet.
  ///
  /// Priority:
  /// 1. Live in-memory MWA connection matches [walletAddress] → MWA
  /// 2. Persisted wallet type from previous session → use that
  /// 3. Default → Privy embedded wallet
  bool _detectWalletType(String walletAddress) {
    // 1. Active MWA connection in this process session
    if (_mwaService.connectedPublicKey == walletAddress) {
      return true;
    }

    // 2. Stored wallet type from last successful Phoenix auth
    final stored = _authService.persistedWalletType;
    if (stored == 'mwa') {
      // Verify MWA service still has a connection; if not, signal re-auth
      if (_mwaService.connectedPublicKey == null) {
        _logger.warning(
          'MWA wallet type stored but MWA is not connected — '
          'will attempt Privy fallback or require re-auth',
          tag: 'PhoenixAuthProvider',
        );
        // Fall through to Privy: user must reconnect MWA if signing fails
      }
      return _mwaService.connectedPublicKey != null;
    }

    // 3. Default to Privy embedded wallet
    return false;
  }
}

// =============================================================================
// Provider
// =============================================================================

final phoenixAuthProvider =
    NotifierProvider<PhoenixAuthNotifier, PhoenixAuthState>(
      PhoenixAuthNotifier.new,
    );
