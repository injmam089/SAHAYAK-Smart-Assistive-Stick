import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahayak_mobile/core/network/api_client.dart';
import 'package:sahayak_mobile/core/storage/token_storage.dart';
import 'package:sahayak_mobile/features/auth/auth_controller.dart';
import 'package:sahayak_mobile/features/auth/auth_state.dart';

void main() {
  group('ApiClient & AuthController Foundation Tests', () {
    test('Attaches Bearer Authorization header to authenticated REST requests', () async {
      final tokenStorage = InMemorySecureTokenStorage();
      await tokenStorage.saveTokens(
        accessToken: 'jwt-access-token-123',
        refreshToken: 'refresh-token-abc',
      );

      String? capturedAuthHeader;
      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: tokenStorage,
        transport: (RawHttpRequest request) async {
          capturedAuthHeader = request.headers['Authorization'];
          return RawHttpResponse(
            statusCode: 200,
            body: jsonEncode({
              'success': true,
              'data': {'brokerActive': true},
            }),
          );
        },
      );

      final response = await apiClient.get('/api/v1/realtime/status');
      expect(response['success'], isTrue);
      expect(capturedAuthHeader, equals('Bearer jwt-access-token-123'));
    });

    test('Rotates refresh token and retries request once on 401 Unauthorized', () async {
      final tokenStorage = InMemorySecureTokenStorage();
      await tokenStorage.saveTokens(
        accessToken: 'expired-access-token',
        refreshToken: 'valid-refresh-token-1',
      );

      int statusCallCount = 0;
      int refreshCallCount = 0;

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: tokenStorage,
        transport: (RawHttpRequest request) async {
          if (request.uri.path.endsWith('/api/v1/auth/refresh')) {
            refreshCallCount++;
            final body = jsonDecode(request.body ?? '{}') as Map<String, dynamic>;
            expect(body['refreshToken'], equals('valid-refresh-token-1'));
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': {
                  'accessToken': 'rotated-access-token-2',
                  'refreshToken': 'rotated-refresh-token-2',
                  'tokenType': 'Bearer',
                  'expiresInSeconds': 900,
                  'user': {
                    'id': '11111111-2222-3333-4444-555555555555',
                    'fullName': 'Stick User',
                    'email': 'user@sahayak.local',
                    'role': 'USER',
                  },
                },
              }),
            );
          }

          if (request.uri.path.endsWith('/api/v1/realtime/status')) {
            statusCallCount++;
            if (request.headers['Authorization'] == 'Bearer expired-access-token') {
              return RawHttpResponse(
                statusCode: 401,
                body: jsonEncode({'status': 401, 'message': 'Unauthorized'}),
              );
            }
            if (request.headers['Authorization'] == 'Bearer rotated-access-token-2') {
              return RawHttpResponse(
                statusCode: 200,
                body: jsonEncode({
                  'success': true,
                  'data': {'brokerActive': true, 'websocketEndpoint': '/ws'},
                }),
              );
            }
          }

          return const RawHttpResponse(statusCode: 404, body: '{}');
        },
      );

      final result = await apiClient.get('/api/v1/realtime/status');
      expect(result['success'], isTrue);
      expect(refreshCallCount, equals(1));
      expect(statusCallCount, equals(2));
      expect(await tokenStorage.readAccessToken(), equals('rotated-access-token-2'));
      expect(await tokenStorage.readRefreshToken(), equals('rotated-refresh-token-2'));
    });

    test('AuthController transitions through login and logout states', () async {
      final tokenStorage = InMemorySecureTokenStorage();
      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: tokenStorage,
        transport: (RawHttpRequest request) async {
          if (request.uri.path.endsWith('/api/v1/auth/login')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': {
                  'accessToken': 'jwt-access-999',
                  'refreshToken': 'refresh-999',
                  'tokenType': 'Bearer',
                  'expiresInSeconds': 900,
                  'user': {
                    'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
                    'fullName': 'Test Parent',
                    'email': 'parent@sahayak.local',
                    'role': 'PARENT',
                  },
                },
              }),
            );
          }
          return const RawHttpResponse(statusCode: 404, body: '{}');
        },
      );

      final authController = AuthController(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
      );

      expect(authController.state.status, equals(AuthStatus.unauthenticated));

      final loggedIn = await authController.login(
        email: 'parent@sahayak.local',
        password: 'StrongPassword#2026',
      );

      expect(loggedIn, isTrue);
      expect(authController.state.status, equals(AuthStatus.authenticated));
      expect(authController.state.user?.role, equals('PARENT'));
      expect(await tokenStorage.readAccessToken(), equals('jwt-access-999'));

      await authController.logout();
      expect(authController.state.status, equals(AuthStatus.unauthenticated));
      expect(await tokenStorage.readAccessToken(), isNull);
      expect(await tokenStorage.readRefreshToken(), isNull);

      authController.dispose();
    });
  });
}
