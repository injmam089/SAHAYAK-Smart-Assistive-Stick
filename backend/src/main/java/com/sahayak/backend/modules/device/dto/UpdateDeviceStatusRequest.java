package com.sahayak.backend.modules.device.dto;

import com.sahayak.backend.modules.device.DeviceStatus;
import jakarta.validation.constraints.NotNull;

/**
 * Request DTO for updating the domain status of a registered SAHAYAK device.
 */
public record UpdateDeviceStatusRequest(
        @NotNull(message = "Device status is required")
        DeviceStatus status
) {
}
