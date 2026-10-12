package com.sahayak.backend.config;

import com.sahayak.backend.common.constants.ApiConstants;
import com.sahayak.backend.security.StompAuthChannelInterceptor;
import org.springframework.context.annotation.Configuration;
import org.springframework.lang.NonNull;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

/**
 * Spring WebSocket / STOMP Message Broker Configuration (Phase 1C Realtime Foundation).
 *
 * Endpoints & Conventions:
 * - Handshake Endpoint: "/ws"
 * - Client-to-Server Application Prefix: "/app"
 * - Broker Prefixes: "/topic", "/queue"
 * - User Destination Prefix: "/user"
 * - Authentication & Authorization: Enforced at the STOMP frame boundary via StompAuthChannelInterceptor.
 */
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    private final StompAuthChannelInterceptor stompAuthChannelInterceptor;

    public WebSocketConfig(StompAuthChannelInterceptor stompAuthChannelInterceptor) {
        this.stompAuthChannelInterceptor = stompAuthChannelInterceptor;
    }

    @Override
    public void registerStompEndpoints(@NonNull StompEndpointRegistry registry) {
        registry.addEndpoint(ApiConstants.WS_ENDPOINT)
                .setAllowedOriginPatterns("*");
    }

    @Override
    public void configureMessageBroker(@NonNull MessageBrokerRegistry registry) {
        registry.enableSimpleBroker(ApiConstants.WS_TOPIC_PREFIX, ApiConstants.WS_QUEUE_PREFIX);
        registry.setApplicationDestinationPrefixes(ApiConstants.WS_APP_PREFIX);
        registry.setUserDestinationPrefix(ApiConstants.WS_USER_PREFIX);
    }

    @Override
    public void configureClientInboundChannel(@NonNull ChannelRegistration registration) {
        registration.interceptors(stompAuthChannelInterceptor);
    }
}
