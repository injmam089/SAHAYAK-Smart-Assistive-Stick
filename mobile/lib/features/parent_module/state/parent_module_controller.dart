import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/realtime/realtime_event_envelope.dart';
import '../../../core/realtime/stomp_realtime_client.dart';
import '../../user_module/models/user_module_models.dart';
import '../models/parent_module_models.dart';
import '../services/parent_module_api_service.dart';

/// State and authorization-aware workflow controller for the SAHAYAK Parent Control Module (Phase 3).
///
/// Enforces:
/// 1. Only ACTIVE [CaregiverUserLink] relationships unlock user/device/telemetry/hazard/SOS data.
/// 2. PENDING and REVOKED relationships expose zero protected device or event data.
/// 3. Domain Device Status ([DomainDeviceStatus]) is strictly separated from
///    Live Transport Connection State ([LiveDeviceConnectionState]).
/// 4. Realtime STOMP subscription is restricted to `/topic/parent/{parentId}/events`
///    and filters every incoming event against currently authorized ACTIVE linked users/devices.
/// 5. Immediate purge of cached protected data when a relationship transitions ACTIVE -> REVOKED.
class ParentModuleController extends ChangeNotifier {
  final ParentModuleApiService apiService;
  final StompRealtimeClient realtimeClient;

  StreamSubscription<RealtimeConnectionState>? _wsStateSub;
  StreamSubscription<RealtimeEventEnvelope<Map<String, dynamic>>>? _parentTopicSub;

  String? _authenticatedParentId;
  String? _subscribedParentDestination;
  RealtimeConnectionState _realtimeSocketState = RealtimeConnectionState.disconnected;

  List<CaregiverUserLink> _links = const [];
  String? _selectedUserId;

  // Protected caches — populated ONLY for ACTIVE linked users and immediately purged on REVOKED
  final Map<String, List<RegisteredDevice>> _devicesByUserId = {};
  final Map<String, DeviceConfigModel> _configurationsByDeviceId = {};
  final Map<String, LiveDeviceConnectionState> _liveConnectionByDeviceId = {};
  final Map<String, TelemetryEventPayload> _latestTelemetryByDeviceId = {};
  final Map<String, List<PersistedHazardEvent>> _hazardsByDeviceId = {};
  final Map<String, List<PersistedSosEvent>> _sosEventsByDeviceId = {};

  bool _isLoading = false;
  bool _isSubmittingAction = false;
  String? _errorMessage;
  String? _infoMessage;

  ParentModuleController({
    required this.apiService,
    required this.realtimeClient,
  }) {
    _realtimeSocketState = realtimeClient.connectionState;
    _wsStateSub = realtimeClient.connectionStateStream.listen((wsState) {
      _realtimeSocketState = wsState;
      notifyListeners();
    });
  }

  // --- Read-Only State Getters ---

  List<CaregiverUserLink> get links => List<CaregiverUserLink>.unmodifiable(_links);

  List<CaregiverUserLink> get activeLinks =>
      _links.where((l) => l.status == ParentLinkState.active).toList(growable: false);

  List<CaregiverUserLink> get pendingLinks =>
      _links.where((l) => l.status == ParentLinkState.pending).toList(growable: false);

  List<CaregiverUserLink> get revokedLinks =>
      _links.where((l) => l.status == ParentLinkState.revoked).toList(growable: false);

  String? get selectedUserId => _selectedUserId;

  CaregiverUserLink? get selectedActiveLink {
    final targetId = _selectedUserId;
    if (targetId == null) return null;
    for (final link in _links) {
      if (link.userId == targetId && link.status == ParentLinkState.active) {
        return link;
      }
    }
    return null;
  }

  RealtimeConnectionState get realtimeSocketState => _realtimeSocketState;
  String? get subscribedParentDestination => _subscribedParentDestination;
  bool get isLoading => _isLoading;
  bool get isSubmittingAction => _isSubmittingAction;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;

