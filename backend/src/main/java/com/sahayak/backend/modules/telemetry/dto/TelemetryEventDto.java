package com.sahayak.backend.modules.telemetry.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.Instant;

/**
 * Foundation Event DTO for device telemetry.
 * In Phase 1C, simulated is explicitly true to distinguish simulated device events
 * from physical ESP32 hardware telemetry.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record TelemetryEventDto(
        String deviceId,
        Instant timestamp,
        String connectionState,
        Integer batteryPercentage,
        Integer forwardDistanceCm,
        Integer groundDistanceCm,
        String hazardLevel,
        boolean simulated
) {
    public TelemetryEventDto {
        if (timestamp == null) {
            timestamp = Instant.now();
        }
    }
}
