import 'dart:async';

import 'models/device_configuration.dart';
import 'models/device_connection_state.dart';
import 'models/hazard_event.dart';
import 'models/sos_event.dart';
import 'models/telemetry_data.dart';

/// Core Device Communication Abstraction.
/// 
/// Decouples all application presentation and domain logic from the underlying
/// physical hardware transport (BLE, Wi-Fi, Cellular, or Mock simulation).
abstract class DeviceCommunication {
  /// Stream broadcasting real-time connection state transitions.
  Stream<DeviceConnectionState> get connectionStateStream;

  /// Stream emitting periodic telemetry updates from the stick.
  Stream<TelemetryData> get telemetryStream;

  /// Stream emitting classified obstacle and drop-off hazard warning events.
  Stream<HazardEvent> get hazardStream;

  /// Stream emitting critical emergency SOS triggers.
  Stream<SosEvent> get sosStream;

  /// Connects to a physical or simulated stick using its identifier/MAC address.
  Future<void> connect(String deviceIdentifier);

  /// Closes the active communication session.
  Future<void> disconnect();

  /// Updates distance thresholds and feedback parameters on the device.
  Future<void> updateConfiguration(DeviceConfiguration configuration);

  /// Returns true if communication is currently active.
  Future<bool> isConnected();

  /// Current device configuration cached or active on the device.
  DeviceConfiguration get currentConfiguration;

  /// Disposes internal streams and resources.
  void dispose();
}
