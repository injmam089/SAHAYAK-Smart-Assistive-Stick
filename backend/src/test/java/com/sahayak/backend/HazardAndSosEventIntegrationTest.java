package com.sahayak.backend;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sahayak.backend.common.dto.EventSource;
import com.sahayak.backend.modules.auth.RefreshTokenRepository;
import com.sahayak.backend.modules.auth.dto.LoginRequest;
import com.sahayak.backend.modules.auth.dto.RegisterRequest;
import com.sahayak.backend.modules.device.DeviceConfigurationRepository;
import com.sahayak.backend.modules.device.DeviceRepository;
import com.sahayak.backend.modules.event.*;
import com.sahayak.backend.modules.event.dto.CreateHazardEventRequest;
import com.sahayak.backend.modules.event.dto.TriggerSosEventRequest;
import com.sahayak.backend.modules.event.dto.UpdateSosEventStatusRequest;
import com.sahayak.backend.modules.link.ParentLinkStatus;
import com.sahayak.backend.modules.link.ParentUserLinkRepository;
import com.sahayak.backend.modules.link.dto.CreateParentUserLinkRequest;
import com.sahayak.backend.modules.link.dto.UpdateParentUserLinkStatusRequest;
import com.sahayak.backend.modules.user.Role;
import com.sahayak.backend.modules.user.User;
import com.sahayak.backend.modules.user.UserRepository;
import com.sahayak.backend.security.StompAuthChannelInterceptor;
import com.sahayak.backend.security.UserPrincipal;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
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
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.hamcrest.Matchers.*;
import static org.mockito.Mockito.mock;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Phase 1E Integration Test Suite verifying:
 * 1. V4 Flyway migration, hazard_events & sos_events schema, foreign keys, and constraints
 * 2. HazardEvent creation, ownership isolation, idempotency, and caregiver read access (ACTIVE vs PENDING/REVOKED/unrelated)
 * 3. SosEvent triggering, ownership isolation, idempotency, and caregiver read access
 * 4. Controlled SOS lifecycle transitions (TRIGGERED -> ACKNOWLEDGED -> RESOLVED, TRIGGERED -> CANCELLED) and rejection of invalid/reopen transitions
 * 5. End-to-End Realtime Hazard & SOS fan-out over STOMP/WebSocket with strict zero-leakage guarantees
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
@ActiveProfiles("test")
class HazardAndSosEventIntegrationTest {

    @LocalServerPort
    private int port;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private Flyway flyway;

    @Autowired
    private JdbcTemplate jdbcTemplate;

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
    private HazardEventRepository hazardEventRepository;

    @Autowired
    private SosEventRepository sosEventRepository;

    @Autowired
    private StompAuthChannelInterceptor stompAuthChannelInterceptor;

