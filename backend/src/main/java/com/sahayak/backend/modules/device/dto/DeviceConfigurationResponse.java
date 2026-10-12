package com.sahayak.backend.modules.device.dto;

import com.sahayak.backend.modules.device.DeviceConfiguration;

import java.time.Instant;
import java.util.UUID;

/**
 * Response DTO representing the runtime configuration for a SAHAYAK device.
 */
public record DeviceConfigurationResponse(
        UUID id,
        UUID deviceId,
        String deviceIdentifier,
        int normalThresholdCm,
        int slowWarningThresholdCm,
        int fastWarningThresholdCm,
        boolean hapticEnabled,
        int hapticIntensity,
        boolean audioEnabled,
        int audioVolume,
        long configurationVersion,
        Instant updatedAt
) {
    public static DeviceConfigurationResponse fromEntity(DeviceConfiguration config) {
        return new DeviceConfigurationResponse(
                config.getId(),
                config.getDevice().getId(),
                config.getDevice().getDeviceIdentifier(),
                config.getNormalThresholdCm(),
                config.getSlowWarningThresholdCm(),
                config.getFastWarningThresholdCm(),
                config.isHapticEnabled(),
                config.getHapticIntensity(),
                config.isAudioEnabled(),
                config.getAudioVolume(),
                config.getConfigurationVersion(),
                config.getUpdatedAt()
        );
    }
}
