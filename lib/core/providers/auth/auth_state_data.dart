import '../../../shared/models/user.dart';

// Immutable auth state value object for clientAuthProvider.
class AuthStateData {
  final AuthState state;
  final AuthSession? session;
  final String? error;
  final bool isInitialized;

  const AuthStateData({
    required this.state,
    this.session,
    this.error,
    this.isInitialized = false,
  });

  AuthStateData copyWith({
    AuthState? state,
    AuthSession? session,
    String? error,
    bool? isInitialized,
    bool clearSession = false,
  }) {
    return AuthStateData(
      state: state ?? this.state,
      session: clearSession ? null : (session ?? this.session),
      error: error,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  bool get isAuthenticated => state == AuthState.authenticated;
  String? get walletAddress => session?.user.walletAddress;
  String? get userEmail => session?.user.email;
}
