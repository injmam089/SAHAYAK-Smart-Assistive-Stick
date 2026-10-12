package com.sahayak.backend.modules.telemetry;

import com.sahayak.backend.common.constants.ApiConstants;
import com.sahayak.backend.common.dto.EventSource;
import com.sahayak.backend.common.dto.RealtimeEventEnvelope;
import com.sahayak.backend.common.dto.RealtimeEventType;
import com.sahayak.backend.common.exception.ApiException;
import com.sahayak.backend.modules.device.Device;
import com.sahayak.backend.modules.device.DeviceRepository;
import com.sahayak.backend.modules.event.dto.HazardEventResponse;
import com.sahayak.backend.modules.event.dto.SosEventResponse;
import com.sahayak.backend.modules.link.ParentUserAuthorizationService;
import com.sahayak.backend.modules.telemetry.dto.RealtimeStatusResponse;
import com.sahayak.backend.modules.telemetry.dto.SimulatedTelemetryRequest;
import com.sahayak.backend.modules.telemetry.dto.TelemetryEventDto;
import com.sahayak.backend.modules.user.Role;
import com.sahayak.backend.security.UserPrincipal;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Phase 1C, 1D & 1E Realtime Event Routing & Authorized Parent Fan-Out Service.
 *
 * Responsibilities:
 * - Wraps telemetry, hazard, and SOS payloads in the standardized RealtimeEventEnvelope.
 * - Validates device ownership if telemetry references a registered Device.
 * - Dispatches realtime events to the user's own topic (/topic/user/{userId}/events)
 *   and fans out ONLY to parent topics (/topic/parent/{parentId}/events) where an
 *   explicit ACTIVE ParentUserLink exists.
 */
@Service
public class RealtimeEventService {

    private static final Logger log = LoggerFactory.getLogger(RealtimeEventService.class);

    private final SimpMessagingTemplate messagingTemplate;
    private final RealtimeSessionRegistry sessionRegistry;
    private final DeviceRepository deviceRepository;
    private final ParentUserAuthorizationService parentUserAuthorizationService;

    public RealtimeEventService(
            SimpMessagingTemplate messagingTemplate,
            RealtimeSessionRegistry sessionRegistry,
            DeviceRepository deviceRepository,
            ParentUserAuthorizationService parentUserAuthorizationService
    ) {
        this.messagingTemplate = messagingTemplate;
        this.sessionRegistry = sessionRegistry;
        this.deviceRepository = deviceRepository;
        this.parentUserAuthorizationService = parentUserAuthorizationService;
    }

    public RealtimeStatusResponse getRealtimeStatus(UserPrincipal principal) {
        return new RealtimeStatusResponse(
                true,
                ApiConstants.WS_ENDPOINT,
                ApiConstants.WS_APP_PREFIX,
                List.of(ApiConstants.WS_TOPIC_PREFIX, ApiConstants.WS_QUEUE_PREFIX),
                principal.getId(),
                principal.getRole().name(),
                sessionRegistry.getActiveSessionCountForUser(principal.getId()),
                sessionRegistry.getTotalActiveSessions(),
                "SIMULATED"
        );
    }

    /**
     * Resolves the list of authorized parent STOMP topics (/topic/parent/{parentId}/events)
     * for a given stick user based strictly on ACTIVE ParentUserLink records.
     */
    public List<String> resolveAuthorizedParentTopicsForUser(UUID userId) {
        return parentUserAuthorizationService.findAuthorizedParentIdsForUser(userId)
                .stream()
                .map(parentId -> ApiConstants.TOPIC_PARENT_EVENTS_PREFIX + parentId + "/events")
                .toList();
    }

