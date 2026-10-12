package com.sahayak.backend.modules.telemetry.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.util.List;
import java.util.UUID;

/**
 * Response DTO describing the Phase 1C realtime communication gateway status.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record RealtimeStatusResponse(
        boolean brokerEnabled,
        String websocketEndpoint,
        String applicationDestinationPrefix,
        List<String> brokerPrefixes,
        UUID authenticatedUserId,
        String authenticatedRole,
        int userActiveSessionCount,
        int totalActiveSessions,
        String deviceTransportMode
) {
}
