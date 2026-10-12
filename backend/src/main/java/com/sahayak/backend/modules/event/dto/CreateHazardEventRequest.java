package com.sahayak.backend.modules.event.dto;

import com.sahayak.backend.common.dto.EventSource;
import com.sahayak.backend.modules.event.HazardLevel;
import com.sahayak.backend.modules.event.HazardType;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Request DTO for recording a meaningful safety hazard event on a registered SAHAYAK device.
 * Device ownership and user identity are strictly verified from the authenticated principal.
 */
public record CreateHazardEventRequest(

        @NotNull(message = "hazardType is required")
        HazardType hazardType,

        @NotNull(message = "hazardLevel is required")
        HazardLevel hazardLevel,

        @NotNull(message = "distanceCm is required")
        @Min(value = 0, message = "distanceCm must be non-negative")
        @Max(value = 1000, message = "distanceCm must not exceed 1000 cm")
        Integer distanceCm,

        EventSource source,

        @Size(max = 100, message = "correlationId must not exceed 100 characters")
        String correlationId
) {
    public CreateHazardEventRequest {
        if (correlationId != null) {
            correlationId = correlationId.trim();
            if (correlationId.isEmpty()) {
                correlationId = null;
            }
        }
    }
}
