import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/realtime/realtime_event_envelope.dart';
import '../../../core/realtime/stomp_realtime_client.dart';
import '../../../device/device_communication.dart';
import '../../../device/models/device_configuration.dart';
import '../../../device/models/device_connection_state.dart';
import '../../../device/models/hazard_event.dart';
import '../../../device/models/telemetry_data.dart';
import '../../../device/telemetry_pipeline_coordinator.dart';
import '../models/user_module_models.dart';
import '../services/user_module_api_service.dart';

/// State and workflow controller for the SAHAYAK User Module (Phase 2).
///
/// Strictly separates:
/// 1. Persistent Domain Device Status ([DomainDeviceStatus]: REGISTERED, ACTIVE, INACTIVE, DISABLED)
/// 2. Live Transport Connection State ([LiveDeviceConnectionState]: CONNECTED, DISCONNECTED, CONNECTING, ERROR, UNKNOWN)
/// 3. Ephemeral Telemetry ([TelemetryEventPayload] + stale detection)
/// 4. Persisted Domain Safety Events ([PersistedHazardEvent] & [PersistedSosEvent])
class UserModuleController extends ChangeNotifier {
  final UserModuleApiService apiService;
  final StompRealtimeClient realtimeClient;
  final DeviceCommunication deviceCommunication;
  final Duration staleTelemetryThreshold;
  final DateTime Function() _clock;

  TelemetryPipelineCoordinator? _telemetryCoordinator;
  StreamSubscription<RealtimeConnectionState>? _wsStateSub;
  StreamSubscription<RealtimeEventEnvelope<Map<String, dynamic>>>? _userTopicSub;
  StreamSubscription<RealtimeEventEnvelope<TelemetryEventPayload>>? _localTelemetrySub;
  StreamSubscription<DeviceConnectionState>? _deviceConnSub;

  String? _subscribedUserDestination;

  List<RegisteredDevice> _devices = const [];
  RegisteredDevice? _selectedDevice;
  LiveDeviceConnectionState _liveConnectionState = LiveDeviceConnectionState.disconnected;
  RealtimeConnectionState _realtimeSocketState = RealtimeConnectionState.disconnected;
  DeviceConfigModel? _deviceConfiguration;
  TelemetryEventPayload? _latestTelemetry;
  List<PersistedHazardEvent> _hazardEvents = const [];
  List<PersistedSosEvent> _sosEvents = const [];

  bool _isLoading = false;
  bool _isSavingConfiguration = false;
  bool _isSubmittingSos = false;
  String? _errorMessage;
  String? _infoMessage;

