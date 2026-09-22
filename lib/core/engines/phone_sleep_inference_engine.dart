import 'dart:math' as math;

import '../models/health_day.dart';
import '../models/sleep_data.dart';
import '../models/sleep_tracking.dart';

/// Conservative phone actigraphy. It estimates sleep/wake only; consumer phone
/// motion sensors cannot independently identify REM or deep sleep.
class PhoneSleepInferenceEngine {
  static const algorithmVersion = 1;

  static PhoneSleepEstimate? estimate({
    required List<SleepSensorEpoch> epochs,
    required DateTime sessionStart,
    required DateTime sessionEnd,
  }) {
    if (sessionEnd.difference(sessionStart) < const Duration(minutes: 45)) {
      return null;
    }
    final ordered = epochs
        .where((e) =>
            e.accelerometerSamples >= 3 &&
            !e.start.isBefore(sessionStart) &&
            e.start.isBefore(sessionEnd))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    if (ordered.length < 60) return null;

    final scores =
        ordered.map((e) => e.accelerationRms + e.gyroscopeRms * .18).toList();
    final median = _median(scores);
    final deviations = scores.map((s) => (s - median).abs()).toList();
    final mad = math.max(_median(deviations), .002);
    final awakeThreshold = median + 3.5 * mad;
    final rawAwake = scores.map((s) => s > awakeThreshold).toList();
    final awake = _smooth(rawAwake);

    final onset = _findStableSleep(awake, fromStart: true);
    final lastSleep = _findStableSleep(awake, fromStart: false);
    if (onset == null || lastSleep == null || lastSleep <= onset) return null;

    final segments = <SleepStageSegment>[];
    var currentStage = awake[onset] ? SleepStage.awake : SleepStage.light;
    var segmentStart = ordered[onset].start;
    var asleepSeconds = 0;
    var awakeSeconds = 0;
    var wakes = 0;
    for (var i = onset; i <= lastSleep; i++) {
      final stage = awake[i] ? SleepStage.awake : SleepStage.light;
      if (stage == SleepStage.light) {
        asleepSeconds += ordered[i].durationSeconds;
      } else {
        awakeSeconds += ordered[i].durationSeconds;
      }
      if (stage != currentStage) {
        segments.add(SleepStageSegment(
            start: segmentStart, end: ordered[i].start, stage: currentStage));
        if (stage == SleepStage.awake) wakes++;
        currentStage = stage;
        segmentStart = ordered[i].start;
      }
    }
    final end = ordered[lastSleep]
        .start
        .add(Duration(seconds: ordered[lastSleep].durationSeconds));
    segments.add(
        SleepStageSegment(start: segmentStart, end: end, stage: currentStage));

    final expectedEpochs =
        math.max(1, sessionEnd.difference(sessionStart).inSeconds ~/ 30);
    final coverage = (ordered.length / expectedEpochs).clamp(0.0, 1.0);
    final sampleQuality = ordered
            .map((e) => math.min(1.0, e.accelerometerSamples / 100))
            .reduce((a, b) => a + b) /
        ordered.length;
    final durationQuality =
        (asleepSeconds / const Duration(hours: 7).inSeconds).clamp(0.0, 1.0);
    final confidence =
        (.55 * coverage + .25 * sampleQuality + .20 * durationQuality)
            .clamp(0.0, 1.0);
    final timeInBed = math.max(1, asleepSeconds + awakeSeconds);
    final date = healthDay(end.subtract(const Duration(hours: 12)));
    final sleep = SleepData(
      date: date,
      bedtime: ordered[onset].start,
      wakeTime: end,
      totalSleep: Duration(seconds: asleepSeconds),
      remDuration: Duration.zero,
      deepDuration: Duration.zero,
      lightDuration: Duration(seconds: asleepSeconds),
      awakeDuration: Duration(seconds: awakeSeconds),
      stages: segments,
      efficiency: asleepSeconds / timeInBed,
      wakeCount: wakes,
      source: SleepDataSource.phoneSensors,
      confidence: confidence,
      limitations: const [
        'Sleep and wake are estimated from phone movement, not brain activity.',
        'REM and deep sleep are not estimated without a validated wearable signal.',
        'Keep the phone charging, face down, and stable on the mattress near your torso.',
      ],
    );
    return PhoneSleepEstimate(
        sleep: sleep,
        confidence: confidence,
        coverage: coverage,
        epochsAnalyzed: ordered.length);
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  static List<bool> _smooth(List<bool> input) {
    final result = List<bool>.from(input);
    for (var i = 2; i < input.length - 2; i++) {
      final awakeVotes = input.sublist(i - 2, i + 3).where((x) => x).length;
      result[i] = awakeVotes >= 2;
    }
    return result;
  }

  static int? _findStableSleep(List<bool> awake, {required bool fromStart}) {
    const window = 20; // Ten minutes with 30-second epochs.
    if (awake.length < window) return null;
    final indices = fromStart
        ? Iterable<int>.generate(awake.length - window + 1)
        : Iterable<int>.generate(
            awake.length - window + 1, (i) => awake.length - window - i);
    for (final i in indices) {
      if (awake.sublist(i, i + window).where((x) => !x).length >= 16) {
        return fromStart ? i : i + window - 1;
      }
    }
    return null;
  }
}
