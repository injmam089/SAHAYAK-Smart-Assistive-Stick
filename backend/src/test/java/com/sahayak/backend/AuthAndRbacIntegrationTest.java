package com.sahayak.backend;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sahayak.backend.modules.auth.AuthService;
import com.sahayak.backend.modules.auth.RefreshToken;
import com.sahayak.backend.modules.auth.RefreshTokenRepository;
import com.sahayak.backend.modules.auth.dto.LoginRequest;
import com.sahayak.backend.modules.auth.dto.RefreshTokenRequest;
import com.sahayak.backend.modules.auth.dto.RegisterRequest;
import com.sahayak.backend.modules.user.AccountStatus;
import com.sahayak.backend.modules.user.Role;
import com.sahayak.backend.modules.user.User;
import com.sahayak.backend.modules.user.UserRepository;
import com.sahayak.backend.security.JwtTokenProvider;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Comprehensive Phase 1B Integration Test Suite verifying:
 * - Flyway V2 migration & User/RefreshToken JPA persistence
 * - BCrypt password hashing & non-exposure of password hashes
 * - Registration & email normalization
 * - Duplicate email rejection
 * - Public registration ADMIN role restriction
 * - Login & JWT generation
 * - Refresh token SHA-256 hashing, rotation, and reuse revocation
 * - RBAC enforcement (USER, PARENT, ADMIN)
 * - Unauthenticated, invalid JWT, and expired JWT rejection
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AuthAndRbacIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @BeforeEach
    void setUp() {
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    @DisplayName("1. Registration hashes password with BCrypt, normalizes email, and never exposes passwordHash")
    void shouldRegisterUserSafelyAndHashPassword() throws Exception {
        RegisterRequest request = new RegisterRequest(
                "  Aarav.User@Sahayak.org  ",
                "StrongPass#2026",
                "Aarav Sharma",
                "+919876543210",
                Role.USER
        );

        MvcResult result = mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.success", is(true)))
                .andExpect(jsonPath("$.data.email", is("aarav.user@sahayak.org")))
                .andExpect(jsonPath("$.data.fullName", is("Aarav Sharma")))
                .andExpect(jsonPath("$.data.role", is("USER")))
                .andExpect(jsonPath("$.data.status", is("ACTIVE")))
                .andExpect(jsonPath("$.data.password").doesNotExist())
                .andExpect(jsonPath("$.data.passwordHash").doesNotExist())
                .andReturn();

        String responseBody = result.getResponse().getContentAsString();
        assertThat(responseBody).doesNotContain("StrongPass#2026");
        assertThat(responseBody).doesNotContain("$2a$");

        Optional<User> savedUser = userRepository.findByEmail("aarav.user@sahayak.org");
        assertThat(savedUser).isPresent();
        assertThat(savedUser.get().getPasswordHash()).isNotEqualTo("StrongPass#2026");
        assertThat(passwordEncoder.matches("StrongPass#2026", savedUser.get().getPasswordHash())).isTrue();
    }

    @Test
    @DisplayName("2. Duplicate registration (case-insensitive email) is rejected with 409 Conflict")
    void shouldRejectDuplicateRegistration() throws Exception {
        RegisterRequest first = new RegisterRequest(
                "user@sahayak.org",
                "StrongPass#2026",
                "First User",
                null,
                Role.USER
        );

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(first)))
                .andExpect(status().isCreated());

        RegisterRequest duplicate = new RegisterRequest(
                "USER@SAHAYAK.ORG",
                "AnotherPass#2026",
                "Duplicate User",
                null,
                Role.PARENT
        );

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(duplicate)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.success", is(false)))
                .andExpect(jsonPath("$.status", is(409)));
    }

    @Test
    @DisplayName("3. Public registration with ADMIN role is explicitly rejected")
    void shouldRejectPublicAdminRegistration() throws Exception {
        RegisterRequest adminAttempt = new RegisterRequest(
                "attacker@sahayak.org",
                "StrongPass#2026",
                "Unauthorized Admin",
                null,
                Role.ADMIN
        );

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(adminAttempt)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success", is(false)))
                .andExpect(jsonPath("$.message", containsString("USER and PARENT")));
    }

    @Test
    @DisplayName("4. Registration validation rejects weak passwords and missing required fields")
    void shouldRejectInvalidRegistrationPayloads() throws Exception {
        RegisterRequest invalidRequest = new RegisterRequest(
                "not-an-email",
                "weak",
                "",
                null,
                Role.USER
        );

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(invalidRequest)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success", is(false)))
                .andExpect(jsonPath("$.validationErrors.email").exists())
                .andExpect(jsonPath("$.validationErrors.password").exists())
                .andExpect(jsonPath("$.validationErrors.fullName").exists());
    }

    @Test
    @DisplayName("5. Login with wrong password is rejected with 401 Unauthorized")
    void shouldRejectWrongPasswordOnLogin() throws Exception {
        registerAccount("cane.user@sahayak.org", "CorrectPass#2026", Role.USER);

        LoginRequest wrongLogin = new LoginRequest("cane.user@sahayak.org", "WrongPass#9999");

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(wrongLogin)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success", is(false)))
                .andExpect(jsonPath("$.status", is(401)))
                .andExpect(jsonPath("$.message", is("Invalid email or password")));
    }

    @Test
    @DisplayName("6. Unauthenticated request to protected endpoints is rejected with 401 Unauthorized")
    void shouldRejectUnauthenticatedRequest() throws Exception {
        mockMvc.perform(get("/api/v1/user/access-check"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success", is(false)))
                .andExpect(jsonPath("$.status", is(401)));

        mockMvc.perform(get("/api/v1/parent/access-check"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success", is(false)))
                .andExpect(jsonPath("$.status", is(401)));
    }

    @Test
    @DisplayName("7. RBAC: USER can access USER resource, but is forbidden (403) from PARENT and ADMIN resources")
    void userRoleAccessControl() throws Exception {
        registerAccount("stick.user@sahayak.org", "StrongPass#2026", Role.USER);
        String userToken = loginAndGetAccessToken("stick.user@sahayak.org", "StrongPass#2026");

        // Allowed: USER endpoint
        mockMvc.perform(get("/api/v1/user/access-check")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success", is(true)))
                .andExpect(jsonPath("$.data.module", is("USER_MODULE")))
                .andExpect(jsonPath("$.data.role", is("USER")));

        // Forbidden: PARENT endpoint
        mockMvc.perform(get("/api/v1/parent/access-check")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success", is(false)))
                .andExpect(jsonPath("$.status", is(403)));

        // Forbidden: ADMIN endpoint
        mockMvc.perform(get("/api/v1/admin/access-check")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + userToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success", is(false)))
                .andExpect(jsonPath("$.status", is(403)));
    }

    @Test
    @DisplayName("8. RBAC: PARENT can access PARENT resource, but is forbidden (403) from USER and ADMIN resources")
    void parentRoleAccessControl() throws Exception {
        registerAccount("caregiver.parent@sahayak.org", "StrongPass#2026", Role.PARENT);
        String parentToken = loginAndGetAccessToken("caregiver.parent@sahayak.org", "StrongPass#2026");

        // Allowed: PARENT endpoint
        mockMvc.perform(get("/api/v1/parent/access-check")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + parentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success", is(true)))
                .andExpect(jsonPath("$.data.module", is("PARENT_CONTROL_MODULE")))
                .andExpect(jsonPath("$.data.role", is("PARENT")));

        // Forbidden: USER endpoint
        mockMvc.perform(get("/api/v1/user/access-check")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + parentToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success", is(false)))
                .andExpect(jsonPath("$.status", is(403)));

        // Forbidden: ADMIN endpoint
        mockMvc.perform(get("/api/v1/admin/access-check")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + parentToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success", is(false)))
                .andExpect(jsonPath("$.status", is(403)));
    }

    @Test
    @DisplayName("9. RBAC: ADMIN can access ADMIN resource and respects least-privilege module separation")
    void adminRoleAccessControl() throws Exception {
        User admin = new User(
                UUID.randomUUID(),
                "admin@sahayak.org",
                passwordEncoder.encode("AdminPass#2026"),
                "Platform Admin",
                null,
                Role.ADMIN,
                AccountStatus.ACTIVE
        );
        userRepository.save(admin);

        String adminToken = loginAndGetAccessToken("admin@sahayak.org", "AdminPass#2026");

        // Allowed: ADMIN endpoint
        mockMvc.perform(get("/api/v1/admin/access-check")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success", is(true)))
                .andExpect(jsonPath("$.data.module", is("ADMIN_GOVERNANCE_MODULE")))
                .andExpect(jsonPath("$.data.role", is("ADMIN")));

        // Least-privilege separation: ADMIN cannot impersonate USER or PARENT module endpoints
        mockMvc.perform(get("/api/v1/user/access-check")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + adminToken))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/v1/parent/access-check")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + adminToken))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("10. Invalid and tampered JWT tokens are rejected with 401 Unauthorized")
    void shouldRejectInvalidJwt() throws Exception {
        mockMvc.perform(get("/api/v1/user/access-check")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer malformed.jwt.token"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success", is(false)))
                .andExpect(jsonPath("$.status", is(401)));

        registerAccount("tamper@sahayak.org", "StrongPass#2026", Role.USER);
        String validToken = loginAndGetAccessToken("tamper@sahayak.org", "StrongPass#2026");
        String tamperedToken = validToken.substring(0, validToken.length() - 4) + "XXXX";

        mockMvc.perform(get("/api/v1/user/access-check")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tamperedToken))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success", is(false)))
                .andExpect(jsonPath("$.status", is(401)));
    }

    @Test
    @DisplayName("11. Expired JWT token is rejected with 401 Unauthorized")
    void shouldRejectExpiredJwt() throws Exception {
        registerAccount("expired@sahayak.org", "StrongPass#2026", Role.USER);
        User user = userRepository.findByEmail("expired@sahayak.org").orElseThrow();

        // Issue a token that expired 10 seconds ago (-10000 ms)
        String expiredToken = jwtTokenProvider.generateAccessToken(
                user.getId(),
                user.getEmail(),
                user.getRole(),
                -10_000L
        );

        mockMvc.perform(get("/api/v1/user/access-check")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + expiredToken))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success", is(false)))
                .andExpect(jsonPath("$.status", is(401)));
    }

    @Test
    @DisplayName("12. Refresh token is stored as SHA-256 hash, rotates cleanly, and blocks token reuse")
    void shouldRotateRefreshTokenAndBlockReuse() throws Exception {
        registerAccount("rotate@sahayak.org", "StrongPass#2026", Role.USER);

        LoginRequest loginRequest = new LoginRequest("rotate@sahayak.org", "StrongPass#2026");
        MvcResult loginResult = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode loginJson = objectMapper.readTree(loginResult.getResponse().getContentAsString());
        String initialRefreshToken = loginJson.at("/data/refreshToken").asText();
        assertThat(initialRefreshToken).isNotBlank();

        // Verify database stores SHA-256 hash, never plaintext
        String expectedHash = AuthService.hashRefreshToken(initialRefreshToken);
        Optional<RefreshToken> stored = refreshTokenRepository.findByTokenHash(expectedHash);
        assertThat(stored).isPresent();
        assertThat(stored.get().getTokenHash()).isNotEqualTo(initialRefreshToken);

        // Rotate refresh token
        RefreshTokenRequest refreshRequest = new RefreshTokenRequest(initialRefreshToken);
        MvcResult refreshResult = mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(refreshRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success", is(true)))
                .andExpect(jsonPath("$.data.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.data.refreshToken").isNotEmpty())
                .andReturn();

        JsonNode refreshJson = objectMapper.readTree(refreshResult.getResponse().getContentAsString());
        String secondRefreshToken = refreshJson.at("/data/refreshToken").asText();
        assertThat(secondRefreshToken).isNotEqualTo(initialRefreshToken);

        // Attempting to reuse the old rotated refresh token must be rejected (401) and revoke active tokens
        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new RefreshTokenRequest(initialRefreshToken))))
                .andExpect(status().isUnauthorized());

        // Even the second refresh token is now revoked due to reuse detection
        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new RefreshTokenRequest(secondRefreshToken))))
                .andExpect(status().isUnauthorized());
    }

    private void registerAccount(String email, String password, Role role) throws Exception {
        RegisterRequest registerRequest = new RegisterRequest(
                email,
                password,
                "Test Account",
                "+919999999999",
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
