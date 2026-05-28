import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privy_flutter/privy_flutter.dart' as privy;

import '../../../shared/models/user.dart';
import '../../services/auth/session_manager.dart';
import '../../services/logger_service.dart';
import '../../services/privy_sdk_service.dart';
import '../../services/wallet/mwa_wallet_service.dart';
import '../../services/wallet/privy_wallet_manager.dart';
import 'auth_state_data.dart';

// Re-export so existing consumers keep working without import changes.
export 'auth_state_data.dart';

/// Client-only auth state notifier using Riverpod 3.x Notifier pattern
/// NO backend calls - only Privy SDK + local storage
class ClientAuthNotifier extends Notifier<AuthStateData> {
  late final PrivySdkService _privySdk;
  late final PrivyWalletManager _walletManager;
  late final MwaWalletService _mwaService;
  late final AuthSessionManager _sessionManager;
  late final LoggerService _logger;

  @override
  AuthStateData build() {
    _privySdk = ref.watch(privySdkServiceProvider);
    _walletManager = ref.watch(privyWalletManagerProvider);
    _mwaService = ref.watch(mwaWalletServiceProvider);
    _logger = ref.watch(loggerServiceProvider);
    _sessionManager = AuthSessionManager(_logger);

    // Initialize immediately without blocking
    Future.microtask(_initialize);

    return const AuthStateData(state: AuthState.initial);
  }

  /// Fast initialization - just checks if Privy SDK has active session
  Future<void> _initialize() async {
    try {
      _logger.info('Initializing auth state', tag: 'ClientAuth');

      // Quick check: is user authenticated with Privy?
      final isAuth = await _privySdk.isAuthenticated();

      if (!isAuth) {
        _logger.info('No Privy session found', tag: 'ClientAuth');
        state = state.copyWith(
          state: AuthState.unauthenticated,
          isInitialized: true,
          clearSession: true,
        );
        return;
      }

      // Load session from storage (fast, no network)
      final session = await _sessionManager.loadSession();

      if (session == null || !session.isValid) {
        _logger.warning(
          'Local session missing or expired; attempting Privy restore',
          tag: 'ClientAuth',
        );

        final restoredSession = await _rebuildSessionFromPrivy();
        if (restoredSession == null) {
          state = state.copyWith(
            state: AuthState.unauthenticated,
            isInitialized: true,
            clearSession: true,
          );
          return;
        }

        state = state.copyWith(
          state: AuthState.authenticated,
          session: restoredSession,
          isInitialized: true,
        );
        return;
      }

      // Valid session found
      _logger.info('Valid session restored', tag: 'ClientAuth');
      state = state.copyWith(
        state: AuthState.authenticated,
        session: session,
        isInitialized: true,
      );
    } catch (error) {
      _logger.error('Auth initialization failed', error: error);
      state = state.copyWith(
        state: AuthState.error,
        error: error.toString(),
        isInitialized: true,
      );
    }
  }

  /// Sign in with OAuth (Google, Apple, Twitter, Discord)
  Future<void> signInWithOAuth(LoginMethod method) async {
    state = state.copyWith(state: AuthState.loading);

    try {
      _logger.info('OAuth sign-in: \$method', tag: 'ClientAuth');

      // Step 1: Authenticate with Privy
      final privyResult = await _privySdk.authenticate(method);
      if (!privyResult.success) {
        throw Exception(privyResult.error ?? 'OAuth failed');
      }

      // Step 2: Get user details
      final privyUser = await _privySdk.getCurrentUser();
      if (privyUser == null) {
        throw Exception('No user after OAuth');
      }

      // Step 3: Ensure wallet exists
      final wallet = await _walletManager.getOrCreateWallet();
      if (wallet == null) {
        throw Exception('Failed to create wallet');
      }

      // Step 4: Create session (NO backend call)
      final session = await _createLocalSession(privyUser, wallet.address);

      // Step 5: Save session
      await _sessionManager.saveSession(session);

      _logger.info('OAuth sign-in complete', tag: 'ClientAuth');
      state = state.copyWith(state: AuthState.authenticated, session: session);
    } catch (error) {
      _logger.error('OAuth sign-in failed', error: error);
      state = state.copyWith(state: AuthState.error, error: error.toString());
    }
  }

