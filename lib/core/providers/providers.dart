import '../services/android_widget_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/health_repository.dart';
import '../repositories/nutrition_repository.dart';
import '../repositories/workout_repository.dart';
import '../repositories/journal_repository.dart';
import '../services/health_connect_service.dart';
import '../services/database_service.dart';
import '../services/device_sensor_service.dart';
import '../models/user_profile.dart';
import '../models/nutrition_models.dart';
import '../models/workout_models.dart';
import '../models/sleep_data.dart';
import '../models/health_score.dart';
import '../models/journal_models.dart';
import '../models/app_preferences.dart';
import '../models/sync_state.dart';
import '../services/health_sync_service.dart';
import '../services/sleep_tracking_service.dart';
import '../engines/phone_sleep_inference_engine.dart';
import '../engines/motion_classifier.dart';
import '../engines/weekly_review_engine.dart';
import '../models/sleep_tracking.dart';
import '../../features/journal/journal_controller.dart';

// ── SERVICES ─────────────────────────────────────────────────────────────────

final healthConnectServiceProvider = Provider<HealthConnectService>(
  (ref) => HealthConnectService(),
);

final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => DatabaseService(),
);

final deviceSensorServiceProvider = Provider<DeviceSensorService>(
  (ref) => DeviceSensorService(),
);

final deviceSensorCapabilitiesProvider =
    FutureProvider<DeviceSensorCapabilities>(
  (ref) => ref.watch(deviceSensorServiceProvider).getCapabilities(),
);

final motionGuidanceProvider = StreamProvider.autoDispose<MotionGuidance>(
  (ref) async* {
    final classifier = MotionClassifier();
    await for (final sample in ref.watch(deviceSensorServiceProvider).samples) {
      yield classifier.add(sample);
    }
  },
);

final sleepTrackingServiceProvider = Provider<SleepTrackingService>(
  (ref) => SleepTrackingService(),
);

final sleepTrackingProvider =
    AsyncNotifierProvider<SleepTrackingNotifier, NativeSleepTrackingState>(
        SleepTrackingNotifier.new);

class SleepTrackingNotifier extends AsyncNotifier<NativeSleepTrackingState> {
  @override
  Future<NativeSleepTrackingState> build() =>
      ref.watch(sleepTrackingServiceProvider).state();

  Future<void> start() async {
    final capabilities =
        await ref.read(deviceSensorServiceProvider).getCapabilities();
    if (!capabilities.accelerometer) {
      throw StateError('This phone does not have an accelerometer.');
    }
    if (!capabilities.activityRecognitionGranted &&
        !await ref
            .read(deviceSensorServiceProvider)
            .requestActivityRecognition()) {
      throw StateError(
          'Activity recognition access is required for overnight tracking.');
    }
    state = AsyncData(await ref.read(sleepTrackingServiceProvider).start());
  }

  Future<PhoneSleepEstimate> stop() async {
    final stopped = await ref.read(sleepTrackingServiceProvider).stop();
    state = AsyncData(stopped);
    final start = stopped.startedAt;
    if (start == null) {
      throw StateError('The tracking start time was not saved.');
    }
    final estimate = PhoneSleepInferenceEngine.estimate(
      epochs: stopped.epochs,
      sessionStart: start,
      sessionEnd: DateTime.now(),
    );
    if (estimate == null) {
      throw StateError(
          'Not enough continuous sensor data was recorded. Track for at least 45 minutes with the phone kept still near you.');
    }
    await ref.read(databaseServiceProvider).savePhoneSleepEstimate(
          estimate,
          algorithmVersion: PhoneSleepInferenceEngine.algorithmVersion,
          epochs: stopped.epochs,
        );
    ref.invalidate(dailySummaryProvider);
    ref.invalidate(sleepDataProvider);
    ref.invalidate(healthHistoryProvider);
    return estimate;
  }
}

// ── REPOSITORIES ─────────────────────────────────────────────────────────────

final healthRepositoryProvider = Provider<HealthRepository>(
  (ref) => HealthRepository(
    hc: ref.watch(healthConnectServiceProvider),
    db: ref.watch(databaseServiceProvider),
  ),
);

final nutritionRepositoryProvider = Provider<NutritionRepository>(
  (ref) => NutritionRepository(db: ref.watch(databaseServiceProvider)),
);

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => WorkoutRepository(db: ref.watch(databaseServiceProvider)),
);

