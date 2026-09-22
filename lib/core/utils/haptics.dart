import 'package:flutter/services.dart';

/// Centralized micro-haptic triggers calibrated for Xiaomi's X-axis linear vibration motor.
/// Provides refined tactile feedback without excessive vibration rumble.
class FitXHaptics {
  FitXHaptics._();

  /// Subtle click for card taps, segmented toggles (7D/30D), and radio selections.
  static void selectionClick() {
    HapticFeedback.selectionClick();
  }

  /// Crisp light impact for quick-actions like adding +250ml water or finishing a workout set.
  static void lightImpact() {
    HapticFeedback.lightImpact();
  }

  /// Medium impact for significant events like completing a workout or reaching a daily strain target.
  static void mediumImpact() {
    HapticFeedback.mediumImpact();
  }
}
