import 'dart:math';
import '../models/health_score.dart';
import '../models/vitals_data.dart';

/// Computes Recovery Score (0-100) from HRV, RHR, and Sleep.
/// Algorithm:
///   - HRV component (40%): How today's HRV compares to 30-day baseline
///   - RHR component (35%): How today's RHR compares to 30-day baseline
///   - Sleep component (25%): Sleep score passthrough
class RecoveryEngine {
  static HealthScore compute({
    required DateTime date,
    required VitalsData vitals,
    required HealthScore sleepScore,
    required double? hrvBaseline,
    required double? rhrBaseline,
  }) {
    final breakdown = <String, double>{};

    // HRV component
    double hrvComponent = 50.0; // neutral default
    if (vitals.hrv != null && hrvBaseline != null && hrvBaseline > 0) {
      final ratio = vitals.hrv! / hrvBaseline;
      // ratio > 1 means better than baseline (good)
      // Sigmoid-like mapping: ratio 0.5 -> 20, 1.0 -> 50, 1.5 -> 80, 2.0 -> 95
      hrvComponent = _sigmoidMap(ratio, center: 1.0, spread: 0.4);
    } else if (vitals.hrv != null) {
      // No baseline yet — score based on absolute HRV (20-60ms is typical range)
      hrvComponent = ((vitals.hrv! - 20) / 40 * 100).clamp(20.0, 95.0);
    }
    breakdown['hrv'] = hrvComponent;

    // RHR component (lower = better)
    double rhrComponent = 50.0;
    if (vitals.restingHeartRate != null &&
        rhrBaseline != null &&
        rhrBaseline > 0) {
      final delta = vitals.restingHeartRate! - rhrBaseline;
      // delta < 0: lower than baseline (good)
      // delta = 0: at baseline = 50
      // delta > 5: elevated (bad)
      rhrComponent = (50.0 - delta * 8.0).clamp(5.0, 95.0);
    } else if (vitals.restingHeartRate != null) {
      // Score based on absolute RHR (40-80 bpm typical)
      rhrComponent =
          ((80 - vitals.restingHeartRate!) / 40 * 100).clamp(20.0, 95.0);
    }
    breakdown['rhr'] = rhrComponent;

    // Sleep component
    final sleepComponent = sleepScore.value;
    breakdown['sleep'] = sleepComponent;

    // Weighted sum
    final raw =
        hrvComponent * 0.40 + rhrComponent * 0.35 + sleepComponent * 0.25;
    final value = raw.clamp(0.0, 100.0);

    return HealthScore(
      value: value,
      date: date,
      level: ScoreLevelExt.fromScore(value),
      breakdown: breakdown,
    );
  }

  /// Maps a ratio to a 0-100 score using a sigmoid curve.
  static double _sigmoidMap(double ratio,
      {required double center, required double spread}) {
    final x = (ratio - center) / spread;
    final sigmoid = 1.0 / (1.0 + exp(-x * 3));
    return (sigmoid * 100).clamp(0.0, 100.0);
  }
}
