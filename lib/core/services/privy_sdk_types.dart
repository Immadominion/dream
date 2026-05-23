import 'package:privy_flutter/privy_flutter.dart' as privy;

/// Enum representing different login methods available
enum LoginMethod {
  google,
  apple,
  twitter,
  discord,
  email;

  /// Convert to Privy's OAuth provider type
  privy.OAuthProvider toPrivyOAuth() {
    switch (this) {
      case LoginMethod.google:
        return privy.OAuthProvider.google;
      case LoginMethod.apple:
        return privy.OAuthProvider.apple;
      case LoginMethod.twitter:
        return privy.OAuthProvider.twitter;
      case LoginMethod.discord:
        return privy.OAuthProvider.discord;
      case LoginMethod.email:
        throw UnsupportedError('Email login does not use OAuth');
    }
  }
}

/// Result of Privy authentication
class PrivyAuthResult {
  const PrivyAuthResult({
    required this.success,
    this.userId,
    this.walletAddress,
    this.error,
  });

  final bool success;
  final String? userId;
  final String? walletAddress;
  final String? error;

  factory PrivyAuthResult.success({
    required String userId,
    String? walletAddress,
  }) {
    return PrivyAuthResult(
      success: true,
      userId: userId,
      walletAddress: walletAddress,
    );
  }

  factory PrivyAuthResult.failure(String error) {
    return PrivyAuthResult(success: false, error: error);
  }
}

/// Generic success/failure result for non-auth Privy operations
class PrivyOperationResult {
  const PrivyOperationResult._({required this.success, this.error});

  final bool success;
  final String? error;

  factory PrivyOperationResult.success() {
    return const PrivyOperationResult._(success: true);
  }

  factory PrivyOperationResult.failure(String error) {
    return PrivyOperationResult._(success: false, error: error);
  }
}

/// Result of SIWS message generation
class SiwsMessageResult {
  const SiwsMessageResult._({required this.success, this.message, this.error});

  final bool success;
  final String? message;
  final String? error;

  factory SiwsMessageResult.success(String message) {
    return SiwsMessageResult._(success: true, message: message);
  }

  factory SiwsMessageResult.failure(String error) {
    return SiwsMessageResult._(success: false, error: error);
  }
}
