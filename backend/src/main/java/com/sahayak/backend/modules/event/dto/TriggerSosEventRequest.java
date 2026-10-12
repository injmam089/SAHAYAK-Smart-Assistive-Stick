package com.sahayak.backend.modules.event.dto;

import com.sahayak.backend.common.dto.EventSource;
import jakarta.validation.constraints.Size;

/**
 * Request DTO for triggering an SOS emergency event on a registered SAHAYAK device.
 * User identity and device ownership are strictly derived from the authenticated principal.
 */
public record TriggerSosEventRequest(
        EventSource source,

        @Size(max = 100, message = "correlationId must not exceed 100 characters")
        String correlationId
) {
    public TriggerSosEventRequest {
        if (correlationId != null) {
            correlationId = correlationId.trim();
            if (correlationId.isEmpty()) {
                correlationId = null;
            }
        }
    }
}
