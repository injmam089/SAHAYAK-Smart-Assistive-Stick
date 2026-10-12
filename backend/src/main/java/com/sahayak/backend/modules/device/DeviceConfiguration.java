package com.sahayak.backend.modules.device;

import jakarta.persistence.*;

import java.time.Instant;
import java.util.UUID;

/**
 * JPA Entity representing the configurable runtime settings for a registered SAHAYAK device.
 * Supports configurable hazard distance thresholds, haptic settings, audio settings, and version tracking.
 */
@Entity
@Table(name = "device_configurations")
public class DeviceConfiguration {

    public static final int DEFAULT_NORMAL_THRESHOLD_CM = 150;
    public static final int DEFAULT_SLOW_WARNING_THRESHOLD_CM = 100;
    public static final int DEFAULT_FAST_WARNING_THRESHOLD_CM = 50;
    public static final boolean DEFAULT_HAPTIC_ENABLED = true;
    public static final int DEFAULT_HAPTIC_INTENSITY = 80;
    public static final boolean DEFAULT_AUDIO_ENABLED = true;
    public static final int DEFAULT_AUDIO_VOLUME = 80;

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "device_id", nullable = false, unique = true)
    private Device device;

    @Column(name = "normal_threshold_cm", nullable = false)
    private int normalThresholdCm = DEFAULT_NORMAL_THRESHOLD_CM;

    @Column(name = "slow_warning_threshold_cm", nullable = false)
    private int slowWarningThresholdCm = DEFAULT_SLOW_WARNING_THRESHOLD_CM;

    @Column(name = "fast_warning_threshold_cm", nullable = false)
    private int fastWarningThresholdCm = DEFAULT_FAST_WARNING_THRESHOLD_CM;

    @Column(name = "haptic_enabled", nullable = false)
    private boolean hapticEnabled = DEFAULT_HAPTIC_ENABLED;

    @Column(name = "haptic_intensity", nullable = false)
    private int hapticIntensity = DEFAULT_HAPTIC_INTENSITY;

    @Column(name = "audio_enabled", nullable = false)
    private boolean audioEnabled = DEFAULT_AUDIO_ENABLED;

    @Column(name = "audio_volume", nullable = false)
    private int audioVolume = DEFAULT_AUDIO_VOLUME;

    @Column(name = "configuration_version", nullable = false)
    private long configurationVersion = 1L;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    public DeviceConfiguration() {
    }

    public static DeviceConfiguration createDefault(Device device) {
        DeviceConfiguration config = new DeviceConfiguration();
        config.setId(UUID.randomUUID());
        config.setDevice(device);
        config.setNormalThresholdCm(DEFAULT_NORMAL_THRESHOLD_CM);
        config.setSlowWarningThresholdCm(DEFAULT_SLOW_WARNING_THRESHOLD_CM);
        config.setFastWarningThresholdCm(DEFAULT_FAST_WARNING_THRESHOLD_CM);
        config.setHapticEnabled(DEFAULT_HAPTIC_ENABLED);
        config.setHapticIntensity(DEFAULT_HAPTIC_INTENSITY);
        config.setAudioEnabled(DEFAULT_AUDIO_ENABLED);
        config.setAudioVolume(DEFAULT_AUDIO_VOLUME);
        config.setConfigurationVersion(1L);
        return config;
    }

    @PrePersist
    protected void onCreate() {
        if (this.id == null) {
            this.id = UUID.randomUUID();
        }
        if (this.configurationVersion < 1L) {
            this.configurationVersion = 1L;
        }
        Instant now = Instant.now();
        if (this.createdAt == null) {
            this.createdAt = now;
        }
        this.updatedAt = now;
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
    }

    public void incrementVersion() {
        this.configurationVersion++;
        this.updatedAt = Instant.now();
    }

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public Device getDevice() {
        return device;
    }

    public void setDevice(Device device) {
        this.device = device;
    }

    public int getNormalThresholdCm() {
        return normalThresholdCm;
    }

    public void setNormalThresholdCm(int normalThresholdCm) {
        this.normalThresholdCm = normalThresholdCm;
    }

    public int getSlowWarningThresholdCm() {
        return slowWarningThresholdCm;
    }

    public void setSlowWarningThresholdCm(int slowWarningThresholdCm) {
        this.slowWarningThresholdCm = slowWarningThresholdCm;
    }

    public int getFastWarningThresholdCm() {
        return fastWarningThresholdCm;
    }

    public void setFastWarningThresholdCm(int fastWarningThresholdCm) {
        this.fastWarningThresholdCm = fastWarningThresholdCm;
    }

    public boolean isHapticEnabled() {
        return hapticEnabled;
    }

    public void setHapticEnabled(boolean hapticEnabled) {
        this.hapticEnabled = hapticEnabled;
    }

    public int getHapticIntensity() {
        return hapticIntensity;
    }

    public void setHapticIntensity(int hapticIntensity) {
        this.hapticIntensity = hapticIntensity;
    }

    public boolean isAudioEnabled() {
        return audioEnabled;
    }

    public void setAudioEnabled(boolean audioEnabled) {
        this.audioEnabled = audioEnabled;
    }

    public int getAudioVolume() {
        return audioVolume;
    }

    public void setAudioVolume(int audioVolume) {
        this.audioVolume = audioVolume;
    }

    public long getConfigurationVersion() {
        return configurationVersion;
    }

    public void setConfigurationVersion(long configurationVersion) {
        this.configurationVersion = configurationVersion;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
