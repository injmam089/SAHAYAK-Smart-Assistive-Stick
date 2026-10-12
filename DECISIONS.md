# SAHAYAK — ARCHITECTURAL DECISIONS

## Decision 001 — One Platform, Two Modules

**Status:** APPROVED

SAHAYAK software will be ONE platform containing:
1. User Module (assistive stick user)
2. Parent Control Module (caregiver / parent)

Both modules belong to the same product ecosystem and share the authentication system, backend API, database, domain logic, and real-time device/event infrastructure.

---

## Decision 002 — Hardware/Software Separation

**Status:** APPROVED

Hardware-specific communication and low-level details must be isolated from general application logic. Domain models, UI, and business workflows must never depend directly on physical microcontroller internals.

---

## Decision 003 — Initial Device Communication Protocol & Abstraction

**Status:** APPROVED

- For the initial physical prototype:
  - `ESP32 emergency event detection → BLE GATT notification → Flutter app`.
  - `Flutter Mobile App <-> Backend API` = Internet (REST API + WebSocket).
- A core device communication abstraction (`DeviceCommunication`) is established in the Flutter client with `SimulatedDeviceCommunication` for Phase 1–3 testing and `BleDeviceCommunication` for future physical integration.

---

## Decision 004 — Safety Scope

**Status:** APPROVED

SAHAYAK is an assistive information layer for a conventional white cane. It does not replace the white cane and does not guarantee collision prevention or safety.

---

## Decision 005 — Threshold Configuration & Telemetry Separation

**Status:** APPROVED

- Hazard detection thresholds (>150 cm normal, 100–150 cm slow, 50–100 cm faster, <50 cm strong) are centralized and configurable per device.
- Real-time telemetry is separated from persistent historical data. High-frequency sensor samples are not persisted indiscriminately. Only meaningful hazard events, SOS events, device configurations, and device health are saved to the database.

---

## Decision 006 — Completion Verification

**Status:** APPROVED

A feature is not COMPLETE merely because code was written. It must be marked with appropriate status (`PLANNED`, `IN PROGRESS`, `IMPLEMENTED — NOT VERIFIED`, `VERIFIED`, `BLOCKED`) and can only be marked `VERIFIED` after tests and verification checks succeed.

---

## Decision 007 — Software Technology Stack

**Status:** APPROVED

- **Frontend / Mobile:** Flutter (Dart 3.x)
- **Backend:** Java 17, Spring Boot 3.3.4, Spring Security 6, Spring Data JPA (Hibernate), Flyway, Spring WebSocket + STOMP
- **Database:** PostgreSQL
- **Push Notifications (FUTURE):** High-priority push notifications via Firebase Cloud Messaging (FCM) backed by persisted SOS state and retry/reconciliation.

---

## Decision 008 — Firmware Framework Selection

**Status:** APPROVED

Use the **Arduino framework for ESP32** (via PlatformIO / Arduino Core).

---

## Decision 009 — SOS Event Lifecycle & Location Strategy

**Status:** APPROVED

- SOS is treated as a critical-path event supporting full lifecycle tracking: creation (`TRIGGERED`), acknowledgment (`ACKNOWLEDGED`), resolution (`RESOLVED`), and cancellation (`CANCELLED`).
- Location enrichment (`FUTURE` Phase 5+) is modular and optional from the smartphone GPS.
- Real-time backend/WebSocket delivery is best-effort over the active network; persistent SOS state in PostgreSQL is the source of truth.

---

## Decision 010 — Hardware Boundary Preservation & Project Status

**Status:** APPROVED

Unresolved physical hardware decisions (`PIN_TBD`, sensor mounting angles, motor driver IC, battery regulation, HC-SR04 echo divider) remain isolated in the hardware domain. There are **no software blockers**.

---

## Decision 011 — Authentication, Refresh Token Hashing, and RBAC Least-Privilege Strategy

**Status:** APPROVED

1. Application roles `USER`, `PARENT`, and `ADMIN` map to `ROLE_USER`, `ROLE_PARENT`, and `ROLE_ADMIN` authorities and are enforced uniformly via `hasRole("USER")`, `hasRole("PARENT")`, and `hasRole("ADMIN")`.
2. Public self-registration (`POST /api/v1/auth/register`) only accepts `USER` and `PARENT` roles.
3. Refresh tokens are stored as SHA-256 hex digests (`token_hash`) with atomic rotation and reuse revocation.
4. Secrets (`SPRING_DATASOURCE_PASSWORD`, `JWT_SECRET`) are strictly externalized via environment variables.

---

## Decision 012 — API Versioning, STOMP Channel Security, and Realtime Event Envelope Standard

