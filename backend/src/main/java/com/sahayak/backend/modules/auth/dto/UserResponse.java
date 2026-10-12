package com.sahayak.backend.modules.auth.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.sahayak.backend.modules.user.AccountStatus;
import com.sahayak.backend.modules.user.Role;
import com.sahayak.backend.modules.user.User;

import java.time.Instant;
import java.util.UUID;

/**
 * Safe user profile representation returned in API responses (never contains password hash).
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record UserResponse(
        UUID id,
        String email,
        String fullName,
        String phoneNumber,
        Role role,
        AccountStatus status,
        Instant createdAt
) {

    public static UserResponse fromUser(User user) {
        return new UserResponse(
                user.getId(),
                user.getEmail(),
                user.getFullName(),
                user.getPhoneNumber(),
                user.getRole(),
                user.getStatus(),
                user.getCreatedAt()
        );
    }
}
