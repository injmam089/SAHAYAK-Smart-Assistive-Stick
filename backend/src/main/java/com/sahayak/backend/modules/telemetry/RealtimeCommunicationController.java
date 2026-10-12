package com.sahayak.backend.modules.telemetry;

import com.sahayak.backend.common.constants.ApiConstants;
import com.sahayak.backend.common.dto.ApiResponse;
import com.sahayak.backend.common.dto.RealtimeEventEnvelope;
import com.sahayak.backend.modules.telemetry.dto.RealtimeStatusResponse;
import com.sahayak.backend.modules.telemetry.dto.SimulatedTelemetryRequest;
import com.sahayak.backend.modules.telemetry.dto.TelemetryEventDto;
import com.sahayak.backend.security.UserPrincipal;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;

/**
 * Phase 1C REST and STOMP Communication Foundation Controller.
 *
 * Provides:
 * - GET  /api/v1/realtime/status             (Authenticated realtime gateway status)
 * - POST /api/v1/realtime/telemetry/simulate (ROLE_USER simulated telemetry REST dispatch)
 * - STOMP /app/telemetry.simulate            (ROLE_USER simulated telemetry STOMP dispatch)
 */
@RestController
@RequestMapping(ApiConstants.API_V1_PREFIX + "/realtime")
public class RealtimeCommunicationController {

    private final RealtimeEventService realtimeEventService;

    public RealtimeCommunicationController(RealtimeEventService realtimeEventService) {
        this.realtimeEventService = realtimeEventService;
    }

    @GetMapping("/status")
    public ResponseEntity<ApiResponse<RealtimeStatusResponse>> getRealtimeStatus(
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        RealtimeStatusResponse status = realtimeEventService.getRealtimeStatus(principal);
        return ResponseEntity.ok(ApiResponse.ok("Realtime communication gateway status", status));
    }

    @PostMapping("/telemetry/simulate")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<ApiResponse<RealtimeEventEnvelope<TelemetryEventDto>>> simulateTelemetryRest(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody SimulatedTelemetryRequest request
    ) {
        RealtimeEventEnvelope<TelemetryEventDto> envelope =
                realtimeEventService.publishSimulatedTelemetry(principal, request);
        return ResponseEntity.ok(ApiResponse.ok("Simulated telemetry event dispatched", envelope));
    }

    @MessageMapping("/telemetry.simulate")
    public void simulateTelemetryStomp(
            @Valid @Payload SimulatedTelemetryRequest request,
            Principal principal
    ) {
        UserPrincipal userPrincipal = extractPrincipal(principal);
        if (userPrincipal == null || !"USER".equals(userPrincipal.getRole().name())) {
            throw new AccessDeniedException("Only USER role can publish simulated device telemetry");
        }
        realtimeEventService.publishSimulatedTelemetry(userPrincipal, request);
    }

    private UserPrincipal extractPrincipal(Principal principal) {
        if (principal instanceof Authentication auth && auth.getPrincipal() instanceof UserPrincipal up) {
            return up;
        }
        if (principal instanceof UserPrincipal up) {
            return up;
        }
        return null;
    }
}
