package com.sahayak.backend.modules.device;

/**
 * Domain lifecycle status of a registered SAHAYAK assistive stick device.
 * Distinct from real-time transport connection state (CONNECTED / DISCONNECTED).
 */
public enum DeviceStatus {
    REGISTERED,
    ACTIVE,
    INACTIVE,
    DISABLED
}
