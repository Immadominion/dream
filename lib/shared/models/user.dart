import 'package:equatable/equatable.dart';

/// User entity representing authenticated user
class User extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? walletAddress;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isEmailVerified;
  final Map<String, dynamic>? metadata;

  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.walletAddress,
    required this.createdAt,
    this.lastLoginAt,
    this.isEmailVerified = false,
    this.metadata,
  });

  /// Create User from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      walletAddress: json['walletAddress'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert User to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'walletAddress': walletAddress,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isEmailVerified': isEmailVerified,
      'metadata': metadata,
    };
  }

  /// Create copy with updated fields
  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? walletAddress,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isEmailVerified,
    Map<String, dynamic>? metadata,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      walletAddress: walletAddress ?? this.walletAddress,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Check if user has connected wallet
  bool get hasWallet => walletAddress != null && walletAddress!.isNotEmpty;

  /// Get display name or email fallback
  String get displayNameOrEmail => displayName ?? email;

  /// Get initials for avatar
  String get initials {
    final name = displayName ?? email;
    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else {
      return name.substring(0, 1).toUpperCase();
    }
  }

  @override
  List<Object?> get props => [
    id,
    email,
    displayName,
    photoUrl,
    walletAddress,
    createdAt,
    lastLoginAt,
    isEmailVerified,
    metadata,
  ];
}

/// Authentication state
enum AuthState { initial, loading, authenticated, unauthenticated, error }

/// Wallet connection state
enum WalletState { disconnected, connecting, connected, error }

/// Authentication session info
class AuthSession extends Equatable {
  final User user;
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final WalletState walletState;

  const AuthSession({
    required this.user,
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
    this.walletState = WalletState.disconnected,
  });

  /// Check if session is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if session is valid
  bool get isValid => !isExpired && accessToken.isNotEmpty;

  /// Create session from JSON
  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      walletState: WalletState.values.firstWhere(
        (state) => state.name == json['walletState'],
        orElse: () => WalletState.disconnected,
      ),
    );
  }

  /// Convert session to JSON
  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt.toIso8601String(),
      'walletState': walletState.name,
    };
  }

  /// Create copy with updated fields
  AuthSession copyWith({
    User? user,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    WalletState? walletState,
  }) {
    return AuthSession(
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      walletState: walletState ?? this.walletState,
    );
  }

  @override
  List<Object?> get props => [
    user,
    accessToken,
    refreshToken,
    expiresAt,
    walletState,
  ];
}
