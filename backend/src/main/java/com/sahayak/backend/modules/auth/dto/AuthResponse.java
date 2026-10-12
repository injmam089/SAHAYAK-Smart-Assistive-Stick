package com.sahayak.backend.modules.auth.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * Authentication response returned upon successful login or refresh token rotation.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record AuthResponse(
        String accessToken,
        String refreshToken,
        String tokenType,
        long expiresInSeconds,
        UserResponse user
) {

    public static AuthResponse of(
            String accessToken,
            String refreshToken,
            long expiresInSeconds,
            UserResponse user
    ) {
        return new AuthResponse(accessToken, refreshToken, "Bearer", expiresInSeconds, user);
    }
}
