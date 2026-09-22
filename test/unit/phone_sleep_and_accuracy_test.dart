import 'package:fitx/core/engines/phone_sleep_inference_engine.dart';
import 'package:fitx/core/engines/strain_engine.dart';
import 'package:fitx/core/models/activity_data.dart';
import 'package:fitx/core/models/sleep_data.dart';
import 'package:fitx/core/models/sleep_tracking.dart';
import 'package:fitx/core/models/user_profile.dart';
import 'package:fitx/core/services/health_data_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phone inference reports sleep/wake without inventing REM or deep sleep',
      () {
    final start = DateTime(2026, 9, 13, 22);
    final epochs = <SleepSensorEpoch>[
      for (var i = 0; i < 960; i++)
        SleepSensorEpoch(
          start: start.add(Duration(seconds: i * 30)),
          durationSeconds: 30,
          accelerationRms: i < 20 || i >= 940 ? .8 : .02,
          gyroscopeRms: i < 20 || i >= 940 ? .4 : .005,
          averageLux: i < 20 || i >= 940 ? 20 : 0,
          accelerometerSamples: 150,
          gyroscopeSamples: 150,
        ),
    ];
    final estimate = PhoneSleepInferenceEngine.estimate(
      epochs: epochs,
      sessionStart: start,
      sessionEnd: start.add(const Duration(hours: 8)),
    );

    expect(estimate, isNotNull);
    expect(estimate!.sleep.source, SleepDataSource.phoneSensors);
    expect(estimate.sleep.totalSleep, greaterThan(const Duration(hours: 7)));
    expect(estimate.sleep.deepDuration, Duration.zero);
    expect(estimate.sleep.remDuration, Duration.zero);
    expect(estimate.sleep.stages.map((s) => s.stage),
        isNot(contains(SleepStage.deep)));
    expect(estimate.coverage, 1);
  });

  test('short or sparse sessions remain unavailable', () {
    final start = DateTime(2026, 9, 13, 22);
    expect(
        PhoneSleepInferenceEngine.estimate(
            epochs: const [],
            sessionStart: start,
            sessionEnd: start.add(const Duration(hours: 8))),
        isNull);
    expect(
        PhoneSleepInferenceEngine.estimate(
            epochs: const [],
            sessionStart: start,
            sessionEnd: start.add(const Duration(minutes: 30))),
        isNull);
  });

  test('vital validation rejects corrupt values and normalizes SpO2 units', () {
    expect(HealthDataValidator.heartRate(0), isNull);
    expect(HealthDataValidator.heartRate(72), 72);
    expect(HealthDataValidator.oxygenSaturation(.98), 98);
    expect(HealthDataValidator.oxygenSaturation(140), isNull);
    expect(HealthDataValidator.median([40, 41, 300]), 41);
  });

  test('strain does not add steps on top of active energy', () {
    const profile = UserProfile(
      name: 'A',
      age: 30,
      gender: Gender.other,
      heightCm: 170,
      weightKg: 70,
    );
    ActivityData activity(int steps) => ActivityData(
          date: DateTime(2026, 9, 14),
          steps: steps,
          activeCalories: 500,
          totalCalories: 2000,
          workouts: const [],
          activeTime: const Duration(hours: 1),
        );
    final lowSteps = StrainEngine.compute(
        date: DateTime(2026, 9, 14),
        activity: activity(1000),
        profile: profile);
    final highSteps = StrainEngine.compute(
        date: DateTime(2026, 9, 14),
        activity: activity(20000),
        profile: profile);
    expect(lowSteps.raw, highSteps.raw);
    expect(lowSteps.score.breakdown, contains('active_kcal_per_kg'));
  });
}
