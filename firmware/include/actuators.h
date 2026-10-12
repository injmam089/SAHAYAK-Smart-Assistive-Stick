#ifndef SAHAYAK_ACTUATORS_H
#define SAHAYAK_ACTUATORS_H

/**
 * Phase 1A Skeleton: Haptic Motors, Buzzer, and Status LED Driver Abstraction.
 * Full implementation deferred to Phase 4 once motor driver IC and GPIO pinouts are finalized.
 */

namespace sahayak {
    void initActuators();
    void updateHapticAndAudioFeedback(int distanceCm);
    void stopAllActuators();
}

#endif // SAHAYAK_ACTUATORS_H
