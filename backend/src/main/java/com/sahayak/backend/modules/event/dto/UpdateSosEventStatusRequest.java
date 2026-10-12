package com.sahayak.backend.modules.event.dto;

import com.sahayak.backend.modules.event.SosEventStatus;
import jakarta.validation.constraints.NotNull;

/**
 * Request DTO for transitioning an SOS event through its controlled lifecycle
 * (TRIGGERED -> ACKNOWLEDGED -> RESOLVED, or TRIGGERED -> CANCELLED).
 */
public record UpdateSosEventStatusRequest(
        @NotNull(message = "Target SOS status is required")
        SosEventStatus status
) {
}
