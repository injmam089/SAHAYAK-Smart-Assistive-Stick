package com.sahayak.backend;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

/**
 * Validates that Spring ApplicationContext starts cleanly,
 * Flyway migration executes against the test database, and all initial beans wire properly.
 */
@SpringBootTest
@ActiveProfiles("test")
class BackendApplicationTests {

    @Test
    void contextLoads() {
        // Confirms Spring Boot context initialization, Flyway migration, and JPA wiring
    }
}
