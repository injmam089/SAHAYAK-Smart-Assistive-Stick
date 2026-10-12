package com.sahayak.backend.modules.event.dto;

import com.sahayak.backend.common.dto.EventSource;
import com.sahayak.backend.modules.event.SosEvent;
import com.sahayak.backend.modules.event.SosEventStatus;

import java.time.Instant;
import java.util.UUID;

/**
 * Safe response and realtime payload DTO representing a persisted SosEvent and its lifecycle timestamps.
 */
public record SosEventResponse(
        UUID id,
        UUID deviceId,
        String deviceIdentifier,
        UUID userId,
        String userFullName,
        SosEventStatus status,
        EventSource source,
        String correlationId,
        Instant triggeredAt,
        Instant acknowledgedAt,
        UUID acknowledgedByUserId,
        Instant resolvedAt,
        UUID resolvedByUserId,
        Instant createdAt,
        Instant updatedAt
) {
    public static SosEventResponse fromEntity(SosEvent entity) {
        return new SosEventResponse(
                entity.getId(),
                entity.getDevice().getId(),
                entity.getDevice().getDeviceIdentifier(),
                entity.getUser().getId(),
                entity.getUser().getFullName(),
                entity.getStatus(),
                entity.getSource(),
                entity.getCorrelationId(),
                entity.getTriggeredAt(),
                entity.getAcknowledgedAt(),
                entity.getAcknowledgedBy() != null ? entity.getAcknowledgedBy().getId() : null,
                entity.getResolvedAt(),
                entity.getResolvedBy() != null ? entity.getResolvedBy().getId() : null,
                entity.getCreatedAt(),
                entity.getUpdatedAt()
        );
    }
}
