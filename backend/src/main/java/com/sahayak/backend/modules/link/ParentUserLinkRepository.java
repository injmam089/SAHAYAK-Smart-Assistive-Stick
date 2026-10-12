package com.sahayak.backend.modules.link;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Spring Data JPA Repository for ParentUserLink entities.
 */
@Repository
public interface ParentUserLinkRepository extends JpaRepository<ParentUserLink, UUID> {

    @EntityGraph(attributePaths = {"parent", "user"})
    List<ParentUserLink> findByParentIdAndStatusOrderByCreatedAtDesc(UUID parentId, ParentLinkStatus status);

    @EntityGraph(attributePaths = {"parent", "user"})
    List<ParentUserLink> findByUserIdAndStatusOrderByCreatedAtDesc(UUID userId, ParentLinkStatus status);

    @EntityGraph(attributePaths = {"parent", "user"})
    List<ParentUserLink> findByParentIdOrderByCreatedAtDesc(UUID parentId);

    @EntityGraph(attributePaths = {"parent", "user"})
    List<ParentUserLink> findByUserIdOrderByCreatedAtDesc(UUID userId);

    @EntityGraph(attributePaths = {"parent", "user"})
    Optional<ParentUserLink> findByParentIdAndUserId(UUID parentId, UUID userId);

    boolean existsByParentIdAndUserIdAndStatus(UUID parentId, UUID userId, ParentLinkStatus status);

    @Override
    @EntityGraph(attributePaths = {"parent", "user"})
    Optional<ParentUserLink> findById(UUID id);
}