final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => JournalRepository(db: ref.watch(databaseServiceProvider)),
);

final journalDayProvider = FutureProvider.family<JournalDay, DateTime>(
  (ref, date) => ref.watch(journalRepositoryProvider).getDay(date),
);

final journalHistoryProvider = FutureProvider<List<JournalHistoryDay>>(
  (ref) => ref.watch(journalRepositoryProvider).getHistory(),
);

final journalInsightsProvider = FutureProvider<List<JournalInsight>>(
  (ref) => ref.watch(journalRepositoryProvider).getInsights(),
);

final journalControllerProvider = Provider.family<JournalController, DateTime>(
  (ref, date) => JournalController(
    repository: ref.watch(journalRepositoryProvider),
    onChanged: () {
      ref.invalidate(journalDayProvider(date));
      ref.invalidate(journalHistoryProvider);
      ref.invalidate(journalInsightsProvider);
    },
  ),
);

// ── USER PROFILE ──────────────────────────────────────────────────────────────

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(
  UserProfileNotifier.new,
);

class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final db = ref.watch(databaseServiceProvider);
    return db.getProfile();
  }

  Future<void> save(UserProfile profile) async {
    final db = ref.watch(databaseServiceProvider);
    await db.saveProfile(profile);
    state = AsyncData(profile);
  }
}

// ── HEALTH CONNECT ────────────────────────────────────────────────────────────

final healthConnectAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(healthConnectServiceProvider).checkAvailability(),
);

final healthPermissionsProvider = FutureProvider<bool>(
  (ref) => ref.watch(healthConnectServiceProvider).checkPermissions(),
);

final healthHistoryPermissionProvider = FutureProvider<bool>(
  (ref) => ref.watch(healthConnectServiceProvider).checkHistoryPermission(),
);

final healthBackgroundPermissionProvider = FutureProvider<bool>(
  (ref) => ref.watch(healthConnectServiceProvider).checkBackgroundPermission(),
);

final appPreferencesProvider =
    AsyncNotifierProvider<AppPreferencesNotifier, AppPreferences>(
  AppPreferencesNotifier.new,
);

class AppPreferencesNotifier extends AsyncNotifier<AppPreferences> {
  @override
  Future<AppPreferences> build() =>
      ref.watch(databaseServiceProvider).getAppPreferences();

  Future<void> save(AppPreferences preferences) async {
    await ref.read(databaseServiceProvider).saveAppPreferences(preferences);
    state = AsyncData(preferences);
  }
}

final healthSyncServiceProvider =
    Provider<HealthSyncService>((ref) => HealthSyncService(
          healthConnect: ref.watch(healthConnectServiceProvider),
          repository: ref.watch(healthRepositoryProvider),
          database: ref.watch(databaseServiceProvider),
        ));

final healthSyncProvider =
    AsyncNotifierProvider<HealthSyncNotifier, HealthSyncState>(
  HealthSyncNotifier.new,
);

class HealthSyncNotifier extends AsyncNotifier<HealthSyncState> {
  @override
  Future<HealthSyncState> build() =>
      ref.watch(databaseServiceProvider).getSyncState();

  Future<HealthSyncState> sync() async {
    if (state.value?.isRunning == true) return state.value!;
    final previous = state.value ?? const HealthSyncState();
    state = AsyncData(previous.copyWith(phase: SyncPhase.syncing));
    final profile = await ref.read(userProfileProvider.future);
    final result = await ref.read(healthSyncServiceProvider).sync(profile);
    state = AsyncData(result);
    ref.invalidate(healthPermissionsProvider);
    ref.invalidate(healthHistoryPermissionProvider);
    ref.invalidate(healthBackgroundPermissionProvider);
    ref.invalidate(dailySummaryProvider);
    ref.invalidate(scoreHistoryProvider);
    return result;
  }
}

// ── DAILY SUMMARY ─────────────────────────────────────────────────────────────

final selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, DateTime>(SelectedDateNotifier.new);

class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void select(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (normalized.isAfter(today)) return;
    state = normalized;
  }

  void previousDay() =>
      select(DateTime(state.year, state.month, state.day - 1));

  void nextDay() => select(DateTime(state.year, state.month, state.day + 1));

  void today() => select(DateTime.now());
}

