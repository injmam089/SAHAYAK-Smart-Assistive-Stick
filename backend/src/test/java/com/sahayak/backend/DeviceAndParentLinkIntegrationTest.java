package com.sahayak.backend;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sahayak.backend.modules.auth.RefreshTokenRepository;
import com.sahayak.backend.modules.auth.dto.LoginRequest;
import com.sahayak.backend.modules.auth.dto.RegisterRequest;
import com.sahayak.backend.modules.device.DeviceConfigurationRepository;
import com.sahayak.backend.modules.device.DeviceRepository;
import com.sahayak.backend.modules.device.DeviceStatus;
import com.sahayak.backend.modules.device.dto.UpdateDeviceConfigurationRequest;
import com.sahayak.backend.modules.device.dto.UpdateDeviceStatusRequest;
import com.sahayak.backend.modules.link.ParentLinkStatus;
import com.sahayak.backend.modules.link.ParentUserAuthorizationService;
import com.sahayak.backend.modules.link.ParentUserLinkRepository;
import com.sahayak.backend.modules.link.dto.CreateParentUserLinkRequest;
import com.sahayak.backend.modules.link.dto.UpdateParentUserLinkStatusRequest;
import com.sahayak.backend.modules.telemetry.RealtimeEventService;
import com.sahayak.backend.modules.telemetry.dto.SimulatedTelemetryRequest;
import com.sahayak.backend.modules.user.Role;
import com.sahayak.backend.modules.user.User;
import com.sahayak.backend.modules.user.UserRepository;
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
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.is;
import static org.mockito.Mockito.mock;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Phase 1D Integration Test Suite verifying:
 * 1. Device Registration & Principal Ownership Binding (cannot spoof ownerUserId; duplicate identifier -> 409)
 * 2. Cross-User Device & Configuration Isolation (USER B denied access to USER A's device)
 * 3. Device Configuration Read/Write & Threshold Hierarchy Validation
 * 4. Parent-User Link Lifecycle (PENDING -> ACTIVE -> REVOKED) & Self-Approval Prevention
 * 5. Caregiver Access Policy (PENDING & REVOKED links denied; ACTIVE link grants read-only access)
 * 6. Authorized Realtime Parent Fan-Out over STOMP/WebSocket (ACTIVE parent receives telemetry; PENDING/unlinked parent does not)
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
@ActiveProfiles("test")
class DeviceAndParentLinkIntegrationTest {

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
    private DeviceRepository deviceRepository;

    @Autowired
    private DeviceConfigurationRepository deviceConfigurationRepository;

    @Autowired
    private ParentUserLinkRepository parentUserLinkRepository;

    @Autowired
    private ParentUserAuthorizationService authorizationService;

    @Autowired
    private RealtimeEventService realtimeEventService;

    @Autowired
    private StompAuthChannelInterceptor stompAuthChannelInterceptor;

    @BeforeEach
    void setUp() {
        deviceConfigurationRepository.deleteAll();
        deviceRepository.deleteAll();
        parentUserLinkRepository.deleteAll();
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    @DisplayName("1. Device registration binds ownership strictly to authenticated USER, initializes default config, and rejects duplicates or PARENT registration")
    void shouldRegisterDeviceForAuthenticatedUserAndEnforceUniqueness() throws Exception {
        registerAccount("userA@sahayak.org", "StrongPass#2026", Role.USER);
        registerAccount("userB@sahayak.org", "StrongPass#2026", Role.USER);
        registerAccount("parent1@sahayak.org", "StrongPass#2026", Role.PARENT);

        User userA = userRepository.findByEmail("usera@sahayak.org").orElseThrow();
        User userB = userRepository.findByEmail("userb@sahayak.org").orElseThrow();

        String userAToken = loginAndGetAccessToken("userA@sahayak.org", "StrongPass#2026");
        String parent1Token = loginAndGetAccessToken("parent1@sahayak.org", "StrongPass#2026");

        // Attempt to spoof ownerUserId as userB in the JSON body while authenticated as userA
        Map<String, Object> registerPayloadWithSpoofedOwner = Map.of(
                "deviceIdentifier", "SAHAYAK-ESP32-001",
                "deviceName", "Primary White Cane",
                "ownerUserId", userB.getId().toString()
        );

        MvcResult createResult = mockMvc.perform(post("/api/v1/devices")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(registerPayloadWithSpoofedOwner)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.success", is(true)))
                .andExpect(jsonPath("$.data.deviceIdentifier", is("SAHAYAK-ESP32-001")))
                .andExpect(jsonPath("$.data.ownerUserId", is(userA.getId().toString())))
                .andExpect(jsonPath("$.data.status", is("ACTIVE")))
                .andReturn();

        UUID deviceId = UUID.fromString(
                objectMapper.readTree(createResult.getResponse().getContentAsString())
                        .at("/data/id").asText()
        );

        // Default DeviceConfiguration is automatically created with version 1 and 150/100/50 thresholds
        mockMvc.perform(get("/api/v1/devices/" + deviceId + "/configuration")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userAToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.deviceId", is(deviceId.toString())))
                .andExpect(jsonPath("$.data.normalThresholdCm", is(150)))
                .andExpect(jsonPath("$.data.slowWarningThresholdCm", is(100)))
                .andExpect(jsonPath("$.data.fastWarningThresholdCm", is(50)))
                .andExpect(jsonPath("$.data.configurationVersion", is(1)));

        // Duplicate deviceIdentifier registration -> 409 Conflict
        mockMvc.perform(post("/api/v1/devices")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(registerPayloadWithSpoofedOwner)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.success", is(false)))
                .andExpect(jsonPath("$.status", is(409)));

        // PARENT cannot register a stick device -> 403 Forbidden
        Map<String, Object> parentDeviceAttempt = Map.of(
                "deviceIdentifier", "SAHAYAK-ESP32-002",
                "deviceName", "Parent Attempt Cane"
        );
        mockMvc.perform(post("/api/v1/devices")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + parent1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(parentDeviceAttempt)))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("2. Cross-user isolation & configuration validation: USER B cannot access or modify USER A's device or configuration")
    void shouldIsolateDeviceOwnershipBetweenUsersAndValidateConfiguration() throws Exception {
        registerAccount("owner@sahayak.org", "StrongPass#2026", Role.USER);
        registerAccount("other@sahayak.org", "StrongPass#2026", Role.USER);

        String ownerToken = loginAndGetAccessToken("owner@sahayak.org", "StrongPass#2026");
        String otherToken = loginAndGetAccessToken("other@sahayak.org", "StrongPass#2026");

        UUID deviceId = registerDeviceAndGetId(ownerToken, "SAHAYAK-ISO-001", "Owner Cane");

        // Owner can update device status (ACTIVE -> INACTIVE)
        mockMvc.perform(patch("/api/v1/devices/" + deviceId + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateDeviceStatusRequest(DeviceStatus.INACTIVE))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status", is("INACTIVE")));

        // Owner can update configuration with valid threshold hierarchy (180 > 120 > 60) -> version 2
        UpdateDeviceConfigurationRequest validConfig = new UpdateDeviceConfigurationRequest(
                180, 120, 60, true, 90, true, 75
        );
        mockMvc.perform(put("/api/v1/devices/" + deviceId + "/configuration")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(validConfig)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.normalThresholdCm", is(180)))
                .andExpect(jsonPath("$.data.slowWarningThresholdCm", is(120)))
                .andExpect(jsonPath("$.data.fastWarningThresholdCm", is(60)))
                .andExpect(jsonPath("$.data.configurationVersion", is(2)));

        // Invalid threshold hierarchy (normal <= slowWarning: 100 <= 120) -> 400 Bad Request
        UpdateDeviceConfigurationRequest invalidHierarchy = new UpdateDeviceConfigurationRequest(
                100, 120, 60, true, 90, true, 75
        );
        mockMvc.perform(put("/api/v1/devices/" + deviceId + "/configuration")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(invalidHierarchy)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success", is(false)));

        // Other USER cannot read device, read config, update config, or update status -> 403 Forbidden
        mockMvc.perform(get("/api/v1/devices/" + deviceId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + otherToken))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/v1/devices/" + deviceId + "/configuration")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + otherToken))
                .andExpect(status().isForbidden());

        mockMvc.perform(put("/api/v1/devices/" + deviceId + "/configuration")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + otherToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(validConfig)))
                .andExpect(status().isForbidden());

        mockMvc.perform(patch("/api/v1/devices/" + deviceId + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + otherToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateDeviceStatusRequest(DeviceStatus.DISABLED))))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("3. Parent-User relationship lifecycle (PENDING -> ACTIVE -> REVOKED) strictly governs caregiver device access")
    void shouldEnforceParentUserLinkLifecycleAndCaregiverDeviceAccess() throws Exception {
        registerAccount("stick.user@sahayak.org", "StrongPass#2026", Role.USER);
        registerAccount("caregiver1@sahayak.org", "StrongPass#2026", Role.PARENT);
        registerAccount("caregiver2@sahayak.org", "StrongPass#2026", Role.PARENT);

        User stickUser = userRepository.findByEmail("stick.user@sahayak.org").orElseThrow();
        User caregiver1 = userRepository.findByEmail("caregiver1@sahayak.org").orElseThrow();

        String userToken = loginAndGetAccessToken("stick.user@sahayak.org", "StrongPass#2026");
        String caregiver1Token = loginAndGetAccessToken("caregiver1@sahayak.org", "StrongPass#2026");
        String caregiver2Token = loginAndGetAccessToken("caregiver2@sahayak.org", "StrongPass#2026");

        UUID deviceId = registerDeviceAndGetId(userToken, "SAHAYAK-LINK-001", "Stick User Cane");

        // 1. Before any link: knowing deviceId or userId grants NO access to caregiver1
        assertThat(authorizationService.isParentLinkedToUser(caregiver1.getId(), stickUser.getId())).isFalse();

        mockMvc.perform(get("/api/v1/devices/" + deviceId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + caregiver1Token))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/v1/devices/" + deviceId + "/configuration")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + caregiver1Token))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/v1/devices")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + caregiver1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data", hasSize(0)));

        // 2. Caregiver 1 creates a link request -> created in PENDING state
        MvcResult linkCreateResult = mockMvc.perform(post("/api/v1/parent-links")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + caregiver1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateParentUserLinkRequest(stickUser.getId()))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.parentUserId", is(caregiver1.getId().toString())))
                .andExpect(jsonPath("$.data.userId", is(stickUser.getId().toString())))
                .andExpect(jsonPath("$.data.status", is("PENDING")))
                .andReturn();

        UUID linkId = UUID.fromString(
                objectMapper.readTree(linkCreateResult.getResponse().getContentAsString())
                        .at("/data/id").asText()
        );

        // Duplicate link request for same pair -> 409 Conflict
        mockMvc.perform(post("/api/v1/parent-links")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + caregiver1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateParentUserLinkRequest(stickUser.getId()))))
                .andExpect(status().isConflict());

        // 3. CRITICAL: A PENDING link does NOT authorize caregiver access!
        assertThat(authorizationService.isParentLinkedToUser(caregiver1.getId(), stickUser.getId())).isFalse();

        mockMvc.perform(get("/api/v1/devices/" + deviceId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + caregiver1Token))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/v1/devices/" + deviceId + "/configuration")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + caregiver1Token))
                .andExpect(status().isForbidden());

        // 4. CRITICAL: Caregiver 1 CANNOT self-approve their own PENDING link request -> 403 Forbidden
        mockMvc.perform(patch("/api/v1/parent-links/" + linkId + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + caregiver1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateParentUserLinkStatusRequest(ParentLinkStatus.ACTIVE))))
                .andExpect(status().isForbidden());

        // 5. Target Stick USER approves the link (PENDING -> ACTIVE) -> 200 OK
        mockMvc.perform(patch("/api/v1/parent-links/" + linkId + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateParentUserLinkStatusRequest(ParentLinkStatus.ACTIVE))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status", is("ACTIVE")));

        assertThat(authorizationService.isParentLinkedToUser(caregiver1.getId(), stickUser.getId())).isTrue();

        // 6. Now Caregiver 1 CAN read the linked user's device and configuration
        mockMvc.perform(get("/api/v1/devices")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + caregiver1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data", hasSize(1)))
                .andExpect(jsonPath("$.data[0].id", is(deviceId.toString())));

        mockMvc.perform(get("/api/v1/devices/" + deviceId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + caregiver1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.deviceIdentifier", is("SAHAYAK-LINK-001")));

        mockMvc.perform(get("/api/v1/devices/" + deviceId + "/configuration")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + caregiver1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.normalThresholdCm", is(150)));

        // Caregiver 1 still has READ-ONLY access to device configuration & status (write -> 403 Forbidden)
        UpdateDeviceConfigurationRequest configWriteAttempt = new UpdateDeviceConfigurationRequest(
                170, 110, 55, true, 80, true, 80
        );
        mockMvc.perform(put("/api/v1/devices/" + deviceId + "/configuration")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + caregiver1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(configWriteAttempt)))
                .andExpect(status().isForbidden());

        // Unrelated Caregiver 2 still receives 403 Forbidden
        mockMvc.perform(get("/api/v1/devices/" + deviceId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + caregiver2Token))
                .andExpect(status().isForbidden());

        // 7. Revoke the link (ACTIVE -> REVOKED) -> Caregiver 1 immediately loses access
        mockMvc.perform(patch("/api/v1/parent-links/" + linkId + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateParentUserLinkStatusRequest(ParentLinkStatus.REVOKED))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status", is("REVOKED")));

        assertThat(authorizationService.isParentLinkedToUser(caregiver1.getId(), stickUser.getId())).isFalse();

        mockMvc.perform(get("/api/v1/devices/" + deviceId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + caregiver1Token))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/v1/devices/" + deviceId + "/configuration")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + caregiver1Token))
                .andExpect(status().isForbidden());

        // Cannot transition a REVOKED link back to ACTIVE -> 400 Bad Request
        mockMvc.perform(patch("/api/v1/parent-links/" + linkId + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateParentUserLinkStatusRequest(ParentLinkStatus.ACTIVE))))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("4. End-to-End Realtime Parent Fan-Out: User telemetry fans out ONLY to ACTIVE linked parents over STOMP/WebSocket")
    void shouldFanOutRealtimeEventsOnlyToActiveLinkedParents() throws Exception {
        registerAccount("cane.operator@sahayak.org", "StrongPass#2026", Role.USER);
        registerAccount("other.operator@sahayak.org", "StrongPass#2026", Role.USER);
        registerAccount("active.parent@sahayak.org", "StrongPass#2026", Role.PARENT);
        registerAccount("pending.parent@sahayak.org", "StrongPass#2026", Role.PARENT);

        User caneOperator = userRepository.findByEmail("cane.operator@sahayak.org").orElseThrow();
        User otherOperator = userRepository.findByEmail("other.operator@sahayak.org").orElseThrow();
        User activeParent = userRepository.findByEmail("active.parent@sahayak.org").orElseThrow();
        User pendingParent = userRepository.findByEmail("pending.parent@sahayak.org").orElseThrow();

        String operatorToken = loginAndGetAccessToken("cane.operator@sahayak.org", "StrongPass#2026");
        String otherOperatorToken = loginAndGetAccessToken("other.operator@sahayak.org", "StrongPass#2026");
        String activeParentToken = loginAndGetAccessToken("active.parent@sahayak.org", "StrongPass#2026");
        String pendingParentToken = loginAndGetAccessToken("pending.parent@sahayak.org", "StrongPass#2026");

        // Register device to caneOperator
        registerDeviceAndGetId(operatorToken, "SAHAYAK-FANOUT-101", "Operator Cane 101");

        // Create and activate link for activeParent (PENDING -> ACTIVE)
        UUID activeLinkId = createParentLinkAndGetId(activeParentToken, caneOperator.getId());
        mockMvc.perform(patch("/api/v1/parent-links/" + activeLinkId + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + operatorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateParentUserLinkStatusRequest(ParentLinkStatus.ACTIVE))))
                .andExpect(status().isOk());

        // Create link for pendingParent but leave it in PENDING state
        createParentLinkAndGetId(pendingParentToken, caneOperator.getId());

        // Verify authorized parent topic resolution
        List<String> authorizedTopics = realtimeEventService.resolveAuthorizedParentTopicsForUser(caneOperator.getId());
        assertThat(authorizedTopics).containsExactly("/topic/parent/" + activeParent.getId() + "/events");

        // Verify STOMP device topic authorization for registered device SAHAYAK-FANOUT-101
        MessageChannel mockChannel = mock(MessageChannel.class);
        String registeredDeviceTopic = "/topic/device/SAHAYAK-FANOUT-101/telemetry";

        Message<byte[]> activeParentDeviceSub = buildStompFrame(
                StompCommand.SUBSCRIBE,
                registeredDeviceTopic,
                UserPrincipal.fromUser(activeParent)
        );
        assertThat(stompAuthChannelInterceptor.preSend(activeParentDeviceSub, mockChannel)).isNotNull();

        Message<byte[]> pendingParentDeviceSub = buildStompFrame(
                StompCommand.SUBSCRIBE,
                registeredDeviceTopic,
                UserPrincipal.fromUser(pendingParent)
        );
        assertThatThrownBy(() -> stompAuthChannelInterceptor.preSend(pendingParentDeviceSub, mockChannel))
                .isInstanceOf(AccessDeniedException.class);

        Message<byte[]> otherOperatorDeviceSub = buildStompFrame(
                StompCommand.SUBSCRIBE,
                registeredDeviceTopic,
                UserPrincipal.fromUser(otherOperator)
        );
        assertThatThrownBy(() -> stompAuthChannelInterceptor.preSend(otherOperatorDeviceSub, mockChannel))
                .isInstanceOf(AccessDeniedException.class);

        // Verify otherOperator CANNOT publish telemetry claiming caneOperator's registered device
        SimulatedTelemetryRequest spoofedDeviceTelemetry = new SimulatedTelemetryRequest(
                "SAHAYAK-FANOUT-101", "CONNECTED", 80, 90, 100, "SLOW_WARNING", "corr-spoof"
        );
        mockMvc.perform(post("/api/v1/realtime/telemetry/simulate")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + otherOperatorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(spoofedDeviceTelemetry)))
                .andExpect(status().isForbidden());

        // Connect both activeParent and pendingParent over live WebSocket STOMP
        WebSocketStompClient stompClient = createStompClient();
        String wsUrl = "ws://localhost:" + port + "/ws";

        StompHeaders activeHeaders = new StompHeaders();
        activeHeaders.add(HttpHeaders.AUTHORIZATION, "Bearer " + activeParentToken);
        StompSession activeParentSession = stompClient.connectAsync(
                wsUrl, new WebSocketHttpHeaders(), activeHeaders, new StompSessionHandlerAdapter() {}
        ).get(5, TimeUnit.SECONDS);

        StompHeaders pendingHeaders = new StompHeaders();
        pendingHeaders.add(HttpHeaders.AUTHORIZATION, "Bearer " + pendingParentToken);
        StompSession pendingParentSession = stompClient.connectAsync(
                wsUrl, new WebSocketHttpHeaders(), pendingHeaders, new StompSessionHandlerAdapter() {}
        ).get(5, TimeUnit.SECONDS);

        BlockingQueue<JsonNode> activeParentQueue = new LinkedBlockingQueue<>();
        BlockingQueue<JsonNode> pendingParentQueue = new LinkedBlockingQueue<>();

        activeParentSession.subscribe("/topic/parent/" + activeParent.getId() + "/events", new JsonFrameHandler(activeParentQueue));
        pendingParentSession.subscribe("/topic/parent/" + pendingParent.getId() + "/events", new JsonFrameHandler(pendingParentQueue));

        Thread.sleep(150);

        // caneOperator publishes simulated telemetry for SAHAYAK-FANOUT-101
        SimulatedTelemetryRequest telemetryRequest = new SimulatedTelemetryRequest(
                "SAHAYAK-FANOUT-101", "CONNECTED", 88, 65, 95, "FAST_WARNING", "corr-fanout-101"
        );
        mockMvc.perform(post("/api/v1/realtime/telemetry/simulate")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + operatorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(telemetryRequest)))
                .andExpect(status().isOk());

        // ACTIVE linked parent receives the telemetry event envelope
        JsonNode receivedByActiveParent = activeParentQueue.poll(5, TimeUnit.SECONDS);
        assertThat(receivedByActiveParent).isNotNull();
        assertThat(receivedByActiveParent.path("eventType").asText()).isEqualTo("DEVICE_TELEMETRY");
        assertThat(receivedByActiveParent.path("correlationId").asText()).isEqualTo("corr-fanout-101");
        assertThat(receivedByActiveParent.path("payload").path("deviceId").asText()).isEqualTo("SAHAYAK-FANOUT-101");
        assertThat(receivedByActiveParent.path("payload").path("hazardLevel").asText()).isEqualTo("FAST_WARNING");

        // PENDING parent receives nothing
        JsonNode receivedByPendingParent = pendingParentQueue.poll(500, TimeUnit.MILLISECONDS);
        assertThat(receivedByPendingParent).isNull();

        activeParentSession.disconnect();
        pendingParentSession.disconnect();
        stompClient.stop();
    }

    private UUID registerDeviceAndGetId(String userToken, String identifier, String name) throws Exception {
        Map<String, String> body = Map.of("deviceIdentifier", identifier, "deviceName", name);
        MvcResult res = mockMvc.perform(post("/api/v1/devices")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isCreated())
                .andReturn();
        return UUID.fromString(
                objectMapper.readTree(res.getResponse().getContentAsString()).at("/data/id").asText()
        );
    }

    private UUID createParentLinkAndGetId(String parentToken, UUID targetUserId) throws Exception {
        MvcResult res = mockMvc.perform(post("/api/v1/parent-links")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + parentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateParentUserLinkRequest(targetUserId))))
                .andExpect(status().isCreated())
                .andReturn();
        return UUID.fromString(
                objectMapper.readTree(res.getResponse().getContentAsString()).at("/data/id").asText()
        );
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
                "Phase 1D Test Account",
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

    private static class JsonFrameHandler implements StompFrameHandler {
        private final BlockingQueue<JsonNode> queue;

        JsonFrameHandler(BlockingQueue<JsonNode> queue) {
            this.queue = queue;
        }

        @Override
        public Type getPayloadType(StompHeaders headers) {
            return JsonNode.class;
        }

        @Override
        public void handleFrame(StompHeaders headers, Object payload) {
            if (payload instanceof JsonNode node) {
                queue.offer(node);
            }
        }
    }
}
