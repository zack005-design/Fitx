import 'package:equatable/equatable.dart';

enum SleepStage { awake, light, deep, rem }

enum SleepDataSource { unknown, healthConnect, phoneSensors }

class SleepStageSegment extends Equatable {
  final DateTime start;
  final DateTime end;
  final SleepStage stage;

  const SleepStageSegment(
      {required this.start, required this.end, required this.stage});

  Duration get duration => end.difference(start);

  @override
  List<Object?> get props => [start, end, stage];
}

class SleepData extends Equatable {
  final DateTime date;
  final List<String> readErrors;
  final DateTime? bedtime;
  final DateTime? wakeTime;
  final Duration totalSleep;
  final Duration remDuration;
  final Duration deepDuration;
  final Duration lightDuration;
  final Duration awakeDuration;
  final List<SleepStageSegment> stages;
  final double efficiency; // 0-1
  final int wakeCount;
  final SleepDataSource source;
  final double? confidence;
  final List<String> limitations;

  const SleepData({
    required this.date,
    this.readErrors = const [],
    this.bedtime,
    this.wakeTime,
    required this.totalSleep,
    required this.remDuration,
    required this.deepDuration,
    required this.lightDuration,
    required this.awakeDuration,
    required this.stages,
    required this.efficiency,
    required this.wakeCount,
    this.source = SleepDataSource.unknown,
    this.confidence,
    this.limitations = const [],
  });

  factory SleepData.empty(DateTime date) => SleepData(
        date: date,
        totalSleep: Duration.zero,
        remDuration: Duration.zero,
        deepDuration: Duration.zero,
        lightDuration: Duration.zero,
        awakeDuration: Duration.zero,
        stages: [],
        efficiency: 0,
        wakeCount: 0,
      );

  String get sourceLabel => switch (source) {
        SleepDataSource.healthConnect => 'Health Connect',
        SleepDataSource.phoneSensors => 'Phone motion estimate',
        SleepDataSource.unknown => 'Recorded sleep',
      };

  @override
  List<Object?> get props =>
      [date, totalSleep, efficiency, source, confidence, limitations];
}
