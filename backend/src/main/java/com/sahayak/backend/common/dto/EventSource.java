package com.sahayak.backend.common.dto;

/**
 * Origin source of a realtime event.
 * SIMULATED_DEVICE explicitly designates mock/simulated telemetry in Phase 1C.
 */
public enum EventSource {
    SIMULATED_DEVICE,
    DEVICE,
    MOBILE_CLIENT,
    BACKEND
}
