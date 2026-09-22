import '../models/workout_models.dart';
import '../services/database_service.dart';
import 'package:uuid/uuid.dart';

class WorkoutRepository {
  final DatabaseService _db;
  final DateTime Function() _now;
  static const _uuid = Uuid();

  WorkoutRepository({DatabaseService? db, DateTime Function()? now})
      : _db = db ?? DatabaseService(),
        _now = now ?? DateTime.now;

  Future<WorkoutLog> startWorkout(String name) async {
    final active = await _db.getActiveWorkout();
    if (active != null) return active;
    final log = WorkoutLog(
      id: _uuid.v4(),
      name: name,
      startedAt: _now(),
      exercises: [],
    );
    await _db.insertWorkoutLog(log);
    return log;
  }

  Future<WorkoutLog> startFromWorkout(WorkoutLog template) async {
    final log = await startWorkout(template.name);
    if (log.exercises.isNotEmpty) return log;
    final exercises = <WorkoutLogExercise>[];
    for (var index = 0; index < template.exercises.length; index++) {
      exercises.add(await addExerciseToWorkout(
        workoutLogId: log.id,
        exercise: template.exercises[index].exercise,
        orderIndex: index,
      ));
    }
    return WorkoutLog(
      id: log.id,
      name: log.name,
      startedAt: log.startedAt,
      exercises: exercises,
    );
  }

  Future<WorkoutLog> finishWorkout(WorkoutLog log) async {
    final finishedAt = _now();
    if (finishedAt.isBefore(log.startedAt)) {
      throw StateError('Workout finish time cannot be before its start time.');
    }
    final finished = WorkoutLog(
      id: log.id,
      name: log.name,
      startedAt: log.startedAt,
      finishedAt: finishedAt,
      exercises: log.exercises,
      notes: log.notes,
    );
    await _db.updateWorkoutLog(finished);
    return finished;
  }

  Future<List<WorkoutLog>> getWorkoutHistory({int limit = 20}) =>
      _db.getWorkoutLogs(limit: limit);

  Future<List<WorkoutLog>> getWorkoutsForDate(DateTime date) =>
      _db.getWorkoutLogsForDate(date);

  Future<WorkoutLog?> getActiveWorkout() => _db.getActiveWorkout();

  Future<void> discardWorkout(String id) => _db.deleteWorkoutLog(id);

  Future<List<Exercise>> searchExercises(String query) =>
      _db.searchExercises(query);

  Future<List<Exercise>> getExercisesByMuscle(MuscleGroup muscle) =>
      _db.getExercisesByMuscle(muscle);

  Future<WorkoutLogExercise> addExerciseToWorkout({
    required String workoutLogId,
    required Exercise exercise,
    required int orderIndex,
  }) async {
    final wle = WorkoutLogExercise(
      id: _uuid.v4(),
      workoutLogId: workoutLogId,
      exercise: exercise,
      sets: [],
      orderIndex: orderIndex,
    );
    await _db.insertWorkoutLogExercise(wle);
    return wle;
  }

  Future<ExerciseSet> logSet({
    required String logExerciseId,
    required int setNumber,
    double? weightKg,
    int? reps,
    Duration? duration,
    bool isWarmup = false,
  }) async {
    if (setNumber < 1 ||
        (weightKg != null &&
            (!weightKg.isFinite || weightKg < 0 || weightKg > 1000)) ||
        (reps != null && (reps < 0 || reps > 10000)) ||
        (duration != null &&
            (duration <= Duration.zero ||
                duration > const Duration(days: 1)))) {
      throw ArgumentError('Set values are outside supported ranges.');
    }
    final set = ExerciseSet(
      id: _uuid.v4(),
      setNumber: setNumber,
      weightKg: weightKg,
      reps: reps,
      duration: duration,
      isWarmup: isWarmup,
      isCompleted: true,
    );
    await _db.upsertExerciseSet(logExerciseId, set);
    return set;
  }

  Future<void> checkAndUpdatePR({
    required Exercise exercise,
    required double weightKg,
    required int reps,
  }) async {
    if (!weightKg.isFinite ||
        weightKg <= 0 ||
        weightKg > 1000 ||
        reps < 1 ||
        reps > 10000) {
      throw ArgumentError(
          'Personal record values are outside supported ranges.');
    }
    final existing = await _db.getPersonalRecord(exercise.id);
    final newPR = PersonalRecord(
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      weightKg: weightKg,
      reps: reps,
      achievedAt: _now(),
    );
    if (existing == null || newPR.oneRepMax > existing.oneRepMax) {
      await _db.upsertPersonalRecord(newPR);
    }
  }

  Future<List<PersonalRecord>> getAllPersonalRecords() =>
      _db.getAllPersonalRecords();

  Future<PersonalRecord?> getPR(String exerciseId) =>
      _db.getPersonalRecord(exerciseId);
}
