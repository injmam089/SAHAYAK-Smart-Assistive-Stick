package com.sahayak.backend.modules.device;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Spring Data JPA Repository for Device entities.
 */
@Repository
public interface DeviceRepository extends JpaRepository<Device, UUID> {

    @EntityGraph(attributePaths = {"owner"})
    Optional<Device> findByDeviceIdentifier(String deviceIdentifier);

    boolean existsByDeviceIdentifier(String deviceIdentifier);

    @EntityGraph(attributePaths = {"owner"})
    List<Device> findByOwnerIdOrderByCreatedAtDesc(UUID ownerId);

    @EntityGraph(attributePaths = {"owner"})
    List<Device> findByOwnerIdInOrderByCreatedAtDesc(Collection<UUID> ownerIds);

    @EntityGraph(attributePaths = {"owner"})
    Optional<Device> findByIdAndOwnerId(UUID id, UUID ownerId);

    @Override
    @EntityGraph(attributePaths = {"owner"})
    Optional<Device> findById(UUID id);
}
