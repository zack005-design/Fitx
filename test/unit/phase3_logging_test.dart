import 'package:fitx/core/models/nutrition_models.dart';
import 'package:fitx/core/models/workout_models.dart';
import 'package:fitx/core/repositories/nutrition_repository.dart';
import 'package:fitx/core/repositories/workout_repository.dart';
import 'package:fitx/core/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late DatabaseService store;
  final now = DateTime(2026, 9, 14, 9, 30);

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createPhase3Schema(database);
    store = DatabaseService.forDatabase(database);
  });

  tearDown(() => database.close());

  group('durable workouts', () {
    test('restores an active workout with persisted exercises and sets',
        () async {
      final repository = WorkoutRepository(db: store, now: () => now);
      final workout = await repository.startWorkout('Strength');
      const exercise = Exercise(
        id: 'squat',
        name: 'Back squat',
        primaryMuscle: MuscleGroup.quads,
        secondaryMuscles: [MuscleGroup.glutes],
      );
      await database.insert('exercises', exercise.toMap());
      final loggedExercise = await repository.addExerciseToWorkout(
        workoutLogId: workout.id,
        exercise: exercise,
        orderIndex: 0,
      );
      await repository.logSet(
        logExerciseId: loggedExercise.id,
        setNumber: 1,
        weightKg: 80,
        reps: 5,
      );

      final restored = await WorkoutRepository(db: store).getActiveWorkout();
      expect(restored, isNotNull);
      expect(restored!.id, workout.id);
      expect(restored.exercises.single.exercise.name, 'Back squat');
      expect(restored.exercises.single.sets.single.weightKg, 80);
      expect(restored.exercises.single.sets.single.reps, 5);
    });

    test('finish moves the active workout to accurate history', () async {
      var clock = now;
      final repository = WorkoutRepository(db: store, now: () => clock);
      final workout = await repository.startWorkout('Run');
      clock = now.add(const Duration(minutes: 42));

      final finished = await repository.finishWorkout(workout);

      expect(await repository.getActiveWorkout(), isNull);
      final history = await repository.getWorkoutHistory();
      expect(history.single.id, workout.id);
      expect(finished.duration, const Duration(minutes: 42));
      expect(history.single.duration, const Duration(minutes: 42));
    });

    test('discard removes the active workout and its children', () async {
      final repository = WorkoutRepository(db: store, now: () => now);
      final workout = await repository.startWorkout('Discard me');
      const exercise = Exercise(
        id: 'row',
        name: 'Row',
        primaryMuscle: MuscleGroup.back,
        secondaryMuscles: [],
      );
      await database.insert('exercises', exercise.toMap());
      final loggedExercise = await repository.addExerciseToWorkout(
        workoutLogId: workout.id,
        exercise: exercise,
        orderIndex: 0,
      );
      await repository.logSet(
        logExerciseId: loggedExercise.id,
        setNumber: 1,
        weightKg: 30,
        reps: 10,
      );

      await repository.discardWorkout(workout.id);

      expect(await repository.getActiveWorkout(), isNull);
      expect(await database.query('workout_logs'), isEmpty);
      expect(await database.query('workout_log_exercises'), isEmpty);
      expect(await database.query('exercise_sets'), isEmpty);
    });

    test('a completed workout can start a reusable routine', () async {
      var clock = now.subtract(const Duration(days: 1));
      final repository = WorkoutRepository(db: store, now: () => clock);
      final template = await repository.startWorkout('Upper body');
      const exercise = Exercise(
        id: 'press',
        name: 'Press',
        primaryMuscle: MuscleGroup.shoulders,
        secondaryMuscles: [MuscleGroup.triceps],
      );
      await database.insert('exercises', exercise.toMap());
      await repository.addExerciseToWorkout(
          workoutLogId: template.id, exercise: exercise, orderIndex: 0);
      clock = clock.add(const Duration(minutes: 40));
      await repository.finishWorkout(
          (await repository.getActiveWorkout())!);
      clock = now;

      final started = await repository
          .startFromWorkout((await repository.getWorkoutHistory()).single);
      expect(started.name, 'Upper body');
      expect(started.exercises.single.exercise, exercise);
      expect(started.exercises.single.sets, isEmpty);
    });
  });

  group('nutrition logging', () {
    test('logs food and quick entries, then deletes a meal', () async {
      final repository = NutritionRepository(db: store, now: () => now);
      const food = FoodItem(
        id: 'idli',
        name: 'Idli',
        nutritionPer100g: NutritionFacts(
          calories: 145,
          protein: 5,
          carbs: 28,
          fat: 1,
        ),
      );
      final meal = await repository.logMeal(
        food: food,
        amountGrams: 200,
        mealType: MealType.breakfast,
        date: now,
      );
      await repository.quickAdd(
        name: 'Post-workout meal',
        calories: 400,
        protein: 30,
        carbs: 45,
        fat: 10,
        mealType: MealType.lunch,
        date: now,
      );

      var day = await repository.getDailyNutrition(now);
      expect(day.entries, hasLength(2));
      expect(day.totals.calories, 690);

      await repository.deleteMealEntry(meal.id);
      day = await repository.getDailyNutrition(now);
      expect(day.entries.single.foodName, 'Post-workout meal');
    });

    test('historical dates cannot create entries for today', () async {
      final repository = NutritionRepository(db: store, now: () => now);
      final yesterday = now.subtract(const Duration(days: 1));

      expect(
        () => repository.addWater(250, date: yesterday),
        throwsA(isA<StateError>()),
      );
      expect(
        () => repository.quickAdd(
          name: 'Old meal',
          calories: 100,
          protein: 1,
          carbs: 1,
          fat: 1,
          mealType: MealType.snack,
          date: yesterday,
        ),
        throwsA(isA<StateError>()),
      );
      expect((await repository.getDailyNutrition(now)).entries, isEmpty);
      expect((await repository.getDailyNutrition(now)).waterMl, 0);
    });

    test('hydration has one database-backed total across repository instances',
        () async {
      final first = NutritionRepository(db: store, now: () => now);
      final second = NutritionRepository(db: store, now: () => now);

      await first.addWater(250, date: now);
      await second.addWater(500, date: now);

      expect((await first.getDailyNutrition(now)).waterMl, 750);
      expect((await second.getDailyNutrition(now)).waterMl, 750);
      expect(
        await store.getWaterForDate(now.subtract(const Duration(days: 1))),
        0,
      );
    });

    test('favourites persist and yesterday meals can be repeated', () async {
      final repository = NutritionRepository(db: store, now: () => now);
      const food = FoodItem(
        id: 'dosa',
        name: 'Dosa',
        nutritionPer100g: NutritionFacts(
            calories: 180, protein: 4, carbs: 30, fat: 5),
      );
      await database.insert('food_items', food.toMap());
      await repository.setFoodFavorite(food.id, true);
      expect((await repository.getFavoriteFoods()).single, food);

      final yesterday = now.subtract(const Duration(days: 1));
      await store.insertMealEntry(MealEntry(
        id: 'yesterday-meal',
        foodItemId: food.id,
        foodName: food.name,
        amountGrams: 150,
        mealType: MealType.breakfast,
        loggedAt: yesterday,
        nutrition: food.nutritionForAmount(150),
      ));
      expect(await repository.repeatPreviousDay(date: now), 1);
      final today = await repository.getDailyNutrition(now);
      expect(today.entries.single.foodName, 'Dosa');
      expect(today.entries.single.amountGrams, 150);

      final preset = await repository.saveCurrentMeals('Breakfast', date: now);
      expect((await repository.getSavedMeals()).single.name, 'Breakfast');
      expect(await repository.logSavedMeal(preset, date: now), 1);
      expect((await repository.getDailyNutrition(now)).entries, hasLength(2));
    });
  });
}

