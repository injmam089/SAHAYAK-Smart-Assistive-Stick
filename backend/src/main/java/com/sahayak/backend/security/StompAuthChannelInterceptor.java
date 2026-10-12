package com.sahayak.backend.security;

import com.sahayak.backend.modules.telemetry.RealtimeSessionRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.lang.NonNull;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

import java.security.Principal;
import java.util.UUID;

/**
 * Inbound STOMP ChannelInterceptor enforcing JWT authentication on CONNECT
 * and role/ownership destination authorization on SUBSCRIBE and SEND frames.
 */
@Component
public class StompAuthChannelInterceptor implements ChannelInterceptor {

    private static final Logger log = LoggerFactory.getLogger(StompAuthChannelInterceptor.class);
    private static final String BEARER_PREFIX = "Bearer ";

    private final JwtTokenProvider jwtTokenProvider;
    private final CustomUserDetailsService userDetailsService;
    private final StompDestinationAuthorizer destinationAuthorizer;
    private final RealtimeSessionRegistry sessionRegistry;

    public StompAuthChannelInterceptor(
            JwtTokenProvider jwtTokenProvider,
            CustomUserDetailsService userDetailsService,
            StompDestinationAuthorizer destinationAuthorizer,
            RealtimeSessionRegistry sessionRegistry
    ) {
        this.jwtTokenProvider = jwtTokenProvider;
        this.userDetailsService = userDetailsService;
        this.destinationAuthorizer = destinationAuthorizer;
        this.sessionRegistry = sessionRegistry;
    }

    @Override
    public Message<?> preSend(@NonNull Message<?> message, @NonNull MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
        if (accessor == null || accessor.getCommand() == null) {
            return message;
        }

        StompCommand command = accessor.getCommand();

        switch (command) {
            case CONNECT -> handleConnect(accessor);
            case SUBSCRIBE -> handleSubscribe(accessor);
            case SEND -> handleSend(accessor);
            case DISCONNECT -> sessionRegistry.removeSession(accessor.getSessionId());
            default -> {
                // ACK, NACK, HEARTBEAT pass through for established sessions
            }
        }

        return message;
    }

    private void handleConnect(StompHeaderAccessor accessor) {
        String token = extractBearerToken(accessor);
        if (!StringUtils.hasText(token)) {
            UserPrincipal existingPrincipal = resolvePrincipal(accessor.getUser());
            if (existingPrincipal != null && existingPrincipal.isEnabled() && existingPrincipal.isAccountNonLocked()) {
                sessionRegistry.registerSession(accessor.getSessionId(), existingPrincipal.getId(), existingPrincipal.getRole());
                return;
            }
            log.warn("Rejected STOMP CONNECT: missing Authorization Bearer header");
            throw new AccessDeniedException("Authentication is required to establish a STOMP connection");
        }

        if (!jwtTokenProvider.validateToken(token)) {
            log.warn("Rejected STOMP CONNECT: invalid or expired JWT");
            throw new AccessDeniedException("Invalid or expired authentication token");
        }

        UUID userId = jwtTokenProvider.getUserIdFromToken(token);
        UserPrincipal userPrincipal;
        try {
            userPrincipal = userDetailsService.loadUserById(userId);
        } catch (Exception ex) {
            log.warn("Rejected STOMP CONNECT: user account not found for id={}", userId);
            throw new AccessDeniedException("Invalid authentication principal");
        }

        if (!userPrincipal.isEnabled() || !userPrincipal.isAccountNonLocked()) {
            log.warn("Rejected STOMP CONNECT: account inactive or locked for id={}", userId);
            throw new AccessDeniedException("User account is locked or disabled");
        }

        UsernamePasswordAuthenticationToken authentication =
                new UsernamePasswordAuthenticationToken(
                        userPrincipal,
                        null,
                        userPrincipal.getAuthorities()
                );

        accessor.setUser(authentication);
        sessionRegistry.registerSession(accessor.getSessionId(), userPrincipal.getId(), userPrincipal.getRole());
    }

    private void handleSubscribe(StompHeaderAccessor accessor) {
        UserPrincipal principal = resolvePrincipal(accessor.getUser());
        if (principal == null) {
            log.warn("Rejected STOMP SUBSCRIBE: unauthenticated session attempting to subscribe to {}", accessor.getDestination());
            throw new AccessDeniedException("Authentication is required to subscribe to realtime destinations");
        }

        String destination = accessor.getDestination();
        if (!destinationAuthorizer.canSubscribe(principal, destination)) {
            log.warn("Rejected STOMP SUBSCRIBE: userId={} (role={}) denied access to destination={}",
                    principal.getId(), principal.getRole(), destination);
            throw new AccessDeniedException("Access denied for subscription destination: " + destination);
        }
    }

    private void handleSend(StompHeaderAccessor accessor) {
        UserPrincipal principal = resolvePrincipal(accessor.getUser());
        if (principal == null) {
            log.warn("Rejected STOMP SEND: unauthenticated session attempting to publish to {}", accessor.getDestination());
            throw new AccessDeniedException("Authentication is required to send realtime messages");
        }

        String destination = accessor.getDestination();
        if (!destinationAuthorizer.canSend(principal, destination)) {
            log.warn("Rejected STOMP SEND: userId={} (role={}) denied publish to destination={}",
                    principal.getId(), principal.getRole(), destination);
            throw new AccessDeniedException("Access denied for publish destination: " + destination);
        }
    }

    private String extractBearerToken(StompHeaderAccessor accessor) {
        String authHeader = accessor.getFirstNativeHeader(HttpHeaders.AUTHORIZATION);
        if (!StringUtils.hasText(authHeader)) {
            authHeader = accessor.getFirstNativeHeader("authorization");
        }
        if (StringUtils.hasText(authHeader) && authHeader.startsWith(BEARER_PREFIX)) {
            return authHeader.substring(BEARER_PREFIX.length()).trim();
        }
        return null;
    }

    private UserPrincipal resolvePrincipal(Principal user) {
        if (user instanceof Authentication authentication
                && authentication.getPrincipal() instanceof UserPrincipal principal) {
            return principal;
        }
        if (user instanceof UserPrincipal principal) {
            return principal;
        }
        return null;
    }
}
