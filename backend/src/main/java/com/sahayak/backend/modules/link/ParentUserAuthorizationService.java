package com.sahayak.backend.modules.link;

import com.sahayak.backend.common.exception.ApiException;
import com.sahayak.backend.modules.device.Device;
import com.sahayak.backend.modules.user.AccountStatus;
import com.sahayak.backend.modules.user.Role;
import com.sahayak.backend.security.UserPrincipal;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * Centralized Caregiver (Parent) & Device Ownership Authorization Policy (Phase 1D).
 *
 * Security Invariant:
 * - A USER may access and modify only devices they own.
 * - A PARENT may read a User's devices, device configurations, and realtime events
 *   ONLY when an explicit ACTIVE ParentUserLink exists between the Parent and the User.
 * - Knowing a User UUID or Device UUID alone NEVER grants access.
 */
@Service
public class ParentUserAuthorizationService {

    private final ParentUserLinkRepository parentUserLinkRepository;

    public ParentUserAuthorizationService(ParentUserLinkRepository parentUserLinkRepository) {
        this.parentUserLinkRepository = parentUserLinkRepository;
    }

    /**
     * Returns true ONLY when an explicit ACTIVE relationship exists between parentId and userId.
     */
    @Transactional(readOnly = true)
    public boolean isParentLinkedToUser(UUID parentId, UUID userId) {
        if (parentId == null || userId == null) {
            return false;
        }
        return parentUserLinkRepository.existsByParentIdAndUserIdAndStatus(
                parentId,
                userId,
                ParentLinkStatus.ACTIVE
        );
    }

    /**
     * Returns the UUIDs of all active Parent accounts that have an ACTIVE caregiver link to the given userId.
     * Used by the realtime event router to fan out authorized telemetry/hazard/SOS events to linked parents.
     */
    @Transactional(readOnly = true)
    public List<UUID> findAuthorizedParentIdsForUser(UUID userId) {
        if (userId == null) {
            return List.of();
        }
        return parentUserLinkRepository
                .findByUserIdAndStatusOrderByCreatedAtDesc(userId, ParentLinkStatus.ACTIVE)
                .stream()
                .map(ParentUserLink::getParent)
                .filter(parent -> parent.getStatus() == AccountStatus.ACTIVE && parent.getRole() == Role.PARENT)
                .map( com.sahayak.backend.modules.user.User::getId)
                .distinct()
                .toList();
    }

    /**
     * Returns the UUIDs of all active User accounts to which the given parentId has an ACTIVE caregiver link.
     */
    @Transactional(readOnly = true)
    public List<UUID> findAuthorizedUserIdsForParent(UUID parentId) {
        if (parentId == null) {
            return List.of();
        }
        return parentUserLinkRepository
                .findByParentIdAndStatusOrderByCreatedAtDesc(parentId, ParentLinkStatus.ACTIVE)
                .stream()
                .map(ParentUserLink::getUser)
                .filter(user -> user.getStatus() == AccountStatus.ACTIVE && user.getRole() == Role.USER)
                .map(com.sahayak.backend.modules.user.User::getId)
                .distinct()
                .toList();
    }

    /**
     * Verifies whether the authenticated principal is authorized to read the specified Device
     * or its DeviceConfiguration.
     */
    @Transactional(readOnly = true)
    public void assertCanReadDevice(UserPrincipal principal, Device device) {
        if (principal == null || device == null) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Access is denied");
        }

        UUID ownerUserId = device.getOwner().getId();

        if (principal.getRole() == Role.USER) {
            if (!principal.getId().equals(ownerUserId)) {
                throw new ApiException(HttpStatus.FORBIDDEN, "Access denied: you do not own this device");
            }
            return;
        }

        if (principal.getRole() == Role.PARENT) {
            if (!isParentLinkedToUser(principal.getId(), ownerUserId)) {
                throw new ApiException(
                        HttpStatus.FORBIDDEN,
                        "Access denied: no active caregiver relationship exists for the owner of this device"
                );
            }
            return;
        }

        if (principal.getRole() == Role.ADMIN) {
            return;
        }

        throw new ApiException(HttpStatus.FORBIDDEN, "Access is denied");
    }

    /**
     * Verifies whether the authenticated principal is authorized to modify a Device's status or configuration.
     * In Phase 1D, device ownership and configuration modification belong to the owning USER (and ADMIN governance).
     * Parents have read-only access to linked devices.
     */
    @Transactional(readOnly = true)
    public void assertCanModifyDevice(UserPrincipal principal, Device device) {
        if (principal == null || device == null) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Access is denied");
        }

        UUID ownerUserId = device.getOwner().getId();

        if (principal.getRole() == Role.USER) {
            if (!principal.getId().equals(ownerUserId)) {
                throw new ApiException(HttpStatus.FORBIDDEN, "Access denied: you do not own this device");
            }
            return;
        }

        if (principal.getRole() == Role.ADMIN) {
            return;
        }

        throw new ApiException(
                HttpStatus.FORBIDDEN,
                "Access denied: only the device owner may modify device status or configuration"
        );
    }
}
