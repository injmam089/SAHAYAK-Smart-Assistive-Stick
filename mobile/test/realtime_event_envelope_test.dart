import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahayak_mobile/core/realtime/realtime_event_envelope.dart';

void main() {
  group('RealtimeEventEnvelope & TelemetryEventPayload', () {
    test('serializes and deserializes DEVICE_TELEMETRY event envelope cleanly', () {
      final timestamp = DateTime.parse('2026-10-13T02:00:00Z');
      final payload = TelemetryEventPayload(
        deviceId: 'SIM-ESP32-001',
        timestamp: timestamp,
        connectionState: 'CONNECTED',
        batteryPercentage: 84,
        forwardDistanceCm: 112,
        groundDistanceCm: 96,
        hazardLevel: 'SLOW_WARNING',
        simulated: true,
      );

      final envelope = RealtimeEventEnvelope<TelemetryEventPayload>(
        eventId: 'evt-001',
        eventType: RealtimeEventType.deviceTelemetry,
        timestamp: timestamp,
        source: EventSource.simulatedDevice,
        correlationId: 'corr-001',
        payload: payload,
      );

      final jsonString = jsonEncode(envelope.toJson());
      final parsed = RealtimeEventEnvelope.tryParseTelemetryJson(jsonString);

      expect(parsed, isNotNull);
      expect(parsed!.eventId, equals('evt-001'));
      expect(parsed.eventType, equals(RealtimeEventType.deviceTelemetry));
      expect(parsed.source, equals(EventSource.simulatedDevice));
      expect(parsed.correlationId, equals('corr-001'));
      expect(parsed.payload.deviceId, equals('SIM-ESP32-001'));
      expect(parsed.payload.batteryPercentage, equals(84));
      expect(parsed.payload.forwardDistanceCm, equals(112));
      expect(parsed.payload.groundDistanceCm, equals(96));
      expect(parsed.payload.hazardLevel, equals('SLOW_WARNING'));
      expect(parsed.payload.simulated, isTrue);
    });

    test('safely maps unknown eventType and source without crashing', () {
      const unknownJson = '''
      {
        "eventId": "evt-future-99",
        "eventType": "FUTURE_QUANTUM_SENSOR_EVENT",
        "timestamp": "2026-10-13T02:00:00Z",
        "source": "FUTURE_GATEWAY",
        "payload": {"customKey": 42}
      }
      ''';

      final parsed = RealtimeEventEnvelope.tryParseRawJson(unknownJson);
      expect(parsed, isNotNull);
      expect(parsed!.eventId, equals('evt-future-99'));
      expect(parsed.eventType, equals(RealtimeEventType.unknown));
      expect(parsed.source, equals(EventSource.unknown));
      expect(parsed.payload['customKey'], equals(42));
    });

    test('safely returns null on malformed JSON without throwing', () {
      expect(RealtimeEventEnvelope.tryParseRawJson('{malformed-json'), isNull);
      expect(RealtimeEventEnvelope.tryParseRawJson('["not-an-object"]'), isNull);
      expect(RealtimeEventEnvelope.tryParseTelemetryJson('not-json'), isNull);
    });
  });
}
