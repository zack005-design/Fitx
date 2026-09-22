import 'dart:math';
import '../models/health_score.dart';
import '../models/vitals_data.dart';

/// Computes Stress Score (0-100)
/// Higher = more stressed.
/// Uses:
///   - HRV deviation from baseline (primary)
///   - Resting HR elevation (secondary)
///   - SpO2 reduction (minor)
class StressEngine {
  static HealthScore compute({
    required DateTime date,
    required VitalsData vitals,
    required double? hrvBaseline,
    required double? rhrBaseline,
  }) {
    final breakdown = <String, double>{};
    double stressScore = 30.0; // baseline low stress

    // HRV stress indicator (primary)
    double hrvStress = 30.0;
    if (vitals.hrv != null && hrvBaseline != null && hrvBaseline > 0) {
      final ratio = vitals.hrv! / hrvBaseline;
      // Lower HRV relative to baseline = more stress
      // ratio 1.0 = 30 stress, ratio 0.5 = 80 stress, ratio 1.5 = 10 stress
      hrvStress = (30 + (1.0 - ratio) * 80).clamp(0.0, 100.0);
    } else if (vitals.hrv != null) {
      // Absolute: HRV < 20ms = high stress, HRV > 60ms = low stress
      hrvStress = ((60 - vitals.hrv!) / 40 * 100).clamp(0.0, 100.0);
    }
    breakdown['hrv'] = hrvStress;

    // RHR elevation
    double rhrStress = 30.0;
    if (vitals.restingHeartRate != null &&
        rhrBaseline != null &&
        rhrBaseline > 0) {
      final delta = vitals.restingHeartRate! - rhrBaseline;
      rhrStress = (30 + delta * 6).clamp(0.0, 100.0);
    }
    breakdown['rhr'] = rhrStress;

    // SpO2 (minor indicator)
    double spo2Stress = 20.0;
    if (vitals.spo2 != null) {
      // Normal SpO2 98-100%. Below 95% is concerning.
      spo2Stress = max(0.0, (98.0 - vitals.spo2!) * 5);
    }
    if (vitals.spo2 != null) breakdown['spo2'] = spo2Stress;

    stressScore = ((hrvStress * 0.55 +
                rhrStress * 0.35 +
                (vitals.spo2 != null ? spo2Stress * 0.10 : 0)) /
            (vitals.spo2 != null ? 1 : .9))
        .clamp(0.0, 100.0);

    // Invert: for stress monitor, higher score = more stressed
    // HealthScore.level is based on 0-100, but for stress 100 = worst
    final healthLevel = ScoreLevelExt.fromScore(100 - stressScore);

    return HealthScore(
      value: stressScore,
      date: date,
      level: healthLevel,
      breakdown: breakdown,
    );
  }

  static String stressLabel(double score) {
    if (score <= 30) return 'Low';
    if (score <= 55) return 'Moderate';
    if (score <= 75) return 'High';
    return 'Very High';
  }
}
