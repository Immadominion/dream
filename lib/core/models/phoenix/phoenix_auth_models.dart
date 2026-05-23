import 'package:equatable/equatable.dart';

/// A stored Phoenix JWT session (access + refresh tokens)
class PhoenixSession extends Equatable {
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final DateTime? refreshExpiresAt;

  const PhoenixSession({
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
    this.refreshExpiresAt,
  });

  /// Access token is still valid (with 60s buffer)
  bool get isValid =>
      accessToken.isNotEmpty &&
      DateTime.now().isBefore(expiresAt.subtract(const Duration(seconds: 60)));

  /// Refresh token can be used to get a new access token
  bool get canRefresh {
    if (refreshToken == null || refreshExpiresAt == null) return false;
    return DateTime.now().isBefore(
      refreshExpiresAt!.subtract(const Duration(seconds: 60)),
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
    'refreshExpiresAt': refreshExpiresAt?.toIso8601String(),
  };

  factory PhoenixSession.fromJson(Map<String, dynamic> json) => PhoenixSession(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String?,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    refreshExpiresAt: json['refreshExpiresAt'] != null
        ? DateTime.parse(json['refreshExpiresAt'] as String)
        : null,
  );

  @override
  List<Object?> get props => [
    accessToken,
    refreshToken,
    expiresAt,
    refreshExpiresAt,
  ];
}

/// Response from GET /v1/auth/nonce
class PhoenixNonceResponse {
  final String nonce;
  final String nonceId;

  const PhoenixNonceResponse({required this.nonce, required this.nonceId});

  factory PhoenixNonceResponse.fromJson(Map<String, dynamic> json) =>
      PhoenixNonceResponse(
        nonce: (json['nonce'] ?? json['message'] ?? '') as String,
        nonceId: (json['nonce_id'] ?? json['id'] ?? '') as String,
      );
}

/// Response from POST /v1/auth/login/wallet or /v1/auth/refresh
class PhoenixAuthResponse {
  final String accessToken;
  final String? refreshToken;
  final int expiresIn;
  final int refreshExpiresIn;
  final String tokenType;

  const PhoenixAuthResponse({
    required this.accessToken,
    this.refreshToken,
    required this.expiresIn,
    required this.refreshExpiresIn,
    required this.tokenType,
  });

  factory PhoenixAuthResponse.fromJson(Map<String, dynamic> json) =>
      PhoenixAuthResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String?,
        expiresIn: (json['expires_in'] as num).toInt(),
        refreshExpiresIn: (json['refresh_expires_in'] as num).toInt(),
        tokenType: (json['token_type'] as String?) ?? 'Bearer',
      );
}
