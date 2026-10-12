package com.sahayak.backend.modules.device.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Request DTO for registering a physical SAHAYAK device.
 * Ownership is strictly derived from the authenticated USER principal and never accepted from the payload.
 */
public record RegisterDeviceRequest(

        @NotBlank(message = "Device identifier is required")
        @Size(min = 3, max = 100, message = "Device identifier must be between 3 and 100 characters")
        @Pattern(
                regexp = "^[A-Za-z0-9._-]+$",
                message = "Device identifier may only contain alphanumeric characters, dots, underscores, and hyphens"
        )
        String deviceIdentifier,

        @NotBlank(message = "Device name is required")
        @Size(min = 2, max = 100, message = "Device name must be between 2 and 100 characters")
        String deviceName
) {
}
