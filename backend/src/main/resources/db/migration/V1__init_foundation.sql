-- Phase 1A Foundation Migration
-- Proves end-to-end connectivity: Application -> Flyway -> PostgreSQL -> JPA

CREATE TABLE foundation_checks (
    id BIGSERIAL PRIMARY KEY,
    check_key VARCHAR(100) NOT NULL UNIQUE,
    status VARCHAR(50) NOT NULL,
    description VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO foundation_checks (check_key, status, description)
VALUES ('PHASE_1A_FOUNDATION', 'READY', 'Initial Flyway schema migration and JPA persistence baseline');
