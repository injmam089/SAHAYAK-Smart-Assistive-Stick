# SAHAYAK — DEVELOPMENT ROADMAP

## Phase 0 — Architecture & Planning
Status: COMPLETED & VERIFIED

- project memory files
- requirements
- architecture
- technology decisions
- repository structure

## Phase 1 — Software Foundation (1A, 1B, 1C, 1D, 1E)
Status: COMPLETED & VERIFIED (31/31 Backend Automated Tests Passing)

- **Phase 1A:** Monorepo skeleton, Spring Boot 3.3.4 foundation, Flyway V1 migration, Flutter `DeviceCommunication` & `SimulatedDeviceCommunication`, ESP32 PlatformIO skeleton
- **Phase 1B:** Flyway V2 migration (`users`, `refresh_tokens`), BCrypt (cost 12), stateless JWT authentication, SHA-256 hashed refresh-token rotation & reuse detection, RBAC (`USER`, `PARENT`, `ADMIN`)
- **Phase 1C:** REST `/api/v1` conventions & DTO separation, Spring WebSocket/STOMP broker (`/ws`), STOMP JWT channel security & destination authorization, `RealtimeEventEnvelope<T>`, `TelemetryEventDto` (`simulated = true`), Flutter `ApiClient`, `AuthController`, `StompRealtimeClient`, and `TelemetryPipelineCoordinator`
- **Phase 1D:** Flyway V3 migration (`devices`, `device_configurations`, `parent_user_links`), Device Registry & Configuration APIs, `ParentUserLink` (`PENDING` -> `ACTIVE` -> `REVOKED`) lifecycle, `ParentUserAuthorizationService`, and authorized realtime parent fan-out over STOMP
- **Phase 1E:** Flyway V4 migration (`hazard_events`, `sos_events`), `HazardEvent` & `SosEvent` domain persistence, controlled SOS lifecycle (`TRIGGERED -> ACKNOWLEDGED -> RESOLVED`, `TRIGGERED -> CANCELLED`), `(device_id, correlation_id)` idempotency, and zero-leakage realtime `HAZARD_ALERT` and `SOS_EVENT` fan-out

## Phase 2 — User Module (Flutter Application Integration)
Status: COMPLETED (`IMPLEMENTED — NOT VERIFIED` on host pending Flutter SDK installation)

- Authentication UI (`AuthScreen`), 4-tab `UserModuleShell`, `UserModuleController`, `UserModuleApiService`, separated `DomainDeviceStatus` vs `LiveDeviceConnectionState`, threshold configuration validation, stale telemetry detection, hold/confirm SOS emergency trigger, user-scoped STOMP subscription (`/topic/user/{userId}/events`), and 30-scenario test suite

## Phase 3 — Parent Control Module (Caregiver Flutter Application)
Status: COMPLETED (`IMPLEMENTED — NOT VERIFIED` on host pending Flutter SDK installation)

- Role-based routing (`PARENT` -> `ParentControlModuleShell`), `ParentModuleController`, `ParentModuleApiService`
- Caregiver–user relationship management (`PENDING`, `ACTIVE`, `REVOKED` UI, no parent self-approval, immediate data purge on `REVOKED`)
- `ACTIVE`-only linked user, device, read-only configuration, telemetry, hazard, and SOS access
- Separated `DomainDeviceStatus` vs `LiveDeviceConnectionState`
- Caregiver SOS `TRIGGERED -> ACKNOWLEDGED -> RESOLVED` actions (with `CANCELLED` prohibited for caregivers)
- Parent-scoped STOMP subscription (`/topic/parent/{parentId}/events`) with authorized user/device filtering and 38-scenario test suite

## Phase 4 — Device/Firmware Integration
Status: NEXT PHASE (PENDING)

- ESP32 communication (`BleDeviceCommunication`)
- sensor telemetry
- hazard events
- battery information
- emergency input
- haptic/audio state

## Phase 5 — Real-Time & Push Notification Expansion
Status: PENDING

- reconnect reconciliation
- FCM push notification delivery, retry, and reconciliation

## Phase 6 — Security Hardening
Status: PENDING

- authentication hardening
- authorization audit
- secure pairing
- validation
- rate limiting where required
- secret management
- privacy review

## Phase 7 — Testing
Status: PENDING

- unit tests
- API tests
- integration tests
- device simulation
- failure testing
- offline/reconnect testing
- SOS reliability testing
- security testing

## Phase 8 — Finalization & Deployment
Status: PENDING

- accessibility review
- UX polish
- production configuration
- deployment
- documentation
- final demo
