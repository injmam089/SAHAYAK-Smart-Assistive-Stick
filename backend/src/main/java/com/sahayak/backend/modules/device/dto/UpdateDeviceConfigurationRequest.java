package com.sahayak.backend.modules.device.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

/**
 * Request DTO for updating configurable hazard thresholds and haptic/audio feedback settings.
 */
public record UpdateDeviceConfigurationRequest(

        @NotNull(message = "normalThresholdCm is required")
        @Min(value = 50, message = "normalThresholdCm must be at least 50 cm")
        @Max(value = 400, message = "normalThresholdCm must not exceed 400 cm")
        Integer normalThresholdCm,

        @NotNull(message = "slowWarningThresholdCm is required")
        @Min(value = 30, message = "slowWarningThresholdCm must be at least 30 cm")
        @Max(value = 350, message = "slowWarningThresholdCm must not exceed 350 cm")
        Integer slowWarningThresholdCm,

        @NotNull(message = "fastWarningThresholdCm is required")
        @Min(value = 10, message = "fastWarningThresholdCm must be at least 10 cm")
        @Max(value = 300, message = "fastWarningThresholdCm must not exceed 300 cm")
        Integer fastWarningThresholdCm,

        @NotNull(message = "hapticEnabled is required")
        Boolean hapticEnabled,

        @NotNull(message = "hapticIntensity is required")
        @Min(value = 0, message = "hapticIntensity must be between 0 and 100")
        @Max(value = 100, message = "hapticIntensity must be between 0 and 100")
        Integer hapticIntensity,

        @NotNull(message = "audioEnabled is required")
        Boolean audioEnabled,

        @NotNull(message = "audioVolume is required")
        @Min(value = 0, message = "audioVolume must be between 0 and 100")
        @Max(value = 100, message = "audioVolume must be between 0 and 100")
        Integer audioVolume
) {
}
