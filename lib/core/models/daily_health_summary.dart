import 'health_score.dart';
import 'sleep_data.dart';
import 'vitals_data.dart';
import 'activity_data.dart';
import 'metric_value.dart';
import 'health_day.dart';

class DailyHealthSummary {
  final DateTime date;
  final HealthScore recovery;
  final HealthScore sleep;
  final SleepData sleepData;
  final HealthScore strain;
  final double strainRaw;
  final HealthScore stress;
  final HealthScore energy;
  final VitalsData vitals;
  final ActivityData activity;

  /// The number of days where both HRV and resting HR are available.
  /// FitX starts treating the personal baseline as reliable at 14 days.
  final int baselineDays;
  final double? hrvBaseline;
  final double? rhrBaseline;
  final DateTime? syncedAt;
  final Duration? sleepGoal;
  final double? strainTarget;
  final int formulaVersion;
  final List<String> readErrors;

  DailyHealthSummary withReadErrors(List<String> errors) => DailyHealthSummary(
        date: date,
        recovery: recovery,
        sleep: sleep,
        sleepData: sleepData,
        strain: strain,
        strainRaw: strainRaw,
        stress: stress,
        energy: energy,
        vitals: vitals,
        activity: activity,
        baselineDays: baselineDays,
        hrvBaseline: hrvBaseline,
        rhrBaseline: rhrBaseline,
        syncedAt: syncedAt,
        sleepGoal: sleepGoal,
        strainTarget: strainTarget,
        formulaVersion: formulaVersion,
        readErrors: errors,
      );

  HealthScore scoreFor(String type) => switch (type) {
        'recovery' => recovery,
        'sleep' => sleep,
        'strain' => strain,
        'stress' => stress,
        'energy' => energy,
        _ => throw ArgumentError.value(type),
      };

  MetricStatus statusFor(String type) {
    final inputs = switch (type) {
      'sleep' =>
        hasSleepData && sleepGoal != null && sleepGoal! > Duration.zero,
      'recovery' =>
        hasRecoveryData && sleepGoal != null && sleepGoal! > Duration.zero,
      'stress' => vitals.hrv != null && vitals.restingHeartRate != null,
      'energy' => hasRecoveryData &&
          hasActivityData &&
          sleepGoal != null &&
          sleepGoal! > Duration.zero &&
          strainTarget != null,
      'strain' => hasActivityData && strainTarget != null,
      _ => false,
    };
    if (!inputs) return MetricStatus.unavailable;
    if (['recovery', 'stress', 'energy'].contains(type) &&
        (!hasReliableBaseline ||
            (hrvBaseline ?? 0) <= 0 ||
            (rhrBaseline ?? 0) <= 0)) {
      return MetricStatus.calibrating;
    }
    return MetricStatus.available;
  }

  MetricValue<double> metricFor(String type) {
    final confidence = switch (type) {
      'sleep' when sleepData.source == SleepDataSource.phoneSensors =>
        (sleepData.confidence ?? 0) >= .8
            ? MetricConfidence.medium
            : MetricConfidence.low,
      'sleep' => sleepData.stages.isEmpty
          ? MetricConfidence.medium
          : MetricConfidence.high,
      'recovery' ||
      'stress' =>
        baselineDays >= 30 ? MetricConfidence.high : MetricConfidence.medium,
      'strain' => MetricConfidence.medium,
      'energy' => MetricConfidence.low,
      _ => MetricConfidence.unknown,
    };
    final sourceName =
        type == 'sleep' && sleepData.source == SleepDataSource.phoneSensors
            ? 'FitX from phone sensors'
            : 'FitX from Health Connect';
    final metadata = MetricMetadata(
      range:
          MetricTimeRange(start: healthDay(date), end: shiftHealthDay(date, 1)),
      source: MetricSource(type: MetricSourceType.derived, name: sourceName),
      confidence: confidence,
      lastSyncedAt: syncedAt,
    );
    return switch (statusFor(type)) {
      MetricStatus.available =>
        MetricValue.available(value: scoreFor(type).value, metadata: metadata),
      MetricStatus.calibrating => MetricValue.calibrating(
          metadata: metadata,
          progress: baselineConfidence,
          message: baselineMessage),
      MetricStatus.unavailable => MetricValue.unavailable(
          metadata: metadata, reason: MetricUnavailableReason.noData),
    };
  }

  const DailyHealthSummary({
    required this.date,
    required this.recovery,
    required this.sleep,
    required this.sleepData,
    required this.strain,
    required this.strainRaw,
    required this.stress,
    required this.energy,
    required this.vitals,
    required this.activity,
    required this.baselineDays,
    this.hrvBaseline,
    this.rhrBaseline,
    this.syncedAt,
    this.sleepGoal,
    this.strainTarget,
    this.formulaVersion = 2,
    this.readErrors = const [],
  });

  String get readinessMessage => 'Review your recorded recovery inputs.';

  /// These flags describe whether the source observations needed to explain a
  /// score exist. They prevent the UI from presenting an engine's neutral
  /// fallback as if it were a measured result.
  bool get hasSleepData => sleepData.totalSleep > Duration.zero;
  bool get hasRecoveryData =>
      hasSleepData && vitals.hrv != null && vitals.restingHeartRate != null;
  bool get hasStressData =>
      vitals.hrv != null || vitals.restingHeartRate != null;
  bool get hasVitalsData =>
      vitals.hrv != null ||
      vitals.restingHeartRate != null ||
      vitals.spo2 != null ||
      vitals.respiratoryRate != null ||
      vitals.heartRateSamples.isNotEmpty;
  bool get hasActivityData =>
      activity.steps > 0 ||
      activity.activeCalories > 0 ||
      activity.activeTime > Duration.zero ||
      activity.workouts.isNotEmpty;

  double get baselineConfidence =>
      (baselineDays / 14).clamp(0.0, 1.0).toDouble();
  bool get hasReliableBaseline => baselineDays >= 14;
  String get baselineMessage => hasReliableBaseline
      ? 'Personal baseline established from $baselineDays days of data.'
      : 'Building your personal baseline: $baselineDays of 14 days.';
}
