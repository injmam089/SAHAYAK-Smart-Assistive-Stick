package com.sahayak.backend.modules.foundation;

import jakarta.persistence.*;
import java.time.Instant;

/**
 * Phase 1A Foundation Entity.
 * Validates the full Application -> Flyway -> PostgreSQL -> JPA database lifecycle.
 */
@Entity
@Table(name = "foundation_checks")
public class FoundationCheck {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "check_key", nullable = false, unique = true, length = 100)
    private String checkKey;

    @Column(name = "status", nullable = false, length = 50)
    private String status;

    @Column(name = "description", length = 255)
    private String description;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    public FoundationCheck() {
    }

    public FoundationCheck(String checkKey, String status, String description) {
        this.checkKey = checkKey;
        this.status = status;
        this.description = description;
        this.createdAt = Instant.now();
    }

    public Long getId() {
        return id;
    }

    public String getCheckKey() {
        return checkKey;
    }

    public void setCheckKey(String checkKey) {
        this.checkKey = checkKey;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }
}
