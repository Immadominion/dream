import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privy_flutter/privy_flutter.dart' as privy;

import '../constants/app_constants.dart';
import 'logger_service.dart';
import 'privy_sdk_types.dart';

export 'privy_sdk_types.dart';

/// Service for handling Privy authentication with Flutter SDK
class PrivySdkService {
  PrivySdkService(this._logger) {
    _initializePrivy();
  }

  final LoggerService _logger;
  late final privy.Privy _privy;
  bool _isInitialized = false;

  /// Initialize Privy SDK
  void _initializePrivy() {
    try {
      final appId = AppConstants.privyAppId;
      final clientId = AppConstants.privyClientId;

      if (appId.isEmpty) {
        throw Exception('PRIVY_APP_ID not configured');
      }

      if (clientId.isEmpty) {
        throw Exception('PRIVY_CLIENT_ID not configured');
      }

      final privyConfig = privy.PrivyConfig(
        appId: appId,
        appClientId: clientId,
        logLevel: privy.PrivyLogLevel.verbose,
      );

      _privy = privy.Privy.init(config: privyConfig);
      _isInitialized = true;

      _logger.info('Privy SDK initialized successfully', tag: 'PrivySDK');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to initialize Privy SDK',
        error: e,
        stackTrace: stackTrace,
        tag: 'PrivySDK',
      );
      _isInitialized = false;
    }
  }

  /// Wait for Privy to be ready
  Future<void> waitForReady() async {
    if (!_isInitialized) {
      throw StateError('Privy SDK not initialized');
    }

    try {
      await _privy.awaitReady();
      _logger.info('Privy SDK is ready', tag: 'PrivySDK');
    } catch (e, stackTrace) {
      _logger.error(
        'Error waiting for Privy',
        error: e,
        stackTrace: stackTrace,
        tag: 'PrivySDK',
      );
      rethrow;
    }
  }

  /// Check if user is currently authenticated
  Future<bool> isAuthenticated() async {
    if (!_isInitialized) return false;

    try {
      final authState = await refreshAuthState();
      return authState?.isAuthenticated ?? false;
    } catch (e, stackTrace) {
      _logger.error(
        'Error checking auth status',
        error: e,
        stackTrace: stackTrace,
        tag: 'PrivySDK',
      );
      return false;
    }
  }

  /// Refresh and return the latest Privy authentication state
  Future<privy.AuthState?> refreshAuthState() async {
    if (!_isInitialized) return null;

    try {
      await waitForReady();
      final authState = await _privy.getAuthState();
      return authState;
    } catch (e, stackTrace) {
      _logger.error(
        'Error refreshing auth state',
        error: e,
        stackTrace: stackTrace,
        tag: 'PrivySDK',
      );
      return null;
    }
  }

  /// Get current user
  Future<privy.PrivyUser?> getCurrentUser() async {
    if (!_isInitialized) return null;

    try {
      await waitForReady();
      final user = await _privy.getUser();
      return user;
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting current user',
        error: e,
        stackTrace: stackTrace,
        tag: 'PrivySDK',
      );
      return null;
    }
  }

  /// Retrieve the Privy access token (JWT) for the authenticated session
  Future<String?> getAccessToken({privy.PrivyUser? cachedUser}) async {
    if (!_isInitialized) return null;

    try {
      await waitForReady();
      final user = cachedUser ?? await _privy.getUser();

      if (user == null) {
        _logger.warning(
          'Cannot read access token: no authenticated user',
          tag: 'PrivySDK',
        );
        return null;
      }

      final result = await user.getAccessToken();

      if (result is privy.Success<String>) {
        final token = result.value.trim();
        if (token.isNotEmpty) {
          return token;
        }
      } else if (result is privy.Failure) {
        _logger.error(
          'Failed to fetch access token from Privy user',
          error: result,
          tag: 'PrivySDK',
        );
      }

      _logger.warning(
        'Privy access token unavailable after authentication',
        tag: 'PrivySDK',
      );
      return null;
    } catch (e, stackTrace) {
      _logger.error(
        'Error retrieving access token',
        error: e,
        stackTrace: stackTrace,
        tag: 'PrivySDK',
      );
      return null;
    }
  }

  /// Ensure the authenticated user has an embedded Solana wallet
  Future<privy.EmbeddedSolanaWallet?> ensureEmbeddedSolanaWallet() async {
    if (!_isInitialized) {
      _logger.error(
        'Cannot ensure wallet: Privy SDK not initialized',
        tag: 'PrivySDK',
      );
      return null;
    }

    try {
      await waitForReady();

      var user = await _privy.getUser();
      if (user == null) {
        _logger.error(
          'Cannot ensure wallet: no authenticated user',
          tag: 'PrivySDK',
        );
        return null;
      }

      if (user.embeddedSolanaWallets.isNotEmpty) {
        final wallet = user.embeddedSolanaWallets.first;
        _logger.info(
          'Found existing embedded wallet: ${wallet.address}',
          tag: 'PrivySDK',
        );
        return wallet;
      }

      _logger.info('Creating new embedded Solana wallet', tag: 'PrivySDK');
      final creationResult = await user.createSolanaWallet();

      if (creationResult is privy.Success<privy.EmbeddedSolanaWallet>) {
        final wallet = creationResult.value;
        _logger.info(
          'Created new embedded wallet: ${wallet.address}',
          tag: 'PrivySDK',
        );
        return wallet;
      }

      if (creationResult is privy.Failure) {
        _logger.error(
          'Failed to create embedded wallet',
          error: creationResult,
          tag: 'PrivySDK',
        );
      }

      // Refresh user in case wallet was created but response not returned
      user = await _privy.getUser();
      if (user?.embeddedSolanaWallets.isNotEmpty ?? false) {
        final wallet = user!.embeddedSolanaWallets.first;
        _logger.info(
          'Embedded wallet available after refresh: ${wallet.address}',
          tag: 'PrivySDK',
        );
        return wallet;
      }

      _logger.error(
        'Unable to provision embedded Solana wallet',
        tag: 'PrivySDK',
      );
      return null;
    } catch (e, stackTrace) {
      _logger.error(
        'Error ensuring embedded wallet',
        error: e,
        stackTrace: stackTrace,
        tag: 'PrivySDK',
      );
      return null;
    }
  }

  /// Authenticate user with OAuth provider (Google, Apple, Twitter, Discord)
  Future<PrivyAuthResult> authenticate(LoginMethod method) async {
    if (!_isInitialized) {
      return PrivyAuthResult.failure('Privy SDK not initialized');
    }

    try {
      _logger.info(
        'Starting authentication with method: $method',
        tag: 'PrivySDK',
      );

      if (method == LoginMethod.email) {
        _logger.error('Email login requires OTP flow', tag: 'PrivySDK');
        return PrivyAuthResult.failure(
          'Email login requires verification code',
        );
      }

      final result = await _privy.oAuth.login(
        provider: method.toPrivyOAuth(),
        appUrlScheme: 'dreamapp', // Matches AndroidManifest.xml and Info.plist
      );

      late PrivyAuthResult authResult;

      result.fold(
        onSuccess: (privy.PrivyUser user) {
          authResult = _mapUserToAuthResult(user);
        },
        onFailure: (privy.PrivyException error) {
          _logger.error(
            'OAuth login failed: ${error.message}',
            tag: 'PrivySDK',
          );
          authResult = PrivyAuthResult.failure(error.message);
        },
      );

      return authResult;
    } catch (e, stackTrace) {
      _logger.error(
        'Authentication error',
        error: e,
        stackTrace: stackTrace,
        tag: 'PrivySDK',
      );
      return PrivyAuthResult.failure(e.toString());
    }
  }

  /// Send an email OTP via Privy
  Future<PrivyOperationResult> sendEmailCode(String email) async {
    if (!_isInitialized) {
      return PrivyOperationResult.failure('Privy SDK not initialized');
    }

    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      return PrivyOperationResult.failure('Email is required');
    }

    try {
      await waitForReady();
      final result = await _privy.email.sendCode(trimmedEmail);

      late PrivyOperationResult operationResult;

      result.fold(
        onSuccess: (_) {
          _logger.info('OTP sent to email $trimmedEmail', tag: 'PrivySDK');
          operationResult = PrivyOperationResult.success();
        },
        onFailure: (privy.PrivyException error) {
          _logger.error(
            'Failed to send email OTP: ${error.message}',
            tag: 'PrivySDK',
          );
          operationResult = PrivyOperationResult.failure(error.message);
        },
      );

      return operationResult;
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending email OTP',
        error: e,
        stackTrace: stackTrace,
        tag: 'PrivySDK',
      );
      return PrivyOperationResult.failure(e.toString());
    }
  }

  /// Verify an email OTP and authenticate the user
  Future<PrivyAuthResult> loginWithEmailCode({
    required String email,
    required String code,
  }) async {
    if (!_isInitialized) {
      return PrivyAuthResult.failure('Privy SDK not initialized');
    }

    final trimmedEmail = email.trim();
    final trimmedCode = code.trim();

    if (trimmedEmail.isEmpty || trimmedCode.isEmpty) {
      return PrivyAuthResult.failure('Email and code are required');
    }

    try {
      await waitForReady();
      final result = await _privy.email.loginWithCode(
        email: trimmedEmail,
        code: trimmedCode,
      );

      late PrivyAuthResult authResult;

      result.fold(
        onSuccess: (privy.PrivyUser user) {
          authResult = _mapUserToAuthResult(user);
        },
        onFailure: (privy.PrivyException error) {
          _logger.error(
            'Email OTP verification failed: ${error.message}',
            tag: 'PrivySDK',
          );
          authResult = PrivyAuthResult.failure(error.message);
        },
      );

      return authResult;
    } catch (e, stackTrace) {
      _logger.error(
        'Email OTP verification error',
        error: e,
        stackTrace: stackTrace,
        tag: 'PrivySDK',
      );
      return PrivyAuthResult.failure(e.toString());
    }
  }

  /// Logout the current user
  Future<void> logout() async {
    if (!_isInitialized) return;

    try {
      await waitForReady();
      await _privy.logout();
      _logger.info('User logged out successfully', tag: 'PrivySDK');
    } catch (e, stackTrace) {
      _logger.error(
        'Logout error',
        error: e,
        stackTrace: stackTrace,
        tag: 'PrivySDK',
      );
      rethrow;
    }
  }

  /// Generate a SIWS (Sign-In With Solana) message
  /// Used for wallet-based authentication
  Future<SiwsMessageResult> generateSiwsMessage(String walletAddress) async {
    if (!_isInitialized) {
      return SiwsMessageResult.failure('Privy SDK not initialized');
    }

    try {
      await waitForReady();

      _logger.info(
        'Generating SIWS message for wallet: $walletAddress',
        tag: 'PrivySDK',
      );

      // Create SIWS message params
      final params = privy.SiwsMessageParams(
        appDomain: 'dream.app',
        appUri: 'https://dream.app',
        walletAddress: walletAddress,
      );

      // Generate the message
      final result = await _privy.siws.generateMessage(params);

      late SiwsMessageResult messageResult;

      result.fold(
        onSuccess: (String message) {
          _logger.info('SIWS message generated', tag: 'PrivySDK');
          messageResult = SiwsMessageResult.success(message);
        },
        onFailure: (privy.PrivyException error) {
          _logger.error(
            'Failed to generate SIWS message: ${error.message}',
            tag: 'PrivySDK',
          );
          messageResult = SiwsMessageResult.failure(error.message);
        },
      );

      return messageResult;
    } catch (e, stackTrace) {
      _logger.error(
        'SIWS message generation error',
        error: e,
        stackTrace: stackTrace,
        tag: 'PrivySDK',
      );
      return SiwsMessageResult.failure(e.toString());
    }
  }

  /// Login with SIWS (Sign-In With Solana)
  /// Requires a signed message from an external wallet
  Future<PrivyAuthResult> loginWithSiws({
    required String message,
    required String signatureBase64,
    required String walletAddress,
    String? walletClientType,
  }) async {
    if (!_isInitialized) {
      return PrivyAuthResult.failure('Privy SDK not initialized');
    }

    try {
      await waitForReady();

      _logger.info('Logging in with SIWS', tag: 'PrivySDK');

      // Create SIWS message params (same as used for generation)
      final params = privy.SiwsMessageParams(
        appDomain: 'dream.app',
        appUri: 'https://dream.app',
        walletAddress: walletAddress,
      );

      // Create wallet metadata
      final metadata = privy.WalletLoginMetadata(
        walletClientType: _mapWalletClientType(walletClientType),
        connectorType: 'mobile_wallet_adapter',
      );

      // Login with SIWS
      final result = await _privy.siws.login(
        message: message,
        signature: signatureBase64,
        params: params,
        metadata: metadata,
      );

      late PrivyAuthResult authResult;

      result.fold(
        onSuccess: (privy.PrivyUser user) {
          authResult = _mapUserToAuthResult(user);
          _logger.info('SIWS login successful', tag: 'PrivySDK');
        },
        onFailure: (privy.PrivyException error) {
          _logger.error('SIWS login failed: ${error.message}', tag: 'PrivySDK');
          authResult = PrivyAuthResult.failure(error.message);
        },
      );

      return authResult;
    } catch (e, stackTrace) {
      _logger.error(
        'SIWS login error',
        error: e,
        stackTrace: stackTrace,
        tag: 'PrivySDK',
      );
      return PrivyAuthResult.failure(e.toString());
    }
  }

  /// Map wallet client type string to Privy enum
  privy.WalletClientType _mapWalletClientType(String? type) {
    // Try to get from string first
    final fromString = privy.WalletClientType.fromString(type?.toLowerCase());
    if (fromString != null) {
      return fromString;
    }
    // Default to 'other' for MWA wallets
    return privy.WalletClientType.other;
  }

  /// Get the Privy instance for advanced use cases
  privy.Privy get instance {
    if (!_isInitialized) {
      throw StateError('Privy SDK not initialized');
    }
    return _privy;
  }

  PrivyAuthResult _mapUserToAuthResult(privy.PrivyUser user) {
    String? walletAddress;
    try {
      if (user.embeddedSolanaWallets.isNotEmpty) {
        walletAddress = user.embeddedSolanaWallets.first.address;
      }
    } catch (_) {
      // Ignore SDK variations.
    }

    if (walletAddress == null) {
      for (final account in user.linkedAccounts) {
        final dynamic dynAccount = account;
        try {
          final addr = dynAccount.address?.toString().trim();
          if (addr != null && addr.isNotEmpty) {
            walletAddress = addr;
            break;
          }
        } catch (_) {
          // Ignore non-wallet linked accounts.
        }
      }
    }

    _logger.info(
      'Login successful: userId=${user.id}, wallet=$walletAddress',
      tag: 'PrivySDK',
    );

    return PrivyAuthResult.success(
      userId: user.id,
      walletAddress: walletAddress,
    );
  }
}

/// Provider for PrivySdkService
final privySdkServiceProvider = Provider<PrivySdkService>((ref) {
  final logger = ref.watch(loggerServiceProvider);
  return PrivySdkService(logger);
});

/// Provider for current authentication state
final privyAuthStateProvider = StreamProvider<privy.AuthState>((ref) async* {
  final service = ref.watch(privySdkServiceProvider);

  try {
    await for (final state in service.instance.authStateStream) {
      yield state;
    }
  } catch (e, stackTrace) {
    ref
        .read(loggerServiceProvider)
        .error(
          'Error in auth state stream',
          error: e,
          stackTrace: stackTrace,
          tag: 'PrivySDK',
        );
    rethrow;
  }
});

/// Provider to check if user is authenticated via Privy
final privyIsAuthenticatedProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(privySdkServiceProvider);
  return service.isAuthenticated();
});

/// Provider for current Privy user
final privyCurrentUserProvider = FutureProvider<privy.PrivyUser?>((ref) async {
  final service = ref.watch(privySdkServiceProvider);
  return service.getCurrentUser();
});
