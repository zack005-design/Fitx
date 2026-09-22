import '../models/health_score.dart';
import '../models/sleep_data.dart';

/// Computes Sleep Score (0-100)
/// Components:
///   - Duration (40%): How close to 8hr goal
///   - Efficiency (25%): Time asleep / time in bed
///   - Deep sleep (20%): Percentage of deep sleep (target ~20%)
///   - REM sleep (15%): Percentage of REM (target ~20%)
class SleepEngine {
  static HealthScore compute({
    required SleepData sleep,
    required Duration sleepGoal,
  }) {
    if (sleepGoal <= Duration.zero || sleep.totalSleep <= Duration.zero) {
      return HealthScore.empty(sleep.date);
    }
    final breakdown = <String, double>{};

    // Duration score
    final goalMinutes = sleepGoal.inMinutes.toDouble();
    final actualMinutes = sleep.totalSleep.inMinutes.toDouble();
    double durationScore;
    if (actualMinutes >= goalMinutes) {
      // Penalty for oversleeping beyond 10hr
      final excess = actualMinutes - goalMinutes;
      durationScore =
          (100 - (excess / 30).clamp(0, 15)).toDouble().clamp(0.0, 100.0);
    } else {
      durationScore = (actualMinutes / goalMinutes * 100).clamp(0.0, 100.0);
    }
    breakdown['duration'] = durationScore;

    // Efficiency score
    final efficiencyScore = (sleep.efficiency * 100).clamp(0.0, 100.0);
    breakdown['efficiency'] = efficiencyScore;

    // Deep sleep score (target: 20% of total sleep)
    double deepScore = 0;
    if (sleep.totalSleep.inMinutes > 0) {
      final deepPct = sleep.deepDuration.inMinutes / sleep.totalSleep.inMinutes;
      // 0-10%: score 0-50, 10-20%: score 50-100, 20-30%: score 100-80
      if (deepPct <= 0.20) {
        deepScore = (deepPct / 0.20 * 100).clamp(0.0, 100.0);
      } else {
        deepScore = (100 - ((deepPct - 0.20) / 0.10 * 20)).clamp(80.0, 100.0);
      }
    }
    breakdown['deep'] = deepScore;

    // REM sleep score (target: 20-25%)
    double remScore = 0;
    if (sleep.totalSleep.inMinutes > 0) {
      final remPct = sleep.remDuration.inMinutes / sleep.totalSleep.inMinutes;
      if (remPct <= 0.25) {
        remScore = (remPct / 0.25 * 100).clamp(0.0, 100.0);
      } else {
        remScore = (100 - ((remPct - 0.25) / 0.10 * 20)).clamp(80.0, 100.0);
      }
    }
    breakdown['rem'] = remScore;

    final hasDeep = sleep.stages.any((stage) => stage.stage == SleepStage.deep);
    final hasRem = sleep.stages.any((stage) => stage.stage == SleepStage.rem);
    final hasEfficiency =
        sleep.bedtime != null && sleep.wakeTime != null && sleep.efficiency > 0;
    if (!hasDeep) breakdown.remove('deep');
    if (!hasRem) breakdown.remove('rem');
    if (!hasEfficiency) breakdown.remove('efficiency');
    final weight = .40 +
        (hasEfficiency ? .25 : 0) +
        (hasDeep ? .20 : 0) +
        (hasRem ? .15 : 0);
    final value = ((durationScore * .40 +
                (hasEfficiency ? efficiencyScore * .25 : 0) +
                (hasDeep ? deepScore * .20 : 0) +
                (hasRem ? remScore * .15 : 0)) /
            weight)
        .clamp(0.0, 100.0);

    return HealthScore(
      value: value,
      date: sleep.date,
      level: ScoreLevelExt.fromScore(value),
      breakdown: breakdown,
    );
  }
}
