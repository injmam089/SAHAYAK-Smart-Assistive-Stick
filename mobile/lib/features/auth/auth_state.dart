/// Application-level authentication lifecycle states (Phase 1C Foundation).
enum AuthStatus {
  unauthenticated,
  authenticating,
  authenticated,
  refreshing,
  failure,
}

/// Safe authenticated user profile model (never stores passwords or raw tokens).
class AuthenticatedUser {
  final String id;
  final String email;
  final String fullName;
  final String role;

  const AuthenticatedUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  factory AuthenticatedUser.fromJson(Map<String, dynamic> json) {
    return AuthenticatedUser(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: (json['fullName'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'role': role,
    };
  }
}

/// Immutable authentication state representation for the SAHAYAK platform.
class AuthState {
  final AuthStatus status;
  final AuthenticatedUser? user;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  const AuthState.unauthenticated()
      : status = AuthStatus.unauthenticated,
        user = null,
        errorMessage = null;

  const AuthState.authenticating()
      : status = AuthStatus.authenticating,
        user = null,
        errorMessage = null;

  const AuthState.authenticated(AuthenticatedUser authenticatedUser)
      : status = AuthStatus.authenticated,
        user = authenticatedUser,
        errorMessage = null;

  const AuthState.refreshing([this.user])
      : status = AuthStatus.refreshing,
        errorMessage = null;

  const AuthState.failure(String message)
      : status = AuthStatus.failure,
        user = null,
        errorMessage = message;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
}
