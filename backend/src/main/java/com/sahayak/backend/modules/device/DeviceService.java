package com.sahayak.backend.modules.device;

import com.sahayak.backend.common.exception.ApiException;
import com.sahayak.backend.modules.device.dto.DeviceResponse;
import com.sahayak.backend.modules.device.dto.RegisterDeviceRequest;
import com.sahayak.backend.modules.device.dto.UpdateDeviceStatusRequest;
import com.sahayak.backend.modules.link.ParentUserAuthorizationService;
import com.sahayak.backend.modules.user.Role;
import com.sahayak.backend.modules.user.User;
import com.sahayak.backend.modules.user.UserRepository;
import com.sahayak.backend.security.UserPrincipal;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * Domain service managing SAHAYAK device registration, lookup, status transitions,
 * and ownership/relationship-based access control.
 */
@Service
public class DeviceService {

    private static final Logger log = LoggerFactory.getLogger(DeviceService.class);

    private final DeviceRepository deviceRepository;
    private final DeviceConfigurationRepository deviceConfigurationRepository;
    private final UserRepository userRepository;
    private final ParentUserAuthorizationService authorizationService;

    public DeviceService(
            DeviceRepository deviceRepository,
            DeviceConfigurationRepository deviceConfigurationRepository,
            UserRepository userRepository,
            ParentUserAuthorizationService authorizationService
    ) {
        this.deviceRepository = deviceRepository;
        this.deviceConfigurationRepository = deviceConfigurationRepository;
        this.userRepository = userRepository;
        this.authorizationService = authorizationService;
    }

    /**
     * Registers a new physical SAHAYAK device to the authenticated USER account.
     * Ownership is strictly bound to principal.getId() and initializes default DeviceConfiguration.
     */
    @Transactional
    public DeviceResponse registerDevice(UserPrincipal principal, RegisterDeviceRequest request) {
        if (principal == null || principal.getRole() != Role.USER) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "Only stick operator accounts (USER) may register a SAHAYAK device"
            );
        }

        String normalizedIdentifier = request.deviceIdentifier().trim();
        if (deviceRepository.existsByDeviceIdentifier(normalizedIdentifier)) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "A device with identifier '" + normalizedIdentifier + "' is already registered"
            );
        }

        User owner = userRepository.findById(principal.getId())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Authenticated user account not found"));

        Device device = new Device(
                UUID.randomUUID(),
                normalizedIdentifier,
                owner,
                request.deviceName().trim(),
                DeviceStatus.ACTIVE
        );

        Device savedDevice = deviceRepository.save(device);

        DeviceConfiguration defaultConfig = DeviceConfiguration.createDefault(savedDevice);
        deviceConfigurationRepository.save(defaultConfig);

        log.info("Registered SAHAYAK device: id={}, identifier={}, ownerUserId={}",
                savedDevice.getId(), savedDevice.getDeviceIdentifier(), owner.getId());

        return DeviceResponse.fromEntity(savedDevice);
    }

    @Transactional(readOnly = true)
    public DeviceResponse getDeviceById(UserPrincipal principal, UUID deviceId) {
        Device device = deviceRepository.findById(deviceId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Device not found"));

        authorizationService.assertCanReadDevice(principal, device);
        return DeviceResponse.fromEntity(device);
    }

    @Transactional(readOnly = true)
    public List<DeviceResponse> listAccessibleDevices(UserPrincipal principal) {
        if (principal == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Authentication is required");
        }

        List<Device> devices;
        if (principal.getRole() == Role.USER) {
            devices = deviceRepository.findByOwnerIdOrderByCreatedAtDesc(principal.getId());
        } else if (principal.getRole() == Role.PARENT) {
            List<UUID> linkedUserIds = authorizationService.findAuthorizedUserIdsForParent(principal.getId());
            if (linkedUserIds.isEmpty()) {
                return List.of();
            }
            devices = deviceRepository.findByOwnerIdInOrderByCreatedAtDesc(linkedUserIds);
        } else {
            devices = deviceRepository.findAll();
        }

        return devices.stream()
                .map(DeviceResponse::fromEntity)
                .toList();
    }

    @Transactional
    public DeviceResponse updateDeviceStatus(
            UserPrincipal principal,
            UUID deviceId,
            UpdateDeviceStatusRequest request
    ) {
        Device device = deviceRepository.findById(deviceId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Device not found"));

        authorizationService.assertCanModifyDevice(principal, device);

        DeviceStatus previousStatus = device.getStatus();
        device.setStatus(request.status());
        Device saved = deviceRepository.save(device);

        log.info("Updated device status: deviceId={}, from={} to={}, byUserId={}",
                saved.getId(), previousStatus, saved.getStatus(), principal.getId());

        return DeviceResponse.fromEntity(saved);
    }
}
