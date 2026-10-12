import '../../../core/network/api_client.dart';
import '../models/user_module_models.dart';

/// Typed REST API client service for the SAHAYAK User Module (Phase 2).
///
/// Wraps Phase 1D (Devices & Configuration) and Phase 1E (Hazard & SOS Events)
/// endpoints using the shared [ApiClient] with automatic JWT Bearer headers
/// and 401 refresh-token retry.
class UserModuleApiService {
  final ApiClient apiClient;

  const UserModuleApiService({required this.apiClient});

  /// POST /api/v1/devices
  /// Never sends ownerUserId; ownership is derived strictly from the authenticated JWT principal.
  Future<RegisteredDevice> registerDevice({
    required String deviceIdentifier,
    required String deviceName,
  }) async {
    final response = await apiClient.post(
      '/api/v1/devices',
      body: {
        'deviceIdentifier': deviceIdentifier.trim(),
        'deviceName': deviceName.trim(),
      },
    );
    final data = _extractDataMap(response);
    return RegisteredDevice.fromJson(data);
  }

  /// GET /api/v1/devices
  Future<List<RegisteredDevice>> fetchDevices() async {
    final response = await apiClient.get('/api/v1/devices');
    final list = _extractDataList(response);
    return list
        .whereType<Map<String, dynamic>>()
        .map(RegisteredDevice.fromJson)
        .toList();
  }

  /// GET /api/v1/devices/{deviceId}
  Future<RegisteredDevice> fetchDevice(String deviceId) async {
    final response = await apiClient.get('/api/v1/devices/$deviceId');
    final data = _extractDataMap(response);
    return RegisteredDevice.fromJson(data);
  }

  /// PATCH /api/v1/devices/{deviceId}/status
  Future<RegisteredDevice> updateDeviceStatus({
    required String deviceId,
    required DomainDeviceStatus status,
  }) async {
    final response = await apiClient.patch(
      '/api/v1/devices/$deviceId/status',
      body: {'status': status.wireName},
    );
    final data = _extractDataMap(response);
    return RegisteredDevice.fromJson(data);
  }

  /// GET /api/v1/devices/{deviceId}/configuration
  Future<DeviceConfigModel> fetchConfiguration(String deviceId) async {
    final response = await apiClient.get('/api/v1/devices/$deviceId/configuration');
    final data = _extractDataMap(response);
    return DeviceConfigModel.fromJson(data);
  }

  /// PUT /api/v1/devices/{deviceId}/configuration
  Future<DeviceConfigModel> updateConfiguration({
    required String deviceId,
    required DeviceConfigModel configuration,
  }) async {
    final validationError = configuration.validate();
    if (validationError != null) {
      throw ApiClientException(statusCode: 400, message: validationError);
    }

    final response = await apiClient.put(
      '/api/v1/devices/$deviceId/configuration',
      body: configuration.toUpdateRequestJson(),
    );
    final data = _extractDataMap(response);
    return DeviceConfigModel.fromJson(data);
  }

  /// POST /api/v1/devices/{deviceId}/hazards
  Future<PersistedHazardEvent> reportHazard({
    required String deviceId,
    required String hazardType,
    required String hazardLevel,
    int? distanceCm,
    String source = 'SIMULATED_DEVICE',
    String? correlationId,
  }) async {
    final response = await apiClient.post(
      '/api/v1/devices/$deviceId/hazards',
      body: {
        'hazardType': hazardType,
        'hazardLevel': hazardLevel,
        if (distanceCm != null) 'distanceCm': distanceCm,
        'source': source,
        if (correlationId != null) 'correlationId': correlationId,
      },
    );
    final data = _extractDataMap(response);
    return PersistedHazardEvent.fromJson(data);
  }

  /// GET /api/v1/devices/{deviceId}/hazards
  Future<List<PersistedHazardEvent>> fetchHazards(String deviceId) async {
    final response = await apiClient.get('/api/v1/devices/$deviceId/hazards');
    final list = _extractDataList(response);
    return list
        .whereType<Map<String, dynamic>>()
        .map(PersistedHazardEvent.fromJson)
        .toList();
  }

  /// POST /api/v1/devices/{deviceId}/sos
  Future<PersistedSosEvent> triggerSos({
    required String deviceId,
    String source = 'MOBILE_CLIENT',
    String? correlationId,
  }) async {
    final response = await apiClient.post(
      '/api/v1/devices/$deviceId/sos',
      body: {
        'source': source,
        if (correlationId != null) 'correlationId': correlationId,
      },
    );
    final data = _extractDataMap(response);
    return PersistedSosEvent.fromJson(data);
  }

  /// GET /api/v1/devices/{deviceId}/sos-events
  Future<List<PersistedSosEvent>> fetchSosEvents(String deviceId) async {
    final response = await apiClient.get('/api/v1/devices/$deviceId/sos-events');
    final list = _extractDataList(response);
    return list
        .whereType<Map<String, dynamic>>()
        .map(PersistedSosEvent.fromJson)
        .toList();
  }

  /// PATCH /api/v1/sos-events/{sosEventId}/status
  /// User Module is restricted to USER-authorized transitions (CANCELLED or RESOLVED).
  Future<PersistedSosEvent> updateSosStatus({
    required String sosEventId,
    required BackendSosStatus status,
  }) async {
    if (status == BackendSosStatus.acknowledged) {
      throw const ApiClientException(
        statusCode: 403,
        message: 'Only caregivers can acknowledge an SOS event.',
      );
    }

    final response = await apiClient.patch(
      '/api/v1/sos-events/$sosEventId/status',
      body: {'status': status.wireName},
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
