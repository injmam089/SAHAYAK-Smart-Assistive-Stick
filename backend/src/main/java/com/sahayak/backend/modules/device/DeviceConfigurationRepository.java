package com.sahayak.backend.modules.device;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

/**
 * Spring Data JPA Repository for DeviceConfiguration entities.
 */
@Repository
public interface DeviceConfigurationRepository extends JpaRepository<DeviceConfiguration, UUID> {

    @EntityGraph(attributePaths = {"device", "device.owner"})
    Optional<DeviceConfiguration> findByDeviceId(UUID deviceId);
}
