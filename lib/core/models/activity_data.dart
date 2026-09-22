import 'package:equatable/equatable.dart';

class ActivityData extends Equatable {
  final DateTime date;
  final List<String> readErrors;
  final int steps;
  final double activeCalories; // kcal
  final double totalCalories; // kcal
  final List<WorkoutSession> workouts;
  final Duration activeTime;

  const ActivityData({
    required this.date,
    this.readErrors = const [],
    required this.steps,
    required this.activeCalories,
    required this.totalCalories,
    required this.workouts,
    required this.activeTime,
  });

  factory ActivityData.empty(DateTime date) => ActivityData(
        date: date,
        steps: 0,
        activeCalories: 0,
        totalCalories: 0,
        workouts: [],
        activeTime: Duration.zero,
      );

  @override
  List<Object?> get props =>
      [date, steps, activeCalories, workouts, activeTime];
}

enum WorkoutType {
  running,
  cycling,
  swimming,
  weightTraining,
  yoga,
  hiit,
  walking,
  hiking,
  other
}

extension WorkoutTypeExt on WorkoutType {
  String get label {
    switch (this) {
      case WorkoutType.running:
        return 'Running';
      case WorkoutType.cycling:
        return 'Cycling';
      case WorkoutType.swimming:
        return 'Swimming';
      case WorkoutType.weightTraining:
        return 'Weight Training';
      case WorkoutType.yoga:
        return 'Yoga';
      case WorkoutType.hiit:
        return 'HIIT';
      case WorkoutType.walking:
        return 'Walking';
      case WorkoutType.hiking:
        return 'Hiking';
      case WorkoutType.other:
        return 'Other';
    }
  }
}

class WorkoutSession extends Equatable {
  final String id;
  final WorkoutType type;
  final DateTime start;
  final DateTime end;
  final double calories;
  final double? avgHeartRate;
  final double? maxHeartRate;
  final double strainContribution; // 0-21
  final List<HrZoneData> hrZones;

  const WorkoutSession({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
    required this.calories,
    this.avgHeartRate,
    this.maxHeartRate,
    required this.strainContribution,
    required this.hrZones,
  });

  Duration get duration => end.difference(start);

  @override
  List<Object?> get props => [id, start, end];
}

class HrZoneData extends Equatable {
  final int zone; // 1-5
  final Duration duration;
  final double minBpm;
  final double maxBpm;

  const HrZoneData({
    required this.zone,
    required this.duration,
    required this.minBpm,
    required this.maxBpm,
  });

  @override
  List<Object?> get props => [zone, duration];
}
