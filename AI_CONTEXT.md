# SAHAYAK — AI PROJECT CONTEXT

## Project

**SAHAYAK — Smart Assistive Stick**

SAHAYAK is an electronic add-on to a traditional white cane. It provides additional information through obstacle detection, ground-hazard sensing, haptic feedback, audible alerts, and emergency assistance.

SAHAYAK does not replace the conventional cane and does not guarantee safety.

## Product Structure

The software is **one platform/application** containing two logical modules:

### 1. User Module
For the person using the assistive stick.

### 2. Parent Control Module
For a parent/caregiver to monitor and manage the user's device/status.

These modules share the same overall platform and backend architecture.

## Hardware

Current prototype hardware includes:

- ESP32 DevKit V1 / ESP-WROOM-32
- 2 × HC-SR04 ultrasonic sensors
- 2 × vibration motors
- 1 × active buzzer
- emergency push button
- optional LED
- motor switching circuitry
- flyback diodes
- 18650 Li-ion battery
- battery holder
- TP4056 charging/protection module
- ON/OFF switch
- resistors
- breadboard
- Dupont wires

## Hardware Flow

Battery → charging/protection + power switch → ESP32

ESP32:
- reads forward obstacle sensor,
- reads ground/step sensor,
- evaluates hazards,
- controls vibration/audio alerts,
- reads emergency input.

## Haptic Logic

Current prototype requirement:

- >150 cm: normal
- 100–150 cm: slow warning
- 50–100 cm: faster warning
- <50 cm: strong/continuous warning

These thresholds should remain configurable rather than scattered as magic numbers throughout code.

## Software Responsibilities

Software should eventually support:

- authentication,
- user/device pairing,
- device status,
- battery status,
- obstacle/hazard status,
- emergency/SOS workflow,
- parent monitoring,
- notifications,
- event/history data,
- device health,
- settings,
- secure communication.

## Important Unknowns

Do not assume these are finalized:

- exact ESP32 GPIO mapping,
- exact sensor mounting angle,
- final motor driver/current,
- final emergency communication method,
- final battery regulation/power rail,
- final device-to-application communication protocol.

## Quality Goal

This is a team/prototype project, not a throwaway personal demo.

Priorities:

1. correctness,
2. reliability,
3. safety,
4. security,
5. maintainability,
6. accessibility,
7. clean UX,
8. visual polish.
