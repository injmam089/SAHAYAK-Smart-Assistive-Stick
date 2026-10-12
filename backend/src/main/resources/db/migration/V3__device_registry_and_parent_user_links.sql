-- Phase 1D Device Registry, Device Configuration & Caregiver-User Linking Migration
-- Establishes explicit device ownership, extensible runtime configuration, and Parent-User relationship lifecycle.

CREATE TABLE devices (
    id UUID PRIMARY KEY,
    device_identifier VARCHAR(100) NOT NULL UNIQUE,
    owner_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('REGISTERED', 'ACTIVE', 'INACTIVE', 'DISABLED')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_devices_owner_user_id ON devices (owner_user_id);
CREATE INDEX idx_devices_device_identifier ON devices (device_identifier);
CREATE INDEX idx_devices_status ON devices (status);

CREATE TABLE device_configurations (
    id UUID PRIMARY KEY,
    device_id UUID NOT NULL UNIQUE REFERENCES devices(id) ON DELETE CASCADE,
    normal_threshold_cm INTEGER NOT NULL DEFAULT 150 CHECK (normal_threshold_cm > 0),
    slow_warning_threshold_cm INTEGER NOT NULL DEFAULT 100 CHECK (slow_warning_threshold_cm > 0),
    fast_warning_threshold_cm INTEGER NOT NULL DEFAULT 50 CHECK (fast_warning_threshold_cm > 0),
    haptic_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    haptic_intensity INTEGER NOT NULL DEFAULT 80 CHECK (haptic_intensity >= 0 AND haptic_intensity <= 100),
    audio_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    audio_volume INTEGER NOT NULL DEFAULT 80 CHECK (audio_volume >= 0 AND audio_volume <= 100),
    configuration_version BIGINT NOT NULL DEFAULT 1 CHECK (configuration_version >= 1),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_device_configurations_device_id ON device_configurations (device_id);

CREATE TABLE parent_user_links (
    id UUID PRIMARY KEY,
    parent_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL CHECK (status IN ('PENDING', 'ACTIVE', 'REVOKED')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_parent_user_links_pair UNIQUE (parent_user_id, user_id),
    CONSTRAINT chk_parent_user_not_same CHECK (parent_user_id <> user_id)
);

CREATE INDEX idx_parent_user_links_parent_id ON parent_user_links (parent_user_id);
CREATE INDEX idx_parent_user_links_user_id ON parent_user_links (user_id);
CREATE INDEX idx_parent_user_links_status ON parent_user_links (status);
