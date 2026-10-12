package com.sahayak.backend.modules.foundation;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

/**
 * Spring Data JPA Repository for FoundationCheck.
 */
@Repository
public interface FoundationCheckRepository extends JpaRepository<FoundationCheck, Long> {

    Optional<FoundationCheck> findByCheckKey(String checkKey);
}
