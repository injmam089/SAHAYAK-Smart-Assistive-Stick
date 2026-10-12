package com.sahayak.backend.modules.health;

import com.sahayak.backend.common.dto.ApiResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Public REST Controller providing baseline system and database connectivity health endpoints.
 */
@RestController
@RequestMapping("/api/v1/health")
public class HealthController {

    private final HealthService healthService;

    public HealthController(HealthService healthService) {
        this.healthService = healthService;
    }

    @GetMapping
    public ResponseEntity<ApiResponse<Map<String, Object>>> getHealth() {
        Map<String, Object> status = healthService.getSystemStatus();
        return ResponseEntity.ok(ApiResponse.ok("SAHAYAK Platform Backend Foundation Healthy", status));
    }
}
