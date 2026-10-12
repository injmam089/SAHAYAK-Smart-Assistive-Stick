# SAHAYAK — PROJECT REQUIREMENTS

## Functional Areas

### Device / Firmware

The system shall:

- initialize the ESP32 and sensors,
- read obstacle distance,
- read ground/step distance,
- classify hazard conditions,
- provide haptic feedback,
- provide audible feedback where configured,
- detect emergency-button activation,
- continue scanning after normal hazard events,
- expose device state to the software layer when communication is available.

### User Module

The User Module should provide:

- registration/login,
- device pairing,
- device connection status,
- battery information,
- current hazard/alert state,
- emergency/SOS control/status,
- notification state,
- user settings,
- device settings where supported.

### Parent Control Module

The Parent module should provide:

- secure parent login,
- user/device linking,
- online/offline status,
- battery status,
- SOS notification,
- relevant hazard/event history,
- device health/status,
- notification controls,
- privacy-aware monitoring.

### Backend

The backend should provide:

- authentication and authorization,
- user and parent roles,
- device management,
- pairing,
- telemetry/event handling,
- SOS handling,
- notification integration,
- history storage,
- API validation,
- error handling,
- audit/logging where appropriate.

### Database

The database should support entities for:

- users,
- parent/caregiver relationships,
- devices,
- device pairing,
- device status,
- hazard events,
- emergency events,
- notifications,
- settings,
- audit information where required.

The exact schema should be finalized during implementation without violating the architecture.

## Security

The system must consider:

- password hashing,
- authentication,
- authorization,
- role separation,
- secure device pairing,
- input validation,
- protected APIs,
- privacy,
- safe handling of SOS information,
- secure secrets/configuration.

## Non-Functional Requirements

The system should be:

- reliable,
- maintainable,
- testable,
- responsive,
- accessible,
- secure,
- fault-tolerant where practical,
- understandable for future team members.

## Safety Scope

SAHAYAK is an assistive information layer. It must not be marketed or implemented as a guaranteed collision-prevention or safety-guarantee system.
