package com.sahayak.backend.security;

import com.sahayak.backend.common.constants.ApiConstants;
import com.sahayak.backend.modules.device.Device;
import com.sahayak.backend.modules.device.DeviceRepository;
import com.sahayak.backend.modules.link.ParentUserAuthorizationService;
import com.sahayak.backend.modules.user.Role;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

import java.util.Optional;
import java.util.UUID;

/**
 * Enforces explicit STOMP topic and application destination authorization boundaries (Phase 1C & 1D).
 *
 * Prevents unauthenticated or unauthorized cross-role/cross-user STOMP subscriptions
 * and message publications (Deny-by-Default).
 */
@Component
public class StompDestinationAuthorizer {

    private final DeviceRepository deviceRepository;
    private final ParentUserAuthorizationService parentUserAuthorizationService;

    public StompDestinationAuthorizer(
            DeviceRepository deviceRepository,
            ParentUserAuthorizationService parentUserAuthorizationService
    ) {
        this.deviceRepository = deviceRepository;
        this.parentUserAuthorizationService = parentUserAuthorizationService;
    }

    public boolean canSubscribe(UserPrincipal principal, String destination) {
        if (principal == null || !StringUtils.hasText(destination)) {
            return false;
        }

        // 1. User-specific topic: /topic/user/{userId}/...
        if (destination.startsWith(ApiConstants.TOPIC_USER_EVENTS_PREFIX)) {
            if (principal.getRole() != Role.USER) {
                return false;
            }
            String targetUserId = extractSegmentAfterPrefix(destination, ApiConstants.TOPIC_USER_EVENTS_PREFIX);
            return principal.getId().toString().equalsIgnoreCase(targetUserId);
        }

        // 2. Parent-specific topic: /topic/parent/{parentId}/...
        if (destination.startsWith(ApiConstants.TOPIC_PARENT_EVENTS_PREFIX)) {
            if (principal.getRole() != Role.PARENT) {
                return false;
            }
            String targetParentId = extractSegmentAfterPrefix(destination, ApiConstants.TOPIC_PARENT_EVENTS_PREFIX);
            return principal.getId().toString().equalsIgnoreCase(targetParentId);
        }

        // 3. Admin governance topic: /topic/admin/...
        if (destination.startsWith(ApiConstants.TOPIC_ADMIN_PREFIX)) {
            return principal.getRole() == Role.ADMIN;
        }

        // 4. Device telemetry topic: /topic/device/{deviceId}/telemetry
        if (destination.startsWith(ApiConstants.TOPIC_DEVICE_PREFIX)) {
            String deviceKey = extractSegmentAfterPrefix(destination, ApiConstants.TOPIC_DEVICE_PREFIX);
            if (!StringUtils.hasText(deviceKey)) {
                return false;
            }

            Optional<Device> registeredDevice = findRegisteredDevice(deviceKey);
            if (registeredDevice.isPresent()) {
                UUID ownerUserId = registeredDevice.get().getOwner().getId();
                if (principal.getRole() == Role.USER) {
                    return principal.getId().equals(ownerUserId);
                }
                if (principal.getRole() == Role.PARENT) {
                    return parentUserAuthorizationService.isParentLinkedToUser(principal.getId(), ownerUserId);
                }
                return principal.getRole() == Role.ADMIN;
            }

            return principal.getRole() == Role.USER || principal.getRole() == Role.PARENT;
        }

        // 5. System status topic or authenticated user queue
        if (ApiConstants.TOPIC_SYSTEM_STATUS.equals(destination)
                || destination.startsWith("/user/queue/")) {
            return true;
        }

        // Deny any arbitrary or unknown topic by default
        return false;
    }

    public boolean canSend(UserPrincipal principal, String destination) {
        if (principal == null || !StringUtils.hasText(destination)) {
            return false;
        }

        // Simulated telemetry / device events can only be published by a stick operator (ROLE_USER)
        if ("/app/telemetry.simulate".equals(destination) || destination.startsWith("/app/device/")) {
            return principal.getRole() == Role.USER;
        }

        // Connection heartbeat / ping allowed for any authenticated user
        if ("/app/ping".equals(destination)) {
            return true;
        }

        return false;
    }

    private Optional<Device> findRegisteredDevice(String deviceKey) {
        Optional<Device> byIdentifier = deviceRepository.findByDeviceIdentifier(deviceKey);
        if (byIdentifier.isPresent()) {
            return byIdentifier;
        }
        try {
            UUID deviceUuid = UUID.fromString(deviceKey);
            return deviceRepository.findById(deviceUuid);
        } catch (IllegalArgumentException ignored) {
            return Optional.empty();
        }
    }

    private String extractSegmentAfterPrefix(String destination, String prefix) {
        String remainder = destination.substring(prefix.length());
        int slashIdx = remainder.indexOf('/');
        if (slashIdx == -1) {
            return remainder;
        }
        return remainder.substring(0, slashIdx);
    }
}
