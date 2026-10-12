package com.sahayak.backend.modules.device;

import com.sahayak.backend.common.exception.ApiException;
import com.sahayak.backend.modules.device.dto.DeviceConfigurationResponse;
import com.sahayak.backend.modules.device.dto.UpdateDeviceConfigurationRequest;
import com.sahayak.backend.modules.link.ParentUserAuthorizationService;
import com.sahayak.backend.security.UserPrincipal;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/**
 * Domain service managing runtime configuration (hazard thresholds, haptic, audio settings)
 * for registered SAHAYAK devices.
 *
 * Authorization Policy:
 * - Read: Owning USER, ACTIVE-linked PARENT, or ADMIN.
 * - Write: Owning USER or ADMIN (Parent accounts have read-only access).
 */
@Service
public class DeviceConfigurationService {

    private static final Logger log = LoggerFactory.getLogger(DeviceConfigurationService.class);

    private final DeviceRepository deviceRepository;
    private final DeviceConfigurationRepository configurationRepository;
    private final ParentUserAuthorizationService authorizationService;

    public DeviceConfigurationService(
            DeviceRepository deviceRepository,
            DeviceConfigurationRepository configurationRepository,
            ParentUserAuthorizationService authorizationService
    ) {
        this.deviceRepository = deviceRepository;
        this.configurationRepository = configurationRepository;
        this.authorizationService = authorizationService;
    }

    @Transactional(readOnly = true)
    public DeviceConfigurationResponse getConfiguration(UserPrincipal principal, UUID deviceId) {
        Device device = deviceRepository.findById(deviceId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Device not found"));

        authorizationService.assertCanReadDevice(principal, device);

        DeviceConfiguration configuration = configurationRepository.findByDeviceId(deviceId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Device configuration not found"));

        return DeviceConfigurationResponse.fromEntity(configuration);
    }

    @Transactional
    public DeviceConfigurationResponse updateConfiguration(
            UserPrincipal principal,
            UUID deviceId,
            UpdateDeviceConfigurationRequest request
    ) {
        Device device = deviceRepository.findById(deviceId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Device not found"));

        authorizationService.assertCanModifyDevice(principal, device);

        validateThresholdHierarchy(
                request.normalThresholdCm(),
                request.slowWarningThresholdCm(),
                request.fastWarningThresholdCm()
        );

        DeviceConfiguration configuration = configurationRepository.findByDeviceId(deviceId)
                .orElseGet(() -> DeviceConfiguration.createDefault(device));

        configuration.setNormalThresholdCm(request.normalThresholdCm());
        configuration.setSlowWarningThresholdCm(request.slowWarningThresholdCm());
        configuration.setFastWarningThresholdCm(request.fastWarningThresholdCm());
        configuration.setHapticEnabled(request.hapticEnabled());
        configuration.setHapticIntensity(request.hapticIntensity());
        configuration.setAudioEnabled(request.audioEnabled());
        configuration.setAudioVolume(request.audioVolume());
        configuration.incrementVersion();

        DeviceConfiguration saved = configurationRepository.save(configuration);

        log.info("Updated device configuration: deviceId={}, version={}, byUserId={}",
                deviceId, saved.getConfigurationVersion(), principal.getId());

        return DeviceConfigurationResponse.fromEntity(saved);
    }

    private void validateThresholdHierarchy(int normalCm, int slowWarningCm, int fastWarningCm) {
        if (!(normalCm > slowWarningCm && slowWarningCm > fastWarningCm)) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "Invalid threshold hierarchy: normalThresholdCm must be greater than slowWarningThresholdCm, "
                            + "and slowWarningThresholdCm must be greater than fastWarningThresholdCm"
            );
        }
    }
}
