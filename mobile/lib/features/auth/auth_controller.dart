import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import 'auth_state.dart';

/// Application-level authentication state controller (Phase 1C Foundation).
///
/// Integrates [ApiClient] and [TokenStorage] to drive authentication state transitions
/// without exposing or logging sensitive credentials.
class AuthController extends ChangeNotifier {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;
  final StreamController<AuthState> _stateStreamController =
      StreamController<AuthState>.broadcast();

  AuthState _state = const AuthState.unauthenticated();

  AuthController({
    required this.apiClient,
    required this.tokenStorage,
  });

  AuthState get state => _state;
  Stream<AuthState> get stateStream => _stateStreamController.stream;

  void _emitState(AuthState nextState) {
    _state = nextState;
    if (!_stateStreamController.isClosed) {
      _stateStreamController.add(nextState);
    }
    notifyListeners();
  }

  /// Authenticates user credentials via POST /api/v1/auth/login.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _emitState(const AuthState.authenticating());
    try {
      final response = await apiClient.post(
        '/api/v1/auth/login',
        requiresAuth: false,
        body: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final accessToken = data['accessToken'] as String?;
        final refreshToken = data['refreshToken'] as String?;
        final userMap = data['user'];

        if (accessToken != null &&
            accessToken.isNotEmpty &&
            refreshToken != null &&
            refreshToken.isNotEmpty &&
            userMap is Map<String, dynamic>) {
          await tokenStorage.saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
          final user = AuthenticatedUser.fromJson(userMap);
          _emitState(AuthState.authenticated(user));
          return true;
        }
      }

      _emitState(const AuthState.failure('Invalid authentication response'));
      return false;
    } on ApiClientException catch (ex) {
      _emitState(AuthState.failure(ex.message));
      return false;
    } catch (_) {
      _emitState(const AuthState.failure('Authentication failed'));
      return false;
    }
  }

  /// Registers a new account via POST /api/v1/auth/register.
  /// Enforces role = USER (or PARENT) and strictly prohibits ADMIN self-registration.
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    String? phoneNumber,
    String role = 'USER',
  }) async {
    final normalizedRole = role.trim().toUpperCase();
    if (normalizedRole != 'USER' && normalizedRole != 'PARENT') {
      _emitState(const AuthState.failure('Invalid registration role.'));
      return false;
    }

    _emitState(const AuthState.authenticating());
    try {
      final response = await apiClient.post(
        '/api/v1/auth/register',
        requiresAuth: false,
        body: {
          'fullName': fullName.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
            'phoneNumber': phoneNumber.trim(),
          'role': normalizedRole,
        },
      );

      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final accessToken = data['accessToken'] as String?;
        final refreshToken = data['refreshToken'] as String?;
        final userMap = data['user'];

        if (accessToken != null &&
            accessToken.isNotEmpty &&
            refreshToken != null &&
            refreshToken.isNotEmpty &&
            userMap is Map<String, dynamic>) {
          await tokenStorage.saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
          final user = AuthenticatedUser.fromJson(userMap);
          _emitState(AuthState.authenticated(user));
          return true;
        }
      }

      _emitState(const AuthState.failure('Invalid registration response'));
      return false;
    } on ApiClientException catch (ex) {
      _emitState(AuthState.failure(ex.toUserFriendlyMessage()));
      return false;
    } catch (_) {
      _emitState(const AuthState.failure('Registration failed'));
      return false;
    }
  }

  /// Restores an existing session on app startup using stored tokens and GET /api/v1/auth/me.
  /// Automatically falls back to refresh-token rotation if the access token expired.
  Future<bool> restoreSession() async {
    final storedAccess = await tokenStorage.readAccessToken();
    final storedRefresh = await tokenStorage.readRefreshToken();
    if ((storedAccess == null || storedAccess.isEmpty) &&
        (storedRefresh == null || storedRefresh.isEmpty)) {
      _emitState(const AuthState.unauthenticated());
      return false;
    }

    _emitState(AuthState.refreshing(_state.user));
    try {
      final meResponse = await apiClient.get('/api/v1/auth/me', requiresAuth: true);
      final userData = meResponse['data'];
      if (userData is Map<String, dynamic>) {
        final user = AuthenticatedUser.fromJson(userData);
        _emitState(AuthState.authenticated(user));
        return true;
      }
    } on ApiClientException catch (_) {
      // Fall through to refresh or unauthenticated cleanup
    } catch (_) {
      // Fall through
    }

    await tokenStorage.clearTokens();
    _emitState(const AuthState.unauthenticated());
    return false;
  }

  /// Rotates the stored refresh token and restores the authenticated state.
  Future<bool> refreshSession() async {
    _emitState(AuthState.refreshing(_state.user));
    final refreshed = await apiClient.tryRefreshSession();
    if (!refreshed) {
      await tokenStorage.clearTokens();
      _emitState(const AuthState.failure('Session expired. Please sign in again.'));
      return false;
    }

    try {
      final meResponse = await apiClient.get('/api/v1/auth/me', requiresAuth: true);
      final userData = meResponse['data'];
      if (userData is Map<String, dynamic>) {
        _emitState(AuthState.authenticated(AuthenticatedUser.fromJson(userData)));
        return true;
      }
    } catch (_) {
      // If user profile is already cached in state, retain it after token refresh
      if (_state.user != null) {
        _emitState(AuthState.authenticated(_state.user!));
        return true;
      }
    }

    _emitState(const AuthState.unauthenticated());
    return false;
  }

  /// Clears stored tokens and resets state to unauthenticated.
  Future<void> logout() async {
    await tokenStorage.clearTokens();
    _emitState(const AuthState.unauthenticated());
  }

  /// Callback invoked when [ApiClient] detects an unrecoverable 401 session expiry.
  void handleSessionExpired() {
    _emitState(const AuthState.unauthenticated());
  }

  @override
  void dispose() {
    _stateStreamController.close();
    super.dispose();
  }
}