final dailySummaryProvider =
    FutureProvider.family<DailyHealthSummary, DateTime>(
  (ref, date) async {
    final profile = await ref.watch(userProfileProvider.future);
    final summary = await ref
        .watch(healthRepositoryProvider)
        .getDailySummary(date, profile);
    if (date ==
        DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day)) {
      await AndroidWidgetService.updateDailyOverview(
        syncedAt: summary.syncedAt,
        recovery: summary.metricFor('recovery').valueOrNull?.round(),
        sleep: summary.metricFor('sleep').valueOrNull?.round(),
        strain: summary.metricFor('strain').valueOrNull == null
            ? null
            : summary.strainRaw.toStringAsFixed(1),
      );
    }
    return summary;
  },
);

final healthHistoryProvider =
    FutureProvider.family<List<DailyHealthSummary>, ({DateTime end, int days})>(
        (ref, args) async {
  final day = await ref.watch(dailySummaryProvider(args.end).future);
  final history = await ref
      .watch(healthRepositoryProvider)
      .getHistory(args.end, days: args.days);
  return [...history.where((summary) => summary.date != day.date), day];
});

final scoreHistoryProvider =
    FutureProvider.family<List<HealthScore>, ({String type, int days})>(
  (ref, args) => ref.watch(healthRepositoryProvider).getScoreHistory(args.type,
      days: args.days, endDate: ref.watch(selectedDateProvider)),
);

// ── NUTRITION ─────────────────────────────────────────────────────────────────

final dailyNutritionProvider = FutureProvider.family<DailyNutrition, DateTime>(
  (ref, date) => ref.watch(nutritionRepositoryProvider).getDailyNutrition(date),
);

final weeklyReviewProvider = FutureProvider<WeeklyReview>((ref) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final values = await Future.wait<Object>([
    ref.watch(healthHistoryProvider((end: today, days: 7)).future),
    ref.watch(nutritionRepositoryProvider).getNutritionHistory(days: 7),
    ref.watch(workoutRepositoryProvider).getWorkoutHistory(limit: 30),
  ]);
  return WeeklyReviewEngine.build(
    health: values[0] as List<DailyHealthSummary>,
    nutrition: values[1] as List<DailyNutrition>,
    workouts: values[2] as List<WorkoutLog>,
  );
});

final favoriteFoodsProvider = FutureProvider<List<FoodItem>>(
  (ref) => ref.watch(nutritionRepositoryProvider).getFavoriteFoods(),
);

final savedMealsProvider = FutureProvider<List<SavedMeal>>(
  (ref) => ref.watch(nutritionRepositoryProvider).getSavedMeals(),
);

final foodSearchProvider =
    NotifierProvider<FoodSearchNotifier, AsyncValue<List<FoodItem>>>(
  FoodSearchNotifier.new,
);

class FoodSearchNotifier extends Notifier<AsyncValue<List<FoodItem>>> {
  NutritionRepository get _repo => ref.read(nutritionRepositoryProvider);

  @override
  AsyncValue<List<FoodItem>> build() => const AsyncData([]);

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.searchFoods(query));
  }

  Future<void> searchByBarcode(String barcode) async {
    state = const AsyncLoading();
    final food = await _repo.getFoodByBarcode(barcode);
    state = AsyncData(food != null ? [food] : []);
  }
}

// ── ACTIVE WORKOUT ────────────────────────────────────────────────────────────

final activeWorkoutProvider =
    AsyncNotifierProvider<ActiveWorkoutNotifier, WorkoutLog?>(
  ActiveWorkoutNotifier.new,
);

class ActiveWorkoutNotifier extends AsyncNotifier<WorkoutLog?> {
  WorkoutRepository get _repo => ref.read(workoutRepositoryProvider);

  @override
  Future<WorkoutLog?> build() => _repo.getActiveWorkout();

  Future<void> start(String name) async {
    final existing = state.value;
    if (existing != null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.startWorkout(name));
  }

  Future<void> startFromWorkout(WorkoutLog template) async {
    if (state.value != null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.startFromWorkout(template));
  }

  Future<void> finish() async {
    final workout = state.value;
    if (workout == null) return;
    await _repo.finishWorkout(workout);
    state = const AsyncData(null);
    ref.invalidate(workoutHistoryProvider);
    ref.invalidate(workoutsForDateProvider);
  }

  Future<void> discard() async {
    final workout = state.value;
    if (workout == null) return;
    await _repo.discardWorkout(workout.id);
    state = const AsyncData(null);
    ref.invalidate(workoutHistoryProvider);
    ref.invalidate(workoutsForDateProvider);
  }

