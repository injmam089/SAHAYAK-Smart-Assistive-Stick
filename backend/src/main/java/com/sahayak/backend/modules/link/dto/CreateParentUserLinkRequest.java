package com.sahayak.backend.modules.link.dto;

import jakarta.validation.constraints.NotNull;

import java.util.UUID;

/**
 * Request DTO for a Parent/Caregiver to initiate a PENDING link request to a Stick Operator (USER).
 * The parentUserId is always extracted from the authenticated PARENT principal.
 */
public record CreateParentUserLinkRequest(
        @NotNull(message = "Target userId is required")
        UUID userId
) {
}
