/// Persistent backend domain device status (Phase 1D/2).
/// Strictly separated from [LiveDeviceConnectionState].
enum DomainDeviceStatus {
  registered('REGISTERED', 'Registered'),
  active('ACTIVE', 'Active'),
  inactive('INACTIVE', 'Inactive'),
  disabled('DISABLED', 'Disabled'),
  unknown('UNKNOWN', 'Unknown');

  final String wireName;
  final String displayLabel;
  const DomainDeviceStatus(this.wireName, this.displayLabel);

  static DomainDeviceStatus fromWireName(String? value) {
    if (value == null || value.isEmpty) {
      return DomainDeviceStatus.unknown;
    }
    final upper = value.trim().toUpperCase();
    for (final status in DomainDeviceStatus.values) {
      if (status.wireName == upper) {
        return status;
      }
    }
    return DomainDeviceStatus.unknown;
  }
}

/// Live device/realtime transport connection state (Phase 1C/2).
/// Strictly separated from [DomainDeviceStatus]: a device can be ACTIVE in the
/// backend domain while DISCONNECTED in live transport.
enum LiveDeviceConnectionState {
  connected('CONNECTED', 'Connected'),
  disconnected('DISCONNECTED', 'Disconnected'),
  connecting('CONNECTING', 'Connecting'),
  error('ERROR', 'Connection Error'),
  unknown('UNKNOWN', 'Unknown');

  final String wireName;
  final String displayLabel;
  const LiveDeviceConnectionState(this.wireName, this.displayLabel);

  static LiveDeviceConnectionState fromWireName(String? value) {
    if (value == null || value.isEmpty) {
      return LiveDeviceConnectionState.unknown;
    }
    final upper = value.trim().toUpperCase();
    for (final state in LiveDeviceConnectionState.values) {
      if (state.wireName == upper) {
        return state;
      }
    }
    return LiveDeviceConnectionState.unknown;
  }
}

