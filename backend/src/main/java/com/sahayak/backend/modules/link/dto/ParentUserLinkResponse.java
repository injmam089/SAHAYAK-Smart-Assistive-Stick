package com.sahayak.backend.modules.link.dto;

import com.sahayak.backend.modules.link.ParentLinkStatus;
import com.sahayak.backend.modules.link.ParentUserLink;

import java.time.Instant;
import java.util.UUID;

/**
 * Safe response DTO representing a Parent-User relationship record without exposing sensitive User fields.
 */
public record ParentUserLinkResponse(
        UUID id,
        UUID parentUserId,
        String parentFullName,
        String parentEmail,
        UUID userId,
        String userFullName,
        String userEmail,
        ParentLinkStatus status,
        Instant createdAt,
        Instant updatedAt
) {
    public static ParentUserLinkResponse fromEntity(ParentUserLink link) {
        return new ParentUserLinkResponse(
                link.getId(),
                link.getParent().getId(),
                link.getParent().getFullName(),
                link.getParent().getEmail(),
                link.getUser().getId(),
                link.getUser().getFullName(),
                link.getUser().getEmail(),
                link.getStatus(),
                link.getCreatedAt(),
                link.getUpdatedAt()
        );
    }
}
