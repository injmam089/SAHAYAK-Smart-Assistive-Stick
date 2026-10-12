import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/network/api_client.dart';
import 'core/realtime/stomp_realtime_client.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'device/device_communication.dart';
import 'device/mock/simulated_device_communication.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_screen.dart';
import 'features/parent_module/screens/parent_module_shell.dart';
import 'features/parent_module/services/parent_module_api_service.dart';
import 'features/parent_module/state/parent_module_controller.dart';
import 'features/user_module/screens/user_module_shell.dart';
import 'features/user_module/services/user_module_api_service.dart';
import 'features/user_module/state/user_module_controller.dart';

void main() {
  runApp(const SahayakApp());
}

/// Root widget for the SAHAYAK Unified Platform (Phase 2 User Module + Phase 3 Parent Control Module).
///
/// Role-based routing inside one unified Flutter application:
/// - `USER` -> [UserModuleShell]
/// - `PARENT` -> [ParentControlModuleShell]
/// - `ADMIN` -> Informational notice (Admin UI is out of scope)
class SahayakApp extends StatefulWidget {
  final AuthController? authController;
  final UserModuleController? userModuleController;
  final ParentModuleController? parentModuleController;
  final bool restoreSessionOnInit;

  const SahayakApp({
    super.key,
    this.authController,
    this.userModuleController,
    this.parentModuleController,
    this.restoreSessionOnInit = true,
  });

  @override
  State<SahayakApp> createState() => _SahayakAppState();
}

class _SahayakAppState extends State<SahayakApp> {
  late final AuthController _authController;
  late final UserModuleController _userModuleController;
  late final ParentModuleController _parentModuleController;

  bool _ownsAuth = false;
  bool _ownsUserModule = false;
  bool _ownsParentModule = false;

  @override
  void initState() {
    super.initState();
    final tokenStorage = InMemorySecureTokenStorage();
    late final AuthController resolvedAuth;
    final apiClient = ApiClient(
      baseUrl: const String.fromEnvironment(
        'SAHAYAK_API_BASE_URL',
        defaultValue: 'http://localhost:8080',
      ),
      tokenStorage: tokenStorage,
      onSessionExpired: () => resolvedAuth.handleSessionExpired(),
    );

    if (widget.authController != null) {
      resolvedAuth = widget.authController!;
    } else {
      _ownsAuth = true;
      resolvedAuth = AuthController(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
      );
    }
    _authController = resolvedAuth;

    if (widget.userModuleController != null) {
      _userModuleController = widget.userModuleController!;
    } else {
      _ownsUserModule = true;
      final userRealtimeClient = StompRealtimeClient(
        wsUrl: const String.fromEnvironment(
          'SAHAYAK_WS_URL',
          defaultValue: 'ws://localhost:8080/ws',
        ),
        tokenStorage: tokenStorage,
      );
      final DeviceCommunication deviceComm = SimulatedDeviceCommunication();
      _userModuleController = UserModuleController(
        apiService: UserModuleApiService(apiClient: apiClient),
        realtimeClient: userRealtimeClient,
        deviceCommunication: deviceComm,
      );
    }

    if (widget.parentModuleController != null) {
      _parentModuleController = widget.parentModuleController!;
    } else {
      _ownsParentModule = true;
      final parentRealtimeClient = StompRealtimeClient(
        wsUrl: const String.fromEnvironment(
          'SAHAYAK_WS_URL',
          defaultValue: 'ws://localhost:8080/ws',
        ),
        tokenStorage: tokenStorage,
      );
      _parentModuleController = ParentModuleController(
        apiService: ParentModuleApiService(apiClient: apiClient),
        realtimeClient: parentRealtimeClient,
      );
    }

    if (widget.restoreSessionOnInit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authController.restoreSession();
      });
    }
  }

  @override
  void dispose() {
    if (_ownsParentModule) {
      _parentModuleController.dispose();
    }
    if (_ownsUserModule) {
      _userModuleController.dispose();
    }
    if (_ownsAuth) {
      _authController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.highContrastTheme,
      home: ListenableBuilder(
        listenable: _authController,
        builder: (context, _) {
          final authState = _authController.state;
          if (!authState.isAuthenticated) {
            return AuthScreen(authController: _authController);
          }

          final user = authState.user!;
          final normalizedRole = user.role.trim().toUpperCase();

          if (normalizedRole == 'PARENT' || normalizedRole == 'ROLE_PARENT') {
            return ParentControlModuleShell(
              authController: _authController,
              parentController: _parentModuleController,
            );
          }

          if (normalizedRole == 'USER' || normalizedRole == 'ROLE_USER') {
            return UserModuleShell(
              authController: _authController,
              userController: _userModuleController,
            );
          }

          return _UnsupportedRoleScreen(
            authController: _authController,
            role: normalizedRole,
          );
        },
      ),
    );
  }
}

/// Safe fallback screen if an account with a non-mobile role (such as ADMIN) signs in.
class _UnsupportedRoleScreen extends StatelessWidget {
  final AuthController authController;
  final String role;

  const _UnsupportedRoleScreen({
    required this.authController,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SAHAYAK — Unsupported Mobile Role'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.admin_panel_settings_outlined,
                size: 64,
                color: Color(0xFFFFD600),
              ),
              const SizedBox(height: 16),
              Text(
                'Signed in with role: $role',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'The SAHAYAK mobile app provides the Stick User Module (USER) and Caregiver Module (PARENT). Admin UI is not included.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  key: const Key('unsupported_role_logout_button'),
                  onPressed: authController.logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('SIGN OUT'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
