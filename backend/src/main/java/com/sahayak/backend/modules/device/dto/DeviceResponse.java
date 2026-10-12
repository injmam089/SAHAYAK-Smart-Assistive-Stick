package com.sahayak.backend.modules.device.dto;

import com.sahayak.backend.modules.device.Device;
import com.sahayak.backend.modules.device.DeviceStatus;

import java.time.Instant;
import java.util.UUID;

/**
 * Safe response DTO representing a registered SAHAYAK device without exposing entity internals.
 */
public record DeviceResponse(
        UUID id,
        String deviceIdentifier,
        String deviceName,
        UUID ownerUserId,
        String ownerFullName,
        DeviceStatus status,
        Instant createdAt,
        Instant updatedAt
) {
    public static DeviceResponse fromEntity(Device device) {
        return new DeviceResponse(
                device.getId(),
                device.getDeviceIdentifier(),
                device.getDeviceName(),
                device.getOwner().getId(),
                device.getOwner().getFullName(),
                device.getStatus(),
                device.getCreatedAt(),
                device.getUpdatedAt()
        );
    }
}
