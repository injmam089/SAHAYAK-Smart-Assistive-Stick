import 'package:flutter/material.dart';

import '../../../device/models/hazard_event.dart';
import '../../auth/auth_controller.dart';
import '../models/user_module_models.dart';
import '../state/user_module_controller.dart';

/// Main User Module Shell with accessible bottom navigation across:
/// 0: Safety (Primary Safety Home, Telemetry, SOS, Simulation Controls)
/// 1: Device (Device Registration, Selection, Domain Status vs Live Connection)
/// 2: Events (Persisted SOS & Hazard Event History)
/// 3: Settings (Device Thresholds, Haptic & Audio Configuration)
class UserModuleShell extends StatefulWidget {
  final AuthController authController;
  final UserModuleController userController;

  const UserModuleShell({
    super.key,
    required this.authController,
    required this.userController,
  });

  @override
  State<UserModuleShell> createState() => _UserModuleShellState();
}

class _UserModuleShellState extends State<UserModuleShell> {
  int _selectedIndex = 0;
  bool _confirmingSos = false;

  // Device registration controllers
  final _deviceIdentifierController = TextEditingController();
  final _deviceNameController = TextEditingController();

  // Configuration form controllers
  final _normalThresholdController = TextEditingController();
  final _slowThresholdController = TextEditingController();
  final _fastThresholdController = TextEditingController();
  final _hapticIntensityController = TextEditingController();
  final _audioVolumeController = TextEditingController();
  bool _hapticEnabled = true;
  bool _audioEnabled = true;
  String? _syncedConfigDeviceId;
  int? _syncedConfigVersion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserSessionData();
    });
  }

  Future<void> _initializeUserSessionData() async {
    final user = widget.authController.state.user;
    if (user != null && user.id.isNotEmpty) {
      await widget.userController.connectRealtimeForUser(user.id);
    }
    await widget.userController.loadUserDevices();
  }

  void _syncConfigurationForm(DeviceConfigModel? config) {
    if (config == null) return;
    if (_syncedConfigDeviceId == config.deviceId &&
        _syncedConfigVersion == config.configurationVersion) {
      return;
    }
    _syncedConfigDeviceId = config.deviceId;
    _syncedConfigVersion = config.configurationVersion;
    _normalThresholdController.text = config.normalThresholdCm.toString();
    _slowThresholdController.text = config.slowWarningThresholdCm.toString();
    _fastThresholdController.text = config.fastWarningThresholdCm.toString();
    _hapticIntensityController.text = config.hapticIntensity.toString();
    _audioVolumeController.text = config.audioVolume.toString();
    _hapticEnabled = config.hapticEnabled;
    _audioEnabled = config.audioEnabled;
  }

  @override
  void dispose() {
    _deviceIdentifierController.dispose();
    _deviceNameController.dispose();
    _normalThresholdController.dispose();
    _slowThresholdController.dispose();
    _fastThresholdController.dispose();
    _hapticIntensityController.dispose();
    _audioVolumeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await widget.userController.resetForLogout();
    await widget.authController.logout();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.authController,
        widget.userController,
      ]),
      builder: (context, _) {
        final user = widget.authController.state.user;
        final controller = widget.userController;
        _syncConfigurationForm(controller.deviceConfiguration);

        return Scaffold(
          appBar: AppBar(
            title: Semantics(
              header: true,
              label: 'SAHAYAK User Module for ${user?.fullName ?? 'Stick User'}',
              child: Text('SAHAYAK — ${user?.fullName ?? 'User'}'),
            ),
            actions: [
              Semantics(
                button: true,
                label: 'Sign out of SAHAYAK account',
                child: TextButton.icon(
                  key: const Key('logout_button'),
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'LOGOUT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (controller.errorMessage != null)
                  _buildStatusAlertBanner(
                    key: const Key('user_module_error_banner'),
                    message: controller.errorMessage!,
                    isError: true,
                    onDismiss: controller.clearMessages,
                  ),
                if (controller.infoMessage != null)
                  _buildStatusAlertBanner(
                    key: const Key('user_module_info_banner'),
                    message: controller.infoMessage!,
                    isError: false,
                    onDismiss: controller.clearMessages,
                  ),
                Expanded(
                  child: _buildCurrentTab(context, controller),
                ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            key: const Key('user_module_bottom_nav'),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (idx) {
              setState(() {
                _selectedIndex = idx;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.shield_outlined),
                selectedIcon: Icon(Icons.shield),
                label: 'Safety',
              ),
              NavigationDestination(
                icon: Icon(Icons.bluetooth_searching),
                selectedIcon: Icon(Icons.bluetooth_connected),
                label: 'Device',
              ),
              NavigationDestination(
                icon: Icon(Icons.history),
                selectedIcon: Icon(Icons.history_edu),
                label: 'Events',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusAlertBanner({
    required Key key,
    required String message,
    required bool isError,
    required VoidCallback onDismiss,
  }) {
    final borderColor =
        isError ? const Color(0xFFFF1744) : const Color(0xFF00E5FF);
    final bgColor = isError ? const Color(0xFF3E1018) : const Color(0xFF0A2A33);
    final icon = isError ? Icons.warning_amber_rounded : Icons.info_outline;

    return Semantics(
      liveRegion: true,
      label: isError ? 'Alert: $message' : 'Notice: $message',
      child: Container(
        key: key,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: borderColor, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Dismiss message',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab(
    BuildContext context,
    UserModuleController controller,
  ) {
    switch (_selectedIndex) {
      case 0:
        return _buildSafetyHomeTab(context, controller);
      case 1:
        return _buildDeviceControlTab(context, controller);
      case 2:
        return _buildSafetyEventsTab(context, controller);
      case 3:
        return _buildConfigurationSettingsTab(context, controller);
      default:
        return _buildSafetyHomeTab(context, controller);
    }
  }

  // ===========================================================================
  // TAB 0: SAFETY HOME (Status, Telemetry, Hazard Banner, Hold-to-SOS)
  // ===========================================================================
  Widget _buildSafetyHomeTab(
    BuildContext context,
    UserModuleController controller,
  ) {
    final device = controller.selectedDevice;
    final telemetry = controller.latestTelemetry;
    final isStale = controller.isTelemetryStale();
    final latestSos = controller.activeSosEvent ?? controller.latestSosEvent;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Device & Connection Separation Card
          _buildDeviceAndConnectionCard(context, controller, device),
          const SizedBox(height: 16),

          // 2. Primary Hazard / Safety Banner
          _buildSafetyHazardBanner(context, controller),
          const SizedBox(height: 16),

          // 3. Active / Latest SOS Lifecycle Card (when present)
          if (latestSos != null) ...[
            _buildSosLifecycleCard(context, controller, latestSos),
            const SizedBox(height: 16),
          ],

          // 4. Safe Hold-to-SOS Emergency Trigger Control
          _buildHoldToSosControl(context, controller),
          const SizedBox(height: 16),

          // 5. Live Telemetry Card + Stale Telemetry Detection
          _buildLiveTelemetryCard(context, controller, telemetry, isStale),
          const SizedBox(height: 16),

          // 6. Simulated Stick Controls (Explicitly labeled as Simulated Mode)
          _buildSimulationControlsCard(context, controller),
        ],
      ),
    );
  }

  Widget _buildDeviceAndConnectionCard(
    BuildContext context,
    UserModuleController controller,
    RegisteredDevice? device,
  ) {
    return Semantics(
      container: true,
      label: device == null
          ? 'No stick device registered. Open the Device tab to register a stick.'
          : 'Selected stick ${device.deviceName}, Domain status ${device.status.displayLabel}, Live connection ${controller.liveConnectionState.displayLabel}',
      child: Container(
        key: const Key('safety_device_summary_card'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: Colors.white54, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.accessibility_new, color: Color(0xFF00E5FF), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    device != null
                        ? '${device.deviceName} (${device.deviceIdentifier})'
                        : 'NO STICK DEVICE REGISTERED',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Container(
                  key: const Key('safety_domain_status_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Domain Status: ${controller.selectedDeviceDomainStatus.wireName}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                ),
                Container(
                  key: const Key('safety_live_connection_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: const Color(0xFFFFD600), width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Live Transport: ${controller.liveConnectionState.wireName}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD600),
                    ),
                  ),
                ),
                if (controller.latestTelemetry?.simulated ?? true)
                  Container(
                    key: const Key('simulated_mode_badge'),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF263238),
                      border: Border.all(color: Colors.white70, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'MODE: SIMULATED STICK',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyHazardBanner(
    BuildContext context,
    UserModuleController controller,
  ) {
    final bannerState = controller.currentSafetyBannerState;
    IconData icon = Icons.check_circle_outline;
    Color borderColor = const Color(0xFF00E5FF);
    String title = 'STATUS: NORMAL — CLEAR PATH';

    if (bannerState == 'TRIGGERED' || bannerState == 'ACKNOWLEDGED') {
      icon = Icons.emergency_share;
      borderColor = const Color(0xFFFF1744);
      title = 'EMERGENCY: SOS $bannerState';
    } else if (bannerState == 'CRITICAL' || bannerState == 'DANGER') {
      icon = Icons.report_problem;
      borderColor = const Color(0xFFFF1744);
      title = 'HAZARD: $bannerState — IMMEDIATE OBSTACLE';
    } else if (bannerState == 'FAST_WARNING' ||
        bannerState == 'SLOW_WARNING' ||
        bannerState == 'WARNING') {
      icon = Icons.warning_amber_rounded;
      borderColor = const Color(0xFFFFD600);
      title = 'CAUTION: $bannerState DETECTED';
    }

    return Semantics(
      liveRegion: true,
      label: 'Safety Status Banner: $title',
      child: Container(
        key: const Key('safety_hazard_banner'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          border: Border.all(color: borderColor, width: 3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: borderColor, size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSosLifecycleCard(
    BuildContext context,
    UserModuleController controller,
    PersistedSosEvent sos,
  ) {
    final isActive = sos.status.isActiveEmergency;
    final borderColor =
        isActive ? const Color(0xFFFF1744) : const Color(0xFF00E5FF);

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'SOS Status: ${sos.status.bannerTitle}',
      child: Container(
        key: const Key('active_sos_status_card'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF330A12) : const Color(0xFF102830),
          border: Border.all(color: borderColor, width: 3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.sos : Icons.verified_user,
                  color: borderColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sos.status.bannerTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'SOS State: ${sos.status.wireName} • Device: ${sos.deviceIdentifier}',
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            if (sos.status == BackendSosStatus.triggered ||
                sos.status == BackendSosStatus.acknowledged) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (sos.status == BackendSosStatus.triggered)
                    SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        key: const Key('cancel_sos_button'),
                        onPressed: controller.isSubmittingSos
                            ? null
                            : () => controller.cancelActiveSos(sos.id),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 2),
                        ),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text(
                          'CANCEL SOS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      key: const Key('resolve_sos_button'),
                      onPressed: controller.isSubmittingSos
                          ? null
                          : () => controller.resolveActiveSos(sos.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text(
                        'MARK SOS RESOLVED',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHoldToSosControl(
    BuildContext context,
    UserModuleController controller,
  ) {
    return Semantics(
      container: true,
      label:
          'Emergency SOS Control. Long press to send SOS immediately, or tap once to open SOS confirmation.',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF24080D),
          border: Border.all(color: const Color(0xFFFF1744), width: 2.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              key: const Key('hold_to_send_sos_button'),
              onLongPress: controller.isSubmittingSos
                  ? null
                  : () async {
                      setState(() {
                        _confirmingSos = false;
                      });
                      await controller.triggerEmergencySos();
                    },
              onTap: controller.isSubmittingSos
                  ? null
                  : () {
                      // Single tap NEVER triggers SOS directly; it reveals an explicit confirmation step
                      setState(() {
                        _confirmingSos = true;
                      });
                    },
              child: Container(
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF1744),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sos, color: Colors.black, size: 34),
                    const SizedBox(width: 12),
                    Text(
                      controller.isSubmittingSos
                          ? 'SENDING SOS...'
                          : 'HOLD TO SEND SOS',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Protected against accidental single tap: Press and hold to send SOS, or tap once to open confirmation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.white70),
            ),
            if (_confirmingSos) ...[
              const SizedBox(height: 14),
              Container(
                key: const Key('sos_confirmation_box'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: const Color(0xFFFFD600), width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'CONFIRM EMERGENCY SOS ALERT?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFD600),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: OutlinedButton(
                              key: const Key('abort_sos_confirm_button'),
                              onPressed: () {
                                setState(() {
                                  _confirmingSos = false;
                                });
                              },
                              child: const Text(
                                'DISMISS',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              key: const Key('confirm_send_sos_button'),
                              onPressed: controller.isSubmittingSos
                                  ? null
                                  : () async {
                                      setState(() {
                                        _confirmingSos = false;
                                      });
                                      await controller.triggerEmergencySos();
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF1744),
                                foregroundColor: Colors.black,
                              ),
                              child: const Text(
                                'CONFIRM SOS',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTelemetryCard(
    BuildContext context,
    UserModuleController controller,
    dynamic telemetry,
    bool isStale,
  ) {
    return Semantics(
      container: true,
      label: 'Live Stick Telemetry Readings',
      child: Container(
        key: const Key('live_telemetry_card'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          border: Border.all(color: Colors.white38, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LIVE TELEMETRY SNAPSHOT',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(height: 12),
            if (isStale) ...[
              Container(
                key: const Key('stale_telemetry_warning'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF332600),
                  border: Border.all(color: const Color(0xFFFFD600), width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.schedule, color: Color(0xFFFFD600)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'STALE TELEMETRY — Last reading is older than threshold',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFD600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (telemetry == null)
              const Text(
                'No live telemetry sample received yet.',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              )
            else ...[
              Text(
                'Forward Obstacle Distance: ${telemetry.forwardDistanceCm ?? '--'} cm',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ground / Drop Distance: ${telemetry.groundDistanceCm ?? '--'} cm',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Battery Level: ${telemetry.batteryPercentage ?? '--'}%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Hazard Level: ${telemetry.hazardLevel ?? 'NORMAL'}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationControlsCard(
    BuildContext context,
    UserModuleController controller,
  ) {
    return Container(
      key: const Key('simulation_controls_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121820),
        border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'SIMULATED DEVICE CONTROLS (PHASE 2)',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00E5FF),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                key: const Key('sim_connect_button'),
                onPressed: controller.connectSimulatedStick,
                icon: const Icon(Icons.link),
                label: const Text('CONNECT SIM STICK'),
              ),
              OutlinedButton.icon(
                key: const Key('sim_disconnect_button'),
                onPressed: controller.disconnectSimulatedStick,
                icon: const Icon(Icons.link_off),
                label: const Text('DISCONNECT SIM STICK'),
              ),
              ElevatedButton.icon(
                key: const Key('sim_telemetry_button'),
                onPressed: () => controller.simulateTelemetrySample(
                  forwardDistanceCm: 85,
                  groundDistanceCm: 100,
                  batteryPercentage: 92,
                  severity: HazardSeverity.fastWarning,
                ),
                icon: const Icon(Icons.sensors),
                label: const Text('EMIT TELEMETRY (85 CM)'),
              ),
              ElevatedButton.icon(
                key: const Key('sim_forward_hazard_button'),
                onPressed: () => controller.reportHazardEvent(
                  hazardType: 'FORWARD_OBSTACLE',
                  hazardLevel: 'FAST_WARNING',
                  distanceCm: 65,
                  source: 'SIMULATED_DEVICE',
                ),
                icon: const Icon(Icons.warning),
                label: const Text('REPORT FORWARD HAZARD'),
              ),
              ElevatedButton.icon(
                key: const Key('sim_ground_hazard_button'),
                onPressed: () => controller.reportHazardEvent(
                  hazardType: 'GROUND_HAZARD',
                  hazardLevel: 'CRITICAL',
                  distanceCm: 35,
                  source: 'SIMULATED_DEVICE',
                ),
                icon: const Icon(Icons.dangerous),
                label: const Text('REPORT GROUND HAZARD'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: DEVICE CONTROL (Registration, Selection, Domain vs Live Status)
  // ===========================================================================
  Widget _buildDeviceControlTab(
    BuildContext context,
    UserModuleController controller,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'REGISTER STICK DEVICE',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('device_identifier_field'),
            controller: _deviceIdentifierController,
            style: const TextStyle(fontSize: 18, color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Device Identifier (Serial / Hardware ID)',
              hintText: 'SAHAYAK-ESP32-001',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('device_name_field'),
            controller: _deviceNameController,
            style: const TextStyle(fontSize: 18, color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Friendly Stick Name',
              hintText: 'Primary Walking Stick',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              key: const Key('register_device_button'),
              onPressed: controller.isLoading
                  ? null
                  : () async {
                      final ok = await controller.registerNewDevice(
                        deviceIdentifier: _deviceIdentifierController.text,
                        deviceName: _deviceNameController.text,
                      );
                      if (ok) {
                        _deviceIdentifierController.clear();
                        _deviceNameController.clear();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text(
                'REGISTER STICK DEVICE',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'REGISTERED DEVICES (${controller.devices.length})',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          if (controller.devices.isEmpty)
            const Text(
              'No devices registered yet. Use the form above to register your stick.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            )
          else
            ...controller.devices.map((device) {
              final isSelected = controller.selectedDevice?.id == device.id;
              return Container(
                key: Key('device_card_${device.deviceIdentifier}'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00E5FF) : Colors.white38,
                    width: isSelected ? 3 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.deviceName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${device.deviceIdentifier}',
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Persistent Domain Status: ${device.status.wireName} (${device.status.displayLabel})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!isSelected)
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          key: Key('select_device_${device.deviceIdentifier}'),
                          onPressed: () => controller.selectDevice(device),
                          child: const Text('SELECT AS ACTIVE STICK'),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            key: const Key('set_domain_status_active_button'),
                            onPressed: () => controller
                                .updateSelectedDeviceDomainStatus(DomainDeviceStatus.active),
                            child: const Text('SET DOMAIN: ACTIVE'),
                          ),
                          OutlinedButton(
                            key: const Key('set_domain_status_inactive_button'),
                            onPressed: () => controller.updateSelectedDeviceDomainStatus(
                                DomainDeviceStatus.inactive),
                            child: const Text('SET DOMAIN: INACTIVE'),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: SAFETY EVENTS HISTORY (Persisted SOS & Hazard Events)
  // ===========================================================================
  Widget _buildSafetyEventsTab(
    BuildContext context,
    UserModuleController controller,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SAFETY EVENT HISTORY',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              IconButton(
                key: const Key('refresh_events_button'),
                onPressed: controller.refreshSafetyEvents,
                icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
                tooltip: 'Refresh Safety Events',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'SOS EMERGENCY EVENTS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF1744),
            ),
          ),
          const SizedBox(height: 8),
          if (controller.sosEvents.isEmpty)
            const Text(
              'No SOS events recorded for this device.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            )
          else
            ...controller.sosEvents.map((sos) {
              return Container(
                key: Key('sos_history_item_${sos.id}'),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1215),
                  border: Border.all(color: const Color(0xFFFF1744), width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOS Status: ${sos.status.wireName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Source: ${sos.source} • Device: ${sos.deviceIdentifier}',
                      style: const TextStyle(fontSize: 15, color: Colors.white70),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 20),
          const Text(
            'HAZARD ALERT HISTORY',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFD600),
            ),
          ),
          const SizedBox(height: 8),
          if (controller.hazardEvents.isEmpty)
            const Text(
              'No hazard events recorded for this device.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            )
          else
            ...controller.hazardEvents.map((hazard) {
              return Container(
                key: Key('hazard_history_item_${hazard.id}'),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1912),
                  border: Border.all(color: const Color(0xFFFFD600), width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${hazard.readableHazardType} — ${hazard.hazardLevel}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Distance: ${hazard.distanceCm ?? '--'} cm • Source: ${hazard.source}',
                      style: const TextStyle(fontSize: 15, color: Colors.white70),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 3: DEVICE CONFIGURATION SETTINGS (Thresholds, Haptic, Audio)
  // ===========================================================================
  Widget _buildConfigurationSettingsTab(
    BuildContext context,
    UserModuleController controller,
  ) {
    final config = controller.deviceConfiguration;
    final selectedDevice = controller.selectedDevice;

    if (selectedDevice == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Register and select a stick device in the Device tab to configure thresholds.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'STICK CONFIGURATION',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Device: ${selectedDevice.deviceName} • Config Version: v${config?.configurationVersion ?? 1}',
            key: const Key('config_version_label'),
            style: const TextStyle(fontSize: 16, color: Color(0xFF00E5FF)),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('config_normal_threshold_field'),
            controller: _normalThresholdController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 18, color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Normal Threshold (cm)',
              helperText: 'Must be greater than Slow Warning threshold',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('config_slow_threshold_field'),
            controller: _slowThresholdController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 18, color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Slow Warning Threshold (cm)',
              helperText: 'Must be between Fast Warning and Normal thresholds',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('config_fast_threshold_field'),
            controller: _fastThresholdController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 18, color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Fast Warning Threshold (cm)',
              helperText: 'Must be > 0 cm and less than Slow Warning threshold',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            key: const Key('config_haptic_switch'),
            title: const Text(
              'Enable Haptic Vibration Feedback',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            value: _hapticEnabled,
            onChanged: (val) {
              setState(() {
                _hapticEnabled = val;
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('config_haptic_intensity_field'),
            controller: _hapticIntensityController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 18, color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Haptic Intensity (0 - 100%)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            key: const Key('config_audio_switch'),
            title: const Text(
              'Enable Audio / Buzzer Feedback',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            value: _audioEnabled,
            onChanged: (val) {
              setState(() {
                _audioEnabled = val;
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('config_audio_volume_field'),
            controller: _audioVolumeController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 18, color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Audio Volume (0 - 100%)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 58,
            child: ElevatedButton.icon(
              key: const Key('save_config_button'),
              onPressed: controller.isSavingConfiguration
                  ? null
                  : () async {
                      final normalCm =
                          int.tryParse(_normalThresholdController.text.trim()) ?? -1;
                      final slowCm =
                          int.tryParse(_slowThresholdController.text.trim()) ?? -1;
                      final fastCm =
                          int.tryParse(_fastThresholdController.text.trim()) ?? -1;
                      final hapticInt =
                          int.tryParse(_hapticIntensityController.text.trim()) ?? -1;
                      final audioVol =
                          int.tryParse(_audioVolumeController.text.trim()) ?? -1;

                      final base = config ??
                          DeviceConfigModel.defaults(
                            deviceId: selectedDevice.id,
                            deviceIdentifier: selectedDevice.deviceIdentifier,
                          );

                      final draft = base.copyWith(
                        normalThresholdCm: normalCm,
                        slowWarningThresholdCm: slowCm,
                        fastWarningThresholdCm: fastCm,
                        hapticEnabled: _hapticEnabled,
                        hapticIntensity: hapticInt,
                        audioEnabled: _audioEnabled,
                        audioVolume: audioVol,
                      );

                      await controller.saveDeviceConfiguration(draft);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.save),
              label: Text(
                controller.isSavingConfiguration
                    ? 'SAVING CONFIGURATION...'
                    : 'SAVE CONFIGURATION',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
