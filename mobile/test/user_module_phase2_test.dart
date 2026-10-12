import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayak_mobile/core/network/api_client.dart';
import 'package:sahayak_mobile/core/realtime/stomp_realtime_client.dart';
import 'package:sahayak_mobile/core/storage/token_storage.dart';
import 'package:sahayak_mobile/device/mock/simulated_device_communication.dart';
import 'package:sahayak_mobile/device/models/hazard_event.dart';
import 'package:sahayak_mobile/features/auth/auth_controller.dart';
import 'package:sahayak_mobile/features/auth/auth_state.dart';
import 'package:sahayak_mobile/features/user_module/models/user_module_models.dart';
import 'package:sahayak_mobile/features/user_module/services/user_module_api_service.dart';
import 'package:sahayak_mobile/features/user_module/state/user_module_controller.dart';
import 'package:sahayak_mobile/main.dart';

void main() {
  const testUserId = '11111111-2222-3333-4444-555555555555';
  const testDeviceId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
  const testDeviceIdentifier = 'SAHAYAK-ESP32-001';

  Map<String, dynamic> buildSampleDeviceJson({String status = 'ACTIVE'}) {
    return {
      'id': testDeviceId,
      'deviceIdentifier': testDeviceIdentifier,
      'deviceName': 'Primary Stick',
      'ownerUserId': testUserId,
      'ownerFullName': 'Stick User',
      'status': status,
      'createdAt': '2026-10-13T00:00:00Z',
      'updatedAt': '2026-10-13T00:00:00Z',
    };
  }

  Map<String, dynamic> buildSampleConfigJson({int version = 1}) {
    return {
      'id': 'cfg-001',
      'deviceId': testDeviceId,
      'deviceIdentifier': testDeviceIdentifier,
      'normalThresholdCm': 150,
      'slowWarningThresholdCm': 100,
      'fastWarningThresholdCm': 50,
      'hapticEnabled': true,
      'hapticIntensity': 80,
      'audioEnabled': true,
      'audioVolume': 75,
      'configurationVersion': version,
      'updatedAt': '2026-10-13T00:00:00Z',
    };
  }

  // ===========================================================================
  // 1-5: AUTHENTICATION TESTS
  // ===========================================================================
  group('Phase 2 Authentication Tests (1-5)', () {
    test('1 & 3. User registration sends role = USER and blocks ADMIN self-registration',
        () async {
      final tokenStorage = InMemorySecureTokenStorage();
      Map<String, dynamic>? capturedRegisterBody;

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: tokenStorage,
        transport: (request) async {
          if (request.uri.path.endsWith('/api/v1/auth/register')) {
            capturedRegisterBody =
                jsonDecode(request.body ?? '{}') as Map<String, dynamic>;
            return RawHttpResponse(
              statusCode: 201,
              body: jsonEncode({
                'success': true,
                'data': {
                  'accessToken': 'jwt-user-access',
                  'refreshToken': 'jwt-user-refresh',
                  'user': {
                    'id': testUserId,
                    'fullName': 'Stick User',
                    'email': 'user@sahayak.local',
                    'role': 'USER',
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

      // Reject ADMIN role
      final adminAttempt = await authController.register(
        fullName: 'Rogue Admin',
        email: 'admin@sahayak.local',
        password: 'StrongPassword#2026',
        role: 'ADMIN',
      );
      expect(adminAttempt, isFalse);
      expect(authController.state.status, equals(AuthStatus.failure));

      // Valid USER registration
      final userSuccess = await authController.register(
        fullName: 'Stick User',
        email: 'user@sahayak.local',
        password: 'StrongPassword#2026',
      );
      expect(userSuccess, isTrue);
      expect(capturedRegisterBody?['role'], equals('USER'));
      expect(authController.state.isAuthenticated, isTrue);
      expect(authController.state.user?.role, equals('USER'));

      authController.dispose();
    });

    test('2, 4 & 5. Invalid login handled cleanly; expired token refreshes or clears session',
        () async {
      final tokenStorage = InMemorySecureTokenStorage();
      bool allowRefresh = false;

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: tokenStorage,
        transport: (request) async {
          if (request.uri.path.endsWith('/api/v1/auth/login')) {
            return RawHttpResponse(
              statusCode: 401,
              body: jsonEncode({
                'status': 401,
                'message': 'Invalid email or password',
              }),
            );
          }
          if (request.uri.path.endsWith('/api/v1/auth/refresh')) {
            if (allowRefresh) {
              return RawHttpResponse(
                statusCode: 200,
                body: jsonEncode({
                  'success': true,
                  'data': {
                    'accessToken': 'new-access-token',
                    'refreshToken': 'new-refresh-token',
                  },
                }),
              );
            }
            return RawHttpResponse(
              statusCode: 401,
              body: jsonEncode({'status': 401, 'message': 'Refresh expired'}),
            );
          }
          if (request.uri.path.endsWith('/api/v1/auth/me')) {
            if (request.headers['Authorization'] == 'Bearer new-access-token') {
              return RawHttpResponse(
                statusCode: 200,
                body: jsonEncode({
                  'success': true,
                  'data': {
                    'id': testUserId,
                    'fullName': 'Restored User',
                    'email': 'restored@sahayak.local',
                    'role': 'USER',
                  },
                }),
              );
            }
            return RawHttpResponse(
              statusCode: 401,
              body: jsonEncode({'status': 401, 'message': 'Expired token'}),
            );
          }
          return const RawHttpResponse(statusCode: 404, body: '{}');
        },
      );

      final authController = AuthController(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
      );

      // Test 2: Invalid login displays error without crashing
      final loginOk = await authController.login(
        email: 'wrong@sahayak.local',
        password: 'WrongPassword123',
      );
      expect(loginOk, isFalse);
      expect(authController.state.status, equals(AuthStatus.failure));
      expect(authController.state.errorMessage, contains('Invalid email or password'));

      // Test 4: Expired access token triggers refresh flow during restoreSession()
      await tokenStorage.saveTokens(
        accessToken: 'expired-access',
        refreshToken: 'valid-refresh',
      );
      allowRefresh = true;
      final restored = await authController.restoreSession();
      expect(restored, isTrue);
      expect(authController.state.isAuthenticated, isTrue);
      expect(authController.state.user?.email, equals('restored@sahayak.local'));

      // Test 5: Failed refresh clears session and returns to unauthenticated
      await tokenStorage.saveTokens(
        accessToken: 'expired-access',
        refreshToken: 'revoked-refresh',
      );
      allowRefresh = false;
      final failedRestore = await authController.restoreSession();
      expect(failedRestore, isFalse);
      expect(authController.state.status, equals(AuthStatus.unauthenticated));
      expect(await tokenStorage.readAccessToken(), isNull);

      authController.dispose();
    });
  });

  // ===========================================================================
  // 6-14: DEVICE & CONFIGURATION TESTS
  // ===========================================================================
  group('Phase 2 Device & Configuration Tests (6-14)', () {
    test(
        '6, 7, 8 & 9. Device registration omits ownerUserId, handles 409 conflict, lists devices, and separates Domain Status from Live Connection State',
        () async {
      final tokenStorage = InMemorySecureTokenStorage();
      await tokenStorage.saveTokens(accessToken: 'jwt-1', refreshToken: 'ref-1');

      Map<String, dynamic>? registerPayload;
      bool simulateDuplicate = false;

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: tokenStorage,
        transport: (request) async {
          if (request.method == 'POST' &&
              request.uri.path.endsWith('/api/v1/devices')) {
            registerPayload =
                jsonDecode(request.body ?? '{}') as Map<String, dynamic>;
            if (simulateDuplicate) {
              return RawHttpResponse(
                statusCode: 409,
                body: jsonEncode({
                  'status': 409,
                  'message': 'Device identifier already registered',
                }),
              );
            }
            return RawHttpResponse(
              statusCode: 201,
              body: jsonEncode({
                'success': true,
                'data': buildSampleDeviceJson(status: 'ACTIVE'),
              }),
            );
          }
          if (request.method == 'GET' &&
              request.uri.path.endsWith('/api/v1/devices')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': [buildSampleDeviceJson(status: 'ACTIVE')],
              }),
            );
          }
          if (request.uri.path.endsWith('/configuration')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': buildSampleConfigJson(version: 1),
              }),
            );
          }
          if (request.uri.path.endsWith('/hazards') ||
              request.uri.path.endsWith('/sos-events')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({'success': true, 'data': []}),
            );
          }
          return const RawHttpResponse(statusCode: 404, body: '{}');
        },
      );

      final controller = UserModuleController(
        apiService: UserModuleApiService(apiClient: apiClient),
        realtimeClient: StompRealtimeClient(
          wsUrl: 'ws://localhost:8080/ws',
          tokenStorage: tokenStorage,
        ),
        deviceCommunication: SimulatedDeviceCommunication(),
      );

      // Test 6: Register device does NOT send ownerUserId
      final registeredOk = await controller.registerNewDevice(
        deviceIdentifier: testDeviceIdentifier,
        deviceName: 'Primary Stick',
      );
      expect(registeredOk, isTrue);
      expect(registerPayload, isNotNull);
      expect(registerPayload!.containsKey('ownerUserId'), isFalse);
      expect(registerPayload!['deviceIdentifier'], equals(testDeviceIdentifier));

      // Test 9: Domain status is ACTIVE while Live Connection State is DISCONNECTED
      expect(
        controller.selectedDeviceDomainStatus,
        equals(DomainDeviceStatus.active),
      );
      expect(
        controller.liveConnectionState,
        equals(LiveDeviceConnectionState.disconnected),
      );

      // Test 7: Duplicate device identifier (409) handled cleanly
      simulateDuplicate = true;
      final duplicateOk = await controller.registerNewDevice(
        deviceIdentifier: testDeviceIdentifier,
        deviceName: 'Duplicate Stick',
      );
      expect(duplicateOk, isFalse);
      expect(
        controller.errorMessage,
        contains('Device identifier already registered'),
      );

      // Test 8: Load devices populates list
      await controller.loadUserDevices();
      expect(controller.devices.length, equals(1));
      expect(controller.devices.first.deviceIdentifier, equals(testDeviceIdentifier));

      controller.dispose();
    });

    test(
        '10, 11, 12, 13 & 14. Configuration loads, validates threshold hierarchy & audio/haptic ranges, and updates configurationVersion',
        () async {
      final tokenStorage = InMemorySecureTokenStorage();
      await tokenStorage.saveTokens(accessToken: 'jwt-1', refreshToken: 'ref-1');

      int putConfigCallCount = 0;

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: tokenStorage,
        transport: (request) async {
          if (request.method == 'GET' &&
              request.uri.path.endsWith('/api/v1/devices')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': [buildSampleDeviceJson()],
              }),
            );
          }
          if (request.method == 'GET' &&
              request.uri.path.endsWith('/configuration')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': buildSampleConfigJson(version: 1),
              }),
            );
          }
          if (request.method == 'PUT' &&
              request.uri.path.endsWith('/configuration')) {
            putConfigCallCount++;
            final body =
                jsonDecode(request.body ?? '{}') as Map<String, dynamic>;
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': {
                  ...buildSampleConfigJson(version: 2),
                  ...body,
                  'configurationVersion': 2,
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

      final controller = UserModuleController(
        apiService: UserModuleApiService(apiClient: apiClient),
        realtimeClient: StompRealtimeClient(
          wsUrl: 'ws://localhost:8080/ws',
          tokenStorage: tokenStorage,
        ),
        deviceCommunication: SimulatedDeviceCommunication(),
      );

      // Test 10: Load configuration from backend
      await controller.loadUserDevices();
      expect(controller.deviceConfiguration, isNotNull);
      expect(controller.deviceConfiguration!.configurationVersion, equals(1));
      expect(controller.deviceConfiguration!.normalThresholdCm, equals(150));

      // Test 12: Reject invalid threshold hierarchy (normal <= slow)
      final invalidHierarchy = controller.deviceConfiguration!.copyWith(
        normalThresholdCm: 90,
        slowWarningThresholdCm: 100,
        fastWarningThresholdCm: 50,
      );
      final hierarchySaved =
          await controller.saveDeviceConfiguration(invalidHierarchy);
      expect(hierarchySaved, isFalse);
      expect(putConfigCallCount, equals(0));
      expect(controller.errorMessage, contains('must be greater than'));

      // Test 13: Reject invalid haptic/audio range (> 100)
      final invalidRange = controller.deviceConfiguration!.copyWith(
        hapticIntensity: 120,
      );
      final rangeSaved = await controller.saveDeviceConfiguration(invalidRange);
      expect(rangeSaved, isFalse);
      expect(putConfigCallCount, equals(0));
      expect(controller.errorMessage, contains('between 0 and 100'));

      // Test 11 & 14: Valid configuration update calls PUT and increments version to v2
      final validConfig = controller.deviceConfiguration!.copyWith(
        normalThresholdCm: 180,
        slowWarningThresholdCm: 120,
        fastWarningThresholdCm: 60,
        hapticIntensity: 90,
        audioVolume: 85,
      );
      final validSaved = await controller.saveDeviceConfiguration(validConfig);
      expect(validSaved, isTrue);
      expect(putConfigCallCount, equals(1));
      expect(controller.deviceConfiguration!.configurationVersion, equals(2));
      expect(controller.deviceConfiguration!.normalThresholdCm, equals(180));

      controller.dispose();
    });
  });

  // ===========================================================================
  // 15-30: TELEMETRY, HAZARD, SOS LIFECYCLE & REALTIME STOMP TESTS
  // ===========================================================================
  group('Phase 2 Telemetry, Hazard, SOS & Realtime Tests (15-30)', () {
    test(
        '15, 16, 17, 18, 28, 29 & 30. Telemetry updates, stale detection, simulated mode, user-only STOMP subscription, and malformed/unknown frame resilience',
        () async {
      final tokenStorage = InMemorySecureTokenStorage();
      await tokenStorage.saveTokens(accessToken: 'jwt-1', refreshToken: 'ref-1');

      DateTime fakeNow = DateTime.utc(2026, 10, 13, 12, 0, 0);
      final stompAdapter = SimulatedStompTransportAdapter();
      final realtimeClient = StompRealtimeClient(
        wsUrl: 'ws://localhost:8080/ws',
        tokenStorage: tokenStorage,
        transport: stompAdapter,
      );

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: tokenStorage,
        transport: (_) async => RawHttpResponse(
          statusCode: 200,
          body: jsonEncode({'success': true, 'data': []}),
        ),
      );

      final controller = UserModuleController(
        apiService: UserModuleApiService(apiClient: apiClient),
        realtimeClient: realtimeClient,
        deviceCommunication: SimulatedDeviceCommunication(),
        staleTelemetryThreshold: const Duration(seconds: 10),
        clock: () => fakeNow,
      );

      // Test 28: Subscribes ONLY to /topic/user/{userId}/events, never /topic/all-parents
      await controller.connectRealtimeForUser(testUserId);
      expect(
        stompAdapter.activeSubscriptions,
        contains('/topic/user/$testUserId/events'),
      );
      expect(
        stompAdapter.activeSubscriptions.contains('/topic/all-parents'),
        isFalse,
      );

      // Test 15 & 18: Simulated telemetry updates state and sets simulated = true
      await controller.simulateTelemetrySample(
        forwardDistanceCm: 75,
        groundDistanceCm: 92,
        batteryPercentage: 84,
        severity: HazardSeverity.fastWarning,
      );
      expect(controller.latestTelemetry, isNotNull);
      expect(controller.latestTelemetry!.forwardDistanceCm, equals(75));
      expect(controller.latestTelemetry!.simulated, isTrue);
      expect(controller.isTelemetryStale(now: fakeNow), isFalse);

      // Test 16: Stale telemetry warning triggers after threshold
      fakeNow = fakeNow.add(const Duration(seconds: 16));
      expect(controller.isTelemetryStale(now: fakeNow), isTrue);

      // Test 17, 29 & 30: Malformed JSON, malformed telemetry, and unknown eventType do not crash
      stompAdapter.simulateServerMessage(
        '/topic/user/$testUserId/events',
        '<<<not-json>>>',
      );
      stompAdapter.simulateServerMessage(
        '/topic/user/$testUserId/events',
        jsonEncode({
          'eventId': 'evt-unknown-1',
          'eventType': 'FUTURE_EVENT_TYPE_2099',
          'timestamp': '2026-10-13T12:00:00Z',
          'source': 'BACKEND',
          'payload': {'foo': 'bar'},
        }),
      );
      stompAdapter.simulateServerMessage(
        '/topic/user/$testUserId/events',
        jsonEncode({
          'eventId': 'evt-malformed-telemetry',
          'eventType': 'DEVICE_TELEMETRY',
          'timestamp': 'invalid-date',
          'source': 'SIMULATED_DEVICE',
          'payload': {'forwardDistanceCm': 'not-an-int'},
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.latestTelemetry!.forwardDistanceCm, isNull);

      controller.dispose();
    });

    test(
        '19, 20, 21, 23, 24, 25, 26 & 27. Hazard reporting, SOS trigger, realtime ACKNOWLEDGED update, USER cancel/resolve, and caregiver-only ACKNOWLEDGED guard',
        () async {
      final tokenStorage = InMemorySecureTokenStorage();
      await tokenStorage.saveTokens(accessToken: 'jwt-1', refreshToken: 'ref-1');

      final stompAdapter = SimulatedStompTransportAdapter();
      final realtimeClient = StompRealtimeClient(
        wsUrl: 'ws://localhost:8080/ws',
        tokenStorage: tokenStorage,
        transport: stompAdapter,
      );

      String currentSosStatus = 'TRIGGERED';

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8080',
        tokenStorage: tokenStorage,
        transport: (request) async {
          if (request.method == 'GET' &&
              request.uri.path.endsWith('/api/v1/devices')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': [buildSampleDeviceJson()],
              }),
            );
          }
          if (request.uri.path.endsWith('/configuration')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': buildSampleConfigJson(),
              }),
            );
          }
          if (request.method == 'GET' && request.uri.path.endsWith('/hazards')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'haz-initial-1',
                    'deviceId': testDeviceId,
                    'deviceIdentifier': testDeviceIdentifier,
                    'userId': testUserId,
                    'hazardType': 'FORWARD_OBSTACLE',
                    'hazardLevel': 'SLOW_WARNING',
                    'distanceCm': 115,
                    'source': 'DEVICE',
                    'detectedAt': '2026-10-13T10:00:00Z',
                    'createdAt': '2026-10-13T10:00:00Z',
                  },
                ],
              }),
            );
          }
          if (request.method == 'POST' && request.uri.path.endsWith('/hazards')) {
            final body =
                jsonDecode(request.body ?? '{}') as Map<String, dynamic>;
            return RawHttpResponse(
              statusCode: 201,
              body: jsonEncode({
                'success': true,
                'data': {
                  'id': 'haz-created-2',
                  'deviceId': testDeviceId,
                  'deviceIdentifier': testDeviceIdentifier,
                  'userId': testUserId,
                  'hazardType': body['hazardType'],
                  'hazardLevel': body['hazardLevel'],
                  'distanceCm': body['distanceCm'],
                  'source': body['source'],
                  'detectedAt': '2026-10-13T10:05:00Z',
                  'createdAt': '2026-10-13T10:05:00Z',
                },
              }),
            );
          }
          if (request.method == 'GET' &&
              request.uri.path.endsWith('/sos-events')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({'success': true, 'data': []}),
            );
          }
          if (request.method == 'POST' && request.uri.path.endsWith('/sos')) {
            currentSosStatus = 'TRIGGERED';
            return RawHttpResponse(
              statusCode: 201,
              body: jsonEncode({
                'success': true,
                'data': {
                  'id': 'sos-001',
                  'deviceId': testDeviceId,
                  'deviceIdentifier': testDeviceIdentifier,
                  'userId': testUserId,
                  'userFullName': 'Stick User',
                  'status': currentSosStatus,
                  'source': 'MOBILE_CLIENT',
                  'triggeredAt': '2026-10-13T10:10:00Z',
                  'createdAt': '2026-10-13T10:10:00Z',
                  'updatedAt': '2026-10-13T10:10:00Z',
                },
              }),
            );
          }
          if (request.method == 'PATCH' &&
              request.uri.path.contains('/api/v1/sos-events/')) {
            final body =
                jsonDecode(request.body ?? '{}') as Map<String, dynamic>;
            currentSosStatus = (body['status'] ?? 'RESOLVED').toString();
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': {
                  'id': 'sos-001',
                  'deviceId': testDeviceId,
                  'deviceIdentifier': testDeviceIdentifier,
                  'userId': testUserId,
                  'userFullName': 'Stick User',
                  'status': currentSosStatus,
                  'source': 'MOBILE_CLIENT',
                  'triggeredAt': '2026-10-13T10:10:00Z',
                  'resolvedAt': '2026-10-13T10:12:00Z',
                  'createdAt': '2026-10-13T10:10:00Z',
                  'updatedAt': '2026-10-13T10:12:00Z',
                },
              }),
            );
          }
          return const RawHttpResponse(statusCode: 404, body: '{}');
        },
      );

      final apiService = UserModuleApiService(apiClient: apiClient);
      final controller = UserModuleController(
        apiService: apiService,
        realtimeClient: realtimeClient,
        deviceCommunication: SimulatedDeviceCommunication(),
      );

      await controller.connectRealtimeForUser(testUserId);
      await controller.loadUserDevices();

      // Test 21: Hazard history loaded from GET /api/v1/devices/{deviceId}/hazards
      expect(controller.hazardEvents.length, equals(1));
      expect(controller.hazardEvents.first.id, equals('haz-initial-1'));

      // Test 19: Report hazard calls POST /api/v1/devices/{deviceId}/hazards
      final createdHazard = await controller.reportHazardEvent(
        hazardType: 'GROUND_HAZARD',
        hazardLevel: 'CRITICAL',
        distanceCm: 30,
      );
      expect(createdHazard, isNotNull);
      expect(controller.hazardEvents.first.id, equals('haz-created-2'));

      // Test 20: Realtime HAZARD_ALERT updates hazard list and safety banner
      stompAdapter.simulateServerMessage(
        '/topic/user/$testUserId/events',
        jsonEncode({
          'eventId': 'rt-haz-3',
          'eventType': 'HAZARD_ALERT',
          'timestamp': '2026-10-13T10:06:00Z',
          'source': 'BACKEND',
          'payload': {
            'id': 'haz-realtime-3',
            'deviceId': testDeviceId,
            'deviceIdentifier': testDeviceIdentifier,
            'userId': testUserId,
            'hazardType': 'FORWARD_OBSTACLE',
            'hazardLevel': 'DANGER',
            'distanceCm': 40,
            'source': 'DEVICE',
            'detectedAt': '2026-10-13T10:06:00Z',
          },
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.hazardEvents.first.id, equals('haz-realtime-3'));
      expect(controller.currentSafetyBannerState, equals('DANGER'));

      // Test 23 & 24: Trigger SOS -> TRIGGERED state active
      final triggeredSos = await controller.triggerEmergencySos();
      expect(triggeredSos, isNotNull);
      expect(controller.activeSosEvent?.status, equals(BackendSosStatus.triggered));
      expect(
        controller.activeSosEvent?.status.bannerTitle,
        equals('SOS ACTIVE — WAITING FOR CAREGIVER'),
      );

      // Test 25: Realtime SOS_EVENT with ACKNOWLEDGED updates active SOS state
      stompAdapter.simulateServerMessage(
        '/topic/user/$testUserId/events',
        jsonEncode({
          'eventId': 'rt-sos-ack',
          'eventType': 'SOS_EVENT',
          'timestamp': '2026-10-13T10:11:00Z',
          'source': 'BACKEND',
          'payload': {
            'id': 'sos-001',
            'deviceId': testDeviceId,
            'deviceIdentifier': testDeviceIdentifier,
            'userId': testUserId,
            'userFullName': 'Stick User',
            'status': 'ACKNOWLEDGED',
            'source': 'MOBILE_CLIENT',
            'triggeredAt': '2026-10-13T10:10:00Z',
            'acknowledgedAt': '2026-10-13T10:11:00Z',
          },
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        controller.activeSosEvent?.status,
        equals(BackendSosStatus.acknowledged),
      );
      expect(
        controller.activeSosEvent?.status.bannerTitle,
        equals('SOS ACKNOWLEDGED BY CAREGIVER'),
      );

      // Guard check: User Module API service blocks ACKNOWLEDGED transition
      expect(
        () => apiService.updateSosStatus(
          sosEventId: 'sos-001',
          status: BackendSosStatus.acknowledged,
        ),
        throwsA(isA<ApiClientException>()),
      );

      // Test 27: User resolves active SOS
      final resolvedOk = await controller.resolveActiveSos('sos-001');
      expect(resolvedOk, isTrue);
      expect(controller.activeSosEvent, isNull);
      expect(controller.latestSosEvent?.status, equals(BackendSosStatus.resolved));

      // Test 26: User cancels a newly triggered SOS
      await controller.triggerEmergencySos();
      expect(controller.activeSosEvent?.status, equals(BackendSosStatus.triggered));
      final cancelledOk = await controller.cancelActiveSos('sos-001');
      expect(cancelledOk, isTrue);
      expect(controller.activeSosEvent, isNull);
      expect(controller.latestSosEvent?.status, equals(BackendSosStatus.cancelled));

      controller.dispose();
    });

    testWidgets(
        '22. Widget test: Accidental single tap on HOLD TO SEND SOS does NOT fire SOS; long-press or explicit confirmation triggers SOS',
        (WidgetTester tester) async {
      final tokenStorage = InMemorySecureTokenStorage();
      await tokenStorage.saveTokens(accessToken: 'jwt-1', refreshToken: 'ref-1');

      int sosPostCount = 0;

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
                  'id': testUserId,
                  'fullName': 'Stick User',
                  'email': 'user@sahayak.local',
                  'role': 'USER',
                },
              }),
            );
          }
          if (request.method == 'GET' &&
              request.uri.path.endsWith('/api/v1/devices')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': [buildSampleDeviceJson()],
              }),
            );
          }
          if (request.uri.path.endsWith('/configuration')) {
            return RawHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'success': true,
                'data': buildSampleConfigJson(),
              }),
            );
          }
          if (request.method == 'POST' && request.uri.path.endsWith('/sos')) {
            sosPostCount++;
            return RawHttpResponse(
              statusCode: 201,
              body: jsonEncode({
                'success': true,
                'data': {
                  'id': 'sos-widget-1',
                  'deviceId': testDeviceId,
                  'deviceIdentifier': testDeviceIdentifier,
                  'userId': testUserId,
                  'userFullName': 'Stick User',
                  'status': 'TRIGGERED',
                  'source': 'MOBILE_CLIENT',
                  'triggeredAt': '2026-10-13T10:10:00Z',
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

      final userController = UserModuleController(
        apiService: UserModuleApiService(apiClient: apiClient),
        realtimeClient: StompRealtimeClient(
          wsUrl: 'ws://localhost:8080/ws',
          tokenStorage: tokenStorage,
        ),
        deviceCommunication: SimulatedDeviceCommunication(),
      );

      await tester.pumpWidget(
        SahayakApp(
          authController: authController,
          userModuleController: userController,
          restoreSessionOnInit: false,
        ),
      );
      await tester.pumpAndSettle();

      // Verify Domain Status and Live Transport badges are rendered separately
      expect(find.byKey(const Key('safety_domain_status_badge')), findsOneWidget);
      expect(find.byKey(const Key('safety_live_connection_badge')), findsOneWidget);

      // Single tap on HOLD TO SEND SOS must NOT call POST /sos
      await tester.tap(find.byKey(const Key('hold_to_send_sos_button')));
      await tester.pumpAndSettle();
      expect(sosPostCount, equals(0));
      expect(find.byKey(const Key('sos_confirmation_box')), findsOneWidget);

      // Tapping CONFIRM SOS triggers POST /sos
      await tester.tap(find.byKey(const Key('confirm_send_sos_button')));
      await tester.pumpAndSettle();
      expect(sosPostCount, equals(1));
      expect(find.text('SOS ACTIVE — WAITING FOR CAREGIVER'), findsOneWidget);

      userController.dispose();
      authController.dispose();
    });
  });
}
