import 'dart:async';

import '../core/realtime/realtime_event_envelope.dart';
import '../core/realtime/stomp_realtime_client.dart';
import 'device_communication.dart';
import 'models/device_connection_state.dart';
import 'models/hazard_event.dart';
import 'models/telemetry_data.dart';

/// Phase 1C Mock Device -> Flutter Event Pipeline Coordinator.
///
/// Bridges the [DeviceCommunication] abstraction (using [SimulatedDeviceCommunication]
/// in Phase 1C) to the standardized [RealtimeEventEnvelope] stream and optional
/// [StompRealtimeClient] upstream relay.
class TelemetryPipelineCoordinator {
  final DeviceCommunication deviceCommunication;
  final StompRealtimeClient? realtimeClient;
  final String deviceId;

  final StreamController<RealtimeEventEnvelope<TelemetryEventPayload>>
      _telemetryEnvelopeController =
      StreamController<RealtimeEventEnvelope<TelemetryEventPayload>>.broadcast();

  StreamSubscription<DeviceConnectionState>? _connectionSub;
  StreamSubscription<TelemetryData>? _telemetrySub;
  StreamSubscription<HazardEvent>? _hazardSub;

  DeviceConnectionState _latestConnectionState = DeviceConnectionState.disconnected;
  HazardSeverity _latestHazardSeverity = HazardSeverity.normal;
  int _eventSequence = 0;

  TelemetryPipelineCoordinator({
    required this.deviceCommunication,
    this.realtimeClient,
    this.deviceId = 'SIMULATED_ESP32_STICK',
  }) {
    _startListening();
  }

  /// Observable stream of standardized, typed telemetry event envelopes.
  Stream<RealtimeEventEnvelope<TelemetryEventPayload>> get telemetryEnvelopeStream =>
      _telemetryEnvelopeController.stream;

  void _startListening() {
    _connectionSub = deviceCommunication.connectionStateStream.listen((state) {
      _latestConnectionState = state;
    });

    _hazardSub = deviceCommunication.hazardStream.listen((hazard) {
      _latestHazardSeverity = hazard.severity;
    });

    _telemetrySub = deviceCommunication.telemetryStream.listen(_onTelemetrySample);
  }

  void _onTelemetrySample(TelemetryData data) {
    _eventSequence++;
    final payload = TelemetryEventPayload(
      deviceId: deviceId,
      timestamp: data.timestamp.toUtc(),
      connectionState: _mapConnectionState(_latestConnectionState),
      batteryPercentage: data.batteryPercentage,
      forwardDistanceCm: data.forwardDistanceCm,
      groundDistanceCm: data.groundDistanceCm,
      hazardLevel: _mapHazardSeverity(_latestHazardSeverity),
      simulated: true, // Explicitly marked as simulated in Phase 1C
    );

    final envelope = RealtimeEventEnvelope<TelemetryEventPayload>(
      eventId: 'sim-evt-${data.timestamp.millisecondsSinceEpoch}-$_eventSequence',
      eventType: RealtimeEventType.deviceTelemetry,
      timestamp: data.timestamp.toUtc(),
      source: EventSource.simulatedDevice,
      correlationId: 'sim-corr-$_eventSequence',
      payload: payload,
    );

    if (!_telemetryEnvelopeController.isClosed) {
      _telemetryEnvelopeController.add(envelope);
    }

    // Forward simulated telemetry to STOMP backend when realtime client is connected
    final client = realtimeClient;
    if (client != null && client.isConnected) {
      client.send('/app/telemetry.simulate', {
        'deviceId': payload.deviceId,
        'connectionState': payload.connectionState,
        'batteryPercentage': payload.batteryPercentage,
        'forwardDistanceCm': payload.forwardDistanceCm,
        'groundDistanceCm': payload.groundDistanceCm,
        'hazardLevel': payload.hazardLevel,
        'correlationId': envelope.correlationId,
      });
    }
  }

  String _mapConnectionState(DeviceConnectionState state) {
    switch (state) {
      case DeviceConnectionState.connected:
        return 'CONNECTED';
      case DeviceConnectionState.connecting:
        return 'CONNECTING';
      case DeviceConnectionState.disconnecting:
      case DeviceConnectionState.disconnected:
      case DeviceConnectionState.error:
        return 'DISCONNECTED';
    }
  }

  String _mapHazardSeverity(HazardSeverity severity) {
    switch (severity) {
      case HazardSeverity.normal:
        return 'NORMAL';
      case HazardSeverity.slowWarning:
        return 'SLOW_WARNING';
      case HazardSeverity.fastWarning:
        return 'FAST_WARNING';
      case HazardSeverity.critical:
        return 'CRITICAL';
    }
  }

  void dispose() {
    _connectionSub?.cancel();
    _telemetrySub?.cancel();
    _hazardSub?.cancel();
    _telemetryEnvelopeController.close();
  }
}
