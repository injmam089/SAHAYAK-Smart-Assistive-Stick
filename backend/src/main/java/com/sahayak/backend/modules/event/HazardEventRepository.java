package com.sahayak.backend.modules.event;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Spring Data JPA Repository for persisted HazardEvent entities.
 */
@Repository
public interface HazardEventRepository extends JpaRepository<HazardEvent, UUID> {

    @EntityGraph(attributePaths = {"device", "user"})
    List<HazardEvent> findByDeviceIdOrderByEventTimestampDesc(UUID deviceId);

    @EntityGraph(attributePaths = {"device", "user"})
    List<HazardEvent> findByUserIdOrderByEventTimestampDesc(UUID userId);

    @EntityGraph(attributePaths = {"device", "user"})
    Optional<HazardEvent> findByDeviceIdAndCorrelationId(UUID deviceId, String correlationId);

    @Override
    @EntityGraph(attributePaths = {"device", "user"})
    Optional<HazardEvent> findById(UUID id);
}
