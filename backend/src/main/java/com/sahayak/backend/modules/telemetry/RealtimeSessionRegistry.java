package com.sahayak.backend.modules.telemetry;

import com.sahayak.backend.modules.user.Role;
import com.sahayak.backend.security.UserPrincipal;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.EventListener;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.messaging.SessionConnectEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Lightweight thread-safe session registry tracking authenticated STOMP connections,
 * disconnections, and per-user session awareness.
 */
@Component
public class RealtimeSessionRegistry {

    private static final Logger log = LoggerFactory.getLogger(RealtimeSessionRegistry.class);

    public record SessionInfo(
            String sessionId,
            UUID userId,
            Role role,
            Instant connectedAt
    ) {
    }

    private final Map<String, SessionInfo> activeSessions = new ConcurrentHashMap<>();

    public void registerSession(String sessionId, UUID userId, Role role) {
        if (sessionId != null && userId != null && role != null) {
            activeSessions.put(sessionId, new SessionInfo(sessionId, userId, role, Instant.now()));
            log.debug("Registered STOMP session: sessionId={}, userId={}, role={}", sessionId, userId, role);
        }
    }

    public void removeSession(String sessionId) {
        if (sessionId != null) {
            SessionInfo removed = activeSessions.remove(sessionId);
            if (removed != null) {
                log.debug("Removed STOMP session: sessionId={}, userId={}", sessionId, removed.userId());
            }
        }
    }

    public int getActiveSessionCountForUser(UUID userId) {
        if (userId == null) {
            return 0;
        }
        return (int) activeSessions.values().stream()
                .filter(info -> userId.equals(info.userId()))
                .count();
    }

    public int getTotalActiveSessions() {
        return activeSessions.size();
    }

    public boolean isUserConnected(UUID userId) {
        return getActiveSessionCountForUser(userId) > 0;
    }

    @EventListener
    public void handleSessionConnect(SessionConnectEvent event) {
        StompHeaderAccessor accessor = StompHeaderAccessor.wrap(event.getMessage());
        String sessionId = accessor.getSessionId();
        if (accessor.getUser() instanceof Authentication auth
                && auth.getPrincipal() instanceof UserPrincipal principal) {
            registerSession(sessionId, principal.getId(), principal.getRole());
        }
    }

    @EventListener
    public void handleSessionDisconnect(SessionDisconnectEvent event) {
        removeSession(event.getSessionId());
    }
}
