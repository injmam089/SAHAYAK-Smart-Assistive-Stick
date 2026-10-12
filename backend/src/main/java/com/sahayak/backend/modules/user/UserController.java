package com.sahayak.backend.modules.user;

import com.sahayak.backend.common.dto.ApiResponse;
import com.sahayak.backend.security.UserPrincipal;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * User Module REST Controller (Restricted strictly to ROLE_USER via hasRole("USER")).
 */
@RestController
@RequestMapping("/api/v1/user")
@PreAuthorize("hasRole('USER')")
public class UserController {

    @GetMapping("/access-check")
    public ResponseEntity<ApiResponse<Map<String, Object>>> checkUserModuleAccess(
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        Map<String, Object> data = Map.of(
                "module", "USER_MODULE",
                "userId", principal.getId(),
                "email", principal.getEmail(),
                "role", principal.getRole().name()
        );
        return ResponseEntity.ok(ApiResponse.ok("User Module access verified", data));
    }
}
