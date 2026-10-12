package com.sahayak.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * SAHAYAK Smart Assistive Stick — Backend Application Entry Point.
 * Provides unified backend infrastructure for both User Module and Parent Control Module.
 */
@SpringBootApplication
public class BackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(BackendApplication.class, args);
    }
}
