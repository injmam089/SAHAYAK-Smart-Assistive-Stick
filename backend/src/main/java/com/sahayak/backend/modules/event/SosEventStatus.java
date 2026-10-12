package com.sahayak.backend.modules.event;

/**
 * Controlled lifecycle state machine for an SOS emergency event (Phase 1E).
 *
 * Valid transitions:
 * - TRIGGERED -> ACKNOWLEDGED
 * - TRIGGERED -> CANCELLED
 * - ACKNOWLEDGED -> RESOLVED
 *
 * Terminal states: RESOLVED, CANCELLED (cannot reopen or transition further).
 */
public enum SosEventStatus {
    TRIGGERED,
    ACKNOWLEDGED,
    RESOLVED,
    CANCELLED;

    public boolean canTransitionTo(SosEventStatus next) {
        if (next == null || this == next) {
            return false;
        }
        return switch (this) {
            case TRIGGERED -> next == ACKNOWLEDGED || next == CANCELLED;
            case ACKNOWLEDGED -> next == RESOLVED;
            case RESOLVED, CANCELLED -> false;
        };
    }

    public boolean isTerminal() {
        return this == RESOLVED || this == CANCELLED;
    }
}
