import 'dart:convert';

/// Canonical realtime event types matching backend RealtimeEventType.
/// Includes [unknown] to safely handle unrecognized future event types without crashing.
enum RealtimeEventType {
  connectionAck('CONNECTION_ACK'),
  deviceConnectionState('DEVICE_CONNECTION_STATE'),
  deviceTelemetry('DEVICE_TELEMETRY'),
  hazardAlert('HAZARD_ALERT'),
  sosEvent('SOS_EVENT'),
  systemHeartbeat('SYSTEM_HEARTBEAT'),
  unknown('UNKNOWN');

  final String wireName;
  const RealtimeEventType(this.wireName);

  static RealtimeEventType fromWireName(String? value) {
    if (value == null || value.isEmpty) {
      return RealtimeEventType.unknown;
    }
    for (final type in RealtimeEventType.values) {
      if (type.wireName == value) {
        return type;
      }
    }
    return RealtimeEventType.unknown;
  }
}

/// Origin source of a realtime event matching backend EventSource.
enum EventSource {
  simulatedDevice('SIMULATED_DEVICE'),
  device('DEVICE'),
  mobileClient('MOBILE_CLIENT'),
  backend('BACKEND'),
  unknown('UNKNOWN');

  final String wireName;
  const EventSource(this.wireName);

  static EventSource fromWireName(String? value) {
    if (value == null || value.isEmpty) {
      return EventSource.unknown;
    }
    for (final src in EventSource.values) {
      if (src.wireName == value) {
        return src;
      }
    }
    return EventSource.unknown;
  }
}

/// Typed foundation model for a device telemetry event payload.
class TelemetryEventPayload {
  final String deviceId;
  final DateTime timestamp;
  final String connectionState;
  final int? batteryPercentage;
  final int? forwardDistanceCm;
  final int? groundDistanceCm;
  final String? hazardLevel;
  final bool simulated;

  const TelemetryEventPayload({
    required this.deviceId,
    required this.timestamp,
    required this.connectionState,
    this.batteryPercentage,
    this.forwardDistanceCm,
    this.groundDistanceCm,
    this.hazardLevel,
    this.simulated = true,
  });

  factory TelemetryEventPayload.fromJson(Map<String, dynamic> json) {
    return TelemetryEventPayload(
      deviceId: (json['deviceId'] ?? 'UNKNOWN_DEVICE').toString(),
      timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now().toUtc(),
      connectionState: (json['connectionState'] ?? 'DISCONNECTED').toString(),
      batteryPercentage: _parseIntSafely(json['batteryPercentage']),
      forwardDistanceCm: _parseIntSafely(json['forwardDistanceCm']),
      groundDistanceCm: _parseIntSafely(json['groundDistanceCm']),
      hazardLevel: json['hazardLevel']?.toString(),
      simulated: json['simulated'] is bool ? json['simulated'] as bool : true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'connectionState': connectionState,
      if (batteryPercentage != null) 'batteryPercentage': batteryPercentage,
      if (forwardDistanceCm != null) 'forwardDistanceCm': forwardDistanceCm,
      if (groundDistanceCm != null) 'groundDistanceCm': groundDistanceCm,
      if (hazardLevel != null) 'hazardLevel': hazardLevel,
      'simulated': simulated,
    };
  }

  static int? _parseIntSafely(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// Standardized Realtime Event Envelope matching backend RealtimeEventEnvelope<T>.
class RealtimeEventEnvelope<T> {
  final String eventId;
  final RealtimeEventType eventType;
  final DateTime timestamp;
  final EventSource source;
  final String? correlationId;
  final T payload;

  const RealtimeEventEnvelope({
    required this.eventId,
    required this.eventType,
    required this.timestamp,
    required this.source,
    this.correlationId,
    required this.payload,
  });

  Map<String, dynamic> toJson([Object? Function(T value)? toJsonT]) {
    final dynamic serializedPayload;
    if (toJsonT != null) {
      serializedPayload = toJsonT(payload);
    } else if (payload is TelemetryEventPayload) {
      serializedPayload = (payload as TelemetryEventPayload).toJson();
    } else {
      serializedPayload = payload;
    }

    return {
      'eventId': eventId,
      'eventType': eventType.wireName,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'source': source.wireName,
      if (correlationId != null) 'correlationId': correlationId,
      'payload': serializedPayload,
    };
  }

  /// Safely parses a JSON map into a [RealtimeEventEnvelope].
  /// Never throws on unknown event types.
  static RealtimeEventEnvelope<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Object? rawPayload) fromJsonT,
  ) {
    return RealtimeEventEnvelope<T>(
      eventId: (json['eventId'] ?? 'unknown-event-id').toString(),
      eventType: RealtimeEventType.fromWireName(json['eventType']?.toString()),
      timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now().toUtc(),
      source: EventSource.fromWireName(json['source']?.toString()),
      correlationId: json['correlationId']?.toString(),
      payload: fromJsonT(json['payload']),
    );
  }

  /// Safely parses a raw JSON string into a [RealtimeEventEnvelope] of dynamic map payload.
  /// Returns null instead of crashing if the string is malformed or non-JSON.
  static RealtimeEventEnvelope<Map<String, dynamic>>? tryParseRawJson(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return fromJson<Map<String, dynamic>>(
        decoded,
        (rawPayload) => rawPayload is Map<String, dynamic>
            ? rawPayload
            : <String, dynamic>{'value': rawPayload},
      );
    } catch (_) {
      return null;
    }
  }

  /// Safely parses a raw JSON string into a typed [TelemetryEventPayload] envelope.
  /// Returns null if the JSON is malformed or not a telemetry event.
  static RealtimeEventEnvelope<TelemetryEventPayload>? tryParseTelemetryJson(String rawJson) {
    final baseEnvelope = tryParseRawJson(rawJson);
    if (baseEnvelope == null ||
        baseEnvelope.eventType != RealtimeEventType.deviceTelemetry) {
      return null;
    }
    return RealtimeEventEnvelope<TelemetryEventPayload>(
      eventId: baseEnvelope.eventId,
      eventType: baseEnvelope.eventType,
      timestamp: baseEnvelope.timestamp,
      source: baseEnvelope.source,
      correlationId: baseEnvelope.correlationId,
      payload: TelemetryEventPayload.fromJson(baseEnvelope.payload),
    );
  }
}
