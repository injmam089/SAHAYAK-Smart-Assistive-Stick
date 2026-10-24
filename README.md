# 🦯 SAHAYAK — Smart Assistive Stick

### Smart Assistive Technology for Safer, More Connected Mobility

<p align="center">
  <strong>Assistive Hardware • Mobile Application • Secure Backend • Real-Time Safety Monitoring</strong>
</p>

<p align="center">
  <a href="https://github.com/injmam089/SAHAYAK-Smart-Assistive-Stick">
    <img src="https://img.shields.io/badge/GitHub-Repository-181717?style=for-the-badge&logo=github" alt="GitHub">
  </a>
  <img src="https://img.shields.io/badge/ESP32-Firmware-E7352C?style=for-the-badge&logo=espressif" alt="ESP32">
  <img src="https://img.shields.io/badge/Flutter-Mobile-02569B?style=for-the-badge&logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Spring%20Boot-Backend-6DB33F?style=for-the-badge&logo=springboot" alt="Spring Boot">
  <img src="https://img.shields.io/badge/PostgreSQL-Database-4169E1?style=for-the-badge&logo=postgresql" alt="PostgreSQL">
</p>

---

## 📌 Overview

**SAHAYAK** is a smart assistive-stick platform designed to support visually impaired users through **hazard detection, haptic feedback, emergency assistance, device monitoring, and caregiver connectivity**.

The platform combines an **ESP32-based assistive device**, a **Flutter mobile application**, and a **secure Spring Boot backend** into one integrated ecosystem.

SAHAYAK follows a **One Platform, Two Modules** approach:

- 👤 **User Module** — designed for the person using the assistive stick.
- 👨‍👩‍👦 **Parent Control Module** — designed for authorized caregivers to monitor safety-related information.

The system is designed as an **assistive information and monitoring layer**, not as a guaranteed collision-prevention or safety-guarantee system.

---

## 🎯 Problem

Traditional walking sticks provide physical support but offer limited digital assistance.

Users may still face challenges such as:

- Detecting obstacles in the walking path
- Identifying ground-level hazards
- Receiving immediate emergency assistance
- Monitoring device status and battery information
- Keeping trusted caregivers informed during safety events

SAHAYAK aims to extend the traditional assistive stick with **embedded sensing, mobile connectivity, realtime communication, and secure caregiver controls**.

---

## 💡 Our Solution

SAHAYAK connects three major layers:

```text
                    🦯 SAHAYAK PLATFORM
                           │
          ┌────────────────┴────────────────┐
          │                                 │
     👤 USER MODULE                  👨‍👩‍👦 PARENT MODULE
          │                                 │
          └────────────────┬────────────────┘
                           │
                    📱 FLUTTER APP
                           │
                    🔗 Device Layer
                           │
                    📡 ESP32 Stick
                           │
             ┌─────────────┴─────────────┐
             │                           │
      🛡️ Hazard Detection          🚨 SOS Events
             │                           │
             └─────────────┬─────────────┘
                           │
                  ☁️ SPRING BOOT API
                           │
              ┌────────────┴────────────┐
              │                         │
        🗄️ PostgreSQL             🔄 WebSocket
```

---

# ✨ Key Features

## 🦯 Smart Assistive Stick

- Forward obstacle detection
- Ground / step hazard detection
- Dual vibration feedback
- Audible alerts where configured
- Emergency / SOS button
- ESP32-based embedded controller
- Device-state communication
- Expandable hardware architecture

## 📱 User Module

- User registration and login
- Secure authentication
- Device management
- Device connection status
- Battery information
- Live hazard state
- Safety events
- SOS control and status
- User settings
- Device settings where supported

## 👨‍👩‍👦 Parent Control Module

Authorized caregivers can:

- Create caregiver-user links
- View linked device information
- Monitor online/offline status
- View battery status
- Receive safety-related events
- Monitor SOS events
- Review relevant hazard history
- View device health/status
- Manage notification preferences

Access is controlled through explicit **ACTIVE caregiver-user relationships**.

---

# 🏗️ System Architecture

SAHAYAK uses a layered architecture consisting of:

```text
┌──────────────────────────────────────────────┐
│                 USER DEVICES                 │
│                                              │
│  🦯 Smart Stick       📱 Flutter Application │
└───────────────────────┬──────────────────────┘
                        │
                        │ REST / WebSocket / BLE*
                        │
┌───────────────────────▼──────────────────────┐
│              SPRING BOOT BACKEND             │
│                                              │
│  Authentication & Authorization              │
│  Device Management                           │
│  Hazard Events                               │
│  SOS Management                              │
│  Parent-User Authorization                   │
│  Realtime Event Processing                   │
└───────────────────────┬──────────────────────┘
                        │
                ┌───────┴───────┐
                │               │
        ┌───────▼──────┐ ┌──────▼────────┐
        │ PostgreSQL   │ │ STOMP/WebSocket│
        │ + Flyway     │ │ Realtime Events│
        └──────────────┘ └───────────────┘
```

