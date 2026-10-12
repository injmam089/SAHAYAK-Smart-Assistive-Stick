package com.sahayak.backend.modules.event;

import com.sahayak.backend.common.dto.EventSource;
import com.sahayak.backend.modules.device.Device;
import com.sahayak.backend.modules.user.User;
import jakarta.persistence.*;

import java.time.Instant;
import java.util.UUID;

/**
 * JPA Entity representing a persisted meaningful safety hazard event emitted by a registered SAHAYAK device.
 * High-frequency raw telemetry samples are not persisted here; only significant hazard transitions/events are recorded.
 */
@Entity
@Table(
        name = "hazard_events",
        uniqueConstraints = {
                @UniqueConstraint(name = "uq_hazard_events_device_correlation", columnNames = {"device_id", "correlation_id"})
        }
)
public class HazardEvent {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "device_id", nullable = false, updatable = false)
    private Device device;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, updatable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "hazard_type", nullable = false, length = 30)
    private HazardType hazardType;

    @Enumerated(EnumType.STRING)
    @Column(name = "hazard_level", nullable = false, length = 30)
    private HazardLevel hazardLevel;

    @Column(name = "distance_cm", nullable = false)
    private int distanceCm;

    @Enumerated(EnumType.STRING)
    @Column(name = "source", nullable = false, length = 30)
    private EventSource source;

    @Column(name = "correlation_id", length = 100)
    private String correlationId;

    @Column(name = "event_timestamp", nullable = false, updatable = false)
    private Instant eventTimestamp;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public HazardEvent() {
    }

    public HazardEvent(
            UUID id,
            Device device,
            User user,
            HazardType hazardType,
            HazardLevel hazardLevel,
            int distanceCm,
            EventSource source,
            String correlationId,
            Instant eventTimestamp
    ) {
        this.id = id != null ? id : UUID.randomUUID();
        this.device = device;
        this.user = user;
        this.hazardType = hazardType;
        this.hazardLevel = hazardLevel;
        this.distanceCm = distanceCm;
        this.source = source != null ? source : EventSource.SIMULATED_DEVICE;
        this.correlationId = correlationId;
        Instant now = Instant.now();
        this.eventTimestamp = eventTimestamp != null ? eventTimestamp : now;
        this.createdAt = now;
    }

    @PrePersist
    protected void onCreate() {
        if (this.id == null) {
            this.id = UUID.randomUUID();
        }
        Instant now = Instant.now();
        if (this.eventTimestamp == null) {
            this.eventTimestamp = now;
        }
        if (this.createdAt == null) {
            this.createdAt = now;
        }
        if (this.source == null) {
            this.source = EventSource.SIMULATED_DEVICE;
        }
    }

    public UUID getId() {
        return id;
    }

    public Device getDevice() {
        return device;
    }

    public User getUser() {
        return user;
    }

    public HazardType getHazardType() {
        return hazardType;
    }

    public HazardLevel getHazardLevel() {
        return hazardLevel;
    }

    public int getDistanceCm() {
        return distanceCm;
    }

    public EventSource getSource() {
        return source;
    }

    public String getCorrelationId() {
        return correlationId;
    }

    public Instant getEventTimestamp() {
        return eventTimestamp;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
