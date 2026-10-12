package com.sahayak.backend.modules.link;

import com.sahayak.backend.common.constants.ApiConstants;
import com.sahayak.backend.common.dto.ApiResponse;
import com.sahayak.backend.modules.link.dto.CreateParentUserLinkRequest;
import com.sahayak.backend.modules.link.dto.ParentUserLinkResponse;
import com.sahayak.backend.modules.link.dto.UpdateParentUserLinkStatusRequest;
import com.sahayak.backend.security.UserPrincipal;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/**
 * Thin REST Controller for Caregiver (Parent) -> Stick Operator (User) relationship linking (Phase 1D).
 */
@RestController
@RequestMapping(ApiConstants.API_V1_PREFIX + "/parent-links")
public class ParentUserLinkController {

    private final ParentUserLinkService parentUserLinkService;

    public ParentUserLinkController(ParentUserLinkService parentUserLinkService) {
        this.parentUserLinkService = parentUserLinkService;
    }

    @PostMapping
    @PreAuthorize("hasRole('PARENT')")
    public ResponseEntity<ApiResponse<ParentUserLinkResponse>> createLinkRequest(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody CreateParentUserLinkRequest request
    ) {
        ParentUserLinkResponse created = parentUserLinkService.createLinkRequest(principal, request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Caregiver link request created in PENDING state", created));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('USER', 'PARENT', 'ADMIN')")
    public ResponseEntity<ApiResponse<List<ParentUserLinkResponse>>> listLinks(
            @AuthenticationPrincipal UserPrincipal principal
    ) {
        List<ParentUserLinkResponse> links = parentUserLinkService.getLinksForPrincipal(principal);
        return ResponseEntity.ok(ApiResponse.ok("Caregiver links retrieved", links));
    }

    @GetMapping("/{linkId}")
    @PreAuthorize("hasAnyRole('USER', 'PARENT', 'ADMIN')")
    public ResponseEntity<ApiResponse<ParentUserLinkResponse>> getLink(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID linkId
    ) {
        ParentUserLinkResponse link = parentUserLinkService.getLinkById(principal, linkId);
        return ResponseEntity.ok(ApiResponse.ok("Caregiver link retrieved", link));
    }

    @PatchMapping("/{linkId}/status")
    @PreAuthorize("hasAnyRole('USER', 'PARENT', 'ADMIN')")
    public ResponseEntity<ApiResponse<ParentUserLinkResponse>> updateLinkStatus(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID linkId,
            @Valid @RequestBody UpdateParentUserLinkStatusRequest request
    ) {
        ParentUserLinkResponse updated = parentUserLinkService.updateLinkStatus(principal, linkId, request);
        return ResponseEntity.ok(ApiResponse.ok("Caregiver link status updated", updated));
    }
}
