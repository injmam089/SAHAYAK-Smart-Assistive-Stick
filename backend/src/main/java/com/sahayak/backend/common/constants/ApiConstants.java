package com.sahayak.backend.common.constants;

/**
 * Centralized API Versioning and STOMP WebSocket Destination Conventions.
 *
 * REST API Convention:
 * - All operational endpoints reside under "/api/v1/..."
 *
 * STOMP over WebSocket Convention:
 * - Handshake Endpoint: "/ws"
 * - Client-to-Server Application Prefix: "/app"
 * - Broker Prefixes: "/topic", "/queue"
 * - User Destination Prefix: "/user"
 * - Canonical Topic Hierarchy:
 *   - "/topic/user/{userId}/events"      (ROLE_USER matching {userId})
 *   - "/topic/parent/{parentId}/events"  (ROLE_PARENT matching {parentId})
 *   - "/topic/device/{deviceId}/telemetry" (Authenticated USER or PARENT)
 *   - "/topic/system/status"             (Authenticated system status)
 *   - "/topic/admin/events"              (ROLE_ADMIN only)
 */
public final class ApiConstants {

    private ApiConstants() {
    }

    public static final String API_V1_PREFIX = "/api/v1";

    // WebSocket / STOMP Endpoints & Prefixes
    public static final String WS_ENDPOINT = "/ws";
    public static final String WS_APP_PREFIX = "/app";
    public static final String WS_TOPIC_PREFIX = "/topic";
    public static final String WS_QUEUE_PREFIX = "/queue";
    public static final String WS_USER_PREFIX = "/user";

    // Canonical Topic Templates
    public static final String TOPIC_USER_EVENTS_PREFIX = "/topic/user/";
    public static final String TOPIC_PARENT_EVENTS_PREFIX = "/topic/parent/";
    public static final String TOPIC_DEVICE_PREFIX = "/topic/device/";
    public static final String TOPIC_ADMIN_PREFIX = "/topic/admin/";
    public static final String TOPIC_SYSTEM_STATUS = "/topic/system/status";
}