  UserModuleController({
    required this.apiService,
    required this.realtimeClient,
    required this.deviceCommunication,
    this.staleTelemetryThreshold = const Duration(seconds: 15),
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc()) {
    _bindDeviceAndRealtimeStreams();
  }

  // --- Read-Only State Getters ---

  List<RegisteredDevice> get devices => List<RegisteredDevice>.unmodifiable(_devices);
  RegisteredDevice? get selectedDevice => _selectedDevice;
  DomainDeviceStatus get selectedDeviceDomainStatus =>
      _selectedDevice?.status ?? DomainDeviceStatus.unknown;
  LiveDeviceConnectionState get liveConnectionState => _liveConnectionState;
  RealtimeConnectionState get realtimeSocketState => _realtimeSocketState;
  DeviceConfigModel? get deviceConfiguration => _deviceConfiguration;
  TelemetryEventPayload? get latestTelemetry => _latestTelemetry;
  List<PersistedHazardEvent> get hazardEvents =>
      List<PersistedHazardEvent>.unmodifiable(_hazardEvents);
  List<PersistedSosEvent> get sosEvents =>
      List<PersistedSosEvent>.unmodifiable(_sosEvents);

  bool get isLoading => _isLoading;
  bool get isSavingConfiguration => _isSavingConfiguration;
  bool get isSubmittingSos => _isSubmittingSos;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  String? get subscribedUserDestination => _subscribedUserDestination;

  /// Returns the currently active SOS event (TRIGGERED or ACKNOWLEDGED), if any.
  PersistedSosEvent? get activeSosEvent {
    for (final event in _sosEvents) {
      if (event.status.isActiveEmergency) {
        return event;
      }
    }
    return null;
  }

  /// Returns the most recent SOS event regardless of terminal status.
  PersistedSosEvent? get latestSosEvent =>
      _sosEvents.isNotEmpty ? _sosEvents.first : null;

  /// Returns true when telemetry has been received but is older than [staleTelemetryThreshold].
  bool isTelemetryStale({DateTime? now}) {
    final telemetry = _latestTelemetry;
    if (telemetry == null) {
      return false;
    }
    final referenceTime = (now ?? _clock()).toUtc();
    return referenceTime.difference(telemetry.timestamp.toUtc()) >
        staleTelemetryThreshold;
  }

  /// Evaluates current overall safety banner level from active SOS, hazards, and telemetry.
  String get currentSafetyBannerState {
    if (activeSosEvent != null) {
      return activeSosEvent!.status.wireName;
    }
    final telemetryHazard = _latestTelemetry?.hazardLevel?.toUpperCase();
    if (telemetryHazard != null &&
        telemetryHazard.isNotEmpty &&
        telemetryHazard != 'NORMAL') {
      return telemetryHazard;
    }
    if (_hazardEvents.isNotEmpty) {
      final latestLevel = _hazardEvents.first.hazardLevel.toUpperCase();
      if (latestLevel != 'NORMAL') {
        return latestLevel;
      }
    }
    return 'NORMAL';
  }

  void clearMessages() {
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  void _bindDeviceAndRealtimeStreams() {
    _realtimeSocketState = realtimeClient.connectionState;
    _wsStateSub = realtimeClient.connectionStateStream.listen((wsState) {
      _realtimeSocketState = wsState;
      notifyListeners();
    });

    _deviceConnSub = deviceCommunication.connectionStateStream.listen((devState) {
      switch (devState) {
        case DeviceConnectionState.connected:
          _liveConnectionState = LiveDeviceConnectionState.connected;
          break;
        case DeviceConnectionState.connecting:
          _liveConnectionState = LiveDeviceConnectionState.connecting;
          break;
        case DeviceConnectionState.disconnecting:
        case DeviceConnectionState.disconnected:
          _liveConnectionState = LiveDeviceConnectionState.disconnected;
          break;
        case DeviceConnectionState.error:
          _liveConnectionState = LiveDeviceConnectionState.error;
          break;
      }
      notifyListeners();
    });

    _rebindTelemetryCoordinator();
  }

  void _rebindTelemetryCoordinator() {
    _localTelemetrySub?.cancel();
    _telemetryCoordinator?.dispose();

    final devId = _selectedDevice?.deviceIdentifier ?? 'SIMULATED_ESP32_STICK';
    _telemetryCoordinator = TelemetryPipelineCoordinator(
      deviceCommunication: deviceCommunication,
      realtimeClient: realtimeClient,
      deviceId: devId,
    );

    _localTelemetrySub =
        _telemetryCoordinator!.telemetryEnvelopeStream.listen((envelope) {
      _latestTelemetry = envelope.payload;
      _liveConnectionState =
          LiveDeviceConnectionState.fromWireName(envelope.payload.connectionState);
      notifyListeners();
    });
  }

  // --- Realtime User Topic Subscription (Section 25) ---

  /// Connects the STOMP client and subscribes strictly to `/topic/user/{userId}/events`.
  /// Never subscribes to `/topic/all-parents`.
  Future<void> connectRealtimeForUser(String userId) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      return;
    }
    final destination = '/topic/user/$trimmedUserId/events';
    if (_subscribedUserDestination != null &&
        _subscribedUserDestination != destination) {
      await _userTopicSub?.cancel();
      await realtimeClient.unsubscribe(_subscribedUserDestination!);
    }

    await realtimeClient.connect();
    final stream = await realtimeClient.subscribe(destination);
    _subscribedUserDestination = destination;
    await _userTopicSub?.cancel();
    _userTopicSub = stream.listen(_handleRealtimeEventEnvelope);
    notifyListeners();
  }

