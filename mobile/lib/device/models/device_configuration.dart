/// Centralized, configurable threshold and feedback parameters for the SAHAYAK stick.
/// Default thresholds follow Decision 005:
/// > 150 cm: normal
/// 100-150 cm: slow warning
/// 50-100 cm: faster warning
/// < 50 cm: strong/continuous warning
class DeviceConfiguration {
  final int normalThresholdCm;
  final int slowWarningThresholdCm;
  final int fastWarningThresholdCm;
  final bool audioAlertsEnabled;
  final int hapticIntensityPercent;

  const DeviceConfiguration({
    this.normalThresholdCm = 150,
    this.slowWarningThresholdCm = 100,
    this.fastWarningThresholdCm = 50,
    this.audioAlertsEnabled = true,
    this.hapticIntensityPercent = 100,
  });

  DeviceConfiguration copyWith({
    int? normalThresholdCm,
    int? slowWarningThresholdCm,
    int? fastWarningThresholdCm,
    bool? audioAlertsEnabled,
    int? hapticIntensityPercent,
  }) {
    return DeviceConfiguration(
      normalThresholdCm: normalThresholdCm ?? this.normalThresholdCm,
      slowWarningThresholdCm: slowWarningThresholdCm ?? this.slowWarningThresholdCm,
      fastWarningThresholdCm: fastWarningThresholdCm ?? this.fastWarningThresholdCm,
      audioAlertsEnabled: audioAlertsEnabled ?? this.audioAlertsEnabled,
      hapticIntensityPercent: hapticIntensityPercent ?? this.hapticIntensityPercent,
    );
  }
}