    @BeforeEach
    void setUp() {
        sosEventRepository.deleteAll();
        hazardEventRepository.deleteAll();
        deviceConfigurationRepository.deleteAll();
        deviceRepository.deleteAll();
        parentUserLinkRepository.deleteAll();
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    @DisplayName("1. V4 Flyway migration applies cleanly and enforces hazard_events and sos_events table constraints and foreign keys")
    void shouldVerifyV4MigrationAndDatabaseConstraints() {
        assertThat(flyway.info().current().getVersion().getVersion()).isEqualTo("4");

        Integer hazardCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM hazard_events", Integer.class);
        Integer sosCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM sos_events", Integer.class);
        assertThat(hazardCount).isZero();
        assertThat(sosCount).isZero();

        // Verify foreign key constraint: cannot insert hazard_event for nonexistent device/user
        assertThatThrownBy(() -> jdbcTemplate.update(
                "INSERT INTO hazard_events (id, device_id, user_id, hazard_type, hazard_level, distance_cm, source, event_timestamp) " +
                        "VALUES (?, ?, ?, 'FORWARD_OBSTACLE', 'CRITICAL', 35, 'SIMULATED_DEVICE', CURRENT_TIMESTAMP)",
                UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID()
        )).isInstanceOf(Exception.class);

        // Verify foreign key constraint: cannot insert sos_event for nonexistent device/user
        assertThatThrownBy(() -> jdbcTemplate.update(
                "INSERT INTO sos_events (id, device_id, user_id, status, source, triggered_at) " +
                        "VALUES (?, ?, ?, 'TRIGGERED', 'SIMULATED_DEVICE', CURRENT_TIMESTAMP)",
                UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID()
        )).isInstanceOf(Exception.class);
    }

    @Test
    @DisplayName("2. HazardEvent domain: Owner creates/reads hazards, idempotency prevents duplicates, and only ACTIVE linked parent can read")
    void shouldEnforceHazardEventOwnershipAndCaregiverAccess() throws Exception {
        registerAccount("hazard.userA@sahayak.org", "StrongPass#2026", Role.USER);
        registerAccount("hazard.userB@sahayak.org", "StrongPass#2026", Role.USER);
        registerAccount("hazard.parent.active@sahayak.org", "StrongPass#2026", Role.PARENT);
        registerAccount("hazard.parent.pending@sahayak.org", "StrongPass#2026", Role.PARENT);
        registerAccount("hazard.parent.revoked@sahayak.org", "StrongPass#2026", Role.PARENT);
        registerAccount("hazard.parent.unrelated@sahayak.org", "StrongPass#2026", Role.PARENT);

        User userA = userRepository.findByEmail("hazard.usera@sahayak.org").orElseThrow();

        String userAToken = loginAndGetAccessToken("hazard.userA@sahayak.org", "StrongPass#2026");
        String userBToken = loginAndGetAccessToken("hazard.userB@sahayak.org", "StrongPass#2026");
        String activeParentToken = loginAndGetAccessToken("hazard.parent.active@sahayak.org", "StrongPass#2026");
        String pendingParentToken = loginAndGetAccessToken("hazard.parent.pending@sahayak.org", "StrongPass#2026");
        String revokedParentToken = loginAndGetAccessToken("hazard.parent.revoked@sahayak.org", "StrongPass#2026");
        String unrelatedParentToken = loginAndGetAccessToken("hazard.parent.unrelated@sahayak.org", "StrongPass#2026");

        UUID deviceAId = registerDeviceAndGetId(userAToken, "SAHAYAK-HAZ-001", "User A Cane");

        // Setup parent relationships:
        // 1. activeParent -> ACTIVE
        UUID activeLinkId = createParentLinkAndGetId(activeParentToken, userA.getId());
        updateParentLinkStatus(userAToken, activeLinkId, ParentLinkStatus.ACTIVE);

        // 2. pendingParent -> remains PENDING
        createParentLinkAndGetId(pendingParentToken, userA.getId());

        // 3. revokedParent -> PENDING -> REVOKED
        UUID revokedLinkId = createParentLinkAndGetId(revokedParentToken, userA.getId());
        updateParentLinkStatus(userAToken, revokedLinkId, ParentLinkStatus.REVOKED);

        // Owner USER A creates a HazardEvent -> 201 Created
        CreateHazardEventRequest createHazard = new CreateHazardEventRequest(
                HazardType.FORWARD_OBSTACLE,
                HazardLevel.CRITICAL,
                38,
                EventSource.SIMULATED_DEVICE,
                "haz-corr-001"
        );

        MvcResult createdHazardRes = mockMvc.perform(post("/api/v1/devices/" + deviceAId + "/hazards")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(createHazard)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.success", is(true)))
                .andExpect(jsonPath("$.data.deviceId", is(deviceAId.toString())))
                .andExpect(jsonPath("$.data.userId", is(userA.getId().toString())))
                .andExpect(jsonPath("$.data.hazardType", is("FORWARD_OBSTACLE")))
                .andExpect(jsonPath("$.data.hazardLevel", is("CRITICAL")))
                .andExpect(jsonPath("$.data.distanceCm", is(38)))
                .andExpect(jsonPath("$.data.correlationId", is("haz-corr-001")))
                .andReturn();

        String firstHazardId = objectMapper.readTree(createdHazardRes.getResponse().getContentAsString())
                .at("/data/id").asText();

        // Duplicate submission with same correlationId returns the same HazardEvent idempotently without creating a 2nd row
        mockMvc.perform(post("/api/v1/devices/" + deviceAId + "/hazards")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(createHazard)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.id", is(firstHazardId)));

        assertThat(hazardEventRepository.findByDeviceIdOrderByEventTimestampDesc(deviceAId)).hasSize(1);

        // Another USER B CANNOT create a hazard for USER A's device -> 403 Forbidden
        mockMvc.perform(post("/api/v1/devices/" + deviceAId + "/hazards")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userBToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(createHazard)))
                .andExpect(status().isForbidden());

        // Owner USER A CAN read own device hazards -> 200 OK
        mockMvc.perform(get("/api/v1/devices/" + deviceAId + "/hazards")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userAToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data", hasSize(1)))
                .andExpect(jsonPath("$.data[0].id", is(firstHazardId)));

        // Unrelated USER B CANNOT read USER A's hazards -> 403 Forbidden
        mockMvc.perform(get("/api/v1/devices/" + deviceAId + "/hazards")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userBToken))
                .andExpect(status().isForbidden());

        // ACTIVE Parent CAN read linked user's hazards -> 200 OK
        mockMvc.perform(get("/api/v1/devices/" + deviceAId + "/hazards")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + activeParentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data", hasSize(1)))
                .andExpect(jsonPath("$.data[0].id", is(firstHazardId)));

        // PENDING Parent CANNOT read hazards -> 403 Forbidden
        mockMvc.perform(get("/api/v1/devices/" + deviceAId + "/hazards")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + pendingParentToken))
                .andExpect(status().isForbidden());

        // REVOKED Parent CANNOT read hazards -> 403 Forbidden
        mockMvc.perform(get("/api/v1/devices/" + deviceAId + "/hazards")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + revokedParentToken))
                .andExpect(status().isForbidden());

        // Unrelated Parent CANNOT read hazards -> 403 Forbidden
        mockMvc.perform(get("/api/v1/devices/" + deviceAId + "/hazards")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + unrelatedParentToken))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("3. SosEvent creation, ownership isolation, and caregiver read access (ACTIVE vs PENDING/REVOKED/unrelated)")
    void shouldEnforceSosEventOwnershipAndCaregiverReadAccess() throws Exception {
        registerAccount("sos.userA@sahayak.org", "StrongPass#2026", Role.USER);
        registerAccount("sos.userB@sahayak.org", "StrongPass#2026", Role.USER);
        registerAccount("sos.parent.active@sahayak.org", "StrongPass#2026", Role.PARENT);
        registerAccount("sos.parent.pending@sahayak.org", "StrongPass#2026", Role.PARENT);
        registerAccount("sos.parent.revoked@sahayak.org", "StrongPass#2026", Role.PARENT);
        registerAccount("sos.parent.unrelated@sahayak.org", "StrongPass#2026", Role.PARENT);

        User userA = userRepository.findByEmail("sos.usera@sahayak.org").orElseThrow();

        String userAToken = loginAndGetAccessToken("sos.userA@sahayak.org", "StrongPass#2026");
        String userBToken = loginAndGetAccessToken("sos.userB@sahayak.org", "StrongPass#2026");
        String activeParentToken = loginAndGetAccessToken("sos.parent.active@sahayak.org", "StrongPass#2026");
        String pendingParentToken = loginAndGetAccessToken("sos.parent.pending@sahayak.org", "StrongPass#2026");
        String revokedParentToken = loginAndGetAccessToken("sos.parent.revoked@sahayak.org", "StrongPass#2026");
        String unrelatedParentToken = loginAndGetAccessToken("sos.parent.unrelated@sahayak.org", "StrongPass#2026");

        UUID deviceAId = registerDeviceAndGetId(userAToken, "SAHAYAK-SOS-001", "User A SOS Cane");

        // Setup parent relationships
        UUID activeLinkId = createParentLinkAndGetId(activeParentToken, userA.getId());
        updateParentLinkStatus(userAToken, activeLinkId, ParentLinkStatus.ACTIVE);

        createParentLinkAndGetId(pendingParentToken, userA.getId());

        UUID revokedLinkId = createParentLinkAndGetId(revokedParentToken, userA.getId());
        updateParentLinkStatus(userAToken, revokedLinkId, ParentLinkStatus.REVOKED);

        // Another USER B CANNOT trigger SOS for USER A's device -> 403 Forbidden
        TriggerSosEventRequest triggerReq = new TriggerSosEventRequest(EventSource.SIMULATED_DEVICE, "sos-corr-001");
        mockMvc.perform(post("/api/v1/devices/" + deviceAId + "/sos")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userBToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(triggerReq)))
                .andExpect(status().isForbidden());

        // Owner USER A triggers SOS -> 201 Created in TRIGGERED state
        MvcResult sosCreateRes = mockMvc.perform(post("/api/v1/devices/" + deviceAId + "/sos")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(triggerReq)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.deviceId", is(deviceAId.toString())))
                .andExpect(jsonPath("$.data.userId", is(userA.getId().toString())))
                .andExpect(jsonPath("$.data.status", is("TRIGGERED")))
                .andExpect(jsonPath("$.data.correlationId", is("sos-corr-001")))
                .andReturn();

        UUID sosEventId = UUID.fromString(
                objectMapper.readTree(sosCreateRes.getResponse().getContentAsString()).at("/data/id").asText()
        );

        // Duplicate physical button press (same correlationId or repeated unacknowledged trigger) returns existing active SOS
        mockMvc.perform(post("/api/v1/devices/" + deviceAId + "/sos")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(triggerReq)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.id", is(sosEventId.toString())));

        assertThat(sosEventRepository.findByDeviceIdOrderByTriggeredAtDesc(deviceAId)).hasSize(1);

        // ACTIVE Parent CAN read linked SOS list and single SOS by ID -> 200 OK
        mockMvc.perform(get("/api/v1/devices/" + deviceAId + "/sos-events")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + activeParentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data", hasSize(1)))
                .andExpect(jsonPath("$.data[0].id", is(sosEventId.toString())));

        mockMvc.perform(get("/api/v1/sos-events/" + sosEventId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + activeParentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id", is(sosEventId.toString())));

        // PENDING Parent CANNOT read SOS list or single SOS -> 403 Forbidden
        mockMvc.perform(get("/api/v1/devices/" + deviceAId + "/sos-events")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + pendingParentToken))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/v1/sos-events/" + sosEventId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + pendingParentToken))
                .andExpect(status().isForbidden());

        // REVOKED Parent CANNOT read SOS -> 403 Forbidden
        mockMvc.perform(get("/api/v1/devices/" + deviceAId + "/sos-events")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + revokedParentToken))
                .andExpect(status().isForbidden());

        // Unrelated Parent CANNOT read SOS -> 403 Forbidden
        mockMvc.perform(get("/api/v1/devices/" + deviceAId + "/sos-events")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + unrelatedParentToken))
                .andExpect(status().isForbidden());

        // Unrelated USER B CANNOT read SOS -> 403 Forbidden
        mockMvc.perform(get("/api/v1/devices/" + deviceAId + "/sos-events")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userBToken))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("4. SOS Lifecycle: Enforces TRIGGERED -> ACKNOWLEDGED -> RESOLVED, TRIGGERED -> CANCELLED, and rejects invalid/reopen transitions")
    void shouldEnforceControlledSosLifecycleTransitions() throws Exception {
        registerAccount("lifecycle.user@sahayak.org", "StrongPass#2026", Role.USER);
        registerAccount("lifecycle.parent.active@sahayak.org", "StrongPass#2026", Role.PARENT);
        registerAccount("lifecycle.parent.pending@sahayak.org", "StrongPass#2026", Role.PARENT);

        User stickUser = userRepository.findByEmail("lifecycle.user@sahayak.org").orElseThrow();
        User activeParent = userRepository.findByEmail("lifecycle.parent.active@sahayak.org").orElseThrow();

        String userToken = loginAndGetAccessToken("lifecycle.user@sahayak.org", "StrongPass#2026");
        String activeParentToken = loginAndGetAccessToken("lifecycle.parent.active@sahayak.org", "StrongPass#2026");
        String pendingParentToken = loginAndGetAccessToken("lifecycle.parent.pending@sahayak.org", "StrongPass#2026");

        UUID deviceId = registerDeviceAndGetId(userToken, "SAHAYAK-LIFE-001", "Lifecycle Cane");

        UUID activeLinkId = createParentLinkAndGetId(activeParentToken, stickUser.getId());
        updateParentLinkStatus(userToken, activeLinkId, ParentLinkStatus.ACTIVE);
        createParentLinkAndGetId(pendingParentToken, stickUser.getId());

        // --- FLOW A: TRIGGERED -> ACKNOWLEDGED -> RESOLVED ---
        MvcResult sos1Res = mockMvc.perform(post("/api/v1/devices/" + deviceId + "/sos")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new TriggerSosEventRequest(EventSource.SIMULATED_DEVICE, "sos-life-1"))))
                .andExpect(status().isCreated())
                .andReturn();
        UUID sos1Id = UUID.fromString(objectMapper.readTree(sos1Res.getResponse().getContentAsString()).at("/data/id").asText());

        // Invalid transition: TRIGGERED -> RESOLVED directly (skipping ACKNOWLEDGED) -> 400 Bad Request
        mockMvc.perform(patch("/api/v1/sos-events/" + sos1Id + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + activeParentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateSosEventStatusRequest(SosEventStatus.RESOLVED))))
                .andExpect(status().isBadRequest());

