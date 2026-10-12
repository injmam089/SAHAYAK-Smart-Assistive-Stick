import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayak_mobile/core/network/api_client.dart';
import 'package:sahayak_mobile/core/realtime/stomp_realtime_client.dart';
import 'package:sahayak_mobile/core/storage/token_storage.dart';
import 'package:sahayak_mobile/features/auth/auth_controller.dart';
import 'package:sahayak_mobile/features/auth/auth_state.dart';
import 'package:sahayak_mobile/features/parent_module/models/parent_module_models.dart';
import 'package:sahayak_mobile/features/parent_module/services/parent_module_api_service.dart';
import 'package:sahayak_mobile/features/parent_module/state/parent_module_controller.dart';
import 'package:sahayak_mobile/features/user_module/models/user_module_models.dart';
import 'package:sahayak_mobile/main.dart';

void main() {
  const parentId = 'pppppppp-1111-2222-3333-444444444444';
  const activeUserId = 'uuuuuuuu-aaaa-bbbb-cccc-111111111111';
  const pendingUserId = 'uuuuuuuu-aaaa-bbbb-cccc-222222222222';
  const revokedUserId = 'uuuuuuuu-aaaa-bbbb-cccc-333333333333';
  const unrelatedUserId = 'uuuuuuuu-aaaa-bbbb-cccc-999999999999';

  const activeDeviceId = 'dddddddd-1111-2222-3333-aaaaaaaaaaaa';
  const activeDeviceIdentifier = 'SAHAYAK-ESP32-WARD-01';

  Map<String, dynamic> buildLinkJson({
    required String id,
    required String userId,
    required String userFullName,
    required String status,
  }) {
    return {
      'id': id,
      'parentUserId': parentId,
      'parentFullName': 'Caregiver One',
      'parentEmail': 'parent@sahayak.local',
      'userId': userId,
      'userFullName': userFullName,
      'userEmail': '$userId@sahayak.local',
      'status': status,
      'createdAt': '2026-10-13T00:00:00Z',
      'updatedAt': '2026-10-13T00:00:00Z',
    };
  }

  Map<String, dynamic> buildActiveDeviceJson() {
    return {
      'id': activeDeviceId,
      'deviceIdentifier': activeDeviceIdentifier,
      'deviceName': 'Ward Primary Stick',
      'ownerUserId': activeUserId,
      'ownerFullName': 'Active Stick User',
      'status': 'ACTIVE',
      'createdAt': '2026-10-13T00:00:00Z',
      'updatedAt': '2026-10-13T00:00:00Z',
    };
  }

  Map<String, dynamic> buildConfigJson() {
    return {
      'id': 'cfg-ward-1',
      'deviceId': activeDeviceId,
      'deviceIdentifier': activeDeviceIdentifier,
      'normalThresholdCm': 150,
      'slowWarningThresholdCm': 100,
      'fastWarningThresholdCm': 50,
      'hapticEnabled': true,
      'hapticIntensity': 80,
      'audioEnabled': true,
      'audioVolume': 75,
      'configurationVersion': 3,
      'updatedAt': '2026-10-13T00:00:00Z',
    };
  }

  // ===========================================================================
  // 1-5: PARENT AUTHENTICATION & SESSION TESTS
  // ===========================================================================
  group('Phase 3 Parent Authentication & Session Tests (1-5)', () {
    test(
        '1, 2, 3, 4 & 5. Parent login, session restoration, token refresh, invalid credentials, and logout',
        () async {
      final tokenStorage = InMemorySecureTokenStorage();
      bool simulateInvalidLogin = true;

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: tokenStorage,
        transport: (request) async {
          if (request.uri.path.endsWith('/api/v1/auth/login')) {
            if (simulateInvalidLogin) {
              return RawHttpResponse(
                statusCode: 401,
                body: jsonEncode({
                  'status': 401,
                  'message': 'Invalid email or password',
                }),
              );
            }
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': {
                  'accessToken': 'parent-access-1',
                  'refreshToken': 'parent-refresh-1',
                  'user': {
                    'id': parentId,
                    'fullName': 'Caregiver One',
                    'email': 'parent@sahayak.local',
                    'role': 'PARENT',
                  },
                },
              }),
            );
          }
          if (request.uri.path.endsWith('/api/v1/auth/refresh')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': {
                  'accessToken': 'parent-access-rotated-2',
                  'refreshToken': 'parent-refresh-rotated-2',
                },
              }),
            );
          }
          if (request.uri.path.endsWith('/api/v1/auth/me')) {
            if (request.headers['Authorization'] ==
                'Bearer parent-access-rotated-2') {
              return RawHttpResponse(
                statusCode: 200,
                body: jsonEncode({
                  'success': true,
                  'data': {
                    'id': parentId,
                    'fullName': 'Caregiver One',
                    'email': 'parent@sahayak.local',
                    'role': 'PARENT',
                  },
                }),
              );
            }
            return RawHttpResponse(
              statusCode: 401,
              body: jsonEncode({'status': 401, 'message': 'Expired'}),
            );
          }
          return const RawHttpResponse(statusCode: 404, body: '{}');
        },
      );

      final authController = AuthController(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
      );

      // Test 4: Invalid credentials
      final badLogin = await authController.login(
        email: 'parent@sahayak.local',
        password: 'WrongPassword123',
      );
      expect(badLogin, isFalse);
      expect(authController.state.status, equals(AuthStatus.failure));

      // Test 1: Valid Parent Login
      simulateInvalidLogin = false;
      final goodLogin = await authController.login(
        email: 'parent@sahayak.local',
        password: 'StrongPassword#2026',
      );
      expect(goodLogin, isTrue);
      expect(authController.state.isAuthenticated, isTrue);
      expect(authController.state.user?.role, equals('PARENT'));
      expect(authController.state.user?.id, equals(parentId));

      // Test 2 & 5: Parent session restoration with expired access token -> refresh rotation
      await tokenStorage.saveTokens(
        accessToken: 'expired-parent-access',
        refreshToken: 'parent-refresh-1',
      );
      final restored = await authController.restoreSession();
      expect(restored, isTrue);
      expect(authController.state.user?.role, equals('PARENT'));
      expect(
        await tokenStorage.readAccessToken(),
        equals('parent-access-rotated-2'),
      );

      // Test 3: Parent logout clears tokens and session
      await authController.logout();
      expect(authController.state.status, equals(AuthStatus.unauthenticated));
      expect(await tokenStorage.readAccessToken(), isNull);

      authController.dispose();
    });
  });

  // ===========================================================================
  // 6-18: RELATIONSHIPS, ACCESS ISOLATION & DEVICE/CONFIG READ-ONLY TESTS
  // ===========================================================================
  group('Phase 3 Relationships, Access Isolation & Device Tests (6-18)', () {
    test(
        '6-18. PENDING/ACTIVE/REVOKED display, no self-approve, PENDING/REVOKED/unrelated isolation, domain vs live status separation, read-only config, and revocation purge',
        () async {
      final tokenStorage = InMemorySecureTokenStorage();
      await tokenStorage.saveTokens(
        accessToken: 'parent-jwt',
        refreshToken: 'parent-ref',
      );

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: tokenStorage,
        transport: (request) async {
          if (request.method == 'GET' &&
              request.uri.path.endsWith('/api/v1/parent-links')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': [
                  buildLinkJson(
                    id: 'link-active-1',
                    userId: activeUserId,
                    userFullName: 'Active Stick User',
                    status: 'ACTIVE',
                  ),
                  buildLinkJson(
                    id: 'link-pending-2',
                    userId: pendingUserId,
                    userFullName: 'Pending Stick User',
                    status: 'PENDING',
                  ),
                  buildLinkJson(
                    id: 'link-revoked-3',
                    userId: revokedUserId,
                    userFullName: 'Revoked Stick User',
                    status: 'REVOKED',
                  ),
                ],
              }),
            );
          }
          if (request.method == 'PATCH' &&
              request.uri.path.contains('/api/v1/parent-links/')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': buildLinkJson(
                  id: 'link-active-1',
                  userId: activeUserId,
                  userFullName: 'Active Stick User',
                  status: 'REVOKED',
                ),
              }),
            );
          }
          if (request.method == 'GET' &&
              request.uri.path.endsWith('/api/v1/devices')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': [buildActiveDeviceJson()],
              }),
            );
          }
          if (request.uri.path.endsWith('/configuration')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': buildConfigJson(),
              }),
            );
          }
          if (request.uri.path.endsWith('/hazards')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'haz-1',
                    'deviceId': activeDeviceId,
                    'deviceIdentifier': activeDeviceIdentifier,
                    'userId': activeUserId,
                    'hazardType': 'FORWARD_OBSTACLE',
                    'hazardLevel': 'WARNING',
                    'distanceCm': 95,
                    'source': 'DEVICE',
                    'detectedAt': '2026-10-13T10:00:00Z',
                  },
                ],
              }),
            );
          }
          if (request.uri.path.endsWith('/sos-events')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({'success': true, 'data': []}),
            );
          }
          return const RawHttpResponse(statusCode: 404, body: '{}');
        },
      );

      final apiService = ParentModuleApiService(apiClient: apiClient);
      final controller = ParentModuleController(
        apiService: apiService,
        realtimeClient: StompRealtimeClient(
          wsUrl: 'ws://localhost:8080/ws',
          tokenStorage: tokenStorage,
        ),
      );

      await controller.loadParentDashboard();

      // Tests 6, 7, 8: PENDING, ACTIVE, and REVOKED relationships separated and labeled
      expect(controller.activeLinks.length, equals(1));
      expect(controller.pendingLinks.length, equals(1));
      expect(controller.revokedLinks.length, equals(1));
      expect(
        controller.pendingLinks.first.status.displayLabel,
        equals('Pending — Waiting for user approval'),
      );
      expect(
        controller.revokedLinks.first.status.displayLabel,
        equals('Revoked — Access removed'),
      );

      // Test 9: Parent cannot self-approve a PENDING relationship
      final selfApproveOk =
          await controller.attemptSelfApproveLink('link-pending-2');
      expect(selfApproveOk, isFalse);
      expect(controller.errorMessage, contains('cannot self-approve'));

      // Tests 11, 12, 13, 14: ACTIVE user has devices/hazards; PENDING, REVOKED, and unrelated users have ZERO protected data
      expect(controller.isUserActiveLinked(activeUserId), isTrue);
      expect(controller.isUserActiveLinked(pendingUserId), isFalse);
      expect(controller.isUserActiveLinked(revokedUserId), isFalse);
      expect(controller.isUserActiveLinked(unrelatedUserId), isFalse);

      expect(controller.devicesForUser(activeUserId).length, equals(1));
      expect(controller.devicesForUser(pendingUserId), isEmpty);
      expect(controller.devicesForUser(revokedUserId), isEmpty);
      expect(controller.devicesForUser(unrelatedUserId), isEmpty);
      expect(controller.selectActiveLinkedUser(pendingUserId), isFalse);
      expect(controller.selectActiveLinkedUser(revokedUserId), isFalse);
      expect(controller.selectActiveLinkedUser(unrelatedUserId), isFalse);

      // Tests 15 & 16: Linked device display + Domain Status vs Live Connection separation
      expect(
        controller.domainStatusForDevice(activeDeviceId),
        equals(DomainDeviceStatus.active),
      );
      expect(
        controller.liveConnectionForDevice(activeDeviceId),
        equals(LiveDeviceConnectionState.disconnected),
      );

      // Test 17: Read-only configuration loaded for ACTIVE linked device
      final config = controller.configurationForDevice(activeDeviceId);
      expect(config, isNotNull);
      expect(config!.configurationVersion, equals(3));

      // Test 18: Parent cannot modify device configuration or register a device
      expect(
        () => apiService.attemptModifyDeviceConfiguration(
          deviceId: activeDeviceId,
          configuration: config,
        ),
        throwsA(isA<ApiClientException>()),
      );
      expect(
        () => apiService.attemptRegisterDevice(
          deviceIdentifier: 'ROGUE-01',
          deviceName: 'Rogue Stick',
        ),
        throwsA(isA<ApiClientException>()),
      );

      // Test 10 & 13: Revoking relationship immediately purges all cached protected data
      final revokedOk = await controller.revokeRelationship('link-active-1');
      expect(revokedOk, isTrue);
      expect(controller.isUserActiveLinked(activeUserId), isFalse);
      expect(controller.devicesForUser(activeUserId), isEmpty);
      expect(controller.configurationForDevice(activeDeviceId), isNull);
      expect(controller.hazardsForUser(activeUserId), isEmpty);
      expect(controller.selectedActiveLink, isNull);

      controller.dispose();
    });
  });

  // ===========================================================================
  // 19-31 & 36-38: REALTIME STOMP, SOS LIFECYCLE & TOPIC SECURITY TESTS
  // ===========================================================================
  group('Phase 3 Realtime STOMP, SOS Lifecycle & Security Tests (19-31, 36-38)', () {
    test(
        '19-26 & 36-38. Parent STOMP topic security, telemetry/hazard/SOS parsing, unauthorized user filtering, reconnect, and logout disconnect',
        () async {
      final tokenStorage = InMemorySecureTokenStorage();
      await tokenStorage.saveTokens(
        accessToken: 'parent-jwt',
        refreshToken: 'parent-ref',
      );

      final stompAdapter = SimulatedStompTransportAdapter();
      final realtimeClient = StompRealtimeClient(
        wsUrl: 'ws://localhost:8080/ws',
        tokenStorage: tokenStorage,
        transport: stompAdapter,
        reconnectDelay: const Duration(milliseconds: 30),
      );

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: tokenStorage,
        transport: (request) async {
          if (request.uri.path.endsWith('/api/v1/parent-links')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': [
                  buildLinkJson(
                    id: 'link-active-1',
                    userId: activeUserId,
                    userFullName: 'Active Stick User',
                    status: 'ACTIVE',
                  ),
                ],
              }),
            );
          }
          if (request.uri.path.endsWith('/api/v1/devices')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': [buildActiveDeviceJson()],
              }),
            );
          }
          if (request.uri.path.endsWith('/configuration')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': buildConfigJson(),
              }),
            );
          }
          return RawHttpResponse(
            statusCode: 200,
            body: jsonEncode({'success': true, 'data': []}),
          );
        },
      );

      final controller = ParentModuleController(
        apiService: ParentModuleApiService(apiClient: apiClient),
        realtimeClient: realtimeClient,
      );

      await controller.loadParentDashboard();

      // Tests 36, 37, 38: Reject wrong-parent topic, arbitrary/user topic, and /topic/all-parents
      await expectLater(
        () => controller.connectRealtimeForParent(
          parentId,
          requestedDestination: '/topic/parent/other-parent-id/events',
        ),
        throwsA(isA<ApiClientException>()),
      );
      await expectLater(
        () => controller.connectRealtimeForParent(
          parentId,
          requestedDestination: '/topic/user/$activeUserId/events',
        ),
        throwsA(isA<ApiClientException>()),
      );
      await expectLater(
        () => controller.connectRealtimeForParent(
          parentId,
          requestedDestination: '/topic/all-parents',
        ),
        throwsA(isA<ApiClientException>()),
      );

      // Test 19: Valid subscription to /topic/parent/{parentId}/events
      await controller.connectRealtimeForParent(parentId);
      expect(
        stompAdapter.activeSubscriptions,
        equals({'/topic/parent/$parentId/events'}),
      );

      // Test 20: Telemetry event parsing for ACTIVE linked device
      stompAdapter.simulateServerMessage(
        '/topic/parent/$parentId/events',
        jsonEncode({
          'eventId': 'evt-tel-1',
          'eventType': 'DEVICE_TELEMETRY',
          'timestamp': '2026-10-13T12:00:00Z',
          'source': 'SIMULATED_DEVICE',
          'payload': {
            'deviceId': activeDeviceIdentifier,
            'timestamp': '2026-10-13T12:00:00Z',
            'connectionState': 'CONNECTED',
            'batteryPercentage': 89,
            'forwardDistanceCm': 110,
            'groundDistanceCm': 98,
            'hazardLevel': 'SLOW_WARNING',
          },
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        controller.liveConnectionForDevice(activeDeviceId),
        equals(LiveDeviceConnectionState.connected),
      );
      expect(
        controller.telemetryForDevice(activeDeviceId)?.batteryPercentage,
        equals(89),
      );

      // Test 21: Hazard event parsing for ACTIVE linked user; unrelated user hazard ignored
      stompAdapter.simulateServerMessage(
        '/topic/parent/$parentId/events',
        jsonEncode({
          'eventId': 'evt-haz-unrelated',
          'eventType': 'HAZARD_ALERT',
          'timestamp': '2026-10-13T12:01:00Z',
          'source': 'BACKEND',
          'payload': {
            'id': 'haz-unrelated-99',
            'deviceId': 'unrelated-device-id',
            'deviceIdentifier': 'UNRELATED-DEV',
            'userId': unrelatedUserId,
            'hazardType': 'GROUND_HAZARD',
            'hazardLevel': 'CRITICAL',
            'distanceCm': 20,
          },
        }),
      );
      stompAdapter.simulateServerMessage(
        '/topic/parent/$parentId/events',
        jsonEncode({
          'eventId': 'evt-haz-valid',
          'eventType': 'HAZARD_ALERT',
          'timestamp': '2026-10-13T12:01:05Z',
          'source': 'BACKEND',
          'payload': {
            'id': 'haz-valid-1',
            'deviceId': activeDeviceId,
            'deviceIdentifier': activeDeviceIdentifier,
            'userId': activeUserId,
            'hazardType': 'GROUND_HAZARD',
            'hazardLevel': 'CRITICAL',
            'distanceCm': 32,
          },
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.hazardsForUser(activeUserId).length, equals(1));
      expect(controller.hazardsForUser(activeUserId).first.id, equals('haz-valid-1'));
      expect(
        controller.safetyStatusForUser(activeUserId),
        equals(CaregiverSafetyStatus.critical),
      );

      // Test 22: SOS event parsing for ACTIVE linked user
      stompAdapter.simulateServerMessage(
        '/topic/parent/$parentId/events',
        jsonEncode({
          'eventId': 'evt-sos-1',
          'eventType': 'SOS_EVENT',
          'timestamp': '2026-10-13T12:02:00Z',
          'source': 'BACKEND',
          'payload': {
            'id': 'sos-rt-1',
            'deviceId': activeDeviceId,
            'deviceIdentifier': activeDeviceIdentifier,
            'userId': activeUserId,
            'userFullName': 'Active Stick User',
            'status': 'TRIGGERED',
            'source': 'DEVICE',
            'triggeredAt': '2026-10-13T12:02:00Z',
          },
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.allActiveSosEvents.length, equals(1));
      expect(
        controller.safetyStatusForUser(activeUserId),
        equals(CaregiverSafetyStatus.sosActive),
      );

      // Tests 23 & 24: Unknown event and malformed frame ignored safely
      stompAdapter.simulateServerMessage(
        '/topic/parent/$parentId/events',
        '<<<malformed-frame>>>',
      );
      stompAdapter.simulateServerMessage(
        '/topic/parent/$parentId/events',
        jsonEncode({
          'eventId': 'evt-unknown',
          'eventType': 'UNKNOWN_FUTURE_TYPE',
          'timestamp': '2026-10-13T12:03:00Z',
          'source': 'BACKEND',
          'payload': {},
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Test 25: Reconnect handling
      realtimeClient.simulateConnectionDrop();
      expect(
        controller.realtimeSocketState,
        equals(RealtimeConnectionState.reconnecting),
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(
        controller.realtimeSocketState,
        equals(RealtimeConnectionState.connected),
      );

      // Test 26: Logout disconnect clears subscriptions and protected caches
      await controller.resetForLogout();
      expect(
        controller.realtimeSocketState,
        equals(RealtimeConnectionState.disconnected),
      );
      expect(controller.activeLinks, isEmpty);
      expect(controller.allActiveSosEvents, isEmpty);

      controller.dispose();
      realtimeClient.dispose();
    });

    test(
        '27, 28, 29, 30 & 31. Caregiver SOS lifecycle: TRIGGERED -> ACKNOWLEDGED -> RESOLVED, TRIGGERED -> RESOLVED rejected, and CANCELLED forbidden',
        () async {
      final tokenStorage = InMemorySecureTokenStorage();
      await tokenStorage.saveTokens(
        accessToken: 'parent-jwt',
        refreshToken: 'parent-ref',
      );

      String backendSosState = 'TRIGGERED';

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: tokenStorage,
        transport: (request) async {
          if (request.uri.path.endsWith('/api/v1/parent-links')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': [
                  buildLinkJson(
                    id: 'link-active-1',
                    userId: activeUserId,
                    userFullName: 'Active Stick User',
                    status: 'ACTIVE',
                  ),
                ],
              }),
            );
          }
          if (request.uri.path.endsWith('/api/v1/devices')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': [buildActiveDeviceJson()],
              }),
            );
          }
          if (request.uri.path.endsWith('/configuration')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({'success': true, 'data': buildConfigJson()}),
            );
          }
          if (request.uri.path.endsWith('/hazards')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({'success': true, 'data': []}),
            );
          }
          if (request.method == 'GET' &&
              request.uri.path.endsWith('/sos-events')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'sos-lifecycle-1',
                    'deviceId': activeDeviceId,
                    'deviceIdentifier': activeDeviceIdentifier,
                    'userId': activeUserId,
                    'userFullName': 'Active Stick User',
                    'status': backendSosState,
                    'source': 'MOBILE_CLIENT',
                    'triggeredAt': '2026-10-13T11:00:00Z',
                  },
                ],
              }),
            );
          }
          if (request.method == 'PATCH' &&
              request.uri.path.contains('/api/v1/sos-events/')) {
            final body =
                jsonDecode(request.body ?? '{}') as Map<String, dynamic>;
            backendSosState = (body['status'] ?? '').toString();
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': {
                  'id': 'sos-lifecycle-1',
                  'deviceId': activeDeviceId,
                  'deviceIdentifier': activeDeviceIdentifier,
                  'userId': activeUserId,
                  'userFullName': 'Active Stick User',
                  'status': backendSosState,
                  'source': 'MOBILE_CLIENT',
                  'triggeredAt': '2026-10-13T11:00:00Z',
                },
              }),
            );
          }
          return const RawHttpResponse(statusCode: 404, body: '{}');
        },
      );

      final apiService = ParentModuleApiService(apiClient: apiClient);
      final controller = ParentModuleController(
        apiService: apiService,
        realtimeClient: StompRealtimeClient(
          wsUrl: 'ws://localhost:8080/ws',
          tokenStorage: tokenStorage,
        ),
      );

      await controller.loadParentDashboard();

      // Test 27: Active SOS displayed
      expect(controller.allActiveSosEvents.length, equals(1));
      final triggeredSos = controller.allActiveSosEvents.first;
      expect(triggeredSos.status, equals(BackendSosStatus.triggered));

      // Test 30: Caregiver is forbidden from cancelling SOS
      expect(
        () => apiService.updateSosStatus(
          sosEventId: triggeredSos.id,
          targetStatus: BackendSosStatus.cancelled,
        ),
        throwsA(isA<ApiClientException>()),
      );

      // Test 31: TRIGGERED -> RESOLVED rejected before acknowledgment
      final prematureResolve = await controller.resolveSosEvent(triggeredSos);
      expect(prematureResolve, isFalse);
      expect(controller.errorMessage, contains('must be ACKNOWLEDGED'));

      // Test 28: Acknowledge TRIGGERED SOS -> ACKNOWLEDGED
      final ackOk = await controller.acknowledgeSosEvent(triggeredSos);
      expect(ackOk, isTrue);
      final acknowledgedSos = controller.allActiveSosEvents.first;
      expect(acknowledgedSos.status, equals(BackendSosStatus.acknowledged));

      // Test 29: Resolve ACKNOWLEDGED SOS -> RESOLVED
      final resolveOk = await controller.resolveSosEvent(acknowledgedSos);
      expect(resolveOk, isTrue);
      expect(controller.allActiveSosEvents, isEmpty);
      expect(
        controller.sosEventsForUser(activeUserId).first.status,
        equals(BackendSosStatus.resolved),
      );

      controller.dispose();
    });

    testWidgets(
        '32, 33, 34 & 35. Widget & Accessibility test: ParentControlModuleShell renders semantic SOS labels, ACKNOWLEDGE -> RESOLVE buttons, separated Domain/Live badges, and NO Cancel SOS button',
        (WidgetTester tester) async {
      final tokenStorage = InMemorySecureTokenStorage();
      await tokenStorage.saveTokens(
        accessToken: 'parent-jwt',
        refreshToken: 'parent-ref',
      );

      String currentSosStatus = 'TRIGGERED';

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: tokenStorage,
        transport: (request) async {
          if (request.uri.path.endsWith('/api/v1/auth/me')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': {
                  'id': parentId,
                  'fullName': 'Caregiver One',
                  'email': 'parent@sahayak.local',
                  'role': 'PARENT',
                },
              }),
            );
          }
          if (request.uri.path.endsWith('/api/v1/parent-links')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': [
                  buildLinkJson(
                    id: 'link-active-1',
                    userId: activeUserId,
                    userFullName: 'Active Stick User',
                    status: 'ACTIVE',
                  ),
                ],
              }),
            );
          }
          if (request.uri.path.endsWith('/api/v1/devices')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': [buildActiveDeviceJson()],
              }),
            );
          }
          if (request.uri.path.endsWith('/configuration')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({'success': true, 'data': buildConfigJson()}),
            );
          }
          if (request.uri.path.endsWith('/hazards')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({'success': true, 'data': []}),
            );
          }
          if (request.method == 'GET' &&
              request.uri.path.endsWith('/sos-events')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'sos-ui-1',
                    'deviceId': activeDeviceId,
                    'deviceIdentifier': activeDeviceIdentifier,
                    'userId': activeUserId,
                    'userFullName': 'Active Stick User',
                    'status': currentSosStatus,
                    'source': 'MOBILE_CLIENT',
                    'triggeredAt': '2026-10-13T11:00:00Z',
                  },
                ],
              }),
            );
          }
          if (request.method == 'PATCH' &&
              request.uri.path.contains('/api/v1/sos-events/')) {
            final body =
                jsonDecode(request.body ?? '{}') as Map<String, dynamic>;
            currentSosStatus = (body['status'] ?? 'ACKNOWLEDGED').toString();
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': {
                  'id': 'sos-ui-1',
                  'deviceId': activeDeviceId,
                  'deviceIdentifier': activeDeviceIdentifier,
                  'userId': activeUserId,
                  'userFullName': 'Active Stick User',
                  'status': currentSosStatus,
                  'source': 'MOBILE_CLIENT',
                  'triggeredAt': '2026-10-13T11:00:00Z',
                },
              }),
            );
          }
          return RawHttpResponse(
            statusCode: 200,
            body: jsonEncode({'success': true, 'data': []}),
          );
        },
      );

      final authController = AuthController(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
      );
      await authController.restoreSession();

      final parentController = ParentModuleController(
        apiService: ParentModuleApiService(apiClient: apiClient),
        realtimeClient: StompRealtimeClient(
          wsUrl: 'ws://localhost:8080/ws',
          tokenStorage: tokenStorage,
        ),
      );

      await tester.pumpWidget(
        SahayakApp(
          authController: authController,
          parentModuleController: parentController,
          restoreSessionOnInit: false,
        ),
      );
      await tester.pumpAndSettle();

      // Verify Parent Home renders Linked Users count, separated Domain & Live badges, and readable Safety text
      expect(find.byKey(const Key('parent_active_linked_count')), findsOneWidget);
      expect(
        find.byKey(const Key('parent_home_domain_status_$activeDeviceId')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('parent_home_live_status_$activeDeviceId')),
        findsOneWidget,
      );
      expect(find.textContaining('Safety: SOS ACTIVE'), findsOneWidget);

      // Verify CANCEL SOS is NOT exposed to Parent
      expect(find.text('CANCEL SOS'), findsNothing);

      // Test 33: Acknowledge button present for TRIGGERED SOS; tap transitions to ACKNOWLEDGED
      final ackButton = find.byKey(const Key('parent_ack_sos_sos-ui-1'));
      expect(ackButton, findsOneWidget);
      await tester.tap(ackButton);
      await tester.pumpAndSettle();

      // Test 34: Resolve button appears once ACKNOWLEDGED; tap resolves SOS
      final resolveButton = find.byKey(const Key('parent_resolve_sos_sos-ui-1'));
      expect(resolveButton, findsOneWidget);
      await tester.tap(resolveButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Safety: SAFE'), findsOneWidget);

      parentController.dispose();
      authController.dispose();
    });
  });
}
