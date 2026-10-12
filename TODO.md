# SAHAYAK — CURRENT TODO

## Priority 0 — Pre-Coding Alignment & Architecture (Status: VERIFIED)

- [x] Confirm final software technology stack (Flutter/Dart, Java 17 Spring Boot 3.x, PostgreSQL, REST/WebSocket, FCM, Arduino-ESP32)
- [x] Document initial BLE communication and pluggable DeviceCommunication abstraction
- [x] Document SOS lifecycle and smartphone-assisted modular location strategy
- [x] Update project memory files (`DECISIONS.md`, `ARCHITECTURE.md`, `CURRENT_STATUS.md`, `TODO.md`)

---

## Priority 1A–1E — Backend & Mobile Foundation (Status: COMPLETED)

- [x] Phase 1A: Monorepo skeleton, Spring Boot 3.3.4 foundation, Flyway V1 migration — `VERIFIED`
- [x] Phase 1B: Flyway V2 migration (`users`, `refresh_tokens`), BCrypt, JWT, refresh-token rotation, RBAC — `VERIFIED`
- [x] Phase 1C: REST `/api/v1`, Spring WebSocket/STOMP broker (`/ws`), STOMP JWT channel security, `RealtimeEventEnvelope<T>`, Flutter `ApiClient`, `AuthController`, `StompRealtimeClient`, `TelemetryPipelineCoordinator` — Backend `VERIFIED` / Flutter `IMPLEMENTED — NOT VERIFIED`
- [x] Phase 1D: Flyway V3 migration (`devices`, `device_configurations`, `parent_user_links`), Device Registry & Configuration APIs, `ParentUserLink` (`PENDING -> ACTIVE -> REVOKED`) lifecycle, `ParentUserAuthorizationService` — `VERIFIED`
- [x] Phase 1E: Flyway V4 migration (`hazard_events`, `sos_events`), `HazardEvent` & `SosEvent` domain persistence, controlled SOS lifecycle (`TRIGGERED -> ACKNOWLEDGED -> RESOLVED`, `TRIGGERED -> CANCELLED`), idempotency, zero-leakage realtime fan-out — `VERIFIED` (31/31 backend tests passing)

---

## Priority 2 — User Module (Phase 2 — COMPLETED: IMPLEMENTED — NOT VERIFIED on host)

- [x] Extend `ApiClient` (`PUT`, `PATCH`, safe error messages) & `AuthController` (`register`, `restoreSession`) — `IMPLEMENTED — NOT VERIFIED`
- [x] Implement `user_module_models.dart`, `UserModuleApiService`, `UserModuleController`, and `UserModuleShell` — `IMPLEMENTED — NOT VERIFIED`
- [x] Write 30-scenario Phase 2 automated test suite (`mobile/test/user_module_phase2_test.dart`) — `IMPLEMENTED — NOT VERIFIED`

---

## Priority 3 — Parent Control Module (Phase 3 — COMPLETED: IMPLEMENTED — NOT VERIFIED on host)

- [x] Update `AuthScreen` and `SahayakApp` for role-based routing (`USER` -> `UserModuleShell`, `PARENT` -> `ParentControlModuleShell`) — `IMPLEMENTED — NOT VERIFIED`
- [x] Implement `parent_module_models.dart` (`ParentLinkState`, `CaregiverUserLink`, `CaregiverSafetyStatus`) — `IMPLEMENTED — NOT VERIFIED`
- [x] Implement `ParentModuleApiService` enforcing caregiver-only actions (blocking parent self-approval, device registration, config mutation, and SOS cancellation) — `IMPLEMENTED — NOT VERIFIED`
- [x] Implement `ParentModuleController` with `ACTIVE`-only protected data access, separated `DomainDeviceStatus` vs `LiveDeviceConnectionState`, `/topic/parent/{parentId}/events` STOMP subscription & authorized user filtering, and immediate revoked-access data purge — `IMPLEMENTED — NOT VERIFIED`
- [x] Implement accessible `ParentControlModuleShell` (`Home`, `Linked Users`, `Safety`, `Events` tabs) with `ACKNOWLEDGE SOS` and `RESOLVE SOS` controls — `IMPLEMENTED — NOT VERIFIED`
- [x] Write 38-scenario Phase 3 automated test suite (`mobile/test/parent_module_phase3_test.dart`) — `IMPLEMENTED — NOT VERIFIED`

---

## Remaining Host Verification Tasks

- [ ] Install Flutter SDK on host environment and run `flutter analyze` and `flutter test`
- [ ] Start Docker Desktop or local PostgreSQL service on host and run live PostgreSQL migration check

---

## Priority 4 — Firmware & Device Integration (Phase 4 — FUTURE)

- [ ] Confirm exact ESP32 GPIO pinout with hardware team
- [ ] Implement HC-SR04 forward and ground distance sensor drivers
- [ ] Implement non-blocking haptic vibration & buzzer driver
- [ ] Implement emergency button debounce and SOS trigger
- [ ] Implement BLE GATT server (`NimBLE-Arduino`) and Flutter `BleDeviceCommunication`

---

## Priority 5 — Real-Time & Push Notification Expansion (Phase 5 — FUTURE)

- [ ] Reconnect state reconciliation
- [ ] Firebase Cloud Messaging (FCM) high-priority push notification delivery, retry, and reconciliation

---

## Hardware Decisions Preserved (Status: TBD)

- [ ] Exact ESP32 GPIO pin assignments (`PIN_TBD`)
- [ ] Exact sensor mounting angles
- [ ] Final motor driver circuit & current limiters
- [ ] Final battery voltage regulation (3.7V Li-ion to 5V HC-SR04 / 3.3V ESP32)
- [ ] Final HC-SR04 level-shifting circuit
- [ ] Future cellular/hardware emergency communication module
