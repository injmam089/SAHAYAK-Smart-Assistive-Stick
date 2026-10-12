import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../../user_module/models/user_module_models.dart';
import '../models/parent_module_models.dart';
import '../state/parent_module_controller.dart';

/// Caregiver-oriented Parent Control Module Shell (Phase 3).
///
/// Navigation Tabs:
/// 0: Home (Prioritized Active SOS, Caregiver Overview, Active Linked Users)
/// 1: Linked Users (Initiate PENDING Link, ACTIVE / PENDING / REVOKED Relationship List)
/// 2: Safety (Selected ACTIVE User Safety Status, Separated Domain vs Live Device State, Read-Only Config, Telemetry)
/// 3: Events (Active & Historical SOS + Hazard Events for ACTIVE Linked Users)
class ParentControlModuleShell extends StatefulWidget {
  final AuthController authController;
  final ParentModuleController parentController;

  const ParentControlModuleShell({
    super.key,
    required this.authController,
    required this.parentController,
  });

  @override
  State<ParentControlModuleShell> createState() =>
      _ParentControlModuleShellState();
}

class _ParentControlModuleShellState extends State<ParentControlModuleShell> {
  int _selectedIndex = 0;
  final _targetUserIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeParentSession();
    });
  }

  Future<void> _initializeParentSession() async {
    final user = widget.authController.state.user;
    if (user != null && user.id.isNotEmpty) {
      await widget.parentController.connectRealtimeForParent(user.id);
    }
    await widget.parentController.loadParentDashboard();
  }

  @override
  void dispose() {
    _targetUserIdController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await widget.parentController.resetForLogout();
    await widget.authController.logout();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.authController,
        widget.parentController,
      ]),
      builder: (context, _) {
        final parentUser = widget.authController.state.user;
        final controller = widget.parentController;

        return Scaffold(
          appBar: AppBar(
            title: Semantics(
              header: true,
              label:
                  'SAHAYAK Caregiver Module for ${parentUser?.fullName ?? 'Caregiver'}',
              child: Text(
                'SAHAYAK CARE — ${parentUser?.fullName ?? 'Caregiver'}',
              ),
            ),
            actions: [
              IconButton(
                key: const Key('parent_refresh_dashboard_button'),
                onPressed: controller.loadParentDashboard,
                icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
                tooltip: 'Refresh caregiver dashboard',
              ),
              Semantics(
                button: true,
                label: 'Sign out of caregiver account',
                child: TextButton.icon(
                  key: const Key('parent_logout_button'),
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
                  _buildAlertBanner(
                    key: const Key('parent_module_error_banner'),
                    message: controller.errorMessage!,
                    isError: true,
                    onDismiss: controller.clearMessages,
                  ),
                if (controller.infoMessage != null)
                  _buildAlertBanner(
                    key: const Key('parent_module_info_banner'),
                    message: controller.infoMessage!,
                    isError: false,
                    onDismiss: controller.clearMessages,
                  ),
                Expanded(
                  child: _buildSelectedTab(context, controller),
                ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            key: const Key('parent_module_bottom_nav'),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (idx) {
              setState(() {
                _selectedIndex = idx;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Linked Users',
              ),
              NavigationDestination(
                icon: Icon(Icons.health_and_safety_outlined),
                selectedIcon: Icon(Icons.health_and_safety),
                label: 'Safety',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_active_outlined),
                selectedIcon: Icon(Icons.notifications_active),
                label: 'Events',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertBanner({
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
      label: isError ? 'Caregiver Alert: $message' : 'Caregiver Notice: $message',
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

  Widget _buildSelectedTab(
    BuildContext context,
    ParentModuleController controller,
  ) {
    switch (_selectedIndex) {
      case 0:
        return _buildParentHomeTab(context, controller);
      case 1:
        return _buildLinkedUsersTab(context, controller);
      case 2:
        return _buildSafetyDetailTab(context, controller);
      case 3:
        return _buildEventsTab(context, controller);
      default:
        return _buildParentHomeTab(context, controller);
    }
  }

  // ===========================================================================
  // TAB 0: PARENT HOME (Prioritized Active SOS, Summary, Active Linked Users)
  // ===========================================================================
  Widget _buildParentHomeTab(
    BuildContext context,
    ParentModuleController controller,
  ) {
    final activeUsers = controller.activeLinks;
    final activeSosList = controller.allActiveSosEvents;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label:
                'Caregiver Overview. Active Linked Users: ${activeUsers.length}. Active SOS Emergencies: ${activeSosList.length}.',
            child: Container(
              key: const Key('parent_home_summary_card'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161A20),
                border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.family_restroom,
                    color: Color(0xFF00E5FF),
                    size: 36,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Linked Users: ${activeUsers.length}',
                          key: const Key('parent_active_linked_count'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pending Requests: ${controller.pendingLinks.length} • Active SOS: ${activeSosList.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Priority 1: Active SOS Emergency Cards
          if (activeSosList.isNotEmpty) ...[
            const Text(
              'ACTIVE SOS EMERGENCIES',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF1744),
              ),
            ),
            const SizedBox(height: 10),
            ...activeSosList.map((sos) => _buildCaregiverSosCard(controller, sos)),
            const SizedBox(height: 16),
          ],

          // Priority 2: Active Linked Users Status Cards
          Text(
            'ACTIVE LINKED USERS',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          if (activeUsers.isEmpty)
            Container(
              key: const Key('parent_no_active_users_card'),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border.all(color: Colors.white38, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'No ACTIVE linked users yet. Open the Linked Users tab to request a caregiver link or check pending requests.',
                style: TextStyle(fontSize: 17, color: Colors.white70),
              ),
            )
          else
            ...activeUsers.map(
              (link) => _buildActiveLinkedUserSummaryCard(
                context,
                controller,
                link,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveLinkedUserSummaryCard(
    BuildContext context,
    ParentModuleController controller,
    CaregiverUserLink link,
  ) {
    final safetyStatus = controller.safetyStatusForUser(link.userId);
    final devices = controller.devicesForUser(link.userId);
    final primaryDevice = devices.isNotEmpty ? devices.first : null;
    final liveConn = primaryDevice != null
        ? controller.liveConnectionForDevice(primaryDevice.id)
        : LiveDeviceConnectionState.unknown;
    final telemetry = primaryDevice != null
        ? controller.telemetryForDevice(primaryDevice.id)
        : null;

    return Semantics(
      container: true,
      label:
          'Linked user ${link.userFullName}, Safety status ${safetyStatus.descriptiveLabel}',
      child: Container(
        key: Key('parent_active_user_card_${link.userId}'),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          border: Border.all(
            color: _borderColorForSafety(safetyStatus),
            width: 2.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconForSafety(safetyStatus),
                  color: _borderColorForSafety(safetyStatus),
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    link.userFullName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  key: Key('parent_user_safety_badge_${link.userId}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(
                      color: _borderColorForSafety(safetyStatus),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Safety: ${safetyStatus.shortLabel}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _borderColorForSafety(safetyStatus),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (primaryDevice == null)
              const Text(
                'Stick: No registered device yet',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              )
            else ...[
              Text(
                'Stick: ${primaryDevice.deviceName} (${primaryDevice.deviceIdentifier})',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  Container(
                    key: Key('parent_home_domain_status_${primaryDevice.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(color: const Color(0xFF00E5FF)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Device: ${primaryDevice.status.wireName}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                  ),
                  Container(
                    key: Key('parent_home_live_status_${primaryDevice.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(color: const Color(0xFFFFD600)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Connection: ${liveConn.wireName}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFD600),
                      ),
                    ),
                  ),
                  if (telemetry?.batteryPercentage != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: Colors.white54),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Battery: ${telemetry!.batteryPercentage}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                key: Key('parent_inspect_user_button_${link.userId}'),
                onPressed: () {
                  if (controller.selectActiveLinkedUser(link.userId)) {
                    setState(() {
                      _selectedIndex = 2; // Navigate to Safety tab
                    });
                  }
                },
                icon: const Icon(Icons.visibility_outlined),
                label: const Text(
                  'VIEW SAFETY & DEVICE DETAILS',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: LINKED USERS (Request Link, ACTIVE, PENDING, REVOKED Lists)
  // ===========================================================================
  Widget _buildLinkedUsersTab(
    BuildContext context,
    ParentModuleController controller,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'REQUEST CAREGIVER LINK',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the Stick User ID to send a PENDING link request. Access is granted only after the Stick User approves.',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('parent_link_user_id_field'),
            controller: _targetUserIdController,
            style: const TextStyle(fontSize: 18, color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Stick User ID',
              hintText: 'Enter target user account ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              key: const Key('parent_request_link_button'),
              onPressed: controller.isSubmittingAction
                  ? null
                  : () async {
                      final ok = await controller.requestUserLink(
                        _targetUserIdController.text,
                      );
                      if (ok) {
                        _targetUserIdController.clear();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text(
                'SEND LINK REQUEST (PENDING)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 1. ACTIVE Relationships
          const Text(
            'ACTIVE RELATIONSHIPS (AUTHORIZED)',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00E5FF),
            ),
          ),
          const SizedBox(height: 8),
          if (controller.activeLinks.isEmpty)
            const Text(
              'No ACTIVE relationships.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            )
          else
            ...controller.activeLinks.map(
              (link) => _buildRelationshipCard(context, controller, link),
            ),
          const SizedBox(height: 20),

          // 2. PENDING Relationships (Waiting for user approval — ZERO protected access)
          const Text(
            'PENDING REQUESTS (WAITING FOR USER APPROVAL)',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFD600),
            ),
          ),
          const SizedBox(height: 8),
          if (controller.pendingLinks.isEmpty)
            const Text(
              'No PENDING requests.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            )
          else
            ...controller.pendingLinks.map(
              (link) => _buildRelationshipCard(context, controller, link),
            ),
          const SizedBox(height: 20),

          // 3. REVOKED Relationships (Access removed — ZERO protected access)
          const Text(
            'REVOKED RELATIONSHIPS (NO ACCESS)',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF1744),
            ),
          ),
          const SizedBox(height: 8),
          if (controller.revokedLinks.isEmpty)
            const Text(
              'No REVOKED relationships.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            )
          else
            ...controller.revokedLinks.map(
              (link) => _buildRelationshipCard(context, controller, link),
            ),
        ],
      ),
    );
  }

  Widget _buildRelationshipCard(
    BuildContext context,
    ParentModuleController controller,
    CaregiverUserLink link,
  ) {
    Color borderColor = Colors.white54;
    IconData statusIcon = Icons.hourglass_top;
    if (link.status == ParentLinkState.active) {
      borderColor = const Color(0xFF00E5FF);
      statusIcon = Icons.verified_user;
    } else if (link.status == ParentLinkState.pending) {
      borderColor = const Color(0xFFFFD600);
      statusIcon = Icons.hourglass_empty;
    } else if (link.status == ParentLinkState.revoked) {
      borderColor = const Color(0xFFFF1744);
      statusIcon = Icons.block;
    }

    return Semantics(
      container: true,
      label:
          'Relationship with ${link.userFullName}: ${link.status.displayLabel}',
      child: Container(
        key: Key('relationship_card_${link.id}'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: borderColor, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    link.userFullName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Status: ${link.status.displayLabel}',
              key: Key('relationship_status_label_${link.id}'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: borderColor,
              ),
            ),
            if (link.status == ParentLinkState.pending) ...[
              const SizedBox(height: 6),
              const Text(
                'Protected device, telemetry, and safety event data remain hidden until the Stick User approves this request.',
                style: TextStyle(fontSize: 15, color: Colors.white70),
              ),
            ],
            if (link.status == ParentLinkState.revoked) ...[
              const SizedBox(height: 6),
              const Text(
                'Access has been revoked. No device, telemetry, or safety event information is available.',
                style: TextStyle(fontSize: 15, color: Colors.white70),
              ),
            ],
            if (link.status == ParentLinkState.active ||
                link.status == ParentLinkState.pending) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (link.status == ParentLinkState.active)
                    ElevatedButton.icon(
                      key: Key('select_active_user_${link.userId}'),
                      onPressed: () {
                        controller.selectActiveLinkedUser(link.userId);
                        setState(() {
                          _selectedIndex = 2;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.shield),
                      label: const Text('OPEN SAFETY VIEW'),
                    ),
                  OutlinedButton.icon(
                    key: Key('revoke_link_button_${link.id}'),
                    onPressed: controller.isSubmittingAction
                        ? null
                        : () => controller.revokeRelationship(link.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF1744),
                      side: const BorderSide(color: Color(0xFFFF1744), width: 1.5),
                    ),
                    icon: const Icon(Icons.link_off),
                    label: const Text('REVOKE LINK'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: SAFETY & DEVICE MONITOR (For Selected ACTIVE Linked User Only)
  // ===========================================================================
  Widget _buildSafetyDetailTab(
    BuildContext context,
    ParentModuleController controller,
  ) {
    final activeLink = controller.selectedActiveLink;
    if (activeLink == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Semantics(
            label:
                'No active linked user selected. Protected safety and device information requires an ACTIVE relationship.',
            child: const Text(
              'Select an ACTIVE linked user to view safety status, device state, and telemetry. PENDING and REVOKED relationships cannot access this view.',
              key: Key('parent_safety_no_active_user_notice'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
          ),
        ),
      );
    }

    final userId = activeLink.userId;
    final safetyStatus = controller.safetyStatusForUser(userId);
    final devices = controller.devicesForUser(userId);
    final userSosEvents = controller
        .sosEventsForUser(userId)
        .where((s) => s.status.isActiveEmergency)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.activeLinks.length > 1) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: controller.activeLinks.map((link) {
                final isSelected = link.userId == userId;
                return ChoiceChip(
                  label: Text(link.userFullName),
                  selected: isSelected,
                  onSelected: (_) => controller.selectActiveLinkedUser(link.userId),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // 1. High-Contrast Safety Status Banner (Text + Icon + Hierarchy)
          Semantics(
            liveRegion: true,
            label:
                'Safety Status for ${activeLink.userFullName}: ${safetyStatus.descriptiveLabel}',
            child: Container(
              key: const Key('parent_safety_status_banner'),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                border: Border.all(
                  color: _borderColorForSafety(safetyStatus),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _iconForSafety(safetyStatus),
                    color: _borderColorForSafety(safetyStatus),
                    size: 38,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User: ${activeLink.userFullName}',
                          style: const TextStyle(
                            fontSize: 17,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          safetyStatus.descriptiveLabel,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Active SOS cards for this user (if any)
          if (userSosEvents.isNotEmpty) ...[
            ...userSosEvents.map((sos) => _buildCaregiverSosCard(controller, sos)),
            const SizedBox(height: 16),
          ],

          // 3. Linked Devices, Separated Statuses, Read-Only Config & Telemetry
          Text(
            'LINKED STICK DEVICES (${devices.length})',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          if (devices.isEmpty)
            const Text(
              'This user has not registered a stick device yet.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            )
          else
            ...devices.map(
              (device) => _buildLinkedDeviceDetailCard(
                context,
                controller,
                device,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLinkedDeviceDetailCard(
    BuildContext context,
    ParentModuleController controller,
    RegisteredDevice device,
  ) {
    final domainStatus = controller.domainStatusForDevice(device.id);
    final liveConn = controller.liveConnectionForDevice(device.id);
    final config = controller.configurationForDevice(device.id);
    final telemetry = controller.telemetryForDevice(device.id);

    return Semantics(
      container: true,
      label:
          'Stick Device ${device.deviceName}, Domain Status ${domainStatus.displayLabel}, Live Connection ${liveConn.displayLabel}',
      child: Container(
        key: Key('parent_device_detail_card_${device.id}'),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: Colors.white54, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${device.deviceName} (${device.deviceIdentifier})',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            // Strictly separated Domain Status vs Live Connection State (Section 14)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Container(
                  key: Key('parent_device_domain_badge_${device.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Domain Status: ${domainStatus.wireName}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                ),
                Container(
                  key: Key('parent_device_live_badge_${device.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: const Color(0xFFFFD600), width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Live Connection: ${liveConn.wireName}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'LIVE TELEMETRY SUMMARY',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(height: 6),
            if (telemetry == null)
              const Text(
                'No live telemetry sample received in this session.',
                style: TextStyle(fontSize: 15, color: Colors.white70),
              )
            else ...[
              Text(
                'Forward Distance: ${telemetry.forwardDistanceCm ?? '--'} cm • Ground Distance: ${telemetry.groundDistanceCm ?? '--'} cm',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              Text(
                'Battery: ${telemetry.batteryPercentage ?? '--'}% • Hazard Level: ${telemetry.hazardLevel ?? 'NORMAL'}',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
            if (config != null) ...[
              const SizedBox(height: 16),
              Container(
                key: Key('parent_readonly_config_card_${device.id}'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'READ-ONLY DEVICE CONFIGURATION (v${config.configurationVersion})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Thresholds: Normal ${config.normalThresholdCm} cm / Slow ${config.slowWarningThresholdCm} cm / Fast ${config.fastWarningThresholdCm} cm',
                      style: const TextStyle(fontSize: 15, color: Colors.white),
                    ),
                    Text(
                      'Haptic: ${config.hapticEnabled ? '${config.hapticIntensity}%' : 'Off'} • Audio: ${config.audioEnabled ? '${config.audioVolume}%' : 'Off'}',
                      style: const TextStyle(fontSize: 15, color: Colors.white),
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

  // ===========================================================================
  // TAB 3: EVENTS (Caregiver SOS Management & Hazard Event History)
  // ===========================================================================
  Widget _buildEventsTab(
    BuildContext context,
    ParentModuleController controller,
  ) {
    final activeLink = controller.selectedActiveLink;
    if (activeLink == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No ACTIVE linked user selected. Protected SOS and hazard event history is available only for ACTIVE relationships.',
            key: Key('parent_events_no_active_user_notice'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
        ),
      );
    }

    final userSosEvents = controller.sosEventsForUser(activeLink.userId);
    final userHazardEvents = controller.hazardsForUser(activeLink.userId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SOS EVENTS — ${activeLink.userFullName}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF1744),
            ),
          ),
          const SizedBox(height: 10),
          if (userSosEvents.isEmpty)
            const Text(
              'No SOS events recorded for this user.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            )
          else
            ...userSosEvents.map(
              (sos) => _buildCaregiverSosCard(controller, sos),
            ),
          const SizedBox(height: 24),
          Text(
            'HAZARD ALERTS — ${activeLink.userFullName}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFD600),
            ),
          ),
          const SizedBox(height: 10),
          if (userHazardEvents.isEmpty)
            const Text(
              'No hazard events recorded for this user.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            )
          else
            ...userHazardEvents.map((hazard) {
              return Semantics(
                container: true,
                label:
                    'Hazard Alert: ${hazard.readableHazardType}, severity ${hazard.hazardLevel}, distance ${hazard.distanceCm ?? 'unknown'} centimeters',
                child: Container(
                  key: Key('parent_hazard_card_${hazard.id}'),
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
                      const SizedBox(height: 4),
                      Text(
                        'Distance: ${hazard.distanceCm ?? '--'} cm • Device: ${hazard.deviceIdentifier}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  /// Renders a caregiver SOS card with semantic labels and strict lifecycle buttons:
  /// - TRIGGERED -> shows `[ ACKNOWLEDGE ]` (`Key('parent_ack_sos_${sos.id}')`)
  /// - ACKNOWLEDGED -> shows `[ RESOLVE ]` (`Key('parent_resolve_sos_${sos.id}')`)
  /// - NEVER exposes a Cancel SOS action (Section 23 & Section 31).
  Widget _buildCaregiverSosCard(
    ParentModuleController controller,
    PersistedSosEvent sos,
  ) {
    final isActive = sos.status.isActiveEmergency;
    final borderColor =
        isActive ? const Color(0xFFFF1744) : const Color(0xFF00E5FF);

    return Semantics(
      container: true,
      liveRegion: isActive,
      label:
          'Emergency SOS Event for ${sos.userFullName}, status ${sos.status.wireName}, device ${sos.deviceIdentifier}',
      child: Container(
        key: Key('parent_sos_card_${sos.id}'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF330A12) : const Color(0xFF142026),
          border: Border.all(color: borderColor, width: 2.5),
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
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isActive ? 'SOS ACTIVE — ${sos.status.wireName}' : 'SOS ${sos.status.wireName}',
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
              'User: ${sos.userFullName} • Device: ${sos.deviceIdentifier}',
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            if (sos.status == BackendSosStatus.triggered) ...[
              const SizedBox(height: 14),
              Semantics(
                button: true,
                label: 'Acknowledge emergency SOS for ${sos.userFullName}',
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    key: Key('parent_ack_sos_${sos.id}'),
                    onPressed: controller.isSubmittingAction
                        ? null
                        : () => controller.acknowledgeSosEvent(sos),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD600),
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.notifications_active),
                    label: const Text(
                      'ACKNOWLEDGE SOS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ] else if (sos.status == BackendSosStatus.acknowledged) ...[
              const SizedBox(height: 14),
              Semantics(
                button: true,
                label: 'Resolve acknowledged SOS for ${sos.userFullName}',
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    key: Key('parent_resolve_sos_${sos.id}'),
                    onPressed: controller.isSubmittingAction
                        ? null
                        : () => controller.resolveSosEvent(sos),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: const Text(
                      'RESOLVE SOS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _borderColorForSafety(CaregiverSafetyStatus status) {
    switch (status) {
      case CaregiverSafetyStatus.sosActive:
      case CaregiverSafetyStatus.critical:
      case CaregiverSafetyStatus.danger:
        return const Color(0xFFFF1744);
      case CaregiverSafetyStatus.warning:
        return const Color(0xFFFFD600);
      case CaregiverSafetyStatus.safe:
        return const Color(0xFF00E5FF);
    }
  }

  IconData _iconForSafety(CaregiverSafetyStatus status) {
    switch (status) {
      case CaregiverSafetyStatus.sosActive:
        return Icons.sos;
      case CaregiverSafetyStatus.critical:
      case CaregiverSafetyStatus.danger:
        return Icons.report_problem;
      case CaregiverSafetyStatus.warning:
        return Icons.warning_amber_rounded;
      case CaregiverSafetyStatus.safe:
        return Icons.check_circle_outline;
    }
  }
}