    public RealtimeEventEnvelope<TelemetryEventDto> publishSimulatedTelemetry(
            UserPrincipal principal,
            SimulatedTelemetryRequest request
    ) {
        String normalizedDeviceId = request.deviceId().trim();

        // If the device identifier is registered in the database, verify caller ownership
        Optional<Device> registeredDevice = deviceRepository.findByDeviceIdentifier(normalizedDeviceId);
        if (registeredDevice.isPresent()) {
            UUID ownerId = registeredDevice.get().getOwner().getId();
            if (principal.getRole() != Role.ADMIN && !ownerId.equals(principal.getId())) {
                throw new ApiException(
                        HttpStatus.FORBIDDEN,
                        "Access denied: you cannot publish telemetry for a device owned by another user"
                );
            }
        }

        TelemetryEventDto telemetryPayload = new TelemetryEventDto(
                normalizedDeviceId,
                Instant.now(),
                request.connectionState(),
                request.batteryPercentage(),
                request.forwardDistanceCm(),
                request.groundDistanceCm(),
                request.hazardLevel(),
                true // Explicitly marked as simulated in Phase 1C/1D/1E
        );

        RealtimeEventEnvelope<TelemetryEventDto> envelope = RealtimeEventEnvelope.of(
                RealtimeEventType.DEVICE_TELEMETRY,
                EventSource.SIMULATED_DEVICE,
                request.correlationId(),
                telemetryPayload
        );

        String userTopic = ApiConstants.TOPIC_USER_EVENTS_PREFIX + principal.getId() + "/events";
        String deviceTopic = ApiConstants.TOPIC_DEVICE_PREFIX + normalizedDeviceId + "/telemetry";

        messagingTemplate.convertAndSend(userTopic, envelope);
        messagingTemplate.convertAndSend(deviceTopic, envelope);

        // Authorized Parent Fan-Out: Deliver ONLY to parents with an ACTIVE ParentUserLink to this user.
        List<String> authorizedParentTopics = resolveAuthorizedParentTopicsForUser(principal.getId());
        for (String parentTopic : authorizedParentTopics) {
            messagingTemplate.convertAndSend(parentTopic, envelope);
        }

        log.debug("Dispatched simulated telemetry event: eventId={}, deviceId={}, userTopic={}, fanOutParentCount={}",
                envelope.eventId(), normalizedDeviceId, userTopic, authorizedParentTopics.size());

        return envelope;
    }

    /**
     * Publishes a persisted HazardEvent wrapped in RealtimeEventEnvelope to the owning user's topic
     * and fans out ONLY to parents with an ACTIVE ParentUserLink to the device owner.
     */
    public RealtimeEventEnvelope<HazardEventResponse> publishHazardEvent(HazardEventResponse hazardResponse) {
        RealtimeEventEnvelope<HazardEventResponse> envelope = new RealtimeEventEnvelope<>(
                hazardResponse.id().toString(),
                RealtimeEventType.HAZARD_ALERT,
                hazardResponse.eventTimestamp(),
                hazardResponse.source(),
                hazardResponse.correlationId(),
                hazardResponse
        );

        String userTopic = ApiConstants.TOPIC_USER_EVENTS_PREFIX + hazardResponse.userId() + "/events";
        messagingTemplate.convertAndSend(userTopic, envelope);

        List<String> authorizedParentTopics = resolveAuthorizedParentTopicsForUser(hazardResponse.userId());
        for (String parentTopic : authorizedParentTopics) {
            messagingTemplate.convertAndSend(parentTopic, envelope);
        }

        log.debug("Dispatched HAZARD_ALERT realtime event: hazardId={}, deviceId={}, fanOutParentCount={}",
                hazardResponse.id(), hazardResponse.deviceId(), authorizedParentTopics.size());

        return envelope;
    }

    /**
     * Publishes a persisted SosEvent (trigger or lifecycle transition) wrapped in RealtimeEventEnvelope
     * to the owning user's topic and fans out ONLY to parents with an ACTIVE ParentUserLink.
     */
    public RealtimeEventEnvelope<SosEventResponse> publishSosEvent(SosEventResponse sosResponse) {
        RealtimeEventEnvelope<SosEventResponse> envelope = new RealtimeEventEnvelope<>(
                sosResponse.id().toString(),
                RealtimeEventType.SOS_EVENT,
                sosResponse.updatedAt() != null ? sosResponse.updatedAt() : sosResponse.triggeredAt(),
                sosResponse.source(),
                sosResponse.correlationId(),
                sosResponse
        );

        String userTopic = ApiConstants.TOPIC_USER_EVENTS_PREFIX + sosResponse.userId() + "/events";
        messagingTemplate.convertAndSend(userTopic, envelope);

        List<String> authorizedParentTopics = resolveAuthorizedParentTopicsForUser(sosResponse.userId());
        for (String parentTopic : authorizedParentTopics) {
            messagingTemplate.convertAndSend(parentTopic, envelope);
        }

        log.debug("Dispatched SOS_EVENT realtime event: sosId={}, status={}, deviceId={}, fanOutParentCount={}",
                sosResponse.id(), sosResponse.status(), sosResponse.deviceId(), authorizedParentTopics.size());

        return envelope;
    }
}
