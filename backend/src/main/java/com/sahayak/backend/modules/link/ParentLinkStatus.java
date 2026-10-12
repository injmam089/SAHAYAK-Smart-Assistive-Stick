package com.sahayak.backend.modules.link;

/**
 * Explicit lifecycle status for a Caregiver (Parent) to Stick Operator (User) relationship.
 * Only ACTIVE links authorize caregiver access to user devices and realtime event streams.
 */
public enum ParentLinkStatus {
    PENDING,
    ACTIVE,
    REVOKED
}
