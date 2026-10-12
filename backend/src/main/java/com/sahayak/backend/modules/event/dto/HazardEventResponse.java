package com.sahayak.backend.modules.event.dto;

import com.sahayak.backend.common.dto.EventSource;
import com.sahayak.backend.modules.event.HazardEvent;
import com.sahayak.backend.modules.event.HazardLevel;
import com.sahayak.backend.modules.event.HazardType;

import java.time.Instant;
import java.util.UUID;

/**
 * Safe response and realtime payload DTO representing a persisted HazardEvent.
 */
public record HazardEventResponse(
        UUID id,
        UUID deviceId,
        String deviceIdentifier,
        UUID userId,
        HazardType hazardType,
        HazardLevel hazardLevel,
        int distanceCm,
        EventSource source,
        String correlationId,
        Instant eventTimestamp,
        Instant createdAt
) {
    public static HazardEventResponse fromEntity(HazardEvent entity) {
        return new HazardEventResponse(
                entity.getId(),
                entity.getDevice().getId(),
                entity.getDevice().getDeviceIdentifier(),
                entity.getUser().getId(),
                entity.getHazardType(),
                entity.getHazardLevel(),
                entity.getDistanceCm(),
                entity.getSource(),
                entity.getCorrelationId(),
                entity.getEventTimestamp(),
                entity.getCreatedAt()
        );
    }
}
