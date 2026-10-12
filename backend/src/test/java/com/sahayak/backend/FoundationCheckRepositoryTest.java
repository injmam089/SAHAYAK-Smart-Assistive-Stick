package com.sahayak.backend;

import com.sahayak.backend.modules.foundation.FoundationCheck;
import com.sahayak.backend.modules.foundation.FoundationCheckRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Validates that Flyway migration V1__init_foundation.sql executed properly
 * and JPA repository can read and persist entities.
 */
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class FoundationCheckRepositoryTest {

    @Autowired
    private FoundationCheckRepository repository;

    @Test
    void shouldLoadFlywaySeededFoundationRecord() {
        Optional<FoundationCheck> seeded = repository.findByCheckKey("PHASE_1A_FOUNDATION");
        assertThat(seeded).isPresent();
        assertThat(seeded.get().getStatus()).isEqualTo("READY");
    }

    @Test
    void shouldSaveAndRetrieveNewFoundationCheck() {
        FoundationCheck customCheck = new FoundationCheck("JPA_WRITE_TEST", "PASSED", "Verify JPA persistence");
        repository.save(customCheck);

        Optional<FoundationCheck> retrieved = repository.findByCheckKey("JPA_WRITE_TEST");
        assertThat(retrieved).isPresent();
        assertThat(retrieved.get().getStatus()).isEqualTo("PASSED");
    }
}