        // PENDING Parent CANNOT acknowledge SOS -> 403 Forbidden
        mockMvc.perform(patch("/api/v1/sos-events/" + sos1Id + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + pendingParentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateSosEventStatusRequest(SosEventStatus.ACKNOWLEDGED))))
                .andExpect(status().isForbidden());

        // ACTIVE Parent CANNOT cancel SOS (CANCELLED is restricted to owning USER) -> 403 Forbidden
        mockMvc.perform(patch("/api/v1/sos-events/" + sos1Id + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + activeParentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateSosEventStatusRequest(SosEventStatus.CANCELLED))))
                .andExpect(status().isForbidden());

        // Valid transition: TRIGGERED -> ACKNOWLEDGED by ACTIVE Parent -> 200 OK
        mockMvc.perform(patch("/api/v1/sos-events/" + sos1Id + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + activeParentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateSosEventStatusRequest(SosEventStatus.ACKNOWLEDGED))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status", is("ACKNOWLEDGED")))
                .andExpect(jsonPath("$.data.acknowledgedByUserId", is(activeParent.getId().toString())))
                .andExpect(jsonPath("$.data.acknowledgedAt", notNullValue()));

        // Invalid transition: ACKNOWLEDGED -> CANCELLED -> 400 Bad Request
        mockMvc.perform(patch("/api/v1/sos-events/" + sos1Id + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateSosEventStatusRequest(SosEventStatus.CANCELLED))))
                .andExpect(status().isBadRequest());

        // Valid transition: ACKNOWLEDGED -> RESOLVED -> 200 OK
        mockMvc.perform(patch("/api/v1/sos-events/" + sos1Id + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + activeParentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateSosEventStatusRequest(SosEventStatus.RESOLVED))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status", is("RESOLVED")))
                .andExpect(jsonPath("$.data.resolvedByUserId", is(activeParent.getId().toString())))
                .andExpect(jsonPath("$.data.resolvedAt", notNullValue()));

        // Resolved SOS CANNOT reopen to TRIGGERED or ACKNOWLEDGED -> 400 Bad Request
        mockMvc.perform(patch("/api/v1/sos-events/" + sos1Id + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateSosEventStatusRequest(SosEventStatus.TRIGGERED))))
                .andExpect(status().isBadRequest());

        mockMvc.perform(patch("/api/v1/sos-events/" + sos1Id + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + activeParentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateSosEventStatusRequest(SosEventStatus.ACKNOWLEDGED))))
                .andExpect(status().isBadRequest());

        // --- FLOW B: TRIGGERED -> CANCELLED ---
        MvcResult sos2Res = mockMvc.perform(post("/api/v1/devices/" + deviceId + "/sos")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new TriggerSosEventRequest(EventSource.MOBILE_CLIENT, "sos-life-2"))))
                .andExpect(status().isCreated())
                .andReturn();
        UUID sos2Id = UUID.fromString(objectMapper.readTree(sos2Res.getResponse().getContentAsString()).at("/data/id").asText());

        // Valid transition: TRIGGERED -> CANCELLED by owning USER -> 200 OK
        mockMvc.perform(patch("/api/v1/sos-events/" + sos2Id + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateSosEventStatusRequest(SosEventStatus.CANCELLED))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status", is("CANCELLED")))
                .andExpect(jsonPath("$.data.resolvedByUserId", is(stickUser.getId().toString())))
                .andExpect(jsonPath("$.data.resolvedAt", notNullValue()));

        // Cancelled SOS CANNOT reopen to TRIGGERED, ACKNOWLEDGED, or RESOLVED -> 400 Bad Request
        mockMvc.perform(patch("/api/v1/sos-events/" + sos2Id + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateSosEventStatusRequest(SosEventStatus.TRIGGERED))))
                .andExpect(status().isBadRequest());

        mockMvc.perform(patch("/api/v1/sos-events/" + sos2Id + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + activeParentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateSosEventStatusRequest(SosEventStatus.ACKNOWLEDGED))))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("5. Realtime Hazard & SOS Fan-Out: ONLY ACTIVE linked parent receives HAZARD_ALERT and SOS_EVENT; PENDING, REVOKED, unrelated parents and other users receive nothing; no global parent topic exists")
    void shouldFanOutHazardAndSosRealtimeEventsWithoutLeakage() throws Exception {
        registerAccount("rt.userA@sahayak.org", "StrongPass#2026", Role.USER);
        registerAccount("rt.userB@sahayak.org", "StrongPass#2026", Role.USER);
        registerAccount("rt.parentA.active@sahayak.org", "StrongPass#2026", Role.PARENT);
        registerAccount("rt.parentB.pending@sahayak.org", "StrongPass#2026", Role.PARENT);
        registerAccount("rt.parentC.revoked@sahayak.org", "StrongPass#2026", Role.PARENT);
        registerAccount("rt.parentD.unrelated@sahayak.org", "StrongPass#2026", Role.PARENT);

        User userA = userRepository.findByEmail("rt.usera@sahayak.org").orElseThrow();
        User userB = userRepository.findByEmail("rt.userb@sahayak.org").orElseThrow();
        User parentA = userRepository.findByEmail("rt.parenta.active@sahayak.org").orElseThrow();
        User parentB = userRepository.findByEmail("rt.parentb.pending@sahayak.org").orElseThrow();
        User parentC = userRepository.findByEmail("rt.parentc.revoked@sahayak.org").orElseThrow();
        User parentD = userRepository.findByEmail("rt.parentd.unrelated@sahayak.org").orElseThrow();

        String userAToken = loginAndGetAccessToken("rt.userA@sahayak.org", "StrongPass#2026");
        String userBToken = loginAndGetAccessToken("rt.userB@sahayak.org", "StrongPass#2026");
        String parentAToken = loginAndGetAccessToken("rt.parentA.active@sahayak.org", "StrongPass#2026");
        String parentBToken = loginAndGetAccessToken("rt.parentB.pending@sahayak.org", "StrongPass#2026");
        String parentCToken = loginAndGetAccessToken("rt.parentC.revoked@sahayak.org", "StrongPass#2026");
        String parentDToken = loginAndGetAccessToken("rt.parentD.unrelated@sahayak.org", "StrongPass#2026");

        UUID deviceAId = registerDeviceAndGetId(userAToken, "SAHAYAK-RT-1E-01", "Realtime Test Cane");

        // Parent A -> ACTIVE
        UUID linkAId = createParentLinkAndGetId(parentAToken, userA.getId());
        updateParentLinkStatus(userAToken, linkAId, ParentLinkStatus.ACTIVE);

        // Parent B -> PENDING
        createParentLinkAndGetId(parentBToken, userA.getId());

        // Parent C -> REVOKED
        UUID linkCId = createParentLinkAndGetId(parentCToken, userA.getId());
        updateParentLinkStatus(userAToken, linkCId, ParentLinkStatus.REVOKED);

        // Parent D -> Unrelated (no link)

        // Verify NO global parent topic (/topic/all-parents) is allowed
        MessageChannel mockChannel = mock(MessageChannel.class);
        Message<byte[]> globalParentTopicSub = buildStompFrame(
                StompCommand.SUBSCRIBE,
                "/topic/all-parents",
                UserPrincipal.fromUser(parentA)
        );
        assertThatThrownBy(() -> stompAuthChannelInterceptor.preSend(globalParentTopicSub, mockChannel))
                .isInstanceOf(AccessDeniedException.class);

        // Connect Parent A (ACTIVE), Parent B (PENDING), Parent C (REVOKED), Parent D (unrelated), and User B over live STOMP
        WebSocketStompClient stompClient = createStompClient();
        String wsUrl = "ws://localhost:" + port + "/ws";

        StompSession sessionParentA = connectStomp(stompClient, wsUrl, parentAToken);
        StompSession sessionParentB = connectStomp(stompClient, wsUrl, parentBToken);
        StompSession sessionParentC = connectStomp(stompClient, wsUrl, parentCToken);
        StompSession sessionParentD = connectStomp(stompClient, wsUrl, parentDToken);
        StompSession sessionUserB = connectStomp(stompClient, wsUrl, userBToken);

        BlockingQueue<JsonNode> queueParentA = new LinkedBlockingQueue<>();
        BlockingQueue<JsonNode> queueParentB = new LinkedBlockingQueue<>();
        BlockingQueue<JsonNode> queueParentC = new LinkedBlockingQueue<>();
        BlockingQueue<JsonNode> queueParentD = new LinkedBlockingQueue<>();
        BlockingQueue<JsonNode> queueUserB = new LinkedBlockingQueue<>();

        sessionParentA.subscribe("/topic/parent/" + parentA.getId() + "/events", new JsonFrameHandler(queueParentA));
        sessionParentB.subscribe("/topic/parent/" + parentB.getId() + "/events", new JsonFrameHandler(queueParentB));
        sessionParentC.subscribe("/topic/parent/" + parentC.getId() + "/events", new JsonFrameHandler(queueParentC));
        sessionParentD.subscribe("/topic/parent/" + parentD.getId() + "/events", new JsonFrameHandler(queueParentD));
        sessionUserB.subscribe("/topic/user/" + userB.getId() + "/events", new JsonFrameHandler(queueUserB));

        Thread.sleep(150);

        // 1. User A creates a HazardEvent
        CreateHazardEventRequest hazardReq = new CreateHazardEventRequest(
                HazardType.GROUND_HAZARD,
                HazardLevel.CRITICAL,
                25,
                EventSource.SIMULATED_DEVICE,
                "rt-haz-corr-01"
        );
        mockMvc.perform(post("/api/v1/devices/" + deviceAId + "/hazards")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(hazardReq)))
                .andExpect(status().isCreated());

        // ONLY Parent A (ACTIVE) receives HAZARD_ALERT
        JsonNode hazardReceivedByParentA = queueParentA.poll(5, TimeUnit.SECONDS);
        assertThat(hazardReceivedByParentA).isNotNull();
        assertThat(hazardReceivedByParentA.path("eventType").asText()).isEqualTo("HAZARD_ALERT");
        assertThat(hazardReceivedByParentA.path("correlationId").asText()).isEqualTo("rt-haz-corr-01");
        assertThat(hazardReceivedByParentA.path("payload").path("hazardType").asText()).isEqualTo("GROUND_HAZARD");
        assertThat(hazardReceivedByParentA.path("payload").path("hazardLevel").asText()).isEqualTo("CRITICAL");
        assertThat(hazardReceivedByParentA.path("payload").path("distanceCm").asInt()).isEqualTo(25);

        assertThat(queueParentB.poll(300, TimeUnit.MILLISECONDS)).isNull();
        assertThat(queueParentC.poll(100, TimeUnit.MILLISECONDS)).isNull();
        assertThat(queueParentD.poll(100, TimeUnit.MILLISECONDS)).isNull();
        assertThat(queueUserB.poll(100, TimeUnit.MILLISECONDS)).isNull();

        // 2. User A triggers an SOS Event
        TriggerSosEventRequest sosReq = new TriggerSosEventRequest(EventSource.DEVICE, "rt-sos-corr-01");
        mockMvc.perform(post("/api/v1/devices/" + deviceAId + "/sos")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(sosReq)))
                .andExpect(status().isCreated());

        // ONLY Parent A (ACTIVE) receives SOS_EVENT
        JsonNode sosReceivedByParentA = queueParentA.poll(5, TimeUnit.SECONDS);
        assertThat(sosReceivedByParentA).isNotNull();
        assertThat(sosReceivedByParentA.path("eventType").asText()).isEqualTo("SOS_EVENT");
        assertThat(sosReceivedByParentA.path("correlationId").asText()).isEqualTo("rt-sos-corr-01");
        assertThat(sosReceivedByParentA.path("payload").path("status").asText()).isEqualTo("TRIGGERED");
        assertThat(sosReceivedByParentA.path("payload").path("deviceId").asText()).isEqualTo(deviceAId.toString());

        assertThat(queueParentB.poll(300, TimeUnit.MILLISECONDS)).isNull();
        assertThat(queueParentC.poll(100, TimeUnit.MILLISECONDS)).isNull();
        assertThat(queueParentD.poll(100, TimeUnit.MILLISECONDS)).isNull();
        assertThat(queueUserB.poll(100, TimeUnit.MILLISECONDS)).isNull();

        sessionParentA.disconnect();
        sessionParentB.disconnect();
        sessionParentC.disconnect();
        sessionParentD.disconnect();
        sessionUserB.disconnect();
        stompClient.stop();
    }

    private StompSession connectStomp(WebSocketStompClient client, String wsUrl, String token) throws Exception {
        StompHeaders headers = new StompHeaders();
        headers.add(HttpHeaders.AUTHORIZATION, "Bearer " + token);
        return client.connectAsync(
                wsUrl,
                new WebSocketHttpHeaders(),
                headers,
                new StompSessionHandlerAdapter() {}
        ).get(5, TimeUnit.SECONDS);
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

    private void updateParentLinkStatus(String token, UUID linkId, ParentLinkStatus status) throws Exception {
        mockMvc.perform(patch("/api/v1/parent-links/" + linkId + "/status")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateParentUserLinkStatusRequest(status))))
                .andExpect(status().isOk());
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
                "Phase 1E Test Account",
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