  Future<void> addExercise(Exercise exercise) async {
    final workout = state.value;
    if (workout == null) return;
    final entry = await _repo.addExerciseToWorkout(
      workoutLogId: workout.id,
      exercise: exercise,
      orderIndex: workout.exercises.length,
    );
    state = AsyncData(WorkoutLog(
      id: workout.id,
      name: workout.name,
      startedAt: workout.startedAt,
      finishedAt: workout.finishedAt,
      exercises: [...workout.exercises, entry],
      notes: workout.notes,
    ));
  }

  Future<void> logSet({
    required String logExerciseId,
    double? weightKg,
    int? reps,
    Duration? duration,
    bool isWarmup = false,
  }) async {
    final workout = state.value;
    if (workout == null) return;
    final exerciseIndex = workout.exercises.indexWhere(
      (entry) => entry.id == logExerciseId,
    );
    if (exerciseIndex < 0) return;
    final currentExercise = workout.exercises[exerciseIndex];
    final set = await _repo.logSet(
      logExerciseId: logExerciseId,
      setNumber: currentExercise.sets.length + 1,
      weightKg: weightKg,
      reps: reps,
      duration: duration,
      isWarmup: isWarmup,
    );
    final exercises = [...workout.exercises];
    exercises[exerciseIndex] = WorkoutLogExercise(
      id: currentExercise.id,
      workoutLogId: currentExercise.workoutLogId,
      exercise: currentExercise.exercise,
      sets: [...currentExercise.sets, set],
      orderIndex: currentExercise.orderIndex,
    );
    state = AsyncData(WorkoutLog(
      id: workout.id,
      name: workout.name,
      startedAt: workout.startedAt,
      finishedAt: workout.finishedAt,
      exercises: exercises,
      notes: workout.notes,
    ));
  }
}

final workoutHistoryProvider = FutureProvider<List<WorkoutLog>>(
  (ref) => ref.watch(workoutRepositoryProvider).getWorkoutHistory(),
);

final workoutsForDateProvider =
    FutureProvider.family<List<WorkoutLog>, DateTime>(
  (ref, date) => ref.watch(workoutRepositoryProvider).getWorkoutsForDate(date),
);

final personalRecordsProvider = FutureProvider<List<PersonalRecord>>(
  (ref) => ref.watch(workoutRepositoryProvider).getAllPersonalRecords(),
);

// ── HYDRATION ─────────────────────────────────────────────────────────────────

final hydrationProvider = AsyncNotifierProvider<HydrationNotifier, int>(
  HydrationNotifier.new,
);

class HydrationNotifier extends AsyncNotifier<int> {
  static const _keyAmount = 'hydration_amount';
  static const _keyDate = 'hydration_date';

  @override
  Future<int> build() async {
    final repository = ref.watch(nutritionRepositoryProvider);
    final today = DateTime.now();
    var amount = (await repository.getDailyNutrition(today)).waterMl.round();

    // One-time compatibility import for builds that stored today's display
    // total only in preferences. SQLite is authoritative after this read.
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_keyDate);
    final todayKey = today.toIso8601String().substring(0, 10);
    final legacy = savedDate == todayKey ? prefs.getInt(_keyAmount) ?? 0 : 0;
    if (amount == 0 && legacy > 0) {
      await repository.addWater(legacy.toDouble());
      amount = legacy;
    }
    await prefs.remove(_keyAmount);
    await prefs.remove(_keyDate);
    return amount;
  }

  Future<void> addWater(int ml) async {
    final repository = ref.read(nutritionRepositoryProvider);
    await repository.addWater(ml.toDouble());
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nutrition = await repository.getDailyNutrition(today);
    state = AsyncData(nutrition.waterMl.round());
    ref.invalidate(dailyNutritionProvider(today));
  }
}

// ── SPECIFIC DATA PROVIDERS ───────────────────────────────────────────────────

final sleepDataProvider = FutureProvider.family<SleepData, DateTime>(
  (ref, date) => ref.watch(healthRepositoryProvider).getSleep(date),
);

final rhrBaselineProvider = FutureProvider<double?>(
  (ref) => ref.watch(databaseServiceProvider).getRhrBaseline(),
);

final hrvBaselineProvider = FutureProvider<double?>(
  (ref) => ref.watch(databaseServiceProvider).getHrvBaseline(),
);
