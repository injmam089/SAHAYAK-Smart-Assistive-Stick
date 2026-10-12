/// Severity levels matching SAHAYAK configurable distance thresholds:
/// > 150 cm: normal
/// 100-150 cm: slowWarning
/// 50-100 cm: fastWarning
/// < 50 cm: critical
enum HazardSeverity {
  normal,
  slowWarning,
  fastWarning,
  critical,
}

enum HazardSource {
  forwardObstacle,
  groundHazard,
}

/// Represents a classified hazard condition emitted by the stick.
class HazardEvent {
  final HazardSource source;
  final HazardSeverity severity;
  final int distanceCm;
  final DateTime timestamp;

  const HazardEvent({
    required this.source,
    required this.severity,
    required this.distanceCm,
    required this.timestamp,
  });
}