/// Registered device domain model matching backend DeviceResponse.
class RegisteredDevice {
  final String id;
  final String deviceIdentifier;
  final String deviceName;
  final String ownerUserId;
  final String ownerFullName;
  final DomainDeviceStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RegisteredDevice({
    required this.id,
    required this.deviceIdentifier,
    required this.deviceName,
    required this.ownerUserId,
    required this.ownerFullName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RegisteredDevice.fromJson(Map<String, dynamic> json) {
    return RegisteredDevice(
      id: (json['id'] ?? '').toString(),
      deviceIdentifier: (json['deviceIdentifier'] ?? '').toString(),
      deviceName: (json['deviceName'] ?? '').toString(),
      ownerUserId: (json['ownerUserId'] ?? '').toString(),
      ownerFullName: (json['ownerFullName'] ?? '').toString(),
      status: DomainDeviceStatus.fromWireName(json['status']?.toString()),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now().toUtc(),
    );
  }

  RegisteredDevice copyWith({
    DomainDeviceStatus? status,
    String? deviceName,
  }) {
    return RegisteredDevice(
      id: id,
      deviceIdentifier: deviceIdentifier,
      deviceName: deviceName ?? this.deviceName,
      ownerUserId: ownerUserId,
      ownerFullName: ownerFullName,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}

/// Device configuration model matching backend DeviceConfigurationResponse & UpdateDeviceConfigurationRequest.
class DeviceConfigModel {
  final String id;
  final String deviceId;
  final String deviceIdentifier;
  final int normalThresholdCm;
  final int slowWarningThresholdCm;
  final int fastWarningThresholdCm;
  final bool hapticEnabled;
  final int hapticIntensity;
  final bool audioEnabled;
  final int audioVolume;
  final int configurationVersion;
  final DateTime updatedAt;

  const DeviceConfigModel({
    this.id = '',
    this.deviceId = '',
    this.deviceIdentifier = '',
    this.normalThresholdCm = 150,
    this.slowWarningThresholdCm = 100,
    this.fastWarningThresholdCm = 50,
    this.hapticEnabled = true,
    this.hapticIntensity = 80,
    this.audioEnabled = true,
    this.audioVolume = 80,
    this.configurationVersion = 1,
    required this.updatedAt,
  });

  factory DeviceConfigModel.defaults({
    String deviceId = '',
    String deviceIdentifier = '',
  }) {
    return DeviceConfigModel(
      deviceId: deviceId,
      deviceIdentifier: deviceIdentifier,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  factory DeviceConfigModel.fromJson(Map<String, dynamic> json) {
    return DeviceConfigModel(
      id: (json['id'] ?? '').toString(),
      deviceId: (json['deviceId'] ?? '').toString(),
      deviceIdentifier: (json['deviceIdentifier'] ?? '').toString(),
      normalThresholdCm: _parseInt(json['normalThresholdCm'], 150),
      slowWarningThresholdCm: _parseInt(json['slowWarningThresholdCm'], 100),
      fastWarningThresholdCm: _parseInt(json['fastWarningThresholdCm'], 50),
      hapticEnabled: json['hapticEnabled'] is bool ? json['hapticEnabled'] as bool : true,
      hapticIntensity: _parseInt(json['hapticIntensity'], 80),
      audioEnabled: json['audioEnabled'] is bool ? json['audioEnabled'] as bool : true,
      audioVolume: _parseInt(json['audioVolume'], 80),
      configurationVersion: _parseInt(json['configurationVersion'], 1),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toUpdateRequestJson() {
    return {
      'normalThresholdCm': normalThresholdCm,
      'slowWarningThresholdCm': slowWarningThresholdCm,
      'fastWarningThresholdCm': fastWarningThresholdCm,
      'hapticEnabled': hapticEnabled,
      'hapticIntensity': hapticIntensity,
      'audioEnabled': audioEnabled,
      'audioVolume': audioVolume,
    };
  }

  /// Validates the threshold hierarchy and feedback ranges before backend submission:
  /// normalThresholdCm > slowWarningThresholdCm > fastWarningThresholdCm > 0
  /// 0 <= hapticIntensity <= 100
  /// 0 <= audioVolume <= 100
  String? validate() {
    if (fastWarningThresholdCm <= 0) {
      return 'Fast warning threshold must be greater than 0 cm.';
    }
    if (slowWarningThresholdCm <= fastWarningThresholdCm) {
      return 'Slow warning threshold ($slowWarningThresholdCm cm) must be greater than fast warning threshold ($fastWarningThresholdCm cm).';
    }
    if (normalThresholdCm <= slowWarningThresholdCm) {
      return 'Normal threshold ($normalThresholdCm cm) must be greater than slow warning threshold ($slowWarningThresholdCm cm).';
    }
    if (hapticIntensity < 0 || hapticIntensity > 100) {
      return 'Haptic intensity must be between 0 and 100.';
    }
    if (audioVolume < 0 || audioVolume > 100) {
      return 'Audio volume must be between 0 and 100.';
    }
    return null;
  }

  DeviceConfigModel copyWith({
    int? normalThresholdCm,
    int? slowWarningThresholdCm,
    int? fastWarningThresholdCm,
    bool? hapticEnabled,
    int? hapticIntensity,
    bool? audioEnabled,
    int? audioVolume,
    int? configurationVersion,
    DateTime? updatedAt,
  }) {
    return DeviceConfigModel(
      id: id,
      deviceId: deviceId,
      deviceIdentifier: deviceIdentifier,
      normalThresholdCm: normalThresholdCm ?? this.normalThresholdCm,
      slowWarningThresholdCm: slowWarningThresholdCm ?? this.slowWarningThresholdCm,
      fastWarningThresholdCm: fastWarningThresholdCm ?? this.fastWarningThresholdCm,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      hapticIntensity: hapticIntensity ?? this.hapticIntensity,
      audioEnabled: audioEnabled ?? this.audioEnabled,
      audioVolume: audioVolume ?? this.audioVolume,
      configurationVersion: configurationVersion ?? this.configurationVersion,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int _parseInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

/// Persisted hazard event model matching backend HazardEventResponse.
class PersistedHazardEvent {
  final String id;
  final String deviceId;
  final String deviceIdentifier;
  final String userId;
  final String hazardType;
  final String hazardLevel;
  final int? distanceCm;
  final String source;
  final String? correlationId;
  final DateTime detectedAt;
  final DateTime createdAt;

  const PersistedHazardEvent({
    required this.id,
    required this.deviceId,
    required this.deviceIdentifier,
    required this.userId,
    required this.hazardType,
    required this.hazardLevel,
    this.distanceCm,
    required this.source,
    this.correlationId,
    required this.detectedAt,
    required this.createdAt,
  });

  factory PersistedHazardEvent.fromJson(Map<String, dynamic> json) {
    final parsedDetected = DateTime.tryParse((json['detectedAt'] ?? '').toString()) ??
        DateTime.now().toUtc();
    return PersistedHazardEvent(
      id: (json['id'] ?? '').toString(),
      deviceId: (json['deviceId'] ?? '').toString(),
      deviceIdentifier: (json['deviceIdentifier'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      hazardType: (json['hazardType'] ?? 'FORWARD_OBSTACLE').toString(),
      hazardLevel: (json['hazardLevel'] ?? 'NORMAL').toString(),
      distanceCm: _parseNullableInt(json['distanceCm']),
      source: (json['source'] ?? 'DEVICE').toString(),
      correlationId: json['correlationId']?.toString(),
      detectedAt: parsedDetected,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? parsedDetected,
    );
  }

  String get readableHazardType {
    switch (hazardType.toUpperCase()) {
      case 'FORWARD_OBSTACLE':
        return 'Forward Obstacle';
      case 'GROUND_HAZARD':
        return 'Ground Drop / Hazard';
      default:
        return hazardType;
    }
  }

  static int? _parseNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// SOS emergency lifecycle states matching backend SosEventStatus.
enum BackendSosStatus {
  triggered('TRIGGERED', 'SOS ACTIVE — WAITING FOR CAREGIVER'),
  acknowledged('ACKNOWLEDGED', 'SOS ACKNOWLEDGED BY CAREGIVER'),
  resolved('RESOLVED', 'SOS RESOLVED'),
  cancelled('CANCELLED', 'SOS CANCELLED'),
  unknown('UNKNOWN', 'UNKNOWN');

  final String wireName;
  final String bannerTitle;
  const BackendSosStatus(this.wireName, this.bannerTitle);

  bool get isActiveEmergency =>
      this == BackendSosStatus.triggered || this == BackendSosStatus.acknowledged;

  static BackendSosStatus fromWireName(String? value) {
    if (value == null || value.isEmpty) {
      return BackendSosStatus.unknown;
    }
    final upper = value.trim().toUpperCase();
    for (final status in BackendSosStatus.values) {
      if (status.wireName == upper) {
        return status;
      }
    }
    return BackendSosStatus.unknown;
  }
}

/// Persisted SOS event model matching backend SosEventResponse.
class PersistedSosEvent {
  final String id;
  final String deviceId;
  final String deviceIdentifier;
  final String userId;
  final String userFullName;
  final BackendSosStatus status;
  final String source;
  final String? correlationId;
  final DateTime triggeredAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedByUserId;
  final DateTime? resolvedAt;
  final String? resolvedByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PersistedSosEvent({
    required this.id,
    required this.deviceId,
    required this.deviceIdentifier,
    required this.userId,
    required this.userFullName,
    required this.status,
    required this.source,
    this.correlationId,
    required this.triggeredAt,
    this.acknowledgedAt,
    this.acknowledgedByUserId,
    this.resolvedAt,
    this.resolvedByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PersistedSosEvent.fromJson(Map<String, dynamic> json) {
    final trigAt = DateTime.tryParse((json['triggeredAt'] ?? '').toString()) ??
        DateTime.now().toUtc();
    return PersistedSosEvent(
      id: (json['id'] ?? '').toString(),
      deviceId: (json['deviceId'] ?? '').toString(),
      deviceIdentifier: (json['deviceIdentifier'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      userFullName: (json['userFullName'] ?? '').toString(),
      status: BackendSosStatus.fromWireName(json['status']?.toString()),
      source: (json['source'] ?? 'MOBILE_CLIENT').toString(),
      correlationId: json['correlationId']?.toString(),
      triggeredAt: trigAt,
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.tryParse(json['acknowledgedAt'].toString())
          : null,
      acknowledgedByUserId: json['acknowledgedByUserId']?.toString(),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'].toString())
          : null,
      resolvedByUserId: json['resolvedByUserId']?.toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? trigAt,
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? trigAt,
    );
  }
}
