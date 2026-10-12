package com.sahayak.backend.modules.link;

import com.sahayak.backend.common.exception.ApiException;
import com.sahayak.backend.modules.link.dto.CreateParentUserLinkRequest;
import com.sahayak.backend.modules.link.dto.ParentUserLinkResponse;
import com.sahayak.backend.modules.link.dto.UpdateParentUserLinkStatusRequest;
import com.sahayak.backend.modules.user.Role;
import com.sahayak.backend.modules.user.User;
import com.sahayak.backend.modules.user.UserRepository;
import com.sahayak.backend.security.UserPrincipal;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Domain service managing Caregiver (Parent) -> Stick Operator (User) relationship lifecycle:
 * PENDING -> ACTIVE -> REVOKED.
 *
 * Security Rules:
 * 1. Only a PARENT can initiate a link request (created in PENDING status).
 * 2. Creating a PENDING link does NOT grant access to the User's devices or events.
 * 3. Only the target USER (or ADMIN) can transition a link from PENDING -> ACTIVE.
 * 4. Either the linked USER, the linked PARENT, or ADMIN can transition a link to REVOKED.
 * 5. A REVOKED link cannot be reactivated back to ACTIVE or PENDING.
 */
@Service
public class ParentUserLinkService {

    private static final Logger log = LoggerFactory.getLogger(ParentUserLinkService.class);

    private final ParentUserLinkRepository parentUserLinkRepository;
    private final UserRepository userRepository;

    public ParentUserLinkService(
            ParentUserLinkRepository parentUserLinkRepository,
            UserRepository userRepository
    ) {
        this.parentUserLinkRepository = parentUserLinkRepository;
        this.userRepository = userRepository;
    }

    @Transactional
    public ParentUserLinkResponse createLinkRequest(
            UserPrincipal principal,
            CreateParentUserLinkRequest request
    ) {
        if (principal == null || principal.getRole() != Role.PARENT) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Only PARENT accounts can initiate caregiver link requests");
        }

        UUID parentId = principal.getId();
        UUID targetUserId = request.userId();

        if (parentId.equals(targetUserId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cannot create a caregiver link to the same account");
        }

        User parentUser = userRepository.findById(parentId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Authenticated parent account not found"));

        User targetUser = userRepository.findById(targetUserId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Target user account not found"));

        if (targetUser.getRole() != Role.USER) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "Caregiver links may only be requested for accounts with role USER"
            );
        }

        Optional<ParentUserLink> existing = parentUserLinkRepository.findByParentIdAndUserId(parentId, targetUserId);
        if (existing.isPresent()) {
            ParentLinkStatus currentStatus = existing.get().getStatus();
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "A caregiver relationship record already exists between this parent and user with status: " + currentStatus
            );
        }

        ParentUserLink newLink = new ParentUserLink(
                UUID.randomUUID(),
                parentUser,
                targetUser,
                ParentLinkStatus.PENDING
        );

        ParentUserLink saved = parentUserLinkRepository.save(newLink);
        log.info("Created PENDING ParentUserLink: linkId={}, parentId={}, userId={}",
                saved.getId(), parentId, targetUserId);

        return ParentUserLinkResponse.fromEntity(saved);
    }

    @Transactional
    public ParentUserLinkResponse updateLinkStatus(
            UserPrincipal principal,
            UUID linkId,
            UpdateParentUserLinkStatusRequest request
    ) {
        if (principal == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Authentication is required");
        }

        ParentUserLink link = parentUserLinkRepository.findById(linkId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Caregiver link not found"));

        ParentLinkStatus currentStatus = link.getStatus();
        ParentLinkStatus targetStatus = request.status();

        if (currentStatus == ParentLinkStatus.REVOKED) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "A revoked caregiver link cannot be modified or reactivated"
            );
        }

        if (targetStatus == ParentLinkStatus.PENDING) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "Cannot transition an existing caregiver link back to PENDING"
            );
        }

        UUID callerId = principal.getId();
        Role callerRole = principal.getRole();
        boolean isTargetUser = callerRole == Role.USER && link.getUser().getId().equals(callerId);
        boolean isRequestingParent = callerRole == Role.PARENT && link.getParent().getId().equals(callerId);
        boolean isAdmin = callerRole == Role.ADMIN;

        if (!isTargetUser && !isRequestingParent && !isAdmin) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Access denied to this caregiver link");
        }

        if (targetStatus == ParentLinkStatus.ACTIVE) {
            if (currentStatus != ParentLinkStatus.PENDING) {
                throw new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "Only PENDING caregiver links can be transitioned to ACTIVE"
                );
            }
            // Security Boundary: A Parent cannot self-approve their own PENDING request!
            if (!isTargetUser && !isAdmin) {
                throw new ApiException(
                        HttpStatus.FORBIDDEN,
                        "Only the target stick USER may approve and activate a pending caregiver link"
                );
            }
        }

        link.setStatus(targetStatus);
        ParentUserLink saved = parentUserLinkRepository.save(link);

        log.info("Transitioned ParentUserLink: linkId={}, from={} to={}, byUserId={} (role={})",
                saved.getId(), currentStatus, targetStatus, callerId, callerRole);

        return ParentUserLinkResponse.fromEntity(saved);
    }

    @Transactional(readOnly = true)
    public List<ParentUserLinkResponse> getLinksForPrincipal(UserPrincipal principal) {
        if (principal == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Authentication is required");
        }

        List<ParentUserLink> links;
        if (principal.getRole() == Role.USER) {
            links = parentUserLinkRepository.findByUserIdOrderByCreatedAtDesc(principal.getId());
        } else if (principal.getRole() == Role.PARENT) {
            links = parentUserLinkRepository.findByParentIdOrderByCreatedAtDesc(principal.getId());
        } else {
            links = parentUserLinkRepository.findAll();
        }

        return links.stream()
                .map(ParentUserLinkResponse::fromEntity)
                .toList();
    }

    @Transactional(readOnly = true)
    public ParentUserLinkResponse getLinkById(UserPrincipal principal, UUID linkId) {
        if (principal == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Authentication is required");
        }

        ParentUserLink link = parentUserLinkRepository.findById(linkId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Caregiver link not found"));

        UUID callerId = principal.getId();
        Role callerRole = principal.getRole();
        boolean isOwnerUser = callerRole == Role.USER && link.getUser().getId().equals(callerId);
        boolean isOwnerParent = callerRole == Role.PARENT && link.getParent().getId().equals(callerId);
        boolean isAdmin = callerRole == Role.ADMIN;

        if (!isOwnerUser && !isOwnerParent && !isAdmin) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Access denied to this caregiver link");
        }

        return ParentUserLinkResponse.fromEntity(link);
    }
}
