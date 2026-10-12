package com.sahayak.backend.common.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.Instant;
import java.util.UUID;

/**
 * Standardized Realtime Event Envelope for STOMP/WebSocket and event pipelines.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record RealtimeEventEnvelope<T>(
        String eventId,
        RealtimeEventType eventType,
        Instant timestamp,
        EventSource source,
        String correlationId,
        T payload
) {
    public RealtimeEventEnvelope {
        if (eventId == null || eventId.isBlank()) {
            eventId = UUID.randomUUID().toString();
        }
        if (timestamp == null) {
            timestamp = Instant.now();
        }
    }

    public static <T> RealtimeEventEnvelope<T> of(
            RealtimeEventType eventType,
            EventSource source,
            String correlationId,
            T payload
    ) {
        return new RealtimeEventEnvelope<>(
                UUID.randomUUID().toString(),
                eventType,
                Instant.now(),
                source,
                correlationId,
                payload
        );
    }

    public static <T> RealtimeEventEnvelope<T> of(
            RealtimeEventType eventType,
            EventSource source,
            T payload
    ) {
        return of(eventType, source, null, payload);
    }
}
