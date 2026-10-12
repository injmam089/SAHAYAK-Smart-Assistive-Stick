import 'package:flutter_test/flutter_test.dart';
import 'package:sahayak_mobile/core/realtime/realtime_event_envelope.dart';
import 'package:sahayak_mobile/core/realtime/stomp_realtime_client.dart';
import 'package:sahayak_mobile/core/storage/token_storage.dart';
import 'package:sahayak_mobile/device/mock/simulated_device_communication.dart';
import 'package:sahayak_mobile/device/models/telemetry_data.dart';
import 'package:sahayak_mobile/device/telemetry_pipeline_coordinator.dart';

void main() {
  group('TelemetryPipelineCoordinator & StompRealtimeClient Tests', () {
    test('SimulatedDeviceCommunication feeds TelemetryPipelineCoordinator into typed envelope stream', () async {
      final tokenStorage = InMemorySecureTokenStorage();
      await tokenStorage.saveTokens(
        accessToken: 'jwt-user-token',
        refreshToken: 'refresh-user-token',
      );

      final simulatedTransport = SimulatedStompTransportAdapter();
      final stompClient = StompRealtimeClient(
        wsUrl: 'ws://localhost:8080/ws',
        tokenStorage: tokenStorage,
        transport: simulatedTransport,
      );

      final connected = await stompClient.connect();
      expect(connected, isTrue);
      expect(stompClient.connectionState, equals(RealtimeConnectionState.connected));
      expect(
        simulatedTransport.lastConnectHeaders['Authorization'],
        equals('Bearer jwt-user-token'),
      );

      final deviceComm = SimulatedDeviceCommunication();
      final coordinator = TelemetryPipelineCoordinator(
        deviceCommunication: deviceComm,
        realtimeClient: stompClient,
        deviceId: 'SAHAYAK-MOCK-01',
      );

      await deviceComm.connect('SAHAYAK-MOCK-01');

      final nextEnvelopeFuture = coordinator.telemetryEnvelopeStream.first;

      deviceComm.emitSimulatedTelemetry(
        TelemetryData(
          forwardDistanceCm: 115,
          groundDistanceCm: 92,
          batteryPercentage: 87,
          timestamp: DateTime.parse('2026-10-13T02:15:00Z'),
        ),
      );

      final firstEnvelope = await nextEnvelopeFuture;

      expect(firstEnvelope.eventType, equals(RealtimeEventType.deviceTelemetry));
      expect(firstEnvelope.source, equals(EventSource.simulatedDevice));
      expect(firstEnvelope.payload.deviceId, equals('SAHAYAK-MOCK-01'));
      expect(firstEnvelope.payload.simulated, isTrue);
      expect(firstEnvelope.payload.batteryPercentage, equals(87));
      expect(firstEnvelope.payload.forwardDistanceCm, equals(115));
      expect(firstEnvelope.payload.groundDistanceCm, equals(92));

      expect(simulatedTransport.sentFrames, isNotEmpty);
      expect(
        simulatedTransport.sentFrames.first['destination'],
        equals('/app/telemetry.simulate'),
      );

      coordinator.dispose();
      stompClient.dispose();
      deviceComm.dispose();
    });

    test('StompRealtimeClient manages topic subscriptions, frames, and reconnect state', () async {
      final tokenStorage = InMemorySecureTokenStorage();
      await tokenStorage.saveTokens(
        accessToken: 'jwt-parent-token',
        refreshToken: 'refresh-parent-token',
      );

      final simulatedTransport = SimulatedStompTransportAdapter();
      final stompClient = StompRealtimeClient(
        wsUrl: 'ws://localhost:8080/ws',
        tokenStorage: tokenStorage,
        transport: simulatedTransport,
        reconnectDelay: const Duration(milliseconds: 50),
      );

      await stompClient.connect();

      const topic = '/topic/parent/11111111-2222-3333-4444-555555555555/events';
      final stream = await stompClient.subscribe(topic);
      expect(simulatedTransport.activeSubscriptions, contains(topic));

      final futureEvent = stream.first;

      simulatedTransport.simulateServerMessage(
        topic,
        '''
        {
          "eventId": "99999999-8888-7777-6666-555555555555",
          "eventType": "DEVICE_TELEMETRY",
          "timestamp": "2026-10-13T02:20:00Z",
          "source": "SIMULATED_DEVICE",
          "correlationId": "corr-777",
          "payload": {
            "deviceId": "SAHAYAK-MOCK-01",
            "timestamp": "2026-10-13T02:20:00Z",
            "connectionState": "CONNECTED",
            "forwardDistanceCm": 92,
            "groundDistanceCm": 95,
            "batteryPercentage": 85,
            "hazardLevel": "FAST_WARNING",
            "simulated": true
          }
        }
        ''',
      );

      final received = await futureEvent;
      expect(received.eventId, equals('99999999-8888-7777-6666-555555555555'));
      expect(received.eventType, equals(RealtimeEventType.deviceTelemetry));
      expect(received.payload['forwardDistanceCm'], equals(92));
      expect(received.payload['simulated'], isTrue);

      // Verify reconnect state handling on unexpected connection drop
      stompClient.simulateConnectionDrop();
      expect(stompClient.connectionState, equals(RealtimeConnectionState.reconnecting));

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(stompClient.connectionState, equals(RealtimeConnectionState.connected));

      stompClient.dispose();
    });
  });
}
