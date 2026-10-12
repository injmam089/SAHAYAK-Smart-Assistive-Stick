import 'dart:async';

import '../device_communication.dart';
import '../models/device_configuration.dart';
import '../models/device_connection_state.dart';
import '../models/hazard_event.dart';
import '../models/sos_event.dart';
import '../models/telemetry_data.dart';

/// Mock / Simulated implementation of [DeviceCommunication].
///
/// Enables complete UI development, automated testing, and integration testing
/// without requiring physical ESP32 BLE hardware.
class SimulatedDeviceCommunication implements DeviceCommunication {
  final StreamController<DeviceConnectionState> _connectionController =
      StreamController<DeviceConnectionState>.broadcast();
  final StreamController<TelemetryData> _telemetryController =
      StreamController<TelemetryData>.broadcast();
  final StreamController<HazardEvent> _hazardController =
      StreamController<HazardEvent>.broadcast();
  final StreamController<SosEvent> _sosController =
      StreamController<SosEvent>.broadcast();

  DeviceConnectionState _currentState = DeviceConnectionState.disconnected;
  DeviceConfiguration _configuration = const DeviceConfiguration();
  String? _connectedDeviceId;

  @override
  Stream<DeviceConnectionState> get connectionStateStream =>
      _connectionController.stream;

  @override
  Stream<TelemetryData> get telemetryStream => _telemetryController.stream;

  @override
  Stream<HazardEvent> get hazardStream => _hazardController.stream;

  @override
  Stream<SosEvent> get sosStream => _sosController.stream;

  @override
  DeviceConfiguration get currentConfiguration => _configuration;

  @override
  Future<void> connect(String deviceIdentifier) async {
    _currentState = DeviceConnectionState.connecting;
    _connectionController.add(_currentState);

    await Future<void>.delayed(const Duration(milliseconds: 50));

    _connectedDeviceId = deviceIdentifier;
    _currentState = DeviceConnectionState.connected;
    _connectionController.add(_currentState);
  }

  @override
  Future<void> disconnect() async {
    _currentState = DeviceConnectionState.disconnecting;
    _connectionController.add(_currentState);

    await Future<void>.delayed(const Duration(milliseconds: 20));

    _connectedDeviceId = null;
    _currentState = DeviceConnectionState.disconnected;
    _connectionController.add(_currentState);
  }

  @override
  Future<void> updateConfiguration(DeviceConfiguration configuration) async {
    _configuration = configuration;
  }

  @override
  Future<bool> isConnected() async {
    return _currentState == DeviceConnectionState.connected;
  }

  // --- Simulation Helpers for Testing & UI Development ---

  void emitSimulatedTelemetry(TelemetryData data) {
    if (_currentState == DeviceConnectionState.connected) {
      _telemetryController.add(data);
    }
  }

  void emitSimulatedHazard(HazardEvent event) {
    if (_currentState == DeviceConnectionState.connected) {
      _hazardController.add(event);
    }
  }

  void emitSimulatedSos({double? latitude, double? longitude}) {
    final event = SosEvent(
      eventId: 'sim-sos-${DateTime.now().millisecondsSinceEpoch}',
      deviceIdentifier: _connectedDeviceId ?? 'SIMULATED_ESP32_STICK',
      status: SosStatus.triggered,
      latitude: latitude,
      longitude: longitude,
      triggeredAt: DateTime.now(),
    );
    _sosController.add(event);
  }

  @override
  void dispose() {
    _connectionController.close();
    _telemetryController.close();
    _hazardController.close();
    _sosController.close();
  }
}