> **\*** BLE hardware communication is part of the planned device-communication architecture; the current software layer also supports simulated device communication for development.

---

# 🧩 Project Structure

```text
SAHAYAK-Smart-Assistive-Stick/
│
├── backend/
│   └── Spring Boot REST + STOMP Backend
│
├── mobile/
│   └── Flutter / Dart Mobile Application
│
├── firmware/
│   └── ESP32 Arduino / PlatformIO Firmware
│
├── ARCHITECTURE.md
├── PROJECT_REQUIREMENTS.md
├── DEVELOPMENT_RULES.md
├── CURRENT_STATUS.md
├── ROADMAP.md
├── DECISIONS.md
├── TODO.md
├── AI_CONTEXT.md
├── AI_MASTER_PROMPT.md
├── docker-compose.yml
├── .gitignore
└── README.md
```

---

# 🛠️ Technology Stack

| Layer | Technology |
|---|---|
| Embedded Controller | ESP32 |
| Firmware | Arduino Framework / C++ |
| Sensors | HC-SR04 Ultrasonic Sensors |
| Mobile App | Flutter / Dart |
| Backend | Java 17 / Spring Boot 3.x |
| API | REST / JSON |
| Realtime | STOMP / WebSocket |
| Database | PostgreSQL |
| Database Migration | Flyway |
| Authentication | JWT |
| Password Security | BCrypt |
| Containerization | Docker / Docker Compose |
| Communication | REST / WebSocket / BLE* |

---

# 🔐 Security Architecture

Security is a core part of SAHAYAK because the platform handles **device information, caregiver relationships, hazard events, and SOS data**.

### Authentication

- JWT-based authentication
- Secure password hashing using BCrypt
- Refresh-token rotation
- Role-based access control

### Roles

```text
ROLE_USER
ROLE_PARENT
ROLE_ADMIN
```

### Caregiver Authorization

A caregiver does not automatically gain access to a user's data.

The relationship follows:

```text
PENDING
   │
   │ User Approval
   ▼
ACTIVE
   │
   │ Revoke
   ▼
REVOKED
```

Only an **ACTIVE** relationship allows access to protected user/device information.

### Realtime Security

STOMP/WebSocket communication uses:

- Authenticated connections
- User-scoped topics
- Parent-scoped topics
- Destination authorization
- Authorized-user filtering

---

# 🚨 Safety & Event Management

SAHAYAK separates different types of device and safety information.

### Device Status

```text
REGISTERED
ACTIVE
INACTIVE
DISABLED
```

### Live Connection State

```text
CONNECTED
DISCONNECTED
CONNECTING
ERROR
UNKNOWN
```

### SOS Lifecycle

For users:

```text
TRIGGERED
   │
   ├── CANCELLED
   │
   └── RESOLVED
```

For caregiver handling:

```text
TRIGGERED
    │
    ▼
ACKNOWLEDGED
    │
    ▼
RESOLVED
```

This separation prevents device state, network state, and safety-event state from being incorrectly treated as the same thing.

---

# 📡 Device & Communication Architecture

The mobile application uses an abstraction-based device communication layer.

```text
DeviceCommunication
        │
        ├── SimulatedDeviceCommunication
        │
        └── BleDeviceCommunication
                    │
                    ▼
             ESP32 Smart Stick
```

This allows software development and testing to continue even when physical hardware is unavailable.

The architecture is intentionally designed so that exact hardware decisions such as GPIO assignments, motor drivers, voltage regulation, and sensor mounting can be finalized independently.

---

# 🗄️ Database

SAHAYAK uses **PostgreSQL** with **Flyway** for incremental schema management.

Current migration areas include:

- User authentication
- Refresh tokens
- Device registry
- Device configuration
- Parent-user relationships
- Hazard events
- SOS events
- Database constraints and indexes

This approach keeps database changes version-controlled and reproducible.

---

# 🧪 Development & Verification

The project uses explicit verification states rather than claiming that every module is production-ready.

### Backend

**Verified**

- Spring Boot backend implemented
- PostgreSQL integration
- Flyway migrations
- REST APIs
- STOMP/WebSocket infrastructure
- Automated backend tests

### Mobile