Future<void> _createPhase3Schema(Database database) async {
  await database.execute('''CREATE TABLE meal_entries (
    id TEXT PRIMARY KEY, food_item_id TEXT NOT NULL, food_name TEXT NOT NULL,
    amount_grams REAL NOT NULL, meal_type INTEGER NOT NULL,
    logged_at TEXT NOT NULL, calories REAL NOT NULL, protein REAL NOT NULL,
    carbs REAL NOT NULL, fat REAL NOT NULL, fiber REAL, sugar REAL, sodium REAL,
    saturated_fat REAL, cholesterol REAL, potassium REAL, calcium REAL,
    iron REAL, magnesium REAL, phosphorus REAL, zinc REAL, vitamin_a REAL,
    vitamin_c REAL, folate REAL
  )''');
  await database.execute('''CREATE TABLE water_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, amount_ml REAL NOT NULL
  )''');
  await database.execute('''CREATE TABLE caffeine_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL,
    amount_mg REAL NOT NULL, logged_at TEXT NOT NULL
  )''');
  await database.execute('''CREATE TABLE food_items (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, brand TEXT, barcode TEXT,
    calories_per100 REAL NOT NULL, protein_per100 REAL NOT NULL,
    carbs_per100 REAL NOT NULL, fat_per100 REAL NOT NULL, fiber_per100 REAL,
    sugar_per100 REAL, sodium_per100 REAL, saturated_fat_per100 REAL,
    cholesterol_per100 REAL, potassium_per100 REAL, calcium_per100 REAL,
    iron_per100 REAL, magnesium_per100 REAL, phosphorus_per100 REAL,
    zinc_per100 REAL, vitamin_a_per100 REAL, vitamin_c_per100 REAL,
    folate_per100 REAL, states TEXT, category TEXT, aliases TEXT,
    serving_name TEXT, serving_grams REAL, is_vegetarian INTEGER, source TEXT,
    source_code TEXT, data_quality TEXT, is_custom INTEGER NOT NULL DEFAULT 0
  )''');
  await database.execute('''CREATE TABLE exercises (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, primary_muscle INTEGER NOT NULL,
    secondary_muscles TEXT NOT NULL DEFAULT '', is_custom INTEGER NOT NULL DEFAULT 0
  )''');
  await database.execute('''CREATE TABLE workout_logs (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, started_at TEXT NOT NULL,
    finished_at TEXT, notes TEXT
  )''');
  await database.execute('''CREATE TABLE workout_log_exercises (
    id TEXT PRIMARY KEY, workout_log_id TEXT NOT NULL, exercise_id TEXT NOT NULL,
    order_index INTEGER NOT NULL
  )''');
  await database.execute('''CREATE TABLE exercise_sets (
    id TEXT PRIMARY KEY, log_exercise_id TEXT NOT NULL, set_number INTEGER NOT NULL,
    weight_kg REAL, reps INTEGER, duration_seconds INTEGER,
    is_warmup INTEGER NOT NULL DEFAULT 0, is_completed INTEGER NOT NULL DEFAULT 0
  )''');
  await database.execute('''CREATE TABLE personal_records (
    exercise_id TEXT PRIMARY KEY, exercise_name TEXT NOT NULL,
    weight_kg REAL NOT NULL, reps INTEGER NOT NULL, achieved_at TEXT NOT NULL
  )''');
  await DatabaseService.createPhase3Tables(database);
  await DatabaseService.createQuickLoggingTables(database);
}
