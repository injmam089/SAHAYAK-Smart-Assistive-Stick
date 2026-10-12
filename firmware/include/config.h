#ifndef SAHAYAK_CONFIG_H
#define SAHAYAK_CONFIG_H

/**
 * SAHAYAK Smart Assistive Stick — Firmware Configuration
 * 
 * IMPORTANT:
 * GPIO pin assignments, sensor mounting offsets, motor current ratings,
 * and voltage conditioning remain UNRESOLVED HARDWARE DECISIONS.
 * 
 * DO NOT invent final pin values. The constants below are marked TBD
 * and must be confirmed with the hardware team during Phase 4 integration.
 */

// ============================================================================
// HARDWARE PIN DEFINITIONS (ALL PENDING PHYSICAL HARDWARE FINALIZATION)
// ============================================================================
#define PIN_TBD -1

// Forward Ultrasonic Sensor (HC-SR04) - TBD
#define PIN_TRIG_FORWARD        PIN_TBD
#define PIN_ECHO_FORWARD        PIN_TBD

// Ground / Drop-off Ultrasonic Sensor (HC-SR04) - TBD
#define PIN_TRIG_GROUND         PIN_TBD
#define PIN_ECHO_GROUND         PIN_TBD

// Haptic Vibration Motors (Dual) - TBD
#define PIN_MOTOR_PRIMARY       PIN_TBD
#define PIN_MOTOR_SECONDARY     PIN_TBD

// Audible Alert & Visual Indicators - TBD
#define PIN_BUZZER              PIN_TBD
#define PIN_STATUS_LED          PIN_TBD

// Emergency Push Button (Active LOW with internal pull-up) - TBD
#define PIN_EMERGENCY_BUTTON    PIN_TBD

// ============================================================================
// DEFAULT HAZARD THRESHOLDS (cm) - Centralized per Decision 005
// ============================================================================
#define DEFAULT_THRESHOLD_NORMAL_CM         150
#define DEFAULT_THRESHOLD_SLOW_WARNING_CM   100
#define DEFAULT_THRESHOLD_FAST_WARNING_CM   50

// Serial Telemetry Baud Rate
#define SERIAL_BAUD_RATE 115200

#endif // SAHAYAK_CONFIG_H
