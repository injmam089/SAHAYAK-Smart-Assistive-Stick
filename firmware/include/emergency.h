#ifndef SAHAYAK_EMERGENCY_H
#define SAHAYAK_EMERGENCY_H

/**
 * Phase 1A Skeleton: Emergency Button Detection & Debouncing.
 * Full implementation deferred to Phase 4 once GPIO pinout is finalized.
 */

namespace sahayak {
    void initEmergencyButton();
    bool checkEmergencyTriggered();
}

#endif // SAHAYAK_EMERGENCY_H
