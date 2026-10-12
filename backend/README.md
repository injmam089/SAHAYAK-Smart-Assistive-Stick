# SAHAYAK — Backend API (Phase 1A–1E Foundation)

Unified Spring Boot 3.x backend serving both the **User Module** and **Parent Control Module** for the SAHAYAK Smart Assistive Stick platform.

## Technology Stack

- **Language:** Java 17 (compatible with JDK 17+)
- **Framework:** Spring Boot 3.3.4
- **Build Tool:** Apache Maven
- **Security:** Spring Security 6, Spring Security Messaging, Stateless JWT (`JJWT 0.12.6`), BCrypt (cost 12), SHA-256 Hashed Refresh Token Rotation
- **Real-Time Communication:** Spring WebSocket + STOMP (`/ws`, `/app`, `/topic`, `/queue`, `/user`)
- **Persistence:** Spring Data JPA (Hibernate)
- **Database:** PostgreSQL
- **Migrations:** Flyway (`V1__init_foundation.sql`, `V2__init_auth_foundation.sql`, `V3__device_registry_and_parent_user_links.sql`, `V4__hazard_and_sos_event_domain.sql`)
- **Observability:** Spring Boot Actuator

## Environment Variables (No Committed Secrets)

See [`.env.example`](file:///d:/VISHWAKARMA2026/backend/.env.example). Secrets (`SPRING_DATASOURCE_PASSWORD`, `JWT_SECRET`) must be supplied via environment variables:

| Variable | Default Value | Description |
|---|---|---|
| `PORT` | `8080` | HTTP server port |
| `SPRING_DATASOURCE_URL` | `jdbc:postgresql://localhost:5432/sahayak_db` | PostgreSQL JDBC URL |
| `SPRING_DATASOURCE_USERNAME` | `sahayak_user` | Database user |
| `SPRING_DATASOURCE_PASSWORD` | *(Required via Env)* | Database password |
| `JWT_SECRET` | *(Required via Env)* | Base64-encoded 256-bit+ signing key |
| `JWT_ACCESS_EXPIRATION_MS` | `900000` (15m) | Access token TTL in milliseconds |
| `JWT_REFRESH_EXPIRATION_MS` | `604800000` (7d) | Refresh token TTL in milliseconds |

## Building and Running

### Run Automated Test Suite (31 Tests)
```bash
mvn clean test
```

### Package Executable JAR
```bash
mvn package -B
```

## Phase 1A–1E REST Endpoints

| Method | Endpoint | Access | Description |
|---|---|---|---|
| `GET` | `/api/v1/health` | Public | Application & Flyway health check |
| `POST` | `/api/v1/auth/register` | Public | Register `USER` or `PARENT` account (`ADMIN` blocked) |
| `POST` | `/api/v1/auth/login` | Public | Authenticate credentials & issue JWT + Refresh Token |
| `POST` | `/api/v1/auth/refresh` | Public | Rotate refresh token & issue new JWT pair |
| `GET` | `/api/v1/auth/me` | Authenticated | Retrieve current authenticated user profile |
| `GET` | `/api/v1/user/access-check` | `hasRole("USER")` | User Module RBAC boundary verification |
| `GET` | `/api/v1/parent/access-check` | `hasRole("PARENT")` | Parent Control Module RBAC boundary verification |
| `GET` | `/api/v1/admin/access-check` | `hasRole("ADMIN")` | Admin governance RBAC boundary verification |
| `POST` | `/api/v1/devices` | `hasRole("USER")` | Register a SAHAYAK device to authenticated `USER` |
| `GET` | `/api/v1/devices` | `USER` / `PARENT` / `ADMIN` | List owned devices (`USER`) or `ACTIVE`-linked user devices (`PARENT`) |
| `GET` | `/api/v1/devices/{deviceId}` | Owner `USER` or `ACTIVE`-linked `PARENT` | Retrieve device metadata |
| `PATCH` | `/api/v1/devices/{deviceId}/status` | Owner `USER` or `ADMIN` | Update domain device status (`REGISTERED`, `ACTIVE`, `INACTIVE`, `DISABLED`) |
| `GET` | `/api/v1/devices/{deviceId}/configuration` | Owner `USER` or `ACTIVE`-linked `PARENT` | Retrieve device runtime configuration |
| `PUT` | `/api/v1/devices/{deviceId}/configuration` | Owner `USER` or `ADMIN` | Update thresholds & haptic/audio settings (increments `configurationVersion`) |
| `POST` | `/api/v1/parent-links` | `hasRole("PARENT")` | Create `PENDING` caregiver link request to a `USER` |
| `GET` | `/api/v1/parent-links` | `USER` / `PARENT` / `ADMIN` | List caregiver links for authenticated principal |
| `GET` | `/api/v1/parent-links/{linkId}` | Linked `USER` / `PARENT` / `ADMIN` | Retrieve caregiver link details |
| `PATCH` | `/api/v1/parent-links/{linkId}/status` | Target `USER` (`ACTIVE`/`REVOKED`) or `PARENT` (`REVOKED`) | Transition caregiver link status (`PENDING` -> `ACTIVE` -> `REVOKED`) |
| `POST` | `/api/v1/devices/{deviceId}/hazards` | Owner `USER` | Persist a `HazardEvent` & fan out `HAZARD_ALERT` to `ACTIVE` parents |
| `GET` | `/api/v1/devices/{deviceId}/hazards` | Owner `USER` or `ACTIVE`-linked `PARENT` | Retrieve persisted hazard event history for device |
| `POST` | `/api/v1/devices/{deviceId}/sos` | Owner `USER` | Trigger & persist an `SosEvent` (`TRIGGERED`) & fan out `SOS_EVENT` to `ACTIVE` parents |
| `GET` | `/api/v1/devices/{deviceId}/sos-events` | Owner `USER` or `ACTIVE`-linked `PARENT` | Retrieve persisted SOS event history for device |
| `GET` | `/api/v1/sos-events/{sosEventId}` | Owner `USER` or `ACTIVE`-linked `PARENT` | Retrieve single SOS event details |
| `PATCH` | `/api/v1/sos-events/{sosEventId}/status` | Owner `USER` (`CANCELLED`/`ACKNOWLEDGED`/`RESOLVED`) or `ACTIVE`-linked `PARENT` (`ACKNOWLEDGED`/`RESOLVED`) | Controlled SOS lifecycle transition (`TRIGGERED -> ACKNOWLEDGED -> RESOLVED` or `TRIGGERED -> CANCELLED`) |
| `GET` | `/api/v1/realtime/status` | Authenticated | Retrieve STOMP broker metadata & active session count |
| `POST` | `/api/v1/realtime/telemetry/simulate` | `hasRole("USER")` or `hasRole("ADMIN")` | Publish simulated `RealtimeEventEnvelope<TelemetryEventDto>` with `ACTIVE` parent fan-out |
