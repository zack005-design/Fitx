import 'package:equatable/equatable.dart';

enum MuscleGroup {
  chest,
  back,
  shoulders,
  biceps,
  triceps,
  forearms,
  abs,
  glutes,
  quads,
  hamstrings,
  calves,
  fullBody,
  cardio
}

extension MuscleGroupExt on MuscleGroup {
  String get label {
    switch (this) {
      case MuscleGroup.chest:
        return 'Chest';
      case MuscleGroup.back:
        return 'Back';
      case MuscleGroup.shoulders:
        return 'Shoulders';
      case MuscleGroup.biceps:
        return 'Biceps';
      case MuscleGroup.triceps:
        return 'Triceps';
      case MuscleGroup.forearms:
        return 'Forearms';
      case MuscleGroup.abs:
        return 'Abs';
      case MuscleGroup.glutes:
        return 'Glutes';
      case MuscleGroup.quads:
        return 'Quads';
      case MuscleGroup.hamstrings:
        return 'Hamstrings';
      case MuscleGroup.calves:
        return 'Calves';
      case MuscleGroup.fullBody:
        return 'Full Body';
      case MuscleGroup.cardio:
        return 'Cardio';
    }
  }
}

class Exercise extends Equatable {
  final String id;
  final String name;
  final MuscleGroup primaryMuscle;
  final List<MuscleGroup> secondaryMuscles;
  final bool isCustom;

  const Exercise({
    required this.id,
    required this.name,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'primary_muscle': primaryMuscle.index,
        'secondary_muscles': secondaryMuscles.map((m) => m.index).join(','),
        'is_custom': isCustom ? 1 : 0,
      };

  factory Exercise.fromMap(Map<String, dynamic> m) {
    final secStr = m['secondary_muscles'] as String? ?? '';
    final secondary = secStr.isEmpty
        ? <MuscleGroup>[]
        : secStr
            .split(',')
            .map((i) => MuscleGroup.values[int.parse(i)])
            .toList();
    return Exercise(
      id: m['id'] as String,
      name: m['name'] as String,
      primaryMuscle: MuscleGroup.values[m['primary_muscle'] as int],
      secondaryMuscles: secondary,
      isCustom: (m['is_custom'] as int? ?? 0) == 1,
    );
  }

  @override
  List<Object?> get props => [id, name];
}

class ExerciseSet extends Equatable {
  final String id;
  final int setNumber;
  final double? weightKg;
  final int? reps;
  final Duration? duration; // for timed sets
  final bool isWarmup;
  final bool isCompleted;

  const ExerciseSet({
    required this.id,
    required this.setNumber,
    this.weightKg,
    this.reps,
    this.duration,
    this.isWarmup = false,
    this.isCompleted = false,
  });

  ExerciseSet copyWith({bool? isCompleted, double? weightKg, int? reps}) =>
      ExerciseSet(
        id: id,
        setNumber: setNumber,
        weightKg: weightKg ?? this.weightKg,
        reps: reps ?? this.reps,
        duration: duration,
        isWarmup: isWarmup,
        isCompleted: isCompleted ?? this.isCompleted,
      );

  Map<String, dynamic> toMap(String logExerciseId) => {
        'id': id,
        'log_exercise_id': logExerciseId,
        'set_number': setNumber,
        'weight_kg': weightKg,
        'reps': reps,
        'duration_seconds': duration?.inSeconds,
        'is_warmup': isWarmup ? 1 : 0,
        'is_completed': isCompleted ? 1 : 0,
      };

  factory ExerciseSet.fromMap(Map<String, dynamic> m) => ExerciseSet(
        id: m['id'] as String,
        setNumber: m['set_number'] as int,
        weightKg: (m['weight_kg'] as num?)?.toDouble(),
        reps: m['reps'] as int?,
        duration: m['duration_seconds'] != null
            ? Duration(seconds: m['duration_seconds'] as int)
            : null,
        isWarmup: (m['is_warmup'] as int? ?? 0) == 1,
        isCompleted: (m['is_completed'] as int? ?? 0) == 1,
      );

  @override
  List<Object?> get props => [id, setNumber, isCompleted];
}

class PersonalRecord extends Equatable {
  final String exerciseId;
  final String exerciseName;
  final double weightKg;
  final int reps;
  final DateTime achievedAt;

  const PersonalRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
    required this.achievedAt,
  });

  double get oneRepMax => weightKg * (1 + reps / 30.0); // Epley formula

  Map<String, dynamic> toMap() => {
        'exercise_id': exerciseId,
        'exercise_name': exerciseName,
        'weight_kg': weightKg,
        'reps': reps,
        'achieved_at': achievedAt.toIso8601String(),
      };

  factory PersonalRecord.fromMap(Map<String, dynamic> m) => PersonalRecord(
        exerciseId: m['exercise_id'] as String,
        exerciseName: m['exercise_name'] as String,
        weightKg: (m['weight_kg'] as num).toDouble(),
        reps: m['reps'] as int,
        achievedAt: DateTime.parse(m['achieved_at'] as String),
      );

  @override
  List<Object?> get props => [exerciseId, weightKg, reps, achievedAt];
}

class WorkoutLog extends Equatable {
  final String id;
  final String name;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<WorkoutLogExercise> exercises;
  final String? notes;

  const WorkoutLog({
    required this.id,
    required this.name,
    required this.startedAt,
    this.finishedAt,
    required this.exercises,
    this.notes,
  });

  Duration get duration => (finishedAt ?? DateTime.now()).difference(startedAt);

  bool get isActive => finishedAt == null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'started_at': startedAt.toIso8601String(),
        'finished_at': finishedAt?.toIso8601String(),
        'notes': notes,
      };

  factory WorkoutLog.fromMap(Map<String, dynamic> m) => WorkoutLog(
        id: m['id'] as String,
        name: m['name'] as String,
        startedAt: DateTime.parse(m['started_at'] as String),
        finishedAt: m['finished_at'] != null
            ? DateTime.parse(m['finished_at'] as String)
            : null,
        exercises: [], // loaded separately
        notes: m['notes'] as String?,
      );

  @override
  List<Object?> get props => [id, startedAt];
}

class WorkoutLogExercise extends Equatable {
  final String id;
  final String workoutLogId;
  final Exercise exercise;
  final List<ExerciseSet> sets;
  final int orderIndex;

  const WorkoutLogExercise({
    required this.id,
    required this.workoutLogId,
    required this.exercise,
    required this.sets,
    required this.orderIndex,
  });

  @override
  List<Object?> get props => [id, workoutLogId, orderIndex];
}
