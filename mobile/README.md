# SAHAYAK — Mobile Client (Phase 1A, 1C, Phase 2 User Module & Phase 3 Parent Control Module)

Cross-platform Flutter application hosting both the **User Module** (for the assistive stick operator, Phase 2) and the **Parent Control Module** (for caregivers, Phase 3) inside a single unified codebase.

## Architecture Highlights

1. **One Platform + Two Role-Driven Modules (`SahayakApp`):**
   - `ROLE_USER` $\rightarrow$ [`UserModuleShell`](file:///d:/VISHWAKARMA2026/mobile/lib/features/user_module/screens/user_module_shell.dart)
   - `ROLE_PARENT` $\rightarrow$ [`ParentControlModuleShell`](file:///d:/VISHWAKARMA2026/mobile/lib/features/parent_module/screens/parent_module_shell.dart)
2. **Phase 2 User Module (`lib/features/user_module/`):**
   - Separates persistent `DomainDeviceStatus` (`REGISTERED`, `ACTIVE`, `INACTIVE`, `DISABLED`) from live `LiveDeviceConnectionState` (`CONNECTED`, `DISCONNECTED`, `CONNECTING`, `ERROR`, `UNKNOWN`).
   - Device registration (`POST /api/v1/devices` without `ownerUserId`), configuration validation (`normalThresholdCm > slowWarningThresholdCm > fastWarningThresholdCm > 0`), stale telemetry detection, hold/confirm SOS emergency trigger, and `/topic/user/{userId}/events` STOMP subscription.
3. **Phase 3 Parent Control Module (`lib/features/parent_module/`):**
   - **Strict `ACTIVE`-Only Authorization:** Caregivers can initiate `PENDING` link requests (`POST /api/v1/parent-links`) and revoke links (`PATCH /api/v1/parent-links/{id}/status`), cannot self-approve (`PENDING -> ACTIVE`), and can access devices, read-only configurations, telemetry, hazards, and SOS events **only** for `ACTIVE`-linked users.
   - **Immediate Revoked-Access Purge:** Transitioning a relationship to `REVOKED` (or receiving `403 Forbidden`) immediately purges all cached devices, configurations, telemetry, hazards, and SOS events for that user.
   - **Caregiver SOS Lifecycle (`TRIGGERED -> ACKNOWLEDGED -> RESOLVED`):** Exposes `ACKNOWLEDGE SOS` (for `TRIGGERED`) and `RESOLVE SOS` (for `ACKNOWLEDGED`), blocks `TRIGGERED -> RESOLVED`, and never exposes or allows SOS cancellation (`CANCELLED`).
   - **Parent-Scoped STOMP Subscription:** Subscribes exclusively to `/topic/parent/{parentId}/events` (rejecting `/topic/all-parents`, other parents' topics, and user topics) and filters incoming events against authorized `ACTIVE`-linked users/devices.

## Directory Structure

```text
mobile/
├── lib/
│   ├── core/
│   │   ├── constants/       # Global constants & default thresholds
│   │   ├── network/         # ApiClient (GET/POST/PUT/PATCH + 401 token refresh)
│   │   ├── realtime/        # RealtimeEventEnvelope & StompRealtimeClient
│   │   ├── storage/         # TokenStorage abstraction & in-memory secure store
│   │   └── theme/           # Accessible high-contrast theme
│   ├── device/              # Hardware Abstraction Layer
│   │   ├── device_communication.dart           # Core interface contract
│   │   ├── telemetry_pipeline_coordinator.dart # SimulatedDevice -> Envelope & STOMP bridge
│   │   ├── models/          # Telemetry, Hazard, SOS, Configuration models
│   │   └── mock/            # SimulatedDeviceCommunication for testing
│   ├── features/
│   │   ├── auth/            # AuthState, AuthenticatedUser, AuthController, AuthScreen
│   │   ├── user_module/     # Phase 2 User Module
│   │   │   ├── models/      # user_module_models.dart
│   │   │   ├── services/    # user_module_api_service.dart
│   │   │   ├── state/       # user_module_controller.dart
│   │   │   └── screens/     # user_module_shell.dart
│   │   └── parent_module/   # Phase 3 Parent Control Module
│   │       ├── models/      # parent_module_models.dart
│   │       ├── services/    # parent_module_api_service.dart
│   │       ├── state/       # parent_module_controller.dart
│   │       └── screens/     # parent_module_shell.dart
│   └── main.dart            # Application entry point & role-based routing
├── test/
│   ├── api_client_and_auth_test.dart       # REST Bearer header, 401 refresh & AuthController tests
│   ├── device_communication_test.dart      # Unit tests for abstraction & simulation
│   ├── realtime_event_envelope_test.dart   # Envelope serialization & unknown/malformed safety tests
│   ├── telemetry_pipeline_test.dart        # SimulatedDevice -> Coordinator -> STOMP pipeline tests
│   ├── user_module_phase2_test.dart        # 30-scenario Phase 2 User Module unit & widget tests
│   ├── parent_module_phase3_test.dart      # 38-scenario Phase 3 Parent Control Module unit & widget tests
│   └── widget_test.dart                    # Root app entry rendering test
└── pubspec.yaml
```
