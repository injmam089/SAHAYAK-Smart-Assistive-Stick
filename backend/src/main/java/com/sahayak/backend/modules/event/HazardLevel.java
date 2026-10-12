package com.sahayak.backend.modules.event;

/**
 * Controlled hazard severity classification aligned with SAHAYAK configurable distance thresholds.
 */
public enum HazardLevel {
    NORMAL,
    SLOW_WARNING,
    FAST_WARNING,
    WARNING,
    DANGER,
    CRITICAL
}
