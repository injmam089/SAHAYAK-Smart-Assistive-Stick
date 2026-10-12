package com.sahayak.backend.modules.auth;

import com.sahayak.backend.common.exception.ApiException;
import com.sahayak.backend.common.exception.ConflictException;
import com.sahayak.backend.common.exception.ResourceNotFoundException;
import com.sahayak.backend.common.exception.UnauthorizedException;
import com.sahayak.backend.modules.auth.dto.*;
import com.sahayak.backend.modules.user.AccountStatus;
import com.sahayak.backend.modules.user.Role;
import com.sahayak.backend.modules.user.User;
import com.sahayak.backend.modules.user.UserRepository;
import com.sahayak.backend.security.JwtTokenProvider;
import com.sahayak.backend.security.UserPrincipal;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.EnumSet;
import java.util.HexFormat;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

/**
 * Core Authentication Service handling registration, login, JWT issuance,
 * and SHA-256 hashed refresh-token rotation.
 */
@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);
    private static final Set<Role> ALLOWED_PUBLIC_REGISTRATION_ROLES = EnumSet.of(Role.USER, Role.PARENT);
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtTokenProvider jwtTokenProvider;

    public AuthService(
            UserRepository userRepository,
            RefreshTokenRepository refreshTokenRepository,
            PasswordEncoder passwordEncoder,
            AuthenticationManager authenticationManager,
            JwtTokenProvider jwtTokenProvider
    ) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.authenticationManager = authenticationManager;
        this.jwtTokenProvider = jwtTokenProvider;
    }

    @Transactional
    public UserResponse register(RegisterRequest request) {
        if (request.role() == null || !ALLOWED_PUBLIC_REGISTRATION_ROLES.contains(request.role())) {
            throw new ApiException(
                    "Public registration is restricted to USER and PARENT roles",
                    HttpStatus.BAD_REQUEST
            );
        }

        String normalizedEmail = normalizeEmail(request.email());
        if (userRepository.existsByEmail(normalizedEmail)) {
            throw new ConflictException("An account with this email is already registered");
        }

        String hashedPassword = passwordEncoder.encode(request.password());
        String trimmedName = request.fullName().trim();
        String trimmedPhone = request.phoneNumber() != null && !request.phoneNumber().isBlank()
                ? request.phoneNumber().trim()
                : null;

        User user = new User(
                UUID.randomUUID(),
                normalizedEmail,
                hashedPassword,
                trimmedName,
                trimmedPhone,
                request.role(),
                AccountStatus.ACTIVE
        );

        User savedUser = userRepository.save(user);
        log.info("Registered new {} account: id={}", savedUser.getRole(), savedUser.getId());

        return UserResponse.fromUser(savedUser);
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        String normalizedEmail = normalizeEmail(request.email());

        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(normalizedEmail, request.password())
        );

        UserPrincipal principal = (UserPrincipal) authentication.getPrincipal();
        User user = userRepository.findById(principal.getId())
                .orElseThrow(() -> new UnauthorizedException("Invalid email or password"));

        String accessToken = jwtTokenProvider.generateAccessToken(principal);
        String rawRefreshToken = createAndStoreRefreshToken(user);

        log.info("Authenticated {} account: id={}", user.getRole(), user.getId());

        return AuthResponse.of(
                accessToken,
                rawRefreshToken,
                jwtTokenProvider.getAccessTokenExpirationSeconds(),
                UserResponse.fromUser(user)
        );
    }

    @Transactional(noRollbackFor = UnauthorizedException.class)
    public AuthResponse refreshToken(RefreshTokenRequest request) {
        String incomingHash = hashRefreshToken(request.refreshToken());

        RefreshToken storedToken = refreshTokenRepository.findByTokenHash(incomingHash)
                .orElseThrow(() -> new UnauthorizedException("Invalid refresh token"));

        User user = storedToken.getUser();

        if (storedToken.isRevoked()) {
            // Token reuse detection: revoke all active refresh tokens for this user
            log.warn("Detected reuse of revoked refresh token for userId={}; revoking all active tokens", user.getId());
            refreshTokenRepository.revokeAllActiveTokensForUser(user.getId(), Instant.now());
            throw new UnauthorizedException("Refresh token has been revoked");
        }

        if (storedToken.getExpiresAt().isBefore(Instant.now())) {
            storedToken.setRevoked(true);
            storedToken.setRevokedAt(Instant.now());
            refreshTokenRepository.save(storedToken);
            throw new UnauthorizedException("Refresh token has expired");
        }

        if (user.getStatus() != AccountStatus.ACTIVE) {
            throw new UnauthorizedException("User account is not active");
        }

        // Rotate refresh token
        String newRawRefreshToken = generateOpaqueRefreshToken();
        String newTokenHash = hashRefreshToken(newRawRefreshToken);

        storedToken.setRevoked(true);
        storedToken.setRevokedAt(Instant.now());
        storedToken.setReplacedByTokenHash(newTokenHash);
        refreshTokenRepository.save(storedToken);

        Instant newExpiry = Instant.now().plusMillis(jwtTokenProvider.getRefreshTokenExpirationMs());
        RefreshToken replacementToken = new RefreshToken(user, newTokenHash, newExpiry);
        refreshTokenRepository.save(replacementToken);

        UserPrincipal principal = UserPrincipal.fromUser(user);
        String newAccessToken = jwtTokenProvider.generateAccessToken(principal);

        return AuthResponse.of(
                newAccessToken,
                newRawRefreshToken,
                jwtTokenProvider.getAccessTokenExpirationSeconds(),
                UserResponse.fromUser(user)
        );
    }

    @Transactional(readOnly = true)
    public UserResponse getCurrentUser(UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", userId));
        return UserResponse.fromUser(user);
    }

    private String createAndStoreRefreshToken(User user) {
        String rawRefreshToken = generateOpaqueRefreshToken();
        String tokenHash = hashRefreshToken(rawRefreshToken);
        Instant expiresAt = Instant.now().plusMillis(jwtTokenProvider.getRefreshTokenExpirationMs());

        RefreshToken refreshToken = new RefreshToken(user, tokenHash, expiresAt);
        refreshTokenRepository.save(refreshToken);

        return rawRefreshToken;
    }

    private String generateOpaqueRefreshToken() {
        byte[] randomBytes = new byte[32];
        SECURE_RANDOM.nextBytes(randomBytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(randomBytes);
    }

    public static String hashRefreshToken(String rawToken) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hashBytes = digest.digest(rawToken.trim().getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hashBytes);
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("SHA-256 algorithm not available", ex);
        }
    }

    private String normalizeEmail(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }
}
