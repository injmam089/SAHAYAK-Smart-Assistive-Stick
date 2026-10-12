import 'package:flutter_test/flutter_test.dart';
import 'package:sahayak_mobile/device/device_communication.dart';
import 'package:sahayak_mobile/device/mock/simulated_device_communication.dart';
import 'package:sahayak_mobile/device/models/device_configuration.dart';
import 'package:sahayak_mobile/device/models/device_connection_state.dart';
import 'package:sahayak_mobile/device/models/hazard_event.dart';
import 'package:sahayak_mobile/device/models/sos_event.dart';
import 'package:sahayak_mobile/device/models/telemetry_data.dart';

void main() {
  group('DeviceCommunication Abstraction & SimulatedDeviceCommunication', () {
    late SimulatedDeviceCommunication deviceComm;

    setUp(() {
      deviceComm = SimulatedDeviceCommunication();
    });

    tearDown(() {
      deviceComm.dispose();
    });

    test('implements DeviceCommunication contract and connects/disconnects', () async {
      final DeviceCommunication contract = deviceComm;
      expect(await contract.isConnected(), isFalse);

      final states = <DeviceConnectionState>[];
      final sub = contract.connectionStateStream.listen(states.add);

      await contract.connect('ESP32-TEST-01');
      expect(await contract.isConnected(), isTrue);

      await contract.disconnect();
      expect(await contract.isConnected(), isFalse);

      await sub.cancel();
      expect(states, containsAllInOrder([
        DeviceConnectionState.connecting,
        DeviceConnectionState.connected,
        DeviceConnectionState.disconnecting,
        DeviceConnectionState.disconnected,
      ]));
    });

    test('emits simulated telemetry, hazard, and SOS streams', () async {
      await deviceComm.connect('ESP32-TEST-01');

      TelemetryData? receivedTelemetry;
      HazardEvent? receivedHazard;
      SosEvent? receivedSos;

      final tSub = deviceComm.telemetryStream.listen((t) => receivedTelemetry = t);
      final hSub = deviceComm.hazardStream.listen((h) => receivedHazard = h);
      final sSub = deviceComm.sosStream.listen((s) => receivedSos = s);

      deviceComm.emitSimulatedTelemetry(TelemetryData(
        forwardDistanceCm: 120,
        groundDistanceCm: 95,
        batteryPercentage: 88,
        timestamp: DateTime.now(),
      ));

      deviceComm.emitSimulatedHazard(HazardEvent(
        source: HazardSource.forwardObstacle,
        severity: HazardSeverity.slowWarning,
        distanceCm: 120,
        timestamp: DateTime.now(),
      ));

      deviceComm.emitSimulatedSos(latitude: 18.5204, longitude: 73.8567);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(receivedTelemetry?.batteryPercentage, equals(88));
      expect(receivedHazard?.severity, equals(HazardSeverity.slowWarning));
      expect(receivedSos?.status, equals(SosStatus.triggered));

      await tSub.cancel();
      await hSub.cancel();
      await sSub.cancel();
    });

    test('updates configurable thresholds', () async {
      expect(deviceComm.currentConfiguration.normalThresholdCm, equals(150));

      const updated = DeviceConfiguration(
        normalThresholdCm: 160,
        slowWarningThresholdCm: 110,
        fastWarningThresholdCm: 60,
      );
      await deviceComm.updateConfiguration(updated);

      expect(deviceComm.currentConfiguration.normalThresholdCm, equals(160));
      expect(deviceComm.currentConfiguration.slowWarningThresholdCm, equals(110));
      expect(deviceComm.currentConfiguration.fastWarningThresholdCm, equals(60));
    });
  });
}