  /// Request email OTP
  Future<void> requestEmailOtp(String email) async {
    try {
      _logger.info('Requesting OTP for email', tag: 'ClientAuth');
      final result = await _privySdk.sendEmailCode(email);

      if (!result.success) {
        throw Exception(result.error ?? 'Failed to send OTP');
      }

      _logger.info('OTP sent successfully', tag: 'ClientAuth');
    } catch (error) {
      _logger.error('OTP request failed', error: error);
      rethrow;
    }
  }

  /// Verify email OTP and sign in
  Future<void> verifyEmailOtp(String email, String code) async {
    state = state.copyWith(state: AuthState.loading);

    try {
      _logger.info('Verifying OTP', tag: 'ClientAuth');

      // Step 1: Verify with Privy
      final privyResult = await _privySdk.loginWithEmailCode(
        email: email,
        code: code,
      );

      if (!privyResult.success) {
        throw Exception(privyResult.error ?? 'OTP verification failed');
      }

      // Step 2: Get user details
      final privyUser = await _privySdk.getCurrentUser();
      if (privyUser == null) {
        throw Exception('No user after OTP verification');
      }

      // Step 3: Ensure wallet exists
      final wallet = await _walletManager.getOrCreateWallet();
      if (wallet == null) {
        throw Exception('Failed to create wallet');
      }

      // Step 4: Create session (NO backend call)
      final session = await _createLocalSession(privyUser, wallet.address);

      // Step 5: Save session
      await _sessionManager.saveSession(session);

      _logger.info('Email OTP sign-in complete', tag: 'ClientAuth');
      state = state.copyWith(state: AuthState.authenticated, session: session);
    } catch (error) {
      _logger.error('OTP verification failed', error: error);
      state = state.copyWith(state: AuthState.error, error: error.toString());
    }
  }

  /// Sign in with external wallet via MWA + SIWS (Android only)
  Future<void> signInWithWallet() async {
    if (!_mwaService.isAvailable) {
      state = state.copyWith(
        state: AuthState.error,
        error: 'Wallet connection is only available on Android',
      );
      return;
    }

    state = state.copyWith(state: AuthState.loading);

    try {
      _logger.info('Starting wallet sign-in via MWA + SIWS', tag: 'ClientAuth');

      // Step 1: Connect wallet via MWA
      final connectionResult = await _mwaService.connectWallet();
      if (!connectionResult.success) {
        throw Exception(connectionResult.error ?? 'Failed to connect wallet');
      }

      final walletAddress = connectionResult.publicKey!;
      final accountLabel = connectionResult.accountLabel;

      _logger.info(
        'Wallet connected: $walletAddress ($accountLabel)',
        tag: 'ClientAuth',
      );

      // Step 2: Generate SIWS message from Privy
      final messageResult = await _privySdk.generateSiwsMessage(walletAddress);
      if (!messageResult.success) {
        throw Exception(
          messageResult.error ?? 'Failed to generate SIWS message',
        );
      }

      final siwsMessage = messageResult.message!;

      // Step 3: Sign the message via MWA
      final signResult = await _mwaService.signMessage(siwsMessage);
      if (!signResult.success) {
        throw Exception(signResult.error ?? 'Failed to sign message');
      }

      // Convert signature to base64 for Privy
      final signatureBase64 = base64Encode(signResult.signature!);

      // Step 4: Login with SIWS via Privy
      final privyResult = await _privySdk.loginWithSiws(
        message: siwsMessage,
        signatureBase64: signatureBase64,
        walletAddress: walletAddress,
        walletClientType: accountLabel,
      );

      if (!privyResult.success) {
        throw Exception(privyResult.error ?? 'SIWS login failed');
      }

      // Step 5: Get Privy user
      final privyUser = await _privySdk.getCurrentUser();
      if (privyUser == null) {
        throw Exception('No user after SIWS login');
      }

      // Step 6: Create session (use connected wallet address)
      final session = await _createLocalSession(privyUser, walletAddress);

      // Step 7: Save session
      await _sessionManager.saveSession(session);

      _logger.info('Wallet sign-in complete', tag: 'ClientAuth');
      state = state.copyWith(state: AuthState.authenticated, session: session);
    } catch (error) {
      _logger.error('Wallet sign-in failed', error: error);
      _mwaService.disconnect();
      state = state.copyWith(state: AuthState.error, error: error.toString());
    }
  }

  /// Sign out
  Future<void> signOut() async {
    state = state.copyWith(state: AuthState.loading);

    try {
      await _privySdk.logout();
      await _sessionManager.clearSession();

      _logger.info('Sign out complete', tag: 'ClientAuth');
      state = state.copyWith(
        state: AuthState.unauthenticated,
        clearSession: true,
      );
    } catch (error) {
      _logger.error('Sign out failed', error: error);
      // Force unauthenticated state even on error
      state = state.copyWith(
        state: AuthState.unauthenticated,
        clearSession: true,
      );
    }
  }

