#ifndef SAHAYAK_SENSORS_H
#define SAHAYAK_SENSORS_H

/**
 * Phase 1A Skeleton: Ultrasonic Sensor Driver Abstraction.
 * Full implementation deferred to Phase 4 once GPIO pinouts and
 * HC-SR04 voltage-conditioning circuitry are finalized.
 */

namespace sahayak {
    void initSensors();
    int readForwardDistanceCm();
    int readGroundDistanceCm();
}

#endif // SAHAYAK_SENSORS_H
