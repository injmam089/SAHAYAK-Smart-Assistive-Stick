package com.sahayak.backend.modules.link.dto;

import com.sahayak.backend.modules.link.ParentLinkStatus;
import jakarta.validation.constraints.NotNull;

/**
 * Request DTO for transitioning the status of an existing ParentUserLink (e.g., PENDING -> ACTIVE or -> REVOKED).
 */
public record UpdateParentUserLinkStatusRequest(
        @NotNull(message = "Target link status is required")
        ParentLinkStatus status
) {
}
