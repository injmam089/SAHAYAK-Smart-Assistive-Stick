package com.sahayak.backend.modules.event;

import com.sahayak.backend.common.dto.EventSource;
import com.sahayak.backend.common.exception.ApiException;
import com.sahayak.backend.modules.device.Device;
import com.sahayak.backend.modules.device.DeviceRepository;
import com.sahayak.backend.modules.event.dto.CreateHazardEventRequest;
import com.sahayak.backend.modules.event.dto.HazardEventResponse;
import com.sahayak.backend.modules.link.ParentUserAuthorizationService;
import com.sahayak.backend.modules.telemetry.RealtimeEventService;
import com.sahayak.backend.modules.user.Role;
import com.sahayak.backend.security.UserPrincipal;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Domain service managing persisted HazardEvent creation, ownership validation,
 * caregiver-authorized retrieval, and realtime publication (Phase 1E).
 *
 * Execution Order Invariant:
 * 1. Validate caller ownership of registered device
 * 2. Persist HazardEvent in PostgreSQL
 * 3. Publish RealtimeEventEnvelope<HazardEventResponse> to user + ACTIVE linked parents
 */
@Service
public class HazardEventService {

    private static final Logger log = LoggerFactory.getLogger(HazardEventService.class);

    private final HazardEventRepository hazardEventRepository;
    private final DeviceRepository deviceRepository;
    private final ParentUserAuthorizationService authorizationService;
    private final RealtimeEventService realtimeEventService;

    public HazardEventService(
            HazardEventRepository hazardEventRepository,
            DeviceRepository deviceRepository,
            ParentUserAuthorizationService authorizationService,
            RealtimeEventService realtimeEventService
    ) {
        this.hazardEventRepository = hazardEventRepository;
        this.deviceRepository = deviceRepository;
        this.authorizationService = authorizationService;
        this.realtimeEventService = realtimeEventService;
    }

    @Transactional
    public HazardEventResponse createHazardEvent(
            UserPrincipal principal,
            UUID deviceId,
            CreateHazardEventRequest request
    ) {
        if (principal == null || principal.getRole() != Role.USER) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "Only stick operator accounts (USER) may submit device hazard events"
            );
        }

        Device device = deviceRepository.findById(deviceId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Device not found"));

        if (!device.getOwner().getId().equals(principal.getId())) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "Access denied: you do not own this device"
            );
        }

        // Idempotency check by (deviceId, correlationId)
        if (StringUtils.hasText(request.correlationId())) {
            Optional<HazardEvent> existing = hazardEventRepository.findByDeviceIdAndCorrelationId(
                    deviceId,
                    request.correlationId()
            );
            if (existing.isPresent()) {
                log.debug("Returning existing idempotent HazardEvent for deviceId={}, correlationId={}",
                        deviceId, request.correlationId());
                return HazardEventResponse.fromEntity(existing.get());
            }
        }

        EventSource eventSource = request.source() != null ? request.source() : EventSource.SIMULATED_DEVICE;

        HazardEvent hazardEvent = new HazardEvent(
                UUID.randomUUID(),
                device,
                device.getOwner(),
                request.hazardType(),
                request.hazardLevel(),
                request.distanceCm(),
                eventSource,
                request.correlationId(),
                Instant.now()
        );

        HazardEvent saved = hazardEventRepository.saveAndFlush(hazardEvent);
        HazardEventResponse response = HazardEventResponse.fromEntity(saved);

        log.info("Persisted HazardEvent: id={}, deviceId={}, userId={}, type={}, level={}, distanceCm={}",
                saved.getId(), deviceId, principal.getId(), saved.getHazardType(), saved.getHazardLevel(), saved.getDistanceCm());

        realtimeEventService.publishHazardEvent(response);

        return response;
    }

    @Transactional(readOnly = true)
    public List<HazardEventResponse> getHazardEventsForDevice(UserPrincipal principal, UUID deviceId) {
        Device device = deviceRepository.findById(deviceId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Device not found"));

        authorizationService.assertCanReadDevice(principal, device);

        return hazardEventRepository.findByDeviceIdOrderByEventTimestampDesc(deviceId)
                .stream()
                .map(HazardEventResponse::fromEntity)
                .toList();
    }
}