  /// Refresh session (updates expiration)
  Future<void> refreshSession() async {
    try {
      final isAuth = await _privySdk.isAuthenticated();
      if (!isAuth) {
        await signOut();
        return;
      }

      final session = await _rebuildSessionFromPrivy();
      if (session != null) {
        state = state.copyWith(session: session);
        _logger.info('Session refreshed', tag: 'ClientAuth');
      } else {
        await signOut();
      }
    } catch (error) {
      _logger.error('Session refresh failed', error: error);
    }
  }

  Future<AuthSession?> _rebuildSessionFromPrivy() async {
    try {
      final privyUser = await _privySdk.getCurrentUser();
      if (privyUser == null) {
        _logger.warning(
          'Privy user unavailable during restore',
          tag: 'ClientAuth',
        );
        await _sessionManager.clearSession();
        return null;
      }

      final walletAddress = await _resolveWalletAddress(privyUser);
      if (walletAddress == null || walletAddress.isEmpty) {
        _logger.warning('Wallet unavailable during restore', tag: 'ClientAuth');
        await _sessionManager.clearSession();
        return null;
      }

      final session = await _createLocalSession(privyUser, walletAddress);
      await _sessionManager.saveSession(session);
      return session;
    } catch (error) {
      _logger.error('Failed to rebuild session from Privy', error: error);
      await _sessionManager.clearSession();
      return null;
    }
  }

  Future<String?> _resolveWalletAddress(privy.PrivyUser privyUser) async {
    final embeddedWallets = privyUser.embeddedSolanaWallets;
    if (embeddedWallets.isNotEmpty) {
      return embeddedWallets.first.address;
    }

    for (final account in privyUser.linkedAccounts) {
      final dynamic dynAccount = account;
      try {
        final address = dynAccount.address?.toString().trim();
        if (address != null && address.isNotEmpty) {
          return address;
        }
      } catch (_) {
        // Ignore non-wallet linked accounts.
      }
    }

    final storedWallet = await _sessionManager.getWalletAddress();
    if (storedWallet != null && storedWallet.isNotEmpty) {
      return storedWallet;
    }

    final wallet = await _walletManager.getOrCreateWallet();
    return wallet?.address;
  }

  /// Create local session from Privy user (NO backend call)
  Future<AuthSession> _createLocalSession(
    privy.PrivyUser privyUser,
    String walletAddress,
  ) async {
    final email = _extractEmail(privyUser);
    final userId = privyUser.id;

    // Get access token from Privy (for Bags API calls)
    final accessToken = await _privySdk.getAccessToken(cachedUser: privyUser);

    final trimmedToken = accessToken?.trim() ?? '';
    if (trimmedToken.isEmpty) {
      throw Exception('Unable to retrieve Privy access token');
    }

    return AuthSession(
      accessToken: trimmedToken,
      user: User(
        id: userId,
        email: email,
        walletAddress: walletAddress,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      ),
      // Privy is the real auth source; keep the app session generous and
      // rebuild it from Privy when needed instead of forcing a daily re-login.
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
  }

  /// Extract email/identifier from Privy user
  String _extractEmail(privy.PrivyUser privyUser) {
    // Privy account model types can vary by SDK version.
    // Prefer tolerant/dynamic extraction over hard type checks.
    for (final account in privyUser.linkedAccounts) {
      final dynamic dynAccount = account;
      try {
        final email = (dynAccount.email ?? dynAccount.emailAddress)
            ?.toString()
            .trim();
        if (email != null && email.isNotEmpty) {
          return email;
        }

        final phone = dynAccount.phoneNumber?.toString().trim();
        if (phone != null && phone.isNotEmpty) {
          return phone;
        }

        final username = dynAccount.username?.toString().trim();
        if (username != null && username.isNotEmpty) {
          return username;
        }
      } catch (e) {
        _logger.warning(
          'Failed to extract identifier from linked account: \$e',
          tag: 'ClientAuth',
        );
      }
    }

    return 'user_\${privyUser.id}';
  }
}

/// Provider for client-only auth notifier (Riverpod 3.x)
final clientAuthProvider = NotifierProvider<ClientAuthNotifier, AuthStateData>(
  ClientAuthNotifier.new,
);
