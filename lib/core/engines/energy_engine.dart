import '../models/health_score.dart';

/// Energy Bank: combination of recovery and strain delta.
/// Think of it as a battery. Recovery charges it, strain drains it.
/// Score: 0-100 (100 = full tank)
class EnergyEngine {
  static HealthScore compute({
    required DateTime date,
    required HealthScore recoveryScore,
    required double strainRaw, // 0-21
    required double strainTarget, // recommended 0-21
  }) {
    // Start with recovery as the initial charge
    final initialCharge = recoveryScore.value;

    // Drain based on how much strain exceeds or is below target
    // If strain == target: no extra drain
    // If strain >> target: large drain
    // If strain << target: small drain (light day)
    final strainRatio = strainTarget > 0 ? strainRaw / strainTarget : 1.0;
    double drainFactor;
    if (strainRatio <= 0.5) {
      drainFactor = 0.05; // Almost no drain (rest day)
    } else if (strainRatio <= 1.0) {
      drainFactor = 0.05 + (strainRatio - 0.5) * 0.3; // 5-20% drain
    } else {
      drainFactor = 0.20 + (strainRatio - 1.0) * 0.25; // 20-45%+ drain
    }

    final energyValue = (initialCharge * (1.0 - drainFactor)).clamp(0.0, 100.0);

    return HealthScore(
      value: energyValue,
      date: date,
      level: ScoreLevelExt.fromScore(energyValue),
      breakdown: {
        'initial_charge': initialCharge,
        'drain_factor': drainFactor * 100,
        'strain_raw': strainRaw,
        'strain_target': strainTarget,
      },
    );
  }

  static String energyLabel(double score) {
    if (score >= 80) return 'Charged';
    if (score >= 55) return 'Good';
    if (score >= 35) return 'Low';
    return 'Depleted';
  }
}