  void clearMessages() {
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  /// Returns true ONLY if [userId] has a currently ACTIVE [CaregiverUserLink].
  bool isUserActiveLinked(String userId) {
    return _links.any(
      (link) => link.userId == userId && link.status == ParentLinkState.active,
    );
  }

  /// Returns authorized devices for [userId]. Always empty if [userId] is PENDING, REVOKED, or unrelated.
  List<RegisteredDevice> devicesForUser(String userId) {
    if (!isUserActiveLinked(userId)) {
      return const [];
    }
    return List<RegisteredDevice>.unmodifiable(
      _devicesByUserId[userId] ?? const [],
    );
  }

  /// Returns all authorized devices across all ACTIVE linked users.
  List<RegisteredDevice> get allAuthorizedDevices {
    final result = <RegisteredDevice>[];
    for (final link in activeLinks) {
      result.addAll(_devicesByUserId[link.userId] ?? const []);
    }
    return List<RegisteredDevice>.unmodifiable(result);
  }

  /// Returns read-only configuration for [deviceId] only if it belongs to an ACTIVE linked user.
  DeviceConfigModel? configurationForDevice(String deviceId) {
    if (!_isDeviceAuthorized(deviceId)) {
      return null;
    }
    return _configurationsByDeviceId[deviceId];
  }

  /// Returns persistent backend domain status ([DomainDeviceStatus]) for [deviceId],
  /// strictly separated from [liveConnectionForDevice].
  DomainDeviceStatus domainStatusForDevice(String deviceId) {
    final device = _findAuthorizedDeviceById(deviceId);
    return device?.status ?? DomainDeviceStatus.unknown;
  }

  /// Returns live transport connection state ([LiveDeviceConnectionState]) for [deviceId],
  /// strictly separated from [domainStatusForDevice].
  LiveDeviceConnectionState liveConnectionForDevice(String deviceId) {
    if (!_isDeviceAuthorized(deviceId)) {
      return LiveDeviceConnectionState.unknown;
    }
    return _liveConnectionByDeviceId[deviceId] ??
        LiveDeviceConnectionState.disconnected;
  }

  /// Returns latest telemetry for [deviceId] only if it belongs to an ACTIVE linked user.
  TelemetryEventPayload? telemetryForDevice(String deviceId) {
    if (!_isDeviceAuthorized(deviceId)) {
      return null;
    }
    return _latestTelemetryByDeviceId[deviceId];
  }

  /// Returns hazard history for [deviceId] only if it belongs to an ACTIVE linked user.
  List<PersistedHazardEvent> hazardsForDevice(String deviceId) {
    if (!_isDeviceAuthorized(deviceId)) {
      return const [];
    }
    return List<PersistedHazardEvent>.unmodifiable(
      _hazardsByDeviceId[deviceId] ?? const [],
    );
  }

  /// Returns all hazard events for an ACTIVE linked [userId].
  List<PersistedHazardEvent> hazardsForUser(String userId) {
    if (!isUserActiveLinked(userId)) {
      return const [];
    }
    final events = <PersistedHazardEvent>[];
    for (final device in devicesForUser(userId)) {
      events.addAll(_hazardsByDeviceId[device.id] ?? const []);
    }
    return List<PersistedHazardEvent>.unmodifiable(events);
  }

  /// Returns SOS events for [deviceId] only if it belongs to an ACTIVE linked user.
  List<PersistedSosEvent> sosEventsForDevice(String deviceId) {
    if (!_isDeviceAuthorized(deviceId)) {
      return const [];
    }
    return List<PersistedSosEvent>.unmodifiable(
      _sosEventsByDeviceId[deviceId] ?? const [],
    );
  }

  /// Returns all SOS events for an ACTIVE linked [userId].
  List<PersistedSosEvent> sosEventsForUser(String userId) {
    if (!isUserActiveLinked(userId)) {
      return const [];
    }
    final events = <PersistedSosEvent>[];
    for (final device in devicesForUser(userId)) {
      events.addAll(_sosEventsByDeviceId[device.id] ?? const []);
    }
    return List<PersistedSosEvent>.unmodifiable(events);
  }

  /// Returns all currently active SOS events (TRIGGERED or ACKNOWLEDGED) across all ACTIVE linked users.
  List<PersistedSosEvent> get allActiveSosEvents {
    final active = <PersistedSosEvent>[];
    for (final link in activeLinks) {
      for (final sos in sosEventsForUser(link.userId)) {
        if (sos.status.isActiveEmergency) {
          active.add(sos);
        }
      }
    }
    return List<PersistedSosEvent>.unmodifiable(active);
  }

  /// Evaluates high-level caregiver safety status for an ACTIVE linked [userId].
  /// Priority: SOS ACTIVE > CRITICAL > DANGER > WARNING > SAFE.
  CaregiverSafetyStatus safetyStatusForUser(String userId) {
    if (!isUserActiveLinked(userId)) {
      return CaregiverSafetyStatus.safe;
    }

    final userSos = sosEventsForUser(userId);
    if (userSos.any((s) => s.status.isActiveEmergency)) {
      return CaregiverSafetyStatus.sosActive;
    }

    CaregiverSafetyStatus highest = CaregiverSafetyStatus.safe;
    for (final device in devicesForUser(userId)) {
      final telemetry = _latestTelemetryByDeviceId[device.id];
      if (telemetry?.hazardLevel != null) {
        final fromTel =
            CaregiverSafetyStatus.fromHazardLevel(telemetry!.hazardLevel);
        if (fromTel.priorityRank > highest.priorityRank) {
          highest = fromTel;
        }
      }
      final hazards = _hazardsByDeviceId[device.id] ?? const [];
      if (hazards.isNotEmpty) {
        final fromHazard =
            CaregiverSafetyStatus.fromHazardLevel(hazards.first.hazardLevel);
        if (fromHazard.priorityRank > highest.priorityRank) {
          highest = fromHazard;
        }
      }
    }
    return highest;
  }

  // --- Parent STOMP Realtime Subscription & Topic Security (Sections 16, 17, 30, 31) ---

  /// Connects STOMP client and subscribes strictly to `/topic/parent/{authenticatedParentId}/events`.
  /// Rejects `/topic/all-parents`, another parent's topic, or any user/arbitrary topic.
  Future<void> connectRealtimeForParent(
    String authenticatedParentId, {
    String? requestedDestination,
  }) async {
    final trimmedParentId = authenticatedParentId.trim();
    if (trimmedParentId.isEmpty) {
      throw const ApiClientException(
        statusCode: 401,
        message: 'Authenticated parent ID is required for realtime subscription.',
      );
    }

    final allowedDestination = '/topic/parent/$trimmedParentId/events';
    final targetDestination =
        (requestedDestination ?? allowedDestination).trim();

    if (targetDestination == '/topic/all-parents' ||
        targetDestination != allowedDestination) {
      _errorMessage =
          'Unauthorized realtime topic subscription rejected ($targetDestination).';
      notifyListeners();
      throw ApiClientException(
        statusCode: 403,
        message: _errorMessage!,
      );
    }

    _authenticatedParentId = trimmedParentId;
    if (_subscribedParentDestination != null &&
        _subscribedParentDestination != allowedDestination) {
      await _parentTopicSub?.cancel();
      await realtimeClient.unsubscribe(_subscribedParentDestination!);
    }

    await realtimeClient.connect();
    final stream = await realtimeClient.subscribe(allowedDestination);
    _subscribedParentDestination = allowedDestination;
    await _parentTopicSub?.cancel();
    _parentTopicSub = stream.listen(_handleParentRealtimeEnvelope);
    notifyListeners();
  }

  void _handleParentRealtimeEnvelope(
    RealtimeEventEnvelope<Map<String, dynamic>> envelope,
  ) {
    switch (envelope.eventType) {
      case RealtimeEventType.deviceTelemetry:
        final telemetry = TelemetryEventPayload.fromJson(envelope.payload);
        final device = _findAuthorizedDeviceByIdentifierOrId(telemetry.deviceId);
        if (device == null) {
          // Untrusted or non-ACTIVE user/device telemetry: discard immediately
          return;
        }
        _latestTelemetryByDeviceId[device.id] = telemetry;
        _liveConnectionByDeviceId[device.id] =
            LiveDeviceConnectionState.fromWireName(telemetry.connectionState);
        notifyListeners();
        break;

      case RealtimeEventType.deviceConnectionState:
        final devKey = (envelope.payload['deviceId'] ?? '').toString();
        final device = _findAuthorizedDeviceByIdentifierOrId(devKey);
        if (device == null) {
          return;
        }
        final stateRaw = envelope.payload['connectionState']?.toString();
        if (stateRaw != null) {
          _liveConnectionByDeviceId[device.id] =
              LiveDeviceConnectionState.fromWireName(stateRaw);
          notifyListeners();
        }
        break;

      case RealtimeEventType.hazardAlert:
        final hazard = PersistedHazardEvent.fromJson(envelope.payload);
        final device = _resolveAuthorizedDeviceForEvent(
          userId: hazard.userId,
          deviceId: hazard.deviceId,
          deviceIdentifier: hazard.deviceIdentifier,
        );
        if (device == null) {
          // Ignore hazard event from PENDING, REVOKED, or unrelated user
          return;
        }
        _upsertHazardForDevice(device.id, hazard);
        notifyListeners();
        break;

      case RealtimeEventType.sosEvent:
        final sos = PersistedSosEvent.fromJson(envelope.payload);
        final device = _resolveAuthorizedDeviceForEvent(
          userId: sos.userId,
          deviceId: sos.deviceId,
          deviceIdentifier: sos.deviceIdentifier,
        );
        if (device == null) {
          // Ignore SOS event from PENDING, REVOKED, or unrelated user
          return;
        }
        _upsertSosForDevice(device.id, sos);
        notifyListeners();
        break;

      case RealtimeEventType.connectionAck:
      case RealtimeEventType.systemHeartbeat:
      case RealtimeEventType.unknown:
        // Ignore safely without crashing
        break;
    }
  }

  // --- Relationship & Dashboard Loading (Sections 9–14, 25) ---

  /// Loads caregiver relationships (`GET /api/v1/parent-links`) and, exclusively for
  /// `ACTIVE` relationships, loads authorized devices, configurations, hazards, and SOS events.
  Future<void> loadParentDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetchedLinks = await apiService.fetchParentLinks();
      _applyUpdatedLinksAndPurgeNonActive(fetchedLinks);

      if (activeLinks.isNotEmpty) {
        final accessibleDevices = await apiService.fetchAccessibleDevices();
        _devicesByUserId.clear();

        for (final device in accessibleDevices) {
          if (isUserActiveLinked(device.ownerUserId)) {
            final list =
                _devicesByUserId.putIfAbsent(device.ownerUserId, () => []);
            list.add(device);
            _liveConnectionByDeviceId.putIfAbsent(
              device.id,
              () => LiveDeviceConnectionState.disconnected,
            );
          }
        }

        // Load configuration, hazards, and SOS events for each authorized device
        for (final device in allAuthorizedDevices) {
          await _loadProtectedDeviceData(device);
        }
      }
    } on ApiClientException catch (ex) {
      _errorMessage = ex.toUserFriendlyMessage();
    } catch (_) {
      _errorMessage = 'Unable to load caregiver dashboard.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadProtectedDeviceData(RegisteredDevice device) async {
    if (!isUserActiveLinked(device.ownerUserId)) {
      return;
    }
    try {
      final results = await Future.wait<Object?>([
        apiService.fetchDeviceConfiguration(device.id),
        apiService.fetchDeviceHazards(device.id),
        apiService.fetchDeviceSosEvents(device.id),
      ]);
      _configurationsByDeviceId[device.id] = results[0] as DeviceConfigModel;
      _hazardsByDeviceId[device.id] = results[1] as List<PersistedHazardEvent>;
      _sosEventsByDeviceId[device.id] = results[2] as List<PersistedSosEvent>;
    } on ApiClientException catch (ex) {
      if (ex.statusCode == 403) {
        handleUserAccessRevoked(device.ownerUserId);
      } else {
        _errorMessage = ex.toUserFriendlyMessage();
      }
    }
  }

