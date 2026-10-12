package com.sahayak.backend.modules.event;

import com.sahayak.backend.common.dto.EventSource;
import com.sahayak.backend.common.exception.ApiException;
import com.sahayak.backend.modules.device.Device;
import com.sahayak.backend.modules.device.DeviceRepository;
import com.sahayak.backend.modules.event.dto.SosEventResponse;
import com.sahayak.backend.modules.event.dto.TriggerSosEventRequest;
import com.sahayak.backend.modules.event.dto.UpdateSosEventStatusRequest;
import com.sahayak.backend.modules.link.ParentUserAuthorizationService;
import com.sahayak.backend.modules.telemetry.RealtimeEventService;
import com.sahayak.backend.modules.user.Role;
import com.sahayak.backend.modules.user.User;
import com.sahayak.backend.modules.user.UserRepository;
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
 * Domain service managing SOS emergency event triggering, controlled lifecycle transitions
 * (TRIGGERED -> ACKNOWLEDGED -> RESOLVED, TRIGGERED -> CANCELLED), ownership & caregiver
 * authorization, and realtime publication (Phase 1E).
 *
 * Role & Lifecycle Policy:
 * - TRIGGER: Only owning USER.
 * - ACKNOWLEDGE (TRIGGERED -> ACKNOWLEDGED): ACTIVE-linked PARENT, owning USER, or ADMIN.
 * - RESOLVE (ACKNOWLEDGED -> RESOLVED): ACTIVE-linked PARENT, owning USER, or ADMIN.
 * - CANCEL (TRIGGERED -> CANCELLED): Owning USER or ADMIN only (caregivers cannot cancel an unacknowledged SOS).
 * - Terminal states (RESOLVED, CANCELLED) cannot be reopened or transitioned further.
 */
@Service
public class SosEventService {

    private static final Logger log = LoggerFactory.getLogger(SosEventService.class);

    private final SosEventRepository sosEventRepository;
    private final DeviceRepository deviceRepository;
    private final UserRepository userRepository;
    private final ParentUserAuthorizationService authorizationService;
    private final RealtimeEventService realtimeEventService;

    public SosEventService(
            SosEventRepository sosEventRepository,
            DeviceRepository deviceRepository,
            UserRepository userRepository,
            ParentUserAuthorizationService authorizationService,
            RealtimeEventService realtimeEventService
    ) {
        this.sosEventRepository = sosEventRepository;
        this.deviceRepository = deviceRepository;
        this.userRepository = userRepository;
        this.authorizationService = authorizationService;
        this.realtimeEventService = realtimeEventService;
    }

    @Transactional
    public SosEventResponse triggerSosEvent(
            UserPrincipal principal,
            UUID deviceId,
            TriggerSosEventRequest request
    ) {
        if (principal == null || principal.getRole() != Role.USER) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "Only stick operator accounts (USER) may trigger a device SOS event"
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

        String correlationId = request != null ? request.correlationId() : null;

        // 1. Correlation ID idempotency check
        if (StringUtils.hasText(correlationId)) {
            Optional<SosEvent> existingByCorrelation = sosEventRepository.findByDeviceIdAndCorrelationId(
                    deviceId,
                    correlationId
            );
            if (existingByCorrelation.isPresent()) {
                log.debug("Returning existing idempotent SosEvent for deviceId={}, correlationId={}",
                        deviceId, correlationId);
                return SosEventResponse.fromEntity(existingByCorrelation.get());
            }
        } else {
            // 2. Physical button bounce protection when correlationId is omitted:
            // If an unacknowledged TRIGGERED SOS is already active on this device, return it idempotently
            Optional<SosEvent> existingActiveTriggered = sosEventRepository
                    .findFirstByDeviceIdAndStatusOrderByTriggeredAtDesc(deviceId, SosEventStatus.TRIGGERED);
            if (existingActiveTriggered.isPresent()) {
                log.debug("Returning existing active TRIGGERED SosEvent for deviceId={}", deviceId);
                return SosEventResponse.fromEntity(existingActiveTriggered.get());
            }
        }

        EventSource eventSource = (request != null && request.source() != null)
                ? request.source()
                : EventSource.SIMULATED_DEVICE;

        SosEvent sosEvent = new SosEvent(
                UUID.randomUUID(),
                device,
                device.getOwner(),
                SosEventStatus.TRIGGERED,
                eventSource,
                correlationId,
                Instant.now()
        );

        SosEvent saved = sosEventRepository.saveAndFlush(sosEvent);
        SosEventResponse response = SosEventResponse.fromEntity(saved);

        log.info("Persisted TRIGGERED SosEvent: id={}, deviceId={}, userId={}, source={}",
                saved.getId(), deviceId, principal.getId(), eventSource);

        realtimeEventService.publishSosEvent(response);

        return response;
    }

