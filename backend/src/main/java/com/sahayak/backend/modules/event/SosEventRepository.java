package com.sahayak.backend.modules.event;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Spring Data JPA Repository for persisted SosEvent entities.
 */
@Repository
public interface SosEventRepository extends JpaRepository<SosEvent, UUID> {

    @EntityGraph(attributePaths = {"device", "user", "acknowledgedBy", "resolvedBy"})
    List<SosEvent> findByDeviceIdOrderByTriggeredAtDesc(UUID deviceId);

    @EntityGraph(attributePaths = {"device", "user", "acknowledgedBy", "resolvedBy"})
    List<SosEvent> findByUserIdOrderByTriggeredAtDesc(UUID userId);

    @EntityGraph(attributePaths = {"device", "user", "acknowledgedBy", "resolvedBy"})
    List<SosEvent> findByDeviceIdAndStatusOrderByTriggeredAtDesc(UUID deviceId, SosEventStatus status);

    @EntityGraph(attributePaths = {"device", "user", "acknowledgedBy", "resolvedBy"})
    Optional<SosEvent> findByDeviceIdAndCorrelationId(UUID deviceId, String correlationId);

    @EntityGraph(attributePaths = {"device", "user", "acknowledgedBy", "resolvedBy"})
    Optional<SosEvent> findFirstByDeviceIdAndStatusOrderByTriggeredAtDesc(UUID deviceId, SosEventStatus status);

    @Override
    @EntityGraph(attributePaths = {"device", "user", "acknowledgedBy", "resolvedBy"})
    Optional<SosEvent> findById(UUID id);
}
