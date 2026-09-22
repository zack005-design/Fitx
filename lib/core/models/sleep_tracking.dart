import 'sleep_data.dart';

class SleepSensorEpoch {
  const SleepSensorEpoch({
    required this.start,
    required this.durationSeconds,
    required this.accelerationRms,
    required this.gyroscopeRms,
    required this.averageLux,
    required this.accelerometerSamples,
    required this.gyroscopeSamples,
  });

  final DateTime start;
  final int durationSeconds;
  final double accelerationRms;
  final double gyroscopeRms;
  final double averageLux;
  final int accelerometerSamples;
  final int gyroscopeSamples;

  factory SleepSensorEpoch.fromMap(Map<Object?, Object?> map) =>
      SleepSensorEpoch(
        start: DateTime.fromMillisecondsSinceEpoch(
            (map['startMs'] as num).toInt()),
        durationSeconds: (map['durationSeconds'] as num? ?? 30).toInt(),
        accelerationRms: (map['accelerationRms'] as num? ?? 0).toDouble(),
        gyroscopeRms: (map['gyroscopeRms'] as num? ?? 0).toDouble(),
        averageLux: (map['averageLux'] as num? ?? -1).toDouble(),
        accelerometerSamples:
            (map['accelerometerSamples'] as num? ?? 0).toInt(),
        gyroscopeSamples: (map['gyroscopeSamples'] as num? ?? 0).toInt(),
      );

  Map<String, Object?> toMap() => {
        'startMs': start.millisecondsSinceEpoch,
        'durationSeconds': durationSeconds,
        'accelerationRms': accelerationRms,
        'gyroscopeRms': gyroscopeRms,
        'averageLux': averageLux,
        'accelerometerSamples': accelerometerSamples,
        'gyroscopeSamples': gyroscopeSamples,
      };
}

class NativeSleepTrackingState {
  const NativeSleepTrackingState({
    required this.isTracking,
    this.startedAt,
    this.epochs = const [],
    this.hasAccelerometer = false,
    this.hasGyroscope = false,
    this.hasLightSensor = false,
  });

  final bool isTracking;
  final DateTime? startedAt;
  final List<SleepSensorEpoch> epochs;
  final bool hasAccelerometer;
  final bool hasGyroscope;
  final bool hasLightSensor;

  factory NativeSleepTrackingState.fromMap(Map<Object?, Object?> map) {
    final rawEpochs = map['epochs'] as List<Object?>? ?? const [];
    return NativeSleepTrackingState(
      isTracking: map['isTracking'] == true,
      startedAt: map['startedAtMs'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['startedAtMs'] as num).toInt())
          : null,
      epochs: rawEpochs
          .whereType<Map<Object?, Object?>>()
          .map(SleepSensorEpoch.fromMap)
          .toList(growable: false),
      hasAccelerometer: map['hasAccelerometer'] == true,
      hasGyroscope: map['hasGyroscope'] == true,
      hasLightSensor: map['hasLightSensor'] == true,
    );
  }
}

class PhoneSleepEstimate {
  const PhoneSleepEstimate({
    required this.sleep,
    required this.confidence,
    required this.coverage,
    required this.epochsAnalyzed,
  });

  final SleepData sleep;
  final double confidence;
  final double coverage;
  final int epochsAnalyzed;
}