    @Transactional(readOnly = true)
    public List<SosEventResponse> getSosEventsForDevice(UserPrincipal principal, UUID deviceId) {
        Device device = deviceRepository.findById(deviceId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Device not found"));

        authorizationService.assertCanReadDevice(principal, device);

        return sosEventRepository.findByDeviceIdOrderByTriggeredAtDesc(deviceId)
                .stream()
                .map(SosEventResponse::fromEntity)
                .toList();
    }

    @Transactional(readOnly = true)
    public SosEventResponse getSosEventById(UserPrincipal principal, UUID sosEventId) {
        SosEvent sosEvent = sosEventRepository.findById(sosEventId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "SOS event not found"));

        authorizationService.assertCanReadDevice(principal, sosEvent.getDevice());

        return SosEventResponse.fromEntity(sosEvent);
    }

    @Transactional
    public SosEventResponse updateSosEventStatus(
            UserPrincipal principal,
            UUID sosEventId,
            UpdateSosEventStatusRequest request
    ) {
        if (principal == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Authentication is required");
        }

        SosEvent sosEvent = sosEventRepository.findById(sosEventId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "SOS event not found"));

        // Verify caller is either the owning USER, an ACTIVE-linked PARENT, or ADMIN
        authorizationService.assertCanReadDevice(principal, sosEvent.getDevice());

        SosEventStatus currentStatus = sosEvent.getStatus();
        SosEventStatus targetStatus = request.status();

        // Role-specific action check: CANCELLED is restricted to owning USER or ADMIN
        if (targetStatus == SosEventStatus.CANCELLED) {
            boolean isOwnerUser = principal.getRole() == Role.USER
                    && sosEvent.getUser().getId().equals(principal.getId());
            boolean isAdmin = principal.getRole() == Role.ADMIN;
            if (!isOwnerUser && !isAdmin) {
                throw new ApiException(
                        HttpStatus.FORBIDDEN,
                        "Access denied: only the device owner may cancel a triggered SOS event"
                );
            }
        }

        // Enforce strict state machine transitions
        if (!currentStatus.canTransitionTo(targetStatus)) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "Invalid SOS status transition from " + currentStatus + " to " + targetStatus
            );
        }

        User actor = userRepository.findById(principal.getId())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Authenticated user account not found"));

        Instant now = Instant.now();
        if (targetStatus == SosEventStatus.ACKNOWLEDGED) {
            sosEvent.setAcknowledgedAt(now);
            sosEvent.setAcknowledgedBy(actor);
        } else if (targetStatus == SosEventStatus.RESOLVED || targetStatus == SosEventStatus.CANCELLED) {
            sosEvent.setResolvedAt(now);
            sosEvent.setResolvedBy(actor);
        }

        sosEvent.setStatus(targetStatus);
        SosEvent saved = sosEventRepository.saveAndFlush(sosEvent);
        SosEventResponse response = SosEventResponse.fromEntity(saved);

        log.info("Transitioned SosEvent: id={}, from={} to={}, byUserId={} (role={})",
                saved.getId(), currentStatus, targetStatus, principal.getId(), principal.getRole());

        realtimeEventService.publishSosEvent(response);

        return response;
    }
}
