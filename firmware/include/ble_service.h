#ifndef SAHAYAK_BLE_SERVICE_H
#define SAHAYAK_BLE_SERVICE_H

/**
 * Phase 1A Skeleton: BLE GATT Telemetry & Emergency Notification Service.
 * Full implementation deferred to Phase 4.
 */

namespace sahayak {
    void initBleService();
    void sendTelemetryNotification(int forwardCm, int groundCm, int batteryPct);
    void sendSosNotification();
    bool isBleClientConnected();
}

#endif // SAHAYAK_BLE_SERVICE_H
