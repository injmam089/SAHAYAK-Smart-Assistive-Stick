package com.sahayak.backend.modules.event;

import com.sahayak.backend.common.dto.EventSource;
import com.sahayak.backend.modules.device.Device;
import com.sahayak.backend.modules.user.User;
import jakarta.persistence.*;

import java.time.Instant;
import java.util.UUID;

/**
 * JPA Entity representing a persisted SOS emergency event and its audit lifecycle.
 */
@Entity
@Table(
        name = "sos_events",
        uniqueConstraints = {
                @UniqueConstraint(name = "uq_sos_events_device_correlation", columnNames = {"device_id", "correlation_id"})
        }
)
public class SosEvent {

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
    @Column(name = "status", nullable = false, length = 20)
    private SosEventStatus status;

    @Enumerated(EnumType.STRING)
    @Column(name = "source", nullable = false, length = 30)
    private EventSource source;

    @Column(name = "correlation_id", length = 100)
    private String correlationId;

    @Column(name = "triggered_at", nullable = false, updatable = false)
    private Instant triggeredAt;

    @Column(name = "acknowledged_at")
    private Instant acknowledgedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "acknowledged_by_user_id")
    private User acknowledgedBy;

    @Column(name = "resolved_at")
    private Instant resolvedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "resolved_by_user_id")
    private User resolvedBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    public SosEvent() {
    }

    public SosEvent(
            UUID id,
            Device device,
            User user,
            SosEventStatus status,
            EventSource source,
            String correlationId,
            Instant triggeredAt
    ) {
        this.id = id != null ? id : UUID.randomUUID();
        this.device = device;
        this.user = user;
        this.status = status != null ? status : SosEventStatus.TRIGGERED;
        this.source = source != null ? source : EventSource.SIMULATED_DEVICE;
        this.correlationId = correlationId;
        Instant now = Instant.now();
        this.triggeredAt = triggeredAt != null ? triggeredAt : now;
        this.createdAt = now;
        this.updatedAt = now;
    }

    @PrePersist
    protected void onCreate() {
        if (this.id == null) {
            this.id = UUID.randomUUID();
        }
        if (this.status == null) {
            this.status = SosEventStatus.TRIGGERED;
        }
        if (this.source == null) {
            this.source = EventSource.SIMULATED_DEVICE;
        }
        Instant now = Instant.now();
        if (this.triggeredAt == null) {
            this.triggeredAt = now;
        }
        if (this.createdAt == null) {
            this.createdAt = now;
        }
        this.updatedAt = now;
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
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

    public SosEventStatus getStatus() {
        return status;
    }

    public void setStatus(SosEventStatus status) {
        this.status = status;
    }

    public EventSource getSource() {
        return source;
    }

    public String getCorrelationId() {
        return correlationId;
    }

    public Instant getTriggeredAt() {
        return triggeredAt;
    }

    public Instant getAcknowledgedAt() {
        return acknowledgedAt;
    }

    public void setAcknowledgedAt(Instant acknowledgedAt) {
        this.acknowledgedAt = acknowledgedAt;
    }

    public User getAcknowledgedBy() {
        return acknowledgedBy;
    }

    public void setAcknowledgedBy(User acknowledgedBy) {
        this.acknowledgedBy = acknowledgedBy;
    }

    public Instant getResolvedAt() {
        return resolvedAt;
    }

    public void setResolvedAt(Instant resolvedAt) {
        this.resolvedAt = resolvedAt;
    }

    public User getResolvedBy() {
        return resolvedBy;
    }

    public void setResolvedBy(User resolvedBy) {
        this.resolvedBy = resolvedBy;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
