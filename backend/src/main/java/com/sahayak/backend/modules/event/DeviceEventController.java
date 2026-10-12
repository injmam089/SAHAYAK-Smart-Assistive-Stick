package com.sahayak.backend.modules.event;

import com.sahayak.backend.common.constants.ApiConstants;
import com.sahayak.backend.common.dto.ApiResponse;
import com.sahayak.backend.modules.event.dto.CreateHazardEventRequest;
import com.sahayak.backend.modules.event.dto.HazardEventResponse;
import com.sahayak.backend.modules.event.dto.SosEventResponse;
import com.sahayak.backend.modules.event.dto.TriggerSosEventRequest;
import com.sahayak.backend.modules.event.dto.UpdateSosEventStatusRequest;
import com.sahayak.backend.security.UserPrincipal;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/**
 * Thin REST Controller for SAHAYAK Hazard Events and SOS Emergency Lifecycle (Phase 1E).
 */
@RestController
@RequestMapping(ApiConstants.API_V1_PREFIX)
public class DeviceEventController {

    private final HazardEventService hazardEventService;
    private final SosEventService sosEventService;

    public DeviceEventController(
            HazardEventService hazardEventService,
            SosEventService sosEventService
    ) {
        this.hazardEventService = hazardEventService;
        this.sosEventService = sosEventService;
    }

    @PostMapping("/devices/{deviceId}/hazards")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<ApiResponse<HazardEventResponse>> createHazardEvent(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID deviceId,
            @Valid @RequestBody CreateHazardEventRequest request
    ) {
        HazardEventResponse created = hazardEventService.createHazardEvent(principal, deviceId, request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Hazard event recorded", created));
    }

    @GetMapping("/devices/{deviceId}/hazards")
    @PreAuthorize("hasAnyRole('USER', 'PARENT', 'ADMIN')")
    public ResponseEntity<ApiResponse<List<HazardEventResponse>>> getDeviceHazards(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID deviceId
    ) {
        List<HazardEventResponse> events = hazardEventService.getHazardEventsForDevice(principal, deviceId);
        return ResponseEntity.ok(ApiResponse.ok("Device hazard events retrieved", events));
    }

    @PostMapping("/devices/{deviceId}/sos")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<ApiResponse<SosEventResponse>> triggerSosEvent(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID deviceId,
            @Valid @RequestBody(required = false) TriggerSosEventRequest request
    ) {
        SosEventResponse created = sosEventService.triggerSosEvent(principal, deviceId, request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("SOS emergency event triggered", created));
    }

    @GetMapping("/devices/{deviceId}/sos-events")
    @PreAuthorize("hasAnyRole('USER', 'PARENT', 'ADMIN')")
    public ResponseEntity<ApiResponse<List<SosEventResponse>>> getDeviceSosEvents(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID deviceId
    ) {
        List<SosEventResponse> events = sosEventService.getSosEventsForDevice(principal, deviceId);
        return ResponseEntity.ok(ApiResponse.ok("Device SOS events retrieved", events));
    }

    @GetMapping("/sos-events/{sosEventId}")
    @PreAuthorize("hasAnyRole('USER', 'PARENT', 'ADMIN')")
    public ResponseEntity<ApiResponse<SosEventResponse>> getSosEvent(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID sosEventId
    ) {
        SosEventResponse event = sosEventService.getSosEventById(principal, sosEventId);
        return ResponseEntity.ok(ApiResponse.ok("SOS event retrieved", event));
    }

    @PatchMapping("/sos-events/{sosEventId}/status")
    @PreAuthorize("hasAnyRole('USER', 'PARENT', 'ADMIN')")
    public ResponseEntity<ApiResponse<SosEventResponse>> updateSosEventStatus(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID sosEventId,
            @Valid @RequestBody UpdateSosEventStatusRequest request
    ) {
        SosEventResponse updated = sosEventService.updateSosEventStatus(principal, sosEventId, request);
        return ResponseEntity.ok(ApiResponse.ok("SOS event status updated", updated));
    }
}
