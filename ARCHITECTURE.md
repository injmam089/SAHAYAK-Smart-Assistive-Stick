# SAHAYAK — SYSTEM ARCHITECTURE

## High-Level System Architecture

```text
                                  SAHAYAK PLATFORM
                                         |
               +-------------------------+-------------------------+
               |                                                   |
      +-----------------+                                 +-----------------+
      |   USER MODULE   |                                 |  PARENT MODULE  |
      | (Stick Operator)|                                 |   (Caregiver)   |
      |  [Phase 2 Ready]|                                 |  [Phase 3 Ready]|
      +--------+--------+                                 +--------+--------+
               |                                                   |
               +-------------------------+-------------------------+
                                         |
                       FLUTTER MOBILE CLIENT (Dart)
                       - AuthScreen (Login / Register ROLE_USER or ROLE_PARENT)
                       - UserModuleShell (Safety / Device / Events / Settings)
                       - ParentControlModuleShell (Home / Linked Users / Safety / Events)
                       - UserModuleController & ParentModuleController
                                         |
                       [DeviceCommunication Interface]
                                         |
             +---------------------------+---------------------------+
             | (Phase 1C–3 Default)                                  | (Future Phase 4)
  [SimulatedDeviceCommunication]                          [BleDeviceCommunication]
             |                                                       | (BLE Wireless)
             v                                                       v
  [TelemetryPipelineCoordinator]                          ESP32 SMART ASSISTIVE STICK
             |                                        (Arduino Framework / C++ Firmware)
             v                                        +---------------------------------+
   FLUTTER NETWORKING & REALTIME LAYER                |  - Forward Obstacle HC-SR04     |
   - ApiClient (REST /api/v1 + 401 Refresh)           |  - Ground Hazard HC-SR04        |
   - StompRealtimeClient (WS /ws + JWT)               |  - Dual Vibration Motors        |
   - User Topic:   /topic/user/{userId}/events        |  - Active Buzzer + LED          |
   - Parent Topic: /topic/parent/{parentId}/events    |  - SOS Emergency Button         |
             |                                        +---------------------------------+
             +-----------------------+----------------+
             | (REST API / JSON)     | (STOMP /ws)
             v                       v
      +---------------------------------------------------------------------+
      |                BACKEND API (Java 17 / Spring Boot 3.x)              |
      |                                                                     |
      |  - Security & Auth (JWT, BCrypt, SHA-256 Refresh Token Rotation)    |
      |  - User & Parent Account Management (RBAC: USER / PARENT / ADMIN)   |
      |  - Device Registry & Configuration (DeviceService, ConfigService)   |
      |  - Caregiver-User Linking & Policy (ParentUserAuthorizationService) |
      |  - Hazard & SOS Event Domain (HazardEventService, SosEventService)  |
      |  - WebSocket STOMP Broker (/ws, /app, /topic, /queue, /user)        |
      |  - StompAuthChannelInterceptor & StompDestinationAuthorizer         |
      |  - RealtimeEventService (User + Authorized ACTIVE Parent Fan-Out)   |
      |  - Push Notification Service (High-Priority FCM — FUTURE)           |
      +-------------------+-----------------------------+-------------------+
                          |                             |
                          v                             v
                 +-----------------+           +-----------------+
                 |   POSTGRESQL    |           |   FIREBASE FCM  |
                 |    DATABASE     |           |  (Push Alerts)  |
                 +-----------------+           +-----------------+
```

---

## Architectural Principles

