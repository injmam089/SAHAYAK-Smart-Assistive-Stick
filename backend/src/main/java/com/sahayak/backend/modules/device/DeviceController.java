package com.sahayak.backend.modules.device;

import com.sahayak.backend.common.constants.ApiConstants;
import com.sahayak.backend.common.dto.ApiResponse;
import com.sahayak.backend.modules.device.dto.DeviceConfigurationResponse;
import com.sahayak.backend.modules.device.dto.DeviceResponse;
import com.sahayak.backend.modules.device.dto.RegisterDeviceRequest;
import com.sahayak.backend.modules.device.dto.UpdateDeviceConfigurationRequest;
import com.sahayak.backend.modules.device.dto.UpdateDeviceStatusRequest;
import com.sahayak.backend.security.UserPrincipal;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/**
 * Thin REST Controller for SAHAYAK Device Registry and Device Configuration management (Phase 1D).
 */
@RestController
@RequestMapping(ApiConstants.API_V1_PREFIX + "/devices")
public class DeviceController {

    private final DeviceService deviceService;
    private final DeviceConfigurationService configurationService;

    public DeviceController(
            DeviceService deviceService,
            DeviceConfigurationService configurationService
    ) {
        this.deviceService = deviceService;
        this.configurationService = configurationService;
    }

    @PostMapping
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<ApiResponse<DeviceResponse>> registerDevice(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody RegisterDeviceRequest request
    ) {
        DeviceResponse created = deviceService.registerDevice(principal, request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Device registered successfully", created));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('USER', 'PARENT', 'ADMIN')")
    public ResponseEntity<ApiResponse<List<DeviceResponse>>> listDevices(
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        List<DeviceResponse> devices = deviceService.listAccessibleDevices(principal);
        return ResponseEntity.ok(ApiResponse.ok("Accessible devices retrieved", devices));
    }

    @GetMapping("/{deviceId}")
    @PreAuthorize("hasAnyRole('USER', 'PARENT', 'ADMIN')")
    public ResponseEntity<ApiResponse<DeviceResponse>> getDevice(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID deviceId
    ) {
        DeviceResponse device = deviceService.getDeviceById(principal, deviceId);
        return ResponseEntity.ok(ApiResponse.ok("Device retrieved", device));
    }

    @PatchMapping("/{deviceId}/status")
    @PreAuthorize("hasAnyRole('USER', 'ADMIN')")
    public ResponseEntity<ApiResponse<DeviceResponse>> updateDeviceStatus(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID deviceId,
            @Valid @RequestBody UpdateDeviceStatusRequest request
    ) {
        DeviceResponse updated = deviceService.updateDeviceStatus(principal, deviceId, request);
        return ResponseEntity.ok(ApiResponse.ok("Device status updated", updated));
    }

    @GetMapping("/{deviceId}/configuration")
    @PreAuthorize("hasAnyRole('USER', 'PARENT', 'ADMIN')")
    public ResponseEntity<ApiResponse<DeviceConfigurationResponse>> getDeviceConfiguration(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID deviceId
    ) {
        DeviceConfigurationResponse config = configurationService.getConfiguration(principal, deviceId);
        return ResponseEntity.ok(ApiResponse.ok("Device configuration retrieved", config));
    }

    @PutMapping("/{deviceId}/configuration")
    @PreAuthorize("hasAnyRole('USER', 'ADMIN')")
    public ResponseEntity<ApiResponse<DeviceConfigurationResponse>> updateDeviceConfiguration(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID deviceId,
            @Valid @RequestBody UpdateDeviceConfigurationRequest request
    ) {
        DeviceConfigurationResponse updated = configurationService.updateConfiguration(principal, deviceId, request);
        return ResponseEntity.ok(ApiResponse.ok("Device configuration updated", updated));
    }
}
