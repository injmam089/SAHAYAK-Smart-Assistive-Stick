-- Phase 1E Hazard & SOS Event Domain Persistence Migration
-- Additive schema for persisted hazard events and SOS emergency lifecycle records.

CREATE TABLE hazard_events (
    id UUID PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    hazard_type VARCHAR(30) NOT NULL CHECK (hazard_type IN ('FORWARD_OBSTACLE', 'GROUND_HAZARD')),
    hazard_level VARCHAR(30) NOT NULL CHECK (hazard_level IN ('NORMAL', 'SLOW_WARNING', 'FAST_WARNING', 'WARNING', 'DANGER', 'CRITICAL')),
    distance_cm INTEGER NOT NULL CHECK (distance_cm >= 0 AND distance_cm <= 1000),
    source VARCHAR(30) NOT NULL CHECK (source IN ('SIMULATED_DEVICE', 'DEVICE', 'MOBILE_CLIENT', 'BACKEND')),
    correlation_id VARCHAR(100),
    event_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_hazard_events_device_correlation UNIQUE (device_id, correlation_id)
);

CREATE INDEX idx_hazard_events_device_id_time ON hazard_events (device_id, event_timestamp DESC);
CREATE INDEX idx_hazard_events_user_id_time ON hazard_events (user_id, event_timestamp DESC);
CREATE INDEX idx_hazard_events_level ON hazard_events (hazard_level);

CREATE TABLE sos_events (
    id UUID PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL CHECK (status IN ('TRIGGERED', 'ACKNOWLEDGED', 'RESOLVED', 'CANCELLED')),
    source VARCHAR(30) NOT NULL CHECK (source IN ('SIMULATED_DEVICE', 'DEVICE', 'MOBILE_CLIENT', 'BACKEND')),
    correlation_id VARCHAR(100),
    triggered_at TIMESTAMP WITH TIME ZONE NOT NULL,
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    acknowledged_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_sos_events_device_correlation UNIQUE (device_id, correlation_id)
);

CREATE INDEX idx_sos_events_device_id_time ON sos_events (device_id, triggered_at DESC);
CREATE INDEX idx_sos_events_user_id_time ON sos_events (user_id, triggered_at DESC);
CREATE INDEX idx_sos_events_status ON sos_events (status);