### 1. One Platform, Two Modules
SAHAYAK delivers both **User Module** and **Parent Control Module** capabilities inside a single unified platform:
- **Client Side (Flutter):** A single mobile codebase (`SahayakApp`) with role-driven navigation shells:
  - `ROLE_USER` $\rightarrow$ [`UserModuleShell`](file:///d:/VISHWAKARMA2026/mobile/lib/features/user_module/screens/user_module_shell.dart) (Phase 2)
  - `ROLE_PARENT` $\rightarrow$ [`ParentControlModuleShell`](file:///d:/VISHWAKARMA2026/mobile/lib/features/parent_module/screens/parent_module_shell.dart) (Phase 3)
  - Shared authentication state (`AuthController`, `AuthState`) and unified REST (`ApiClient`) + STOMP (`StompRealtimeClient`) communication infrastructure.
- **Server Side (Spring Boot):** A single backend service handling both user roles, sharing relational models, authentication pipelines, device ownership/relationship policies (`ParentUserAuthorizationService`), hazard/SOS event lifecycles, and real-time message brokers.

### 2. Phase 2 User Module State Separation & Safety-First UX
The Flutter **User Module** (`UserModuleController`, `UserModuleApiService`, `UserModuleShell`) enforces strict separation across:
1. **Persistent Domain Device Status (`DomainDeviceStatus`):** `REGISTERED`, `ACTIVE`, `INACTIVE`, `DISABLED`.
2. **Live Transport Connection State (`LiveDeviceConnectionState`):** `CONNECTED`, `DISCONNECTED`, `CONNECTING`, `ERROR`, `UNKNOWN`.
3. **Ephemeral Telemetry & Stale Detection (`TelemetryEventPayload`):** Live forward/ground distance, battery level, `MODE: SIMULATED STICK`, and stale telemetry warning.
4. **Protected Hold-to-SOS Emergency Trigger:** Long-press (`HOLD TO SEND SOS`) or explicit two-step single-tap confirmation (`CONFIRM SOS`), with `USER`-authorized `CANCELLED` and `RESOLVED` transitions and user-scoped STOMP subscription (`/topic/user/{userId}/events`).

### 3. Phase 3 Parent Control Module Architecture & Caregiver Security Boundaries
The Flutter **Parent Control Module** (`ParentModuleController`, `ParentModuleApiService`, `ParentControlModuleShell`) provides a calm, safety-prioritized caregiver interface governed by `ACTIVE` `ParentUserLink` authorization:
1. **Relationship Lifecycle (`PENDING -> ACTIVE -> REVOKED`):**
   - Caregivers can initiate link requests (`POST /api/v1/parent-links` $\rightarrow$ `PENDING`) and revoke links (`PATCH /api/v1/parent-links/{linkId}/status` $\rightarrow$ `REVOKED`), but **cannot self-approve** (`PENDING -> ACTIVE`).
   - `PENDING` (`"Pending — Waiting for user approval"`) and `REVOKED` (`"Revoked — Access removed"`) relationships expose **zero** protected device, configuration, telemetry, hazard, or SOS data.
2. **Read-Only Linked Device & Separated Status Display:**
   - For `ACTIVE`-linked users only, caregivers can view linked devices (`GET /api/v1/devices`) and read-only device configurations (`GET /api/v1/devices/{deviceId}/configuration`).
   - Caregivers cannot register devices, modify device status, or modify device configuration.
   - `DomainDeviceStatus` (`REGISTERED`, `ACTIVE`, `INACTIVE`, `DISABLED`) is always displayed separately from `LiveDeviceConnectionState` (`CONNECTED`, `DISCONNECTED`, `CONNECTING`, `ERROR`, `UNKNOWN`).
3. **Caregiver SOS Lifecycle (`TRIGGERED -> ACKNOWLEDGED -> RESOLVED`):**
   - Caregivers can acknowledge a `TRIGGERED` SOS (`PATCH /api/v1/sos-events/{id}/status` with `ACKNOWLEDGED`) and resolve an `ACKNOWLEDGED` SOS (`RESOLVED`).
   - Direct `TRIGGERED -> RESOLVED` transitions are rejected, and caregivers are **forbidden from cancelling (`CANCELLED`)** a user's SOS event.
4. **Parent-Scoped STOMP Subscription & Authorized User Filtering:**
   - Subscribes exclusively to `/topic/parent/{parentId}/events` (rejecting `/topic/all-parents`, other parents' topics, and user topics).
   - Every incoming realtime event is verified against currently authorized `ACTIVE`-linked users/devices before being cached or displayed.
5. **Immediate Revoked-Access Purge:**
   - When a relationship transitions `ACTIVE -> REVOKED` (or returns `403 Forbidden`), `ParentModuleController.handleUserAccessRevoked` immediately purges all cached devices, configurations, telemetry, hazards, and SOS events for that user and displays a safe access-revoked message.

---

## Database Architecture (Incremental Migration Strategy)

The database schema is managed incrementally through Flyway migrations:
- **`V1__init_foundation.sql` (Phase 1A):** Foundation connectivity check table (`foundation_checks`).
- **`V2__init_auth_foundation.sql` (Phase 1B):** UUID-based `users` table and `refresh_tokens` table.
- **`V3__device_registry_and_parent_user_links.sql` (Phase 1D):** `devices`, `device_configurations`, and `parent_user_links` tables.
- **`V4__hazard_and_sos_event_domain.sql` (Phase 1E):** `hazard_events` and `sos_events` tables with foreign keys, check constraints, unique `(device_id, correlation_id)` idempotency constraints, and composite lookup indexes.

---

## Hardware Boundaries & Status

- **Software Blockers:** None.
- **Hardware TBDs Preserved:** Physical hardware decisions (exact ESP32 GPIO pin assignments, sensor mounting angles, motor driver IC / current limits, battery voltage regulation / 5V booster, HC-SR04 voltage-divider circuit, and future onboard cellular hardware) remain unresolved hardware decisions and are cleanly isolated from the software platform.
