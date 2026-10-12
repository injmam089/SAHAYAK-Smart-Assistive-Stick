/// SOS Emergency event lifecycle states.
enum SosStatus {
  triggered,
  notified,
  acknowledged,
  resolved,
}

/// Critical emergency SOS payload with optional smartphone GPS enrichment.
class SosEvent {
  final String eventId;
  final String deviceIdentifier;
  final SosStatus status;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime triggeredAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;

  const SosEvent({
    required this.eventId,
    required this.deviceIdentifier,
    required this.status,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    required this.triggeredAt,
    this.acknowledgedAt,
    this.acknowledgedBy,
  });

  SosEvent copyWith({
    SosStatus? status,
    DateTime? acknowledgedAt,
    String? acknowledgedBy,
  }) {
    return SosEvent(
      eventId: eventId,
      deviceIdentifier: deviceIdentifier,
      status: status ?? this.status,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      triggeredAt: triggeredAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
    );
  }
}
