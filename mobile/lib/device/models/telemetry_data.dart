/// Periodic or real-time telemetry snapshot received from the SAHAYAK stick.
class TelemetryData {
  final int forwardDistanceCm;
  final int groundDistanceCm;
  final int batteryPercentage;
  final DateTime timestamp;

  const TelemetryData({
    required this.forwardDistanceCm,
    required this.groundDistanceCm,
    required this.batteryPercentage,
    required this.timestamp,
  });
}
