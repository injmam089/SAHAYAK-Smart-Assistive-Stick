import '../../../core/network/api_client.dart';
import '../../user_module/models/user_module_models.dart';
import '../models/parent_module_models.dart';

/// Typed REST API client service for the SAHAYAK Parent Control Module (Phase 3).
///
/// Reuses the shared [ApiClient] and enforces strict caregiver security policies:
/// - Parents can initiate PENDING link requests and revoke links, but CANNOT self-approve (PENDING -> ACTIVE).
/// - Parents can read devices, configurations, hazards, and SOS events ONLY for ACTIVE-linked users.
/// - Parents CANNOT register devices, modify device status, or modify device configurations.
/// - Parents can ACKNOWLEDGE (from TRIGGERED) and RESOLVE (from ACKNOWLEDGED) SOS events,
///   but CANNOT CANCEL a user's SOS event.
class ParentModuleApiService {
  final ApiClient apiClient;

  const ParentModuleApiService({required this.apiClient});

  /// GET /api/v1/parent-links
  Future<List<CaregiverUserLink>> fetchParentLinks() async {
    final response = await apiClient.get('/api/v1/parent-links');
    final list = _extractDataList(response);
    return list
        .whereType<Map<String, dynamic>>()
        .map(CaregiverUserLink.fromJson)
        .toList();
  }

  /// POST /api/v1/parent-links
  /// Initiates a caregiver relationship request in PENDING status.
  Future<CaregiverUserLink> createLinkRequest({
    required String targetUserId,
  }) async {
    final response = await apiClient.post(
      '/api/v1/parent-links',
      body: {'userId': targetUserId.trim()},
    );
    final data = _extractDataMap(response);
    return CaregiverUserLink.fromJson(data);
  }

  /// PATCH /api/v1/parent-links/{linkId}/status
  /// Caregivers are strictly prohibited from self-approving (PENDING -> ACTIVE).
  Future<CaregiverUserLink> updateLinkStatus({
    required String linkId,
    required ParentLinkState targetState,
  }) async {
    if (targetState == ParentLinkState.active) {
      throw const ApiClientException(
        statusCode: 403,
        message:
            'Caregivers cannot self-approve a pending relationship request. Waiting for user approval.',
      );
    }
    if (targetState != ParentLinkState.revoked) {
      throw const ApiClientException(
        statusCode: 400,
        message: 'Invalid caregiver relationship transition.',
      );
    }

    final response = await apiClient.patch(
      '/api/v1/parent-links/$linkId/status',
      body: {'status': targetState.wireName},
    );
    final data = _extractDataMap(response);
    return CaregiverUserLink.fromJson(data);
  }

  /// Convenience helper to revoke an existing relationship.
  Future<CaregiverUserLink> revokeLink({required String linkId}) {
    return updateLinkStatus(
      linkId: linkId,
      targetState: ParentLinkState.revoked,
    );
  }

  /// GET /api/v1/devices
  /// Backend returns devices exclusively for users with an ACTIVE ParentUserLink.
  Future<List<RegisteredDevice>> fetchAccessibleDevices() async {
    final response = await apiClient.get('/api/v1/devices');
    final list = _extractDataList(response);
    return list
        .whereType<Map<String, dynamic>>()
        .map(RegisteredDevice.fromJson)
        .toList();
  }

  /// GET /api/v1/devices/{deviceId}
  Future<RegisteredDevice> fetchDeviceById(String deviceId) async {
    final response = await apiClient.get('/api/v1/devices/$deviceId');
    final data = _extractDataMap(response);
    return RegisteredDevice.fromJson(data);
  }

  /// GET /api/v1/devices/{deviceId}/configuration (Read-only for ACTIVE linked caregivers)
  Future<DeviceConfigModel> fetchDeviceConfiguration(String deviceId) async {
    final response =
        await apiClient.get('/api/v1/devices/$deviceId/configuration');
    final data = _extractDataMap(response);
    return DeviceConfigModel.fromJson(data);
  }

  /// Caregiver policy guard: Parents are strictly forbidden from modifying device configuration.
  Future<Never> attemptModifyDeviceConfiguration({
    required String deviceId,
    required DeviceConfigModel configuration,
  }) async {
    throw const ApiClientException(
      statusCode: 403,
      message: 'Caregivers are not authorized to modify device configuration.',
    );
  }

  /// Caregiver policy guard: Parents are strictly forbidden from registering devices.
  Future<Never> attemptRegisterDevice({
    required String deviceIdentifier,
    required String deviceName,
  }) async {
    throw const ApiClientException(
      statusCode: 403,
      message: 'Caregivers are not authorized to register or claim devices.',
    );
  }

  /// GET /api/v1/devices/{deviceId}/hazards
  Future<List<PersistedHazardEvent>> fetchDeviceHazards(String deviceId) async {
    final response = await apiClient.get('/api/v1/devices/$deviceId/hazards');
    final list = _extractDataList(response);
    return list
        .whereType<Map<String, dynamic>>()
        .map(PersistedHazardEvent.fromJson)
        .toList();
  }

  /// GET /api/v1/devices/{deviceId}/sos-events
  Future<List<PersistedSosEvent>> fetchDeviceSosEvents(String deviceId) async {
    final response =
        await apiClient.get('/api/v1/devices/$deviceId/sos-events');
    final list = _extractDataList(response);
    return list
        .whereType<Map<String, dynamic>>()
        .map(PersistedSosEvent.fromJson)
        .toList();
  }

  /// GET /api/v1/sos-events/{sosEventId}
  Future<PersistedSosEvent> fetchSosEventById(String sosEventId) async {
    final response = await apiClient.get('/api/v1/sos-events/$sosEventId');
    final data = _extractDataMap(response);
    return PersistedSosEvent.fromJson(data);
  }

  /// PATCH /api/v1/sos-events/{sosEventId}/status
  /// Caregivers may only transition TRIGGERED -> ACKNOWLEDGED or ACKNOWLEDGED -> RESOLVED.
  /// Caregivers are strictly prohibited from cancelling (CANCELLED) a user's SOS.
  Future<PersistedSosEvent> updateSosStatus({
    required String sosEventId,
    required BackendSosStatus targetStatus,
  }) async {
    if (targetStatus == BackendSosStatus.cancelled) {
      throw const ApiClientException(
        statusCode: 403,
        message: 'Caregivers are not permitted to cancel a user SOS event.',
      );
    }
    if (targetStatus != BackendSosStatus.acknowledged &&
        targetStatus != BackendSosStatus.resolved) {
      throw const ApiClientException(
        statusCode: 400,
        message: 'Invalid caregiver SOS transition.',
      );
    }

    final response = await apiClient.patch(
      '/api/v1/sos-events/$sosEventId/status',
      body: {'status': targetStatus.wireName},
    );
    final data = _extractDataMap(response);
    return PersistedSosEvent.fromJson(data);
  }

  Map<String, dynamic> _extractDataMap(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return response;
  }

  List<dynamic> _extractDataList(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List<dynamic>) {
      return data;
    }
    return const <dynamic>[];
  }
}
