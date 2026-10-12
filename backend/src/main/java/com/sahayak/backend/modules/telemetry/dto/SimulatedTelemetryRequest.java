package com.sahayak.backend.modules.telemetry.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Request DTO for submitting a simulated device telemetry event in Phase 1C.
 */
public record SimulatedTelemetryRequest(
        @NotBlank(message = "deviceId is required")
        @Size(max = 64, message = "deviceId must not exceed 64 characters")
        String deviceId,

        @NotBlank(message = "connectionState is required")
        @Size(max = 32, message = "connectionState must not exceed 32 characters")
        String connectionState,

        @Min(value = 0, message = "batteryPercentage must be at least 0")
        @Max(value = 100, message = "batteryPercentage must not exceed 100")
        Integer batteryPercentage,

        @Min(value = 0, message = "forwardDistanceCm must be non-negative")
        @Max(value = 1000, message = "forwardDistanceCm must not exceed 1000")
        Integer forwardDistanceCm,

        @Min(value = 0, message = "groundDistanceCm must be non-negative")
        @Max(value = 1000, message = "groundDistanceCm must not exceed 1000")
        Integer groundDistanceCm,

        @Size(max = 32, message = "hazardLevel must not exceed 32 characters")
        String hazardLevel,

        @Size(max = 64, message = "correlationId must not exceed 64 characters")
        String correlationId
) {
    public SimulatedTelemetryRequest {
        if (deviceId != null) {
            deviceId = deviceId.trim();
        }
        if (connectionState != null) {
            connectionState = connectionState.trim();
        }
        if (hazardLevel != null) {
            hazardLevel = hazardLevel.trim();
        }
        if (correlationId != null) {
            correlationId = correlationId.trim();
        }
    }
}
