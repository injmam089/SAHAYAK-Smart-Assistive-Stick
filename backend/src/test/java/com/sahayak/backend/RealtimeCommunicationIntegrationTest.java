package com.sahayak.backend;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sahayak.backend.common.dto.EventSource;
import com.sahayak.backend.common.dto.RealtimeEventEnvelope;
import com.sahayak.backend.common.dto.RealtimeEventType;
import com.sahayak.backend.modules.auth.RefreshTokenRepository;
import com.sahayak.backend.modules.auth.dto.LoginRequest;
import com.sahayak.backend.modules.auth.dto.RegisterRequest;
import com.sahayak.backend.modules.telemetry.RealtimeSessionRegistry;
import com.sahayak.backend.modules.telemetry.dto.SimulatedTelemetryRequest;
import com.sahayak.backend.modules.telemetry.dto.TelemetryEventDto;
import com.sahayak.backend.modules.user.Role;
import com.sahayak.backend.modules.user.User;
import com.sahayak.backend.modules.user.UserRepository;
import com.sahayak.backend.security.JwtTokenProvider;
import com.sahayak.backend.security.StompAuthChannelInterceptor;
import com.sahayak.backend.security.UserPrincipal;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.converter.MappingJackson2MessageConverter;
import org.springframework.messaging.simp.stomp.*;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.web.socket.WebSocketHttpHeaders;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.messaging.WebSocketStompClient;

import java.lang.reflect.Type;
import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.hamcrest.Matchers.is;
import static org.mockito.Mockito.mock;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Phase 1C Integration Test Suite verifying:
 * - RealtimeEventEnvelope & TelemetryEventDto serialization/deserialization
 * - STOMP/WebSocket authentication & destination authorization boundaries
 * - End-to-end authenticated STOMP connection, subscription, and simulated telemetry delivery
 * - Session registry connect/disconnect tracking
 * - REST communication foundation endpoints (/api/v1/realtime/status, /api/v1/realtime/telemetry/simulate)
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
@ActiveProfiles("test")
class RealtimeCommunicationIntegrationTest {

    @LocalServerPort
    private int port;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private StompAuthChannelInterceptor stompAuthChannelInterceptor;

    @Autowired
    private RealtimeSessionRegistry sessionRegistry;

