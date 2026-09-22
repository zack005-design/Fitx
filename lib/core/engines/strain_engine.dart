import 'dart:math' as math;

import '../models/health_score.dart';
import '../models/activity_data.dart';
import '../models/user_profile.dart';

/// Computes a transparent activity-load index (0-21).
/// Active calories already include walking and workouts on Health Connect, so
/// the engine never adds steps and workout calories to the same day's load.
class StrainEngine {
  /// Returns a score in 0-21 range mapped to a HealthScore (0-100 value)
  static ({HealthScore score, double raw}) compute({
    required DateTime date,
    required ActivityData activity,
    required UserProfile profile,
  }) {
    final breakdown = <String, double>{};

    final double loadRatio;
    if (activity.activeCalories > 0 && profile.weightKg > 0) {
      // Scale estimated active energy to body mass. The saturating curve avoids
      // treating implausibly high imports as proportionally higher exertion.
      loadRatio = activity.activeCalories / (profile.weightKg * 8);
      breakdown['active_kcal_per_kg'] =
          activity.activeCalories / profile.weightKg;
    } else {
      loadRatio = profile.dailyStepGoal > 0
          ? activity.steps / profile.dailyStepGoal
          : 0;
      breakdown['step_goal_ratio'] = loadRatio;
    }
    final rawStrain = (21 * (1 - math.exp(-1.05 * loadRatio))).clamp(0.0, 21.0);

    // Convert to 0-100 for HealthScore
    final value = (rawStrain / 21.0 * 100).clamp(0.0, 100.0);

    final score = HealthScore(
      value: value,
      date: date,
      level: ScoreLevelExt.fromScore(value),
      breakdown: breakdown,
    );

    return (score: score, raw: rawStrain);
  }

  /// Get recommended strain target based on recovery score
  static double recommendedStrain(double recoveryScore) {
    if (recoveryScore >= 80) return 18.0; // Optimal: push hard
    if (recoveryScore >= 60) return 14.0; // Good: moderate
    if (recoveryScore >= 40) return 10.0; // Fair: light activity
    return 7.0; // Poor: rest
  }

  /// HR zone label
  static String hrZoneLabel(int zone) {
    switch (zone) {
      case 1:
        return 'Warm Up';
      case 2:
        return 'Easy';
      case 3:
        return 'Aerobic';
      case 4:
        return 'Threshold';
      case 5:
        return 'Maximum';
      default:
        return 'Unknown';
    }
  }
}