**Status:** APPROVED

1. All REST endpoints are versioned under `/api/v1/...` with strict Request/Response/Event DTO separation.
2. `StompAuthChannelInterceptor` and `StompDestinationAuthorizer` enforce JWT authentication on STOMP `CONNECT` and deny-by-default authorization on `SUBSCRIBE` and `SEND`.
3. All real-time events use `RealtimeEventEnvelope<T>`.

---

## Decision 013 — Device Ownership, Caregiver-User Link Lifecycle, and Authorized Parent Fan-Out Policy

**Status:** APPROVED

1. Device registration (`POST /api/v1/devices`) binds ownership strictly to the authenticated `USER` principal.
2. Caregiver links follow `PENDING -> ACTIVE -> REVOKED`. Only the target `USER` (or `ADMIN`) can activate a `PENDING` link; `PARENT` self-approval is forbidden.
3. `ParentUserAuthorizationService.isParentLinkedToUser(parentId, userId)` returns `true` only when an `ACTIVE` link exists.

---

## Decision 014 — Hazard & SOS Event Domain Persistence, Controlled SOS Lifecycle, and Idempotency Strategy

**Status:** APPROVED

1. Only the owning `ROLE_USER` of a registered `Device` may create a `HazardEvent` (`POST /api/v1/devices/{deviceId}/hazards`) or trigger an `SosEvent` (`POST /api/v1/devices/{deviceId}/sos`).
2. SOS lifecycle enforces `TRIGGERED -> ACKNOWLEDGED -> RESOLVED` and `TRIGGERED -> CANCELLED`. Terminal states (`RESOLVED`, `CANCELLED`) cannot be reopened.
3. Both `hazard_events` and `sos_events` enforce `(device_id, correlation_id)` idempotency, and `sos_events` suppresses duplicate unacknowledged physical triggers per device.

---

## Decision 015 — Phase 2 User Module State Separation, Protected SOS Trigger, and Stale Telemetry Handling

**Status:** APPROVED

1. `DomainDeviceStatus` (`REGISTERED`, `ACTIVE`, `INACTIVE`, `DISABLED`) and `LiveDeviceConnectionState` (`CONNECTED`, `DISCONNECTED`, `CONNECTING`, `ERROR`, `UNKNOWN`) are strictly separated.
2. The `HOLD TO SEND SOS` control requires either a long-press or an explicit two-step confirmation on single tap (`CONFIRM SOS`).
3. `UserModuleController` evaluates telemetry timestamps against `staleTelemetryThreshold` (default 15s) and subscribes exclusively to `/topic/user/{userId}/events`.

---

## Decision 016 — Phase 3 Parent Control Module Authorization, Revoked-Access Purge, and Caregiver SOS Policy

**Status:** APPROVED

**Context:** Phase 3 implements the caregiver-facing Parent Control Module inside the unified Flutter application (`SahayakApp`).
**Decision:**
1. **Role-Based Module Routing in Single Application:**
   - `SahayakApp` routes authenticated `USER` principals to `UserModuleShell` and authenticated `PARENT` principals to `ParentControlModuleShell` while relying on the backend as the sole authority for data and action authorization.
2. **Strict `ACTIVE`-Only Caregiver Data Access & Immediate Revocation Purge:**
   - `ParentModuleController` loads and caches devices, read-only configurations, telemetry, hazards, and SOS events **only** for users with an `ACTIVE` `CaregiverUserLink`.
   - `PENDING` relationships (`"Pending — Waiting for user approval"`) and `REVOKED` relationships (`"Revoked — Access removed"`) expose zero protected data, and parent self-approval is blocked on both client and server.
   - When a relationship transitions `ACTIVE -> REVOKED` (or returns `403 Forbidden`), `handleUserAccessRevoked` immediately purges all cached devices, configurations, telemetry, hazards, and SOS events for that user.
3. **Caregiver SOS Lifecycle Enforcement (`TRIGGERED -> ACKNOWLEDGED -> RESOLVED`):**
   - Caregivers may acknowledge `TRIGGERED` SOS events (`ACKNOWLEDGED`) and resolve `ACKNOWLEDGED` SOS events (`RESOLVED`).
   - Direct `TRIGGERED -> RESOLVED` transitions are rejected, and SOS cancellation (`CANCELLED`) is never exposed or permitted to caregivers.
4. **Parent-Scoped STOMP Subscription & Event Filtering:**
   - `ParentModuleController` subscribes exclusively to `/topic/parent/{parentId}/events` (rejecting `/topic/all-parents`, other parents' topics, and user topics) and filters every incoming realtime event against currently authorized `ACTIVE`-linked users and devices.