  void _handleRealtimeEventEnvelope(
    RealtimeEventEnvelope<Map<String, dynamic>> envelope,
  ) {
    switch (envelope.eventType) {
      case RealtimeEventType.deviceTelemetry:
        final telemetry = TelemetryEventPayload.fromJson(envelope.payload);
        _latestTelemetry = telemetry;
        _liveConnectionState =
            LiveDeviceConnectionState.fromWireName(telemetry.connectionState);
        notifyListeners();
        break;

      case RealtimeEventType.deviceConnectionState:
        final stateRaw = envelope.payload['connectionState']?.toString();
        if (stateRaw != null) {
          _liveConnectionState = LiveDeviceConnectionState.fromWireName(stateRaw);
          notifyListeners();
        }
        break;

      case RealtimeEventType.hazardAlert:
        final hazard = PersistedHazardEvent.fromJson(envelope.payload);
        _upsertHazardEvent(hazard);
        notifyListeners();
        break;

      case RealtimeEventType.sosEvent:
        final sos = PersistedSosEvent.fromJson(envelope.payload);
        _upsertSosEvent(sos);
        notifyListeners();
        break;

      case RealtimeEventType.connectionAck:
      case RealtimeEventType.systemHeartbeat:
      case RealtimeEventType.unknown:
        // Safely ignored without crashing UI
        break;
    }
  }

  // --- Device Management & Selection (Sections 11-14) ---

  /// Loads all registered devices owned by the authenticated user via GET /api/v1/devices.
  Future<void> loadUserDevices() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await apiService.fetchDevices();
      _devices = fetched;

