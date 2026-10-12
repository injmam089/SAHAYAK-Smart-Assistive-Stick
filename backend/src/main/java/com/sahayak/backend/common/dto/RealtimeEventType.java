package com.sahayak.backend.common.dto;

/**
 * Canonical realtime event types supported across the SAHAYAK STOMP/WebSocket layer.
 */
public enum RealtimeEventType {
    CONNECTION_ACK,
    DEVICE_CONNECTION_STATE,
    DEVICE_TELEMETRY,
    HAZARD_ALERT,
    SOS_EVENT,
    SYSTEM_HEARTBEAT
}
