package com.sahayak.backend.modules.admin;

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
 * Administrative Governance REST Controller (Restricted strictly to ROLE_ADMIN via hasRole("ADMIN")).
 * Enforces least-privilege separation: ADMIN manages platform/device registry governance
 * and cannot arbitrarily impersonate USER or PARENT module endpoints.
 */
@RestController
@RequestMapping("/api/v1/admin")
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {

    @GetMapping("/access-check")
    public ResponseEntity<ApiResponse<Map<String, Object>>> checkAdminModuleAccess(
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        Map<String, Object> data = Map.of(
                "module", "ADMIN_GOVERNANCE_MODULE",
                "userId", principal.getId(),
                "email", principal.getEmail(),
                "role", principal.getRole().name()
        );
        return ResponseEntity.ok(ApiResponse.ok("Admin governance access verified", data));
    }
}