  /// Selects an ACTIVE linked user to view in the Safety / Events tabs.
  /// Rejects selecting PENDING, REVOKED, or unrelated users.
  bool selectActiveLinkedUser(String userId) {
    if (!isUserActiveLinked(userId)) {
      _errorMessage =
          "You no longer have permission to view this user's information.";
      notifyListeners();
      return false;
    }
    _selectedUserId = userId;
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  /// Initiates a new caregiver relationship request (`POST /api/v1/parent-links`) in PENDING status.
  Future<bool> requestUserLink(String targetUserId) async {
    final trimmed = targetUserId.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'Please enter the Stick User ID to request a link.';
      notifyListeners();
      return false;
    }

    _isSubmittingAction = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final created = await apiService.createLinkRequest(targetUserId: trimmed);
      _links = [created, ..._links.where((l) => l.id != created.id)];
      // Ensure PENDING never populates any protected data
      _purgeProtectedCachesForUser(created.userId);
      _infoMessage =
          'Link request created (${created.status.displayLabel}).';
      return true;
    } on ApiClientException catch (ex) {
      _errorMessage = ex.toUserFriendlyMessage();
      return false;
    } catch (_) {
      _errorMessage = 'Unable to create caregiver link request.';
      return false;
    } finally {
      _isSubmittingAction = false;
      notifyListeners();
    }
  }

  /// Explicitly blocks self-approval if invoked programmatically.
  Future<bool> attemptSelfApproveLink(String linkId) async {
    _errorMessage = null;
    try {
      await apiService.updateLinkStatus(
        linkId: linkId,
        targetState: ParentLinkState.active,
      );
      return true;
    } on ApiClientException catch (ex) {
      _errorMessage = ex.message;
      notifyListeners();
      return false;
    }
  }

  /// Revokes a relationship (`PATCH /api/v1/parent-links/{linkId}/status` -> REVOKED)
  /// and immediately purges all cached protected data for that user.
  Future<bool> revokeRelationship(String linkId) async {
    _isSubmittingAction = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final updated = await apiService.revokeLink(linkId: linkId);
      _links = _links.map((l) => l.id == updated.id ? updated : l).toList();
      handleUserAccessRevoked(
        updated.userId,
        customMessage:
            'Relationship with ${updated.userFullName} has been revoked. Protected data cleared.',
      );
      return true;
    } on ApiClientException catch (ex) {
      _errorMessage = ex.toUserFriendlyMessage();
      return false;
    } catch (_) {
      _errorMessage = 'Unable to revoke caregiver relationship.';
      return false;
    } finally {
      _isSubmittingAction = false;
      notifyListeners();
    }
  }

  /// Handles immediate revocation of access for [userId] (Section 11 & Section 25):
  /// 1. Transitions the link record to REVOKED
  /// 2. Purges all cached devices, configurations, telemetry, hazards, and SOS events for [userId]
  /// 3. Clears or switches [_selectedUserId]
  /// 4. Surfaces a safe access-revoked message
  void handleUserAccessRevoked(
    String userId, {
    String? customMessage,
  }) {
    _links = _links.map((link) {
      if (link.userId == userId) {
        return link.copyWith(status: ParentLinkState.revoked);
      }
      return link;
    }).toList();

    _purgeProtectedCachesForUser(userId);

    if (_selectedUserId == userId) {
      final remainingActive = activeLinks;
      _selectedUserId =
          remainingActive.isNotEmpty ? remainingActive.first.userId : null;
    }

    _errorMessage = customMessage ??
        "You no longer have permission to view this user's information.";
    notifyListeners();
  }

  // --- Caregiver SOS Acknowledgement & Resolution (Sections 20–24) ---

  /// Acknowledges an active TRIGGERED SOS event (`TRIGGERED -> ACKNOWLEDGED`)
  /// via `PATCH /api/v1/sos-events/{id}/status`.
  Future<bool> acknowledgeSosEvent(PersistedSosEvent sos) async {
    if (!isUserActiveLinked(sos.userId)) {
      handleUserAccessRevoked(sos.userId);
      return false;
    }
    if (sos.status != BackendSosStatus.triggered) {
      _errorMessage =
          'Only TRIGGERED SOS events can be acknowledged (current status: ${sos.status.wireName}).';
      notifyListeners();
      return false;
    }

    _isSubmittingAction = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final updated = await apiService.updateSosStatus(
        sosEventId: sos.id,
        targetStatus: BackendSosStatus.acknowledged,
      );
      _upsertSosForDevice(updated.deviceId, updated);
      _infoMessage =
          'SOS acknowledged for ${updated.userFullName}.';
      return true;
    } on ApiClientException catch (ex) {
      if (ex.statusCode == 403) {
        handleUserAccessRevoked(sos.userId);
      } else {
        _errorMessage = ex.toUserFriendlyMessage();
      }
      return false;
    } catch (_) {
      _errorMessage = 'Failed to acknowledge SOS event.';
      return false;
    } finally {
      _isSubmittingAction = false;
      notifyListeners();
    }
  }

  /// Resolves an ACKNOWLEDGED SOS event (`ACKNOWLEDGED -> RESOLVED`)
  /// via `PATCH /api/v1/sos-events/{id}/status`.
  /// Strictly rejects `TRIGGERED -> RESOLVED` per Phase 1E/3 lifecycle rules.
  Future<bool> resolveSosEvent(PersistedSosEvent sos) async {
    if (!isUserActiveLinked(sos.userId)) {
      handleUserAccessRevoked(sos.userId);
      return false;
    }
    if (sos.status != BackendSosStatus.acknowledged) {
      _errorMessage =
          'SOS must be ACKNOWLEDGED before it can be marked RESOLVED (current status: ${sos.status.wireName}).';
      notifyListeners();
      return false;
    }

    _isSubmittingAction = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final updated = await apiService.updateSosStatus(
        sosEventId: sos.id,
        targetStatus: BackendSosStatus.resolved,
      );
      _upsertSosForDevice(updated.deviceId, updated);
      _infoMessage = 'SOS marked resolved for ${updated.userFullName}.';
      return true;
    } on ApiClientException catch (ex) {
      if (ex.statusCode == 403) {
        handleUserAccessRevoked(sos.userId);
      } else {
        _errorMessage = ex.toUserFriendlyMessage();
      }
      return false;
    } catch (_) {
      _errorMessage = 'Failed to resolve SOS event.';
      return false;
    } finally {
      _isSubmittingAction = false;
      notifyListeners();
    }
  }

  // --- Internal Authorization & Cache Helpers ---

  void _applyUpdatedLinksAndPurgeNonActive(List<CaregiverUserLink> nextLinks) {
    _links = nextLinks;
    final activeUserIds =
        nextLinks.where((l) => l.status == ParentLinkState.active).map((l) => l.userId).toSet();

    // Purge cached data for any user who is not currently ACTIVE
    final cachedUserIds = _devicesByUserId.keys.toList();
    for (final userId in cachedUserIds) {
      if (!activeUserIds.contains(userId)) {
        _purgeProtectedCachesForUser(userId);
      }
    }

    for (final link in nextLinks) {
      if (!link.canAccessProtectedData) {
        _purgeProtectedCachesForUser(link.userId);
      }
    }

    if (_selectedUserId == null || !activeUserIds.contains(_selectedUserId)) {
      _selectedUserId =
          activeUserIds.isNotEmpty ? activeUserIds.first : null;
    }
  }

  void _purgeProtectedCachesForUser(String userId) {
    final userDevices = _devicesByUserId.remove(userId) ?? const [];
    for (final dev in userDevices) {
      _configurationsByDeviceId.remove(dev.id);
      _liveConnectionByDeviceId.remove(dev.id);
      _latestTelemetryByDeviceId.remove(dev.id);
      _hazardsByDeviceId.remove(dev.id);
      _sosEventsByDeviceId.remove(dev.id);
    }
  }

  bool _isDeviceAuthorized(String deviceId) {
    return _findAuthorizedDeviceById(deviceId) != null;
  }

  RegisteredDevice? _findAuthorizedDeviceById(String deviceId) {
    for (final link in activeLinks) {
      final devices = _devicesByUserId[link.userId] ?? const [];
      for (final dev in devices) {
        if (dev.id == deviceId) {
          return dev;
        }
      }
    }
    return null;
  }

  RegisteredDevice? _findAuthorizedDeviceByIdentifierOrId(String key) {
    if (key.isEmpty) return null;
    for (final link in activeLinks) {
      final devices = _devicesByUserId[link.userId] ?? const [];
      for (final dev in devices) {
        if (dev.id == key || dev.deviceIdentifier == key) {
          return dev;
        }
      }
    }
    return null;
  }

  RegisteredDevice? _resolveAuthorizedDeviceForEvent({
    required String userId,
    required String deviceId,
    required String deviceIdentifier,
  }) {
    if (userId.isNotEmpty && !isUserActiveLinked(userId)) {
      return null;
    }
    return _findAuthorizedDeviceByIdentifierOrId(deviceId) ??
        _findAuthorizedDeviceByIdentifierOrId(deviceIdentifier);
  }

  void _upsertHazardForDevice(String deviceId, PersistedHazardEvent event) {
    final existing = _hazardsByDeviceId[deviceId] ?? const [];
    final idx = existing.indexWhere((e) => e.id == event.id);
    if (idx >= 0) {
      final copy = List<PersistedHazardEvent>.of(existing);
      copy[idx] = event;
      _hazardsByDeviceId[deviceId] = copy;
    } else {
      _hazardsByDeviceId[deviceId] = [event, ...existing];
    }
  }

  void _upsertSosForDevice(String deviceId, PersistedSosEvent event) {
    final existing = _sosEventsByDeviceId[deviceId] ?? const [];
    final idx = existing.indexWhere((e) => e.id == event.id);
    if (idx >= 0) {
      final copy = List<PersistedSosEvent>.of(existing);
      copy[idx] = event;
      _sosEventsByDeviceId[deviceId] = copy;
    } else {
      _sosEventsByDeviceId[deviceId] = [event, ...existing];
    }
  }

  /// Disconnects STOMP and clears all caregiver state on logout.
  Future<void> resetForLogout() async {
    await _parentTopicSub?.cancel();
    _parentTopicSub = null;
    if (_subscribedParentDestination != null) {
      await realtimeClient.unsubscribe(_subscribedParentDestination!);
      _subscribedParentDestination = null;
    }
    await realtimeClient.disconnect();

    _authenticatedParentId = null;
    _links = const [];
    _selectedUserId = null;
    _devicesByUserId.clear();
    _configurationsByDeviceId.clear();
    _liveConnectionByDeviceId.clear();
    _latestTelemetryByDeviceId.clear();
    _hazardsByDeviceId.clear();
    _sosEventsByDeviceId.clear();
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsStateSub?.cancel();
    _parentTopicSub?.cancel();
    super.dispose();
  }
}
