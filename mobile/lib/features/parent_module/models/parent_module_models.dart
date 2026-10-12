/// Caregiver–User relationship lifecycle states (Phase 1D / Phase 3).
///
/// Only [ParentLinkState.active] grants authorization to read a user's devices,
/// configurations, telemetry, hazards, or SOS events.
enum ParentLinkState {
  pending('PENDING', 'Pending — Waiting for user approval'),
  active('ACTIVE', 'Active — Authorized'),
  revoked('REVOKED', 'Revoked — Access removed'),
  unknown('UNKNOWN', 'Unknown');

  final String wireName;
  final String displayLabel;
  const ParentLinkState(this.wireName, this.displayLabel);

  /// Only ACTIVE relationships grant access to protected user/device/event data.
  bool get isAuthorized => this == ParentLinkState.active;

  static ParentLinkState fromWireName(String? value) {
    if (value == null || value.isEmpty) {
      return ParentLinkState.unknown;
    }
    final upper = value.trim().toUpperCase();
    for (final state in ParentLinkState.values) {
      if (state.wireName == upper) {
        return state;
      }
    }
    return ParentLinkState.unknown;
  }
}

/// Safe caregiver–user relationship record matching backend ParentUserLinkResponse.
class CaregiverUserLink {
  final String id;
  final String parentUserId;
  final String parentFullName;
  final String parentEmail;
  final String userId;
  final String userFullName;
  final String userEmail;
  final ParentLinkState status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CaregiverUserLink({
    required this.id,
    required this.parentUserId,
    required this.parentFullName,
    required this.parentEmail,
    required this.userId,
    required this.userFullName,
    required this.userEmail,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Returns true ONLY when the relationship is ACTIVE.
  bool get canAccessProtectedData => status.isAuthorized;

  factory CaregiverUserLink.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
        DateTime.now().toUtc();
    return CaregiverUserLink(
      id: (json['id'] ?? '').toString(),
      parentUserId: (json['parentUserId'] ?? '').toString(),
      parentFullName: (json['parentFullName'] ?? '').toString(),
      parentEmail: (json['parentEmail'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      userFullName: (json['userFullName'] ?? '').toString(),
      userEmail: (json['userEmail'] ?? '').toString(),
      status: ParentLinkState.fromWireName(json['status']?.toString()),
      createdAt: created,
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? created,
    );
  }

  CaregiverUserLink copyWith({
    ParentLinkState? status,
    DateTime? updatedAt,
  }) {
    return CaregiverUserLink(
      id: id,
      parentUserId: parentUserId,
      parentFullName: parentFullName,
      parentEmail: parentEmail,
      userId: userId,
      userFullName: userFullName,
      userEmail: userEmail,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }
}

/// High-level caregiver safety summary levels (Section 15 & Section 37).
/// Priority order: SOS ACTIVE > CRITICAL > DANGER > WARNING > SAFE.
enum CaregiverSafetyStatus {
  sosActive('SOS ACTIVE', 'SOS ACTIVE — Emergency Assistance Needed', 5),
  critical('CRITICAL', 'CRITICAL — Immediate Obstacle Hazard', 4),
  danger('DANGER', 'DANGER — Close Obstacle Detected', 3),
  warning('WARNING', 'WARNING — Caution Ahead', 2),
  safe('SAFE', 'SAFE — Clear Path', 1);

  final String shortLabel;
  final String descriptiveLabel;
  final int priorityRank;
  const CaregiverSafetyStatus(
    this.shortLabel,
    this.descriptiveLabel,
    this.priorityRank,
  );

  static CaregiverSafetyStatus fromHazardLevel(String? level) {
    if (level == null || level.isEmpty) {
      return CaregiverSafetyStatus.safe;
    }
    switch (level.trim().toUpperCase()) {
      case 'CRITICAL':
        return CaregiverSafetyStatus.critical;
      case 'DANGER':
        return CaregiverSafetyStatus.danger;
      case 'FAST_WARNING':
      case 'SLOW_WARNING':
      case 'WARNING':
        return CaregiverSafetyStatus.warning;
      case 'NORMAL':
      default:
        return CaregiverSafetyStatus.safe;
    }
  }
}