**Implemented — Verification dependent on Flutter SDK availability**

- User Module
- Parent Control Module
- Authentication flow
- Device abstraction
- Safety/event interfaces

### Firmware

**Implemented — Hardware verification pending**

- ESP32 firmware foundation
- Sensor boundaries
- Hazard-processing architecture
- Feedback interfaces
- Emergency-button boundary

---

# 🚀 Getting Started

## Prerequisites

Install:

- Java 17+
- Flutter SDK
- Dart SDK
- PostgreSQL
- Docker & Docker Compose
- PlatformIO / Arduino-compatible ESP32 environment

---

## 1. Clone the Repository

```bash
git clone https://github.com/injmam089/SAHAYAK-Smart-Assistive-Stick.git

cd SAHAYAK-Smart-Assistive-Stick
```

---

## 2. Backend

Navigate to:

```bash
cd backend
```

Configure the required database/environment variables and start the Spring Boot application.

Example:

```bash
./mvnw spring-boot:run
```

Windows:

```bash
mvnw.cmd spring-boot:run
```

---

## 3. Mobile Application

Navigate to:

```bash
cd mobile
```

Install dependencies:

```bash
flutter pub get
```

Run:

```bash
flutter run
```

---

## 4. Firmware

Navigate to:

```bash
cd firmware
```

Open the project using **PlatformIO** or the configured ESP32 development environment.

> Physical GPIO mappings and hardware-specific parameters should be configured according to the actual prototype hardware.

---

# 🗺️ Development Roadmap

```text
Phase 1 ─ Foundation & Backend
          │
          ▼
Phase 2 ─ User Module
          │
          ▼
Phase 3 ─ Parent Control Module
          │
          ▼
Phase 4 ─ Physical BLE Device Integration
          │
          ▼
Phase 5 ─ Hardware Validation
          │
          ▼
Phase 6 ─ End-to-End Safety Testing
          │
          ▼
Future ── Production Hardening & Deployment
```

The repository maintains the detailed roadmap and implementation status separately in `ROADMAP.md` and `CURRENT_STATUS.md`.

---

# 📚 Project Documentation

| Document | Purpose |
|---|---|
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | System architecture and security boundaries |
| [`PROJECT_REQUIREMENTS.md`](./PROJECT_REQUIREMENTS.md) | Functional & non-functional requirements |
| [`CURRENT_STATUS.md`](./CURRENT_STATUS.md) | Current implementation and verification status |
| [`ROADMAP.md`](./ROADMAP.md) | Development roadmap |
| [`DEVELOPMENT_RULES.md`](./DEVELOPMENT_RULES.md) | Engineering and security rules |
| [`DECISIONS.md`](./DECISIONS.md) | Permanent architectural decisions |
| [`TODO.md`](./TODO.md) | Active development tasks |
| [`AI_CONTEXT.md`](./AI_CONTEXT.md) | Stable project context |
| [`AI_MASTER_PROMPT.md`](./AI_MASTER_PROMPT.md) | AI-assisted development instructions |

---

# 🎯 Project Goals

SAHAYAK aims to provide a platform that is:

- ♿ Accessibility-focused
- 🛡️ Security-conscious
- 📡 Realtime-capable
- 🔧 Hardware-aware
- 📱 Mobile-first
- 🧩 Modular
- 🧪 Testable
- 🔒 Privacy-aware
- 📈 Extensible

The long-term goal is to create a reliable software and hardware ecosystem around assistive mobility rather than simply adding sensors to a traditional walking stick.

---

# ⚠️ Safety Disclaimer

SAHAYAK is an **assistive technology prototype**.

It should not be considered a guaranteed collision-prevention, navigation, medical, or life-safety system.

Sensor readings can be affected by environmental conditions, hardware limitations, installation quality, battery state, communication failures, and other factors.

Users should continue to follow appropriate mobility and safety practices.

---

# 🤝 Contributing

Contributions, suggestions, testing feedback, and improvements are welcome.

Before contributing:

1. Review `DEVELOPMENT_RULES.md`
2. Review `ARCHITECTURE.md`
3. Check `CURRENT_STATUS.md`
4. Review the active tasks in `TODO.md`
5. Keep security and accessibility requirements in mind

---

# 👨‍💻 Project

**SAHAYAK — Smart Assistive Stick**

Developed as a technology project focused on **assistive mobility, accessibility, embedded systems, mobile computing, and secure realtime software architecture**.

<p align="center">
  <strong>🦯 Technology with a Purpose.</strong>
</p>

<p align="center">
  <sub>Built to assist. Designed to connect. Engineered with safety in mind.</sub>
</p>