      if (_devices.isEmpty) {
        _selectedDevice = null;
        _deviceConfiguration = null;
        _hazardEvents = const [];
        _sosEvents = const [];
      } else {
        final currentId = _selectedDevice?.id;
        final matching = currentId != null
            ? _devices.where((d) => d.id == currentId).toList()
            : const <RegisteredDevice>[];
        final target = matching.isNotEmpty ? matching.first : _devices.first;
        await selectDevice(target, notifyStart: false);
      }
    } on ApiClientException catch (ex) {
      _errorMessage = ex.toUserFriendlyMessage();
    } catch (_) {
      _errorMessage = 'Unable to load registered devices.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Selects the active stick device and loads its configuration, hazards, and SOS events.
  Future<void> selectDevice(
    RegisteredDevice device, {
    bool notifyStart = true,
  }) async {
    _selectedDevice = device;
    _rebindTelemetryCoordinator();
    if (notifyStart) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final results = await Future.wait<Object?>([
        apiService.fetchConfiguration(device.id),
        apiService.fetchHazards(device.id),
        apiService.fetchSosEvents(device.id),
      ]);

      final config = results[0] as DeviceConfigModel;
      final hazards = results[1] as List<PersistedHazardEvent>;
      final sosList = results[2] as List<PersistedSosEvent>;

      _deviceConfiguration = config;
      _hazardEvents = hazards;
      _sosEvents = sosList;

      await deviceCommunication.updateConfiguration(
        DeviceConfiguration(
          normalThresholdCm: config.normalThresholdCm,
          slowWarningThresholdCm: config.slowWarningThresholdCm,
          fastWarningThresholdCm: config.fastWarningThresholdCm,
          audioAlertsEnabled: config.audioEnabled,
          hapticIntensityPercent: config.hapticIntensity,
        ),
      );
    } on ApiClientException catch (ex) {
      _errorMessage = ex.toUserFriendlyMessage();
    } catch (_) {
      _errorMessage = 'Unable to load device details.';
    } finally {
      if (notifyStart) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Registers a new SAHAYAK device via POST /api/v1/devices.
  /// Never sends ownerUserId.
  Future<bool> registerNewDevice({
    required String deviceIdentifier,
    required String deviceName,
  }) async {
    final trimmedId = deviceIdentifier.trim();
    final trimmedName = deviceName.trim();
    if (trimmedId.isEmpty || trimmedName.isEmpty) {
      _errorMessage = 'Device identifier and device name are required.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final created = await apiService.registerDevice(
        deviceIdentifier: trimmedId,
        deviceName: trimmedName,
      );
      _devices = [created, ..._devices.where((d) => d.id != created.id)];
      await selectDevice(created, notifyStart: false);
      _infoMessage = 'Device "${created.deviceName}" registered.';
      return true;
    } on ApiClientException catch (ex) {
      _errorMessage = ex.toUserFriendlyMessage();
      return false;
    } catch (_) {
      _errorMessage = 'Unable to register device.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the persistent backend domain status (REGISTERED, ACTIVE, INACTIVE, DISABLED)
  /// without conflating it with live transport connection state.
  Future<bool> updateSelectedDeviceDomainStatus(DomainDeviceStatus newStatus) async {
    final device = _selectedDevice;
    if (device == null) {
      _errorMessage = 'No device selected.';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    _infoMessage = null;
    try {
      final updated = await apiService.updateDeviceStatus(
        deviceId: device.id,
        status: newStatus,
      );
      _selectedDevice = updated;
      _devices = _devices.map((d) => d.id == updated.id ? updated : d).toList();
      _infoMessage = 'Device domain status updated to ${updated.status.displayLabel}.';
      notifyListeners();
      return true;
    } on ApiClientException catch (ex) {
      _errorMessage = ex.toUserFriendlyMessage();
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Failed to update device status.';
      notifyListeners();
      return false;
    }
  }

  // --- Device Configuration Management (Sections 15-16) ---

  /// Validates and saves updated device configuration via PUT /api/v1/devices/{deviceId}/configuration.
  Future<bool> saveDeviceConfiguration(DeviceConfigModel draftConfig) async {
    final device = _selectedDevice;
    if (device == null) {
      _errorMessage = 'No device selected.';
      notifyListeners();
      return false;
    }

    final validationError = draftConfig.validate();
    if (validationError != null) {
      _errorMessage = validationError;
      _infoMessage = null;
      notifyListeners();
      return false;
    }

    _isSavingConfiguration = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final updated = await apiService.updateConfiguration(
        deviceId: device.id,
        configuration: draftConfig,
      );
      _deviceConfiguration = updated;
      await deviceCommunication.updateConfiguration(
        DeviceConfiguration(
          normalThresholdCm: updated.normalThresholdCm,
          slowWarningThresholdCm: updated.slowWarningThresholdCm,
          fastWarningThresholdCm: updated.fastWarningThresholdCm,
          audioAlertsEnabled: updated.audioEnabled,
          hapticIntensityPercent: updated.hapticIntensity,
        ),
      );
      _infoMessage =
          'Configuration saved (Version v${updated.configurationVersion}).';
      return true;
    } on ApiClientException catch (ex) {
      _errorMessage = ex.toUserFriendlyMessage();
      return false;
    } catch (_) {
      _errorMessage = 'Unable to save device configuration.';
      return false;
    } finally {
      _isSavingConfiguration = false;
      notifyListeners();
    }
  }

  // --- Hazard Event Reporting & History (Sections 18-19) ---

  /// Reports and persists an important hazard event via POST /api/v1/devices/{deviceId}/hazards.
  Future<PersistedHazardEvent?> reportHazardEvent({
    required String hazardType,
    required String hazardLevel,
    int? distanceCm,
    String source = 'SIMULATED_DEVICE',
  }) async {
    final device = _selectedDevice;
    if (device == null) {
      _errorMessage = 'Register and select a device before reporting hazards.';
      notifyListeners();
      return null;
    }

    _errorMessage = null;
    try {
      final created = await apiService.reportHazard(
        deviceId: device.id,
        hazardType: hazardType,
        hazardLevel: hazardLevel,
        distanceCm: distanceCm,
        source: source,
      );
      _upsertHazardEvent(created);
      _infoMessage =
          'Hazard recorded: ${created.readableHazardType} (${created.hazardLevel}).';
      notifyListeners();
      return created;
    } on ApiClientException catch (ex) {
      _errorMessage = ex.toUserFriendlyMessage();
      notifyListeners();
      return null;
    } catch (_) {
      _errorMessage = 'Unable to report hazard event.';
      notifyListeners();
      return null;
    }
  }

  Future<void> refreshSafetyEvents() async {
    final device = _selectedDevice;
    if (device == null) return;

    try {
      final results = await Future.wait<Object?>([
        apiService.fetchHazards(device.id),
        apiService.fetchSosEvents(device.id),
      ]);
      _hazardEvents = results[0] as List<PersistedHazardEvent>;
      _sosEvents = results[1] as List<PersistedSosEvent>;
      notifyListeners();
    } on ApiClientException catch (ex) {
      _errorMessage = ex.toUserFriendlyMessage();
      notifyListeners();
    }
  }

  // --- SOS Emergency Workflow (Sections 20-24) ---

  /// Triggers a persisted emergency SOS event via POST /api/v1/devices/{deviceId}/sos.
  Future<PersistedSosEvent?> triggerEmergencySos({
    String source = 'MOBILE_CLIENT',
  }) async {
    final device = _selectedDevice;
    if (device == null) {
      _errorMessage = 'Register and select a device before triggering SOS.';
      notifyListeners();
      return null;
    }

    _isSubmittingSos = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final created = await apiService.triggerSos(
        deviceId: device.id,
        source: source,
      );
      _upsertSosEvent(created);
      _infoMessage = 'Emergency SOS triggered and caregivers notified.';
      return created;
    } on ApiClientException catch (ex) {
      _errorMessage = ex.toUserFriendlyMessage();
      return null;
    } catch (_) {
      _errorMessage = 'Failed to trigger emergency SOS.';
      return null;
    } finally {
      _isSubmittingSos = false;
      notifyListeners();
    }
  }

  /// Cancels an active TRIGGERED SOS event (`TRIGGERED -> CANCELLED`).
  Future<bool> cancelActiveSos([String? sosEventId]) async {
    final targetId = sosEventId ?? activeSosEvent?.id;
    if (targetId == null || targetId.isEmpty) {
      _errorMessage = 'No active SOS event to cancel.';
      notifyListeners();
      return false;
    }

    _isSubmittingSos = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final updated = await apiService.updateSosStatus(
        sosEventId: targetId,
        status: BackendSosStatus.cancelled,
      );
      _upsertSosEvent(updated);
      _infoMessage = 'SOS emergency cancelled.';
      return true;
    } on ApiClientException catch (ex) {
      _errorMessage = ex.toUserFriendlyMessage();
      return false;
    } catch (_) {
      _errorMessage = 'Unable to cancel SOS event.';
      return false;
    } finally {
      _isSubmittingSos = false;
      notifyListeners();
    }
  }

  /// Resolves an active SOS event (`TRIGGERED/ACKNOWLEDGED -> RESOLVED`).
  Future<bool> resolveActiveSos([String? sosEventId]) async {
    final targetId = sosEventId ?? activeSosEvent?.id;
    if (targetId == null || targetId.isEmpty) {
      _errorMessage = 'No active SOS event to resolve.';
      notifyListeners();
      return false;
    }

    _isSubmittingSos = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final updated = await apiService.updateSosStatus(
        sosEventId: targetId,
        status: BackendSosStatus.resolved,
      );
      _upsertSosEvent(updated);
      _infoMessage = 'SOS emergency marked resolved.';
      return true;
    } on ApiClientException catch (ex) {
      _errorMessage = ex.toUserFriendlyMessage();
      return false;
    } catch (_) {
      _errorMessage = 'Unable to resolve SOS event.';
      return false;
    } finally {
      _isSubmittingSos = false;
      notifyListeners();
    }
  }

  // --- Simulated Device Controls (Section 26) ---

  Future<void> connectSimulatedStick() async {
    final devIdentifier =
        _selectedDevice?.deviceIdentifier ?? 'SIMULATED_ESP32_STICK';
    await deviceCommunication.connect(devIdentifier);
    _infoMessage = 'Simulated stick connected ($devIdentifier).';
    notifyListeners();
  }

  Future<void> disconnectSimulatedStick() async {
    await deviceCommunication.disconnect();
    _infoMessage = 'Simulated stick disconnected.';
    notifyListeners();
  }

  /// Emits a simulated telemetry sample through [TelemetryPipelineCoordinator].
  Future<void> simulateTelemetrySample({
    int forwardDistanceCm = 120,
    int groundDistanceCm = 95,
    int batteryPercentage = 88,
    HazardSeverity severity = HazardSeverity.normal,
  }) async {
    if (!(await deviceCommunication.isConnected())) {
      await connectSimulatedStick();
    }
    final devComm = deviceCommunication;
    final now = _clock();

    // Update local hazard severity on the coordinator before telemetry emission
    final payload = TelemetryEventPayload(
      deviceId: _selectedDevice?.deviceIdentifier ?? 'SIMULATED_ESP32_STICK',
      timestamp: now,
      connectionState: 'CONNECTED',
      batteryPercentage: batteryPercentage,
      forwardDistanceCm: forwardDistanceCm,
      groundDistanceCm: groundDistanceCm,
      hazardLevel: _mapSeverityName(severity),
      simulated: true,
    );
    _latestTelemetry = payload;
    _liveConnectionState = LiveDeviceConnectionState.connected;

    // Also drive through DeviceCommunication if it supports simulation
    try {
      (devComm as dynamic).emitSimulatedHazard(
        HazardEvent(
          source: HazardSource.forwardObstacle,
          severity: severity,
          distanceCm: forwardDistanceCm,
          timestamp: now,
        ),
      );
      (devComm as dynamic).emitSimulatedTelemetry(
        TelemetryData(
          forwardDistanceCm: forwardDistanceCm,
          groundDistanceCm: groundDistanceCm,
          batteryPercentage: batteryPercentage,
          timestamp: now,
        ),
      );
    } catch (_) {
      // Non-simulated transport implementation; local payload already updated
    }
    notifyListeners();
  }

  String _mapSeverityName(HazardSeverity severity) {
    switch (severity) {
      case HazardSeverity.normal:
        return 'NORMAL';
      case HazardSeverity.slowWarning:
        return 'SLOW_WARNING';
      case HazardSeverity.fastWarning:
        return 'FAST_WARNING';
      case HazardSeverity.critical:
        return 'CRITICAL';
    }
  }

  void _upsertHazardEvent(PersistedHazardEvent event) {
    final existingIdx = _hazardEvents.indexWhere((e) => e.id == event.id);
    if (existingIdx >= 0) {
      final copy = List<PersistedHazardEvent>.of(_hazardEvents);
      copy[existingIdx] = event;
      _hazardEvents = copy;
    } else {
      _hazardEvents = [event, ..._hazardEvents];
    }
  }

  void _upsertSosEvent(PersistedSosEvent event) {
    final existingIdx = _sosEvents.indexWhere((e) => e.id == event.id);
    if (existingIdx >= 0) {
      final copy = List<PersistedSosEvent>.of(_sosEvents);
      copy[existingIdx] = event;
      _sosEvents = copy;
    } else {
      _sosEvents = [event, ..._sosEvents];
    }
  }

  /// Resets all user-specific device and event state upon logout.
  Future<void> resetForLogout() async {
    await _userTopicSub?.cancel();
    _userTopicSub = null;
    if (_subscribedUserDestination != null) {
      await realtimeClient.unsubscribe(_subscribedUserDestination!);
      _subscribedUserDestination = null;
    }
    await realtimeClient.disconnect();
    await deviceCommunication.disconnect();

    _devices = const [];
    _selectedDevice = null;
    _liveConnectionState = LiveDeviceConnectionState.disconnected;
    _deviceConfiguration = null;
    _latestTelemetry = null;
    _hazardEvents = const [];
    _sosEvents = const [];
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsStateSub?.cancel();
    _userTopicSub?.cancel();
    _localTelemetrySub?.cancel();
    _deviceConnSub?.cancel();
    _telemetryCoordinator?.dispose();
    super.dispose();
  }
}
