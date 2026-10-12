package com.sahayak.backend.modules.auth.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Request payload for rotating a refresh token and obtaining a new JWT access token.
 */
public record RefreshTokenRequest(
        @NotBlank(message = "Refresh token is required")
        String refreshToken
) {
}
