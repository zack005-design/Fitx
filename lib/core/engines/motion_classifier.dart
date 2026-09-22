import 'dart:math' as math;

import '../services/device_sensor_service.dart';

enum GuidedMotion { calibrating, still, walking, running, strengthMovement }

class MotionGuidance {
  const MotionGuidance({
    required this.motion,
    required this.confidence,
    required this.cue,
    this.cadence,
  });

  final GuidedMotion motion;
  final double confidence;
  final String cue;
  final int? cadence;

  String get label => switch (motion) {
        GuidedMotion.calibrating => 'Calibrating motion',
        GuidedMotion.still => 'Resting',
        GuidedMotion.walking => 'Walking',
        GuidedMotion.running => 'Running',
        GuidedMotion.strengthMovement => 'Strength movement',
      };
}

/// Lightweight foreground classifier for live workout guidance.
///
/// It deliberately reports broad motion classes rather than pretending a
/// phone can identify a specific lift. Raw samples never leave the device.
class MotionClassifier {
  final List<({int time, double magnitude})> _acceleration = [];
  final List<int> _steps = [];
  double _gyroEnergy = 0;
  int _samples = 0;

  MotionGuidance add(DeviceSensorSample sample) {
    _samples++;
    final now = sample.timestampNanos;
    if (sample.type == 'stepDetector') _steps.add(now);
    if (sample.type == 'accelerometer' && sample.values.length >= 3) {
      final magnitude = math.sqrt(sample.values
          .take(3)
          .fold<double>(0, (sum, value) => sum + value * value));
      _acceleration.add((time: now, magnitude: magnitude));
    }
    if (sample.type == 'gyroscope' && sample.values.length >= 3) {
      final magnitude = math.sqrt(sample.values
          .take(3)
          .fold<double>(0, (sum, value) => sum + value * value));
      _gyroEnergy = _gyroEnergy * .86 + magnitude * .14;
    }

    const window = 4000000000;
    _acceleration.removeWhere((point) => now - point.time > window);
    _steps.removeWhere((time) => now - time > window);
    if (_samples < 8 || _acceleration.length < 6) {
      return const MotionGuidance(
        motion: GuidedMotion.calibrating,
        confidence: 0,
        cue: 'Move naturally while FitX learns the phone position.',
      );
    }

    final mean =
        _acceleration.fold<double>(0, (sum, point) => sum + point.magnitude) /
            _acceleration.length;
    final variance = _acceleration.fold<double>(0, (sum, point) {
          final delta = point.magnitude - mean;
          return sum + delta * delta;
        }) /
        _acceleration.length;
    final cadence = (_steps.length * 15).clamp(0, 240);

    if (cadence >= 125 || variance > 4.5) {
      return MotionGuidance(
        motion: GuidedMotion.running,
        confidence: (.55 + variance / 20).clamp(.55, .96),
        cadence: cadence == 0 ? null : cadence,
        cue: cadence > 190
            ? 'Quick cadence detected. Keep the effort controlled.'
            : 'Steady impact pattern detected. Keep your stride relaxed.',
      );
    }
    if (cadence >= 45) {
      return MotionGuidance(
        motion: GuidedMotion.walking,
        confidence: (.58 + cadence / 500).clamp(.58, .9),
        cadence: cadence,
        cue: 'Consistent steps detected. Keep a comfortable rhythm.',
      );
    }
    if (_gyroEnergy > .42 && variance > .35) {
      return MotionGuidance(
        motion: GuidedMotion.strengthMovement,
        confidence: (.5 + (_gyroEnergy + variance) / 10).clamp(.5, .86),
        cue: 'Controlled movement detected. Finish the rep before logging.',
      );
    }
    return MotionGuidance(
      motion: GuidedMotion.still,
      confidence: (1 - variance / 3).clamp(.55, .96),
      cue: 'Rest interval detected. Breathe slowly before your next set.',
    );
  }
}