    @BeforeEach
    void setUp() {
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    @DisplayName("1. RealtimeEventEnvelope and TelemetryEventDto serialize and deserialize cleanly")
    void shouldSerializeAndDeserializeEventEnvelopeAndTelemetryDto() throws Exception {
        TelemetryEventDto telemetry = new TelemetryEventDto(
                "SIM-STICK-001",
                Instant.parse("2026-10-13T02:00:00Z"),
                "CONNECTED",
                92,
                115,
                98,
                "SLOW_WARNING",
                true
        );

        RealtimeEventEnvelope<TelemetryEventDto> envelope = RealtimeEventEnvelope.of(
                RealtimeEventType.DEVICE_TELEMETRY,
                EventSource.SIMULATED_DEVICE,
                "corr-12345",
                telemetry
        );

        String json = objectMapper.writeValueAsString(envelope);
        assertThat(json).contains("DEVICE_TELEMETRY");
        assertThat(json).contains("SIMULATED_DEVICE");
        assertThat(json).contains("SIM-STICK-001");

        RealtimeEventEnvelope<TelemetryEventDto> deserialized = objectMapper.readValue(
                json,
                new TypeReference<RealtimeEventEnvelope<TelemetryEventDto>>() {}
        );

        assertThat(deserialized.eventId()).isEqualTo(envelope.eventId());
        assertThat(deserialized.eventType()).isEqualTo(RealtimeEventType.DEVICE_TELEMETRY);
        assertThat(deserialized.source()).isEqualTo(EventSource.SIMULATED_DEVICE);
        assertThat(deserialized.correlationId()).isEqualTo("corr-12345");
        assertThat(deserialized.payload().deviceId()).isEqualTo("SIM-STICK-001");
        assertThat(deserialized.payload().batteryPercentage()).isEqualTo(92);
        assertThat(deserialized.payload().forwardDistanceCm()).isEqualTo(115);
        assertThat(deserialized.payload().hazardLevel()).isEqualTo("SLOW_WARNING");
        assertThat(deserialized.payload().simulated()).isTrue();
    }

    @Test
    @DisplayName("2. Unauthenticated STOMP CONNECT, SUBSCRIBE, and SEND frames are rejected")
    void shouldRejectUnauthenticatedStompFrames() {
        MessageChannel mockChannel = mock(MessageChannel.class);

        // 1. CONNECT without Authorization header
        StompHeaderAccessor connectAccessor = StompHeaderAccessor.create(StompCommand.CONNECT);
        connectAccessor.setSessionId("unauth-sess-1");
        connectAccessor.setLeaveMutable(true);
        Message<byte[]> unauthConnect = MessageBuilder.createMessage(new byte[0], connectAccessor.getMessageHeaders());

        assertThatThrownBy(() -> stompAuthChannelInterceptor.preSend(unauthConnect, mockChannel))
                .isInstanceOf(AccessDeniedException.class)
                .hasMessageContaining("Authentication is required");

        // 2. CONNECT with invalid JWT
        StompHeaderAccessor invalidTokenAccessor = StompHeaderAccessor.create(StompCommand.CONNECT);
        invalidTokenAccessor.setSessionId("unauth-sess-2");
        invalidTokenAccessor.setNativeHeader(HttpHeaders.AUTHORIZATION, "Bearer invalid.jwt.token");
        invalidTokenAccessor.setLeaveMutable(true);
        Message<byte[]> invalidConnect = MessageBuilder.createMessage(new byte[0], invalidTokenAccessor.getMessageHeaders());

        assertThatThrownBy(() -> stompAuthChannelInterceptor.preSend(invalidConnect, mockChannel))
                .isInstanceOf(AccessDeniedException.class)
                .hasMessageContaining("Invalid or expired");

        // 3. SUBSCRIBE without authenticated user principal
        StompHeaderAccessor subAccessor = StompHeaderAccessor.create(StompCommand.SUBSCRIBE);
        subAccessor.setSessionId("unauth-sess-3");
        subAccessor.setDestination("/topic/system/status");
        subAccessor.setLeaveMutable(true);
        Message<byte[]> unauthSub = MessageBuilder.createMessage(new byte[0], subAccessor.getMessageHeaders());

        assertThatThrownBy(() -> stompAuthChannelInterceptor.preSend(unauthSub, mockChannel))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    @DisplayName("3. STOMP destination authorization enforces strict role and user-ownership boundaries")
    void shouldEnforceStompSubscriptionAndSendAuthorizationBoundaries() throws Exception {
        registerAccount("user1@sahayak.org", "StrongPass#2026", Role.USER);
        registerAccount("user2@sahayak.org", "StrongPass#2026", Role.USER);
        registerAccount("parent1@sahayak.org", "StrongPass#2026", Role.PARENT);

        User user1 = userRepository.findByEmail("user1@sahayak.org").orElseThrow();
        User user2 = userRepository.findByEmail("user2@sahayak.org").orElseThrow();
        User parent1 = userRepository.findByEmail("parent1@sahayak.org").orElseThrow();

        UserPrincipal user1Principal = UserPrincipal.fromUser(user1);
        UserPrincipal parent1Principal = UserPrincipal.fromUser(parent1);

        MessageChannel mockChannel = mock(MessageChannel.class);

        // A. USER 1 can subscribe to own user topic (/topic/user/{user1.id}/events)
        Message<byte[]> validUserSub = buildStompFrame(
                StompCommand.SUBSCRIBE,
                "/topic/user/" + user1.getId() + "/events",
                user1Principal
        );
        assertThat(stompAuthChannelInterceptor.preSend(validUserSub, mockChannel)).isNotNull();

        // B. USER 1 CANNOT subscribe to USER 2's topic (/topic/user/{user2.id}/events)
        Message<byte[]> crossUserSub = buildStompFrame(
                StompCommand.SUBSCRIBE,
                "/topic/user/" + user2.getId() + "/events",
                user1Principal
        );
        assertThatThrownBy(() -> stompAuthChannelInterceptor.preSend(crossUserSub, mockChannel))
                .isInstanceOf(AccessDeniedException.class);

        // C. USER 1 CANNOT subscribe to PARENT topic (/topic/parent/{parent1.id}/events)
        Message<byte[]> userToParentSub = buildStompFrame(
                StompCommand.SUBSCRIBE,
                "/topic/parent/" + parent1.getId() + "/events",
                user1Principal
        );
        assertThatThrownBy(() -> stompAuthChannelInterceptor.preSend(userToParentSub, mockChannel))
                .isInstanceOf(AccessDeniedException.class);

        // D. PARENT 1 can subscribe to own parent topic (/topic/parent/{parent1.id}/events)
        Message<byte[]> validParentSub = buildStompFrame(
                StompCommand.SUBSCRIBE,
                "/topic/parent/" + parent1.getId() + "/events",
                parent1Principal
        );
        assertThat(stompAuthChannelInterceptor.preSend(validParentSub, mockChannel)).isNotNull();

        // E. PARENT 1 CANNOT subscribe to USER topic (/topic/user/{user1.id}/events) directly
        Message<byte[]> parentToUserSub = buildStompFrame(
                StompCommand.SUBSCRIBE,
                "/topic/user/" + user1.getId() + "/events",
                parent1Principal
        );
        assertThatThrownBy(() -> stompAuthChannelInterceptor.preSend(parentToUserSub, mockChannel))
                .isInstanceOf(AccessDeniedException.class);

        // F. PARENT 1 CANNOT SEND simulated device telemetry to /app/telemetry.simulate
        Message<byte[]> parentSendTelemetry = buildStompFrame(
                StompCommand.SEND,
                "/app/telemetry.simulate",
                parent1Principal
        );
        assertThatThrownBy(() -> stompAuthChannelInterceptor.preSend(parentSendTelemetry, mockChannel))
                .isInstanceOf(AccessDeniedException.class);

        // G. Arbitrary unapproved topic (/topic/public/random) is denied by default
        Message<byte[]> unknownTopicSub = buildStompFrame(
                StompCommand.SUBSCRIBE,
                "/topic/public/random",
                user1Principal
        );
        assertThatThrownBy(() -> stompAuthChannelInterceptor.preSend(unknownTopicSub, mockChannel))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    @DisplayName("4. End-to-End WebSocket/STOMP: Authenticated client connects, subscribes, and receives simulated telemetry event")
    void shouldConnectOverStompAndReceiveSimulatedTelemetryEvent() throws Exception {
        registerAccount("live.user@sahayak.org", "StrongPass#2026", Role.USER);
        User user = userRepository.findByEmail("live.user@sahayak.org").orElseThrow();
        String accessToken = loginAndGetAccessToken("live.user@sahayak.org", "StrongPass#2026");

        WebSocketStompClient stompClient = createStompClient();
        StompHeaders connectHeaders = new StompHeaders();
        connectHeaders.add(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken);

        String wsUrl = "ws://localhost:" + port + "/ws";
        StompSession session = stompClient.connectAsync(
                wsUrl,
                new WebSocketHttpHeaders(),
                connectHeaders,
                new StompSessionHandlerAdapter() {}
        ).get(5, TimeUnit.SECONDS);

        assertThat(session.isConnected()).isTrue();
        assertThat(sessionRegistry.isUserConnected(user.getId())).isTrue();

        BlockingQueue<JsonNode> receivedEvents = new LinkedBlockingQueue<>();
        String userTopic = "/topic/user/" + user.getId() + "/events";

        session.subscribe(userTopic, new StompFrameHandler() {
            @Override
            public Type getPayloadType(StompHeaders headers) {
                return JsonNode.class;
            }

            @Override
            public void handleFrame(StompHeaders headers, Object payload) {
                if (payload instanceof JsonNode node) {
                    receivedEvents.offer(node);
                }
            }
        });

        // Allow subscription registration to complete on broker
        Thread.sleep(150);

        SimulatedTelemetryRequest telemetryRequest = new SimulatedTelemetryRequest(
                "SIM-ESP32-CANE-01",
                "CONNECTED",
                85,
                75,
                110,
                "FAST_WARNING",
                "corr-e2e-001"
        );

        // Trigger simulated telemetry via REST endpoint and verify STOMP subscriber receives it
        mockMvc.perform(post("/api/v1/realtime/telemetry/simulate")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(telemetryRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success", is(true)))
                .andExpect(jsonPath("$.data.eventType", is("DEVICE_TELEMETRY")))
                .andExpect(jsonPath("$.data.source", is("SIMULATED_DEVICE")))
                .andExpect(jsonPath("$.data.payload.deviceId", is("SIM-ESP32-CANE-01")))
                .andExpect(jsonPath("$.data.payload.simulated", is(true)));

        JsonNode eventNode = receivedEvents.poll(5, TimeUnit.SECONDS);
        assertThat(eventNode).isNotNull();
        assertThat(eventNode.path("eventType").asText()).isEqualTo("DEVICE_TELEMETRY");
        assertThat(eventNode.path("source").asText()).isEqualTo("SIMULATED_DEVICE");
        assertThat(eventNode.path("correlationId").asText()).isEqualTo("corr-e2e-001");
        assertThat(eventNode.path("payload").path("deviceId").asText()).isEqualTo("SIM-ESP32-CANE-01");
        assertThat(eventNode.path("payload").path("batteryPercentage").asInt()).isEqualTo(85);
        assertThat(eventNode.path("payload").path("forwardDistanceCm").asInt()).isEqualTo(75);
        assertThat(eventNode.path("payload").path("hazardLevel").asText()).isEqualTo("FAST_WARNING");
        assertThat(eventNode.path("payload").path("simulated").asBoolean()).isTrue();

        session.disconnect();
        stompClient.stop();
    }

    @Test
    @DisplayName("5. End-to-End WebSocket/STOMP: Unauthenticated STOMP connection attempt fails")
    void shouldFailLiveStompConnectionWithoutToken() {
        WebSocketStompClient stompClient = createStompClient();
        String wsUrl = "ws://localhost:" + port + "/ws";

        assertThatThrownBy(() ->
                stompClient.connectAsync(
                        wsUrl,
                        new WebSocketHttpHeaders(),
                        new StompHeaders(), // No Authorization header
                        new StompSessionHandlerAdapter() {}
                ).get(5, TimeUnit.SECONDS)
        ).isInstanceOf(ExecutionException.class);

        stompClient.stop();
    }

    @Test
    @DisplayName("6. REST /api/v1/realtime/status and /api/v1/realtime/telemetry/simulate enforce authentication, RBAC, and validation")
    void shouldEnforceRestRealtimeSecurityAndValidation() throws Exception {
        // 1. Unauthenticated request -> 401
        mockMvc.perform(get("/api/v1/realtime/status"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success", is(false)));

        registerAccount("status.user@sahayak.org", "StrongPass#2026", Role.USER);
        registerAccount("status.parent@sahayak.org", "StrongPass#2026", Role.PARENT);

        String userToken = loginAndGetAccessToken("status.user@sahayak.org", "StrongPass#2026");
        String parentToken = loginAndGetAccessToken("status.parent@sahayak.org", "StrongPass#2026");

        // 2. Authenticated status check -> 200 OK
        mockMvc.perform(get("/api/v1/realtime/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success", is(true)))
                .andExpect(jsonPath("$.data.brokerEnabled", is(true)))
                .andExpect(jsonPath("$.data.websocketEndpoint", is("/ws")))
                .andExpect(jsonPath("$.data.deviceTransportMode", is("SIMULATED")));

        // 3. PARENT cannot invoke USER-only /api/v1/realtime/telemetry/simulate -> 403 Forbidden
        SimulatedTelemetryRequest validRequest = new SimulatedTelemetryRequest(
                "SIM-DEV-01", "CONNECTED", 90, 120, 100, "NORMAL", null
        );
        mockMvc.perform(post("/api/v1/realtime/telemetry/simulate")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + parentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(validRequest)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success", is(false)))
                .andExpect(jsonPath("$.status", is(403)));

        // 4. Invalid telemetry payload (blank deviceId, battery > 100) -> 400 Bad Request
        SimulatedTelemetryRequest invalidRequest = new SimulatedTelemetryRequest(
                "", "CONNECTED", 150, -10, 100, "NORMAL", null
        );
        mockMvc.perform(post("/api/v1/realtime/telemetry/simulate")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(invalidRequest)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success", is(false)))
                .andExpect(jsonPath("$.validationErrors.deviceId").exists())
                .andExpect(jsonPath("$.validationErrors.batteryPercentage").exists())
                .andExpect(jsonPath("$.validationErrors.forwardDistanceCm").exists());
    }

    private Message<byte[]> buildStompFrame(
            StompCommand command,
            String destination,
            UserPrincipal principal
    ) {
        StompHeaderAccessor accessor = StompHeaderAccessor.create(command);
        accessor.setSessionId("test-sess-" + UUID.randomUUID());
        accessor.setDestination(destination);
        if (principal != null) {
            accessor.setUser(new UsernamePasswordAuthenticationToken(
                    principal, null, principal.getAuthorities()
            ));
        }
        accessor.setLeaveMutable(true);
        return MessageBuilder.createMessage(new byte[0], accessor.getMessageHeaders());
    }

    private WebSocketStompClient createStompClient() {
        WebSocketStompClient stompClient = new WebSocketStompClient(new StandardWebSocketClient());
        MappingJackson2MessageConverter converter = new MappingJackson2MessageConverter();
        converter.setObjectMapper(objectMapper);
        stompClient.setMessageConverter(converter);
        return stompClient;
    }

    private void registerAccount(String email, String password, Role role) throws Exception {
        RegisterRequest registerRequest = new RegisterRequest(
                email,
                password,
                "Realtime Test Account",
                "+919888888888",
                role
        );
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(registerRequest)))
                .andExpect(status().isCreated());
    }

    private String loginAndGetAccessToken(String email, String password) throws Exception {
        LoginRequest loginRequest = new LoginRequest(email, password);
        MvcResult result = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode root = objectMapper.readTree(result.getResponse().getContentAsString());
        return root.at("/data/accessToken").asText();
    }
}
