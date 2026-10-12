package com.sahayak.backend.modules.health;

import com.sahayak.backend.modules.foundation.FoundationCheck;
import com.sahayak.backend.modules.foundation.FoundationCheckRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

/**
 * Service providing application and database foundation health telemetry.
 */
@Service
public class HealthService {

    private static final Logger log = LoggerFactory.getLogger(HealthService.class);

    private final FoundationCheckRepository foundationCheckRepository;

    public HealthService(FoundationCheckRepository foundationCheckRepository) {
        this.foundationCheckRepository = foundationCheckRepository;
    }

    public Map<String, Object> getSystemStatus() {
        log.debug("Checking SAHAYAK backend system health and database migration status");

        Map<String, Object> status = new LinkedHashMap<>();
        status.put("platform", "SAHAYAK Smart Assistive Stick");
        status.put("architecture", "ONE_PLATFORM_TWO_MODULES");
        status.put("status", "UP");

        try {
            Optional<FoundationCheck> check = foundationCheckRepository.findByCheckKey("PHASE_1A_FOUNDATION");
            if (check.isPresent()) {
                status.put("database", "CONNECTED");
                status.put("flywayMigration", check.get().getStatus());
            } else {
                status.put("database", "CONNECTED");
                status.put("flywayMigration", "SEED_NOT_FOUND");
            }
        } catch (Exception ex) {
            log.error("Database connectivity check failed", ex);
            status.put("database", "DOWN");
            status.put("error", ex.getMessage());
        }

        return status;
    }
}
