import 'package:fitx/core/models/activity_data.dart';
import 'package:fitx/core/models/daily_health_summary.dart';
import 'package:fitx/core/models/health_score.dart';
import 'package:fitx/core/models/sleep_data.dart';
import 'package:fitx/core/models/vitals_data.dart';

DailyHealthSummary healthFixture(
    {DateTime? date,
    bool empty = false,
    bool partial = false,
    int baselineDays = 14,
    double scoreValue = 72}) {
  final day = date ?? DateTime(2026, 9, 13);
  final bedtime = DateTime(day.year, day.month, day.day - 1, 23);
  final wake = DateTime(day.year, day.month, day.day, 7);
  HealthScore score() => HealthScore(
      value: scoreValue,
      date: day,
      level: ScoreLevel.good,
      breakdown: empty ? {} : {'hrv': 70, 'rhr': 65, 'sleep': 80});
  return DailyHealthSummary(
    date: day,
    recovery: score(),
    sleep: score(),
    strain: score(),
    strainRaw: 8,
    stress: score(),
    energy: score(),
    baselineDays: baselineDays,
    hrvBaseline: baselineDays > 0 ? 50 : null,
    rhrBaseline: baselineDays > 0 ? 60 : null,
    sleepGoal: const Duration(hours: 8),
    strainTarget: 14,
    syncedAt: day.add(const Duration(hours: 9)),
    sleepData: empty
        ? SleepData.empty(day)
        : SleepData(
            date: day,
            bedtime: bedtime,
            wakeTime: wake,
            totalSleep: const Duration(hours: 7),
            remDuration: const Duration(hours: 1),
            deepDuration: const Duration(hours: 1),
            lightDuration: const Duration(hours: 5),
            awakeDuration: const Duration(hours: 1),
            efficiency: .875,
            wakeCount: 1,
            stages: [
                SleepStageSegment(
                    start: bedtime,
                    end: bedtime.add(const Duration(hours: 5)),
                    stage: SleepStage.light),
                SleepStageSegment(
                    start: bedtime.add(const Duration(hours: 5)),
                    end: bedtime.add(const Duration(hours: 6)),
                    stage: SleepStage.deep),
                SleepStageSegment(
                    start: bedtime.add(const Duration(hours: 6)),
                    end: bedtime.add(const Duration(hours: 7)),
                    stage: SleepStage.rem),
                SleepStageSegment(
                    start: bedtime.add(const Duration(hours: 7)),
                    end: wake,
                    stage: SleepStage.awake)
              ]),
    vitals: empty
        ? VitalsData.empty(day)
        : VitalsData(
            date: day,
            hrv: 55,
            restingHeartRate: partial ? null : 58,
            spo2: partial ? null : 98,
            respiratoryRate: partial ? null : 15,
            heartRateSamples: []),
    activity: empty || partial
        ? ActivityData.empty(day)
        : ActivityData(
            date: day,
            steps: 4200,
            activeCalories: 230,
            totalCalories: 1700,
            workouts: [],
            activeTime: Duration.zero),
  );
}
