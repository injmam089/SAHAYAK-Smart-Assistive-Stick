# SAHAYAK — Smart Assistive Stick Platform

Unified software and firmware monorepo for the **SAHAYAK Smart Assistive Stick** ecosystem (**One Platform, Two Logical Modules**: **User Module** for visually impaired cane operators and **Parent Control Module** for caregivers).

## Monorepo Structure

| Directory | Component | Status |
|---|---|---|
| [`backend/`](file:///d:/VISHWAKARMA2026/backend) | Java 17 / Spring Boot 3.3.4 REST + STOMP/WebSocket API, PostgreSQL + Flyway V1–V4 | **`VERIFIED` (31/31 Automated Tests Passing)** |
| [`mobile/`](file:///d:/VISHWAKARMA2026/mobile) | Flutter / Dart 3.x Unified Platform: **Phase 2 User Module** (`UserModuleShell`) + **Phase 3 Parent Control Module** (`ParentControlModuleShell`) + 6 test suites | **`IMPLEMENTED — NOT VERIFIED` (Flutter SDK not installed on host)** |
| [`firmware/`](file:///d:/VISHWAKARMA2026/firmware) | ESP32 Arduino Framework (PlatformIO) Skeleton with isolated `PIN_TBD` hardware boundaries | **`IMPLEMENTED — NOT VERIFIED` (PlatformIO CLI not installed on host)** |

## Project Memory & Governance Files

| File | Purpose |
|---|---|
| [`AI_MASTER_PROMPT.md`](file:///d:/VISHWAKARMA2026/AI_MASTER_PROMPT.md) | Main instructions for the AI agent |
| [`AI_CONTEXT.md`](file:///d:/VISHWAKARMA2026/AI_CONTEXT.md) | Stable project context |
| [`PROJECT_REQUIREMENTS.md`](file:///d:/VISHWAKARMA2026/PROJECT_REQUIREMENTS.md) | Functional and non-functional requirements |
| [`ARCHITECTURE.md`](file:///d:/VISHWAKARMA2026/ARCHITECTURE.md) | System architecture, domain hierarchy, and realtime security boundaries |
| [`DEVELOPMENT_RULES.md`](file:///d:/VISHWAKARMA2026/DEVELOPMENT_RULES.md) | Engineering, security, and verification rules |
| [`CURRENT_STATUS.md`](file:///d:/VISHWAKARMA2026/CURRENT_STATUS.md) | Live project progress and verification classification |
| [`ROADMAP.md`](file:///d:/VISHWAKARMA2026/ROADMAP.md) | Phased development roadmap |
| [`DECISIONS.md`](file:///d:/VISHWAKARMA2026/DECISIONS.md) | Permanent architectural decisions (Decisions 001–016) |
| [`TODO.md`](file:///d:/VISHWAKARMA2026/TODO.md) | Actionable task tracking |
