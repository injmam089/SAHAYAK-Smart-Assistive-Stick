# SAHAYAK — CURRENT STATUS

> This file is the project's live progress memory. Update it after meaningful development work.

## Overall Status

**Stage:** Phase 3 — Parent Control Module (Caregiver Flutter Application) Completed (`IMPLEMENTED — NOT VERIFIED` on host because Flutter SDK is not installed; Backend Phase 1A–1E `VERIFIED` with 31/31 passing tests).

**Software Blockers:** None.
**Hardware Blockers:** Previously identified physical hardware TBDs remain unresolved and isolated.

---

## Status Classification Breakdown

### VERIFIED (Tested & Confirmed Passing — 31/31 Backend Automated Tests)
- [x] **Architecture & Project Memory System** (`ARCHITECTURE.md`, `DECISIONS.md`, `PROJECT_REQUIREMENTS.md`, `DEVELOPMENT_RULES.md`)
- [x] **Spring Boot 3.3.4 Backend Compilation, Packaging & Test Execution** (`mvn test -B` & `mvn package -B` -> 31/31 passed, `BUILD SUCCESS`)
- [x] **Flyway V1, V2, V3 & V4 Incremental Schema Migrations** (`V1__init_foundation.sql`, `V2__init_auth_foundation.sql`, `V3__device_registry_and_parent_user_links.sql`, `V4__hazard_and_sos_event_domain.sql` validated and applied in test suite)
- [x] **User & RefreshToken JPA Persistence Models & Auth APIs** (`User`, `Role`, `AccountStatus`, `RefreshToken`, BCrypt cost 12, stateless JWT, SHA-256 hashed refresh-token rotation & reuse detection)
- [x] **Role-Based Access Control (RBAC)** (Consistent `hasRole("USER")`, `hasRole("PARENT")`, `hasRole("ADMIN")` enforcement)
- [x] **Spring WebSocket / STOMP Real-Time Broker & Channel Security** (`/ws`, `StompAuthChannelInterceptor`, `StompDestinationAuthorizer`, `RealtimeEventEnvelope<T>`, `TelemetryEventDto`)
- [x] **Device Registry, Configuration & Caregiver–User Linking (`Device`, `DeviceConfiguration`, `ParentUserLink`, `ParentUserAuthorizationService`)** (`PENDING -> ACTIVE -> REVOKED` lifecycle, principal-bound ownership, threshold hierarchy validation)
- [x] **Hazard Event Domain Persistence & API (`HazardEvent`, `HazardType`, `HazardLevel`, `HazardEventRepository`, `HazardEventService`, `DeviceEventController`)** (`POST /api/v1/devices/{deviceId}/hazards`, `GET /api/v1/devices/{deviceId}/hazards`, `(device_id, correlation_id)` idempotency, ownership & `ACTIVE` caregiver read enforcement)
- [x] **SOS Event Domain Persistence & Controlled Lifecycle (`SosEvent`, `SosEventStatus`, `SosEventRepository`, `SosEventService`, `DeviceEventController`)** (`POST /api/v1/devices/{deviceId}/sos`, `GET /api/v1/devices/{deviceId}/sos-events`, `GET /api/v1/sos-events/{sosEventId}`, `PATCH /api/v1/sos-events/{sosEventId}/status` enforcing `TRIGGERED -> ACKNOWLEDGED -> RESOLVED` and `TRIGGERED -> CANCELLED`, rejecting invalid/reopen transitions)
- [x] **Zero-Leakage Realtime Hazard & SOS Parent Fan-Out (`RealtimeEventService`)** (Live STOMP verification confirming `ACTIVE` linked parents receive `HAZARD_ALERT` and `SOS_EVENT` envelopes while `PENDING`, `REVOKED`, and unrelated parents and other users receive nothing, and no global parent topic exists)

### IMPLEMENTED — NOT VERIFIED (Code & Config Written; Host Runtime / Daemon Unavailable)
- [ ] **Phase 3 Flutter Parent Control Module (`ParentControlModuleShell`, `ParentModuleController`, `ParentModuleApiService`, `parent_module_models.dart`, and 38-scenario test suite `parent_module_phase3_test.dart`)** (All Dart implementation files and unit/widget test suites written under `mobile/lib/` and `mobile/test/`; `flutter` / `dart` SDK is not installed on the host machine)
- [ ] **Phase 2 Flutter User Module (`AuthScreen`, `UserModuleShell`, `UserModuleController`, `UserModuleApiService`, `user_module_models.dart`, and 30-scenario test suite `user_module_phase2_test.dart`)** (`flutter` / `dart` SDK is not installed on the host machine)
- [ ] **Flutter Core Networking (`ApiClient` with GET/POST/PUT/PATCH & 401 refresh), Auth State (`AuthController` with login/register/restoreSession), STOMP Client (`StompRealtimeClient`), and Telemetry Pipeline (`TelemetryPipelineCoordinator`)** (`flutter` / `dart` SDK is not installed on the host machine)
- [ ] **Live External PostgreSQL Instance Connectivity** (`application.yml`, `docker-compose.yml`, `org.postgresql.Driver`, and `flyway-database-postgresql` configured with environment variables; local PostgreSQL service and Docker Desktop daemon are not running on the host machine)
- [ ] **ESP32 Firmware Project Skeleton** (`firmware/platformio.ini`, `include/config.h` with `PIN_TBD`, `src/main.cpp`; PlatformIO CLI `pio` is not installed on the host machine)

### FUTURE (Deferred to Subsequent Phases)
- [ ] Real `BleDeviceCommunication` implementation & ESP32 firmware logic (Phase 4)
- [ ] Firebase Cloud Messaging (FCM) high-priority push notification delivery, retry, and reconciliation (Phase 5)
- [ ] Smartphone GPS location enrichment for SOS events
- [ ] Transactional outbox / distributed multi-node event idempotency

### TBD (Unresolved Hardware Decisions)
- [ ] Exact ESP32 GPIO pin assignment (`PIN_TBD` in `firmware/include/config.h`)
- [ ] Exact sensor mounting angle
- [ ] Final motor current / driver IC circuitry
- [ ] Final battery voltage regulation / power rail (3.7V Li-ion to 5V HC-SR04 & 3.3V ESP32)
- [ ] Final HC-SR04 5V-to-3.3V echo voltage-conditioning circuit
- [ ] Final standalone hardware emergency communication method

### BLOCKED
- None for software development. Host execution of `flutter analyze` / `flutter test`, live Docker PostgreSQL, and PlatformIO builds (`pio run`) requires installing the Flutter SDK, starting Docker Desktop, and installing PlatformIO CLI on the host machine.
