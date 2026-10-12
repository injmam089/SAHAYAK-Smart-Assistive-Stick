package com.sahayak.backend.modules.parent;

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
 * Parent Control Module REST Controller (Restricted strictly to ROLE_PARENT via hasRole("PARENT")).
 */
@RestController
@RequestMapping("/api/v1/parent")
@PreAuthorize("hasRole('PARENT')")
public class ParentController {

    @GetMapping("/access-check")
    public ResponseEntity<ApiResponse<Map<String, Object>>> checkParentModuleAccess(
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        Map<String, Object> data = Map.of(
                "module", "PARENT_CONTROL_MODULE",
                "userId", principal.getId(),
                "email", principal.getEmail(),
                "role", principal.getRole().name()
        );
        return ResponseEntity.ok(ApiResponse.ok("Parent Control Module access verified", data));
    }
}
