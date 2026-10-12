# SAHAYAK — ESP32 Firmware Foundation Skeleton

Embedded C++ firmware project for the **ESP32 DevKit V1 / ESP-WROOM-32** smart assistive stick add-on, built using the **Arduino framework** via **PlatformIO** (Decision 008).

## Current Status (Phase 1A)

This directory contains the foundational firmware project skeleton (`platformio.ini`, `include/`, `src/`).

## Hardware Boundaries (TBD — Pending Finalization)

Per `DEVELOPMENT_RULES.md` and `DECISIONS.md` (Decision 010), the following physical hardware parameters are not invented in software and remain marked as `PIN_TBD` in `include/config.h`:

1. Exact ESP32 GPIO pin assignments (Ultrasonic Trig/Echo, Motors, Buzzer, Emergency Button, LED).
2. Exact physical sensor mounting angles (forward and downward sensors).
3. Final motor driver IC and current regulation circuitry.
4. Final battery voltage regulation (3.7V Li-ion to 5V HC-SR04 / 3.3V ESP32 logic).
5. Final HC-SR04 echo pin 5V-to-3.3V voltage divider / level-shifting circuit.

## Building (PlatformIO)

When PlatformIO CLI is available:

```bash
pio run
```
