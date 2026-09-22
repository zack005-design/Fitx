import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/workout_models.dart';
import '../models/nutrition_models.dart';
import 'database_service.dart';

/// Seeds the local database with default exercises and common food items.
/// Runs once on first app launch.
class SeedService {
  final DatabaseService _db;
  static const _uuid = Uuid();

  SeedService({DatabaseService? db}) : _db = db ?? DatabaseService();

  Future<void> seedIfNeeded() async {
    // Always attempt to seed food database if needed
    await seedFoodDatabase();

    final db = await _db.db;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM exercises');
    final count = result.first['c'] as int? ?? 0;
    if (count > 0) return;
    await _seedExercises();
    await _seedFoods();
  }

  Future<void> _seedExercises() async {
    final exercises = [
      // CHEST
      Exercise(
          id: _uuid.v4(),
          name: 'Bench Press',
          primaryMuscle: MuscleGroup.chest,
          secondaryMuscles: [MuscleGroup.triceps, MuscleGroup.shoulders]),
      Exercise(
          id: _uuid.v4(),
          name: 'Incline Bench Press',
          primaryMuscle: MuscleGroup.chest,
          secondaryMuscles: [MuscleGroup.triceps]),
      Exercise(
          id: _uuid.v4(),
          name: 'Decline Bench Press',
          primaryMuscle: MuscleGroup.chest,
          secondaryMuscles: [MuscleGroup.triceps]),
      Exercise(
          id: _uuid.v4(),
          name: 'Dumbbell Fly',
          primaryMuscle: MuscleGroup.chest,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Cable Crossover',
          primaryMuscle: MuscleGroup.chest,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Push Up',
          primaryMuscle: MuscleGroup.chest,
          secondaryMuscles: [MuscleGroup.triceps]),
      Exercise(
          id: _uuid.v4(),
          name: 'Chest Dip',
          primaryMuscle: MuscleGroup.chest,
          secondaryMuscles: [MuscleGroup.triceps]),
      // BACK
      Exercise(
          id: _uuid.v4(),
          name: 'Deadlift',
          primaryMuscle: MuscleGroup.back,
          secondaryMuscles: [MuscleGroup.glutes, MuscleGroup.hamstrings]),
      Exercise(
          id: _uuid.v4(),
          name: 'Pull Up',
          primaryMuscle: MuscleGroup.back,
          secondaryMuscles: [MuscleGroup.biceps]),
      Exercise(
          id: _uuid.v4(),
          name: 'Lat Pulldown',
          primaryMuscle: MuscleGroup.back,
          secondaryMuscles: [MuscleGroup.biceps]),
      Exercise(
          id: _uuid.v4(),
          name: 'Barbell Row',
          primaryMuscle: MuscleGroup.back,
          secondaryMuscles: [MuscleGroup.biceps]),
      Exercise(
          id: _uuid.v4(),
          name: 'Dumbbell Row',
          primaryMuscle: MuscleGroup.back,
          secondaryMuscles: [MuscleGroup.biceps]),
      Exercise(
          id: _uuid.v4(),
          name: 'Cable Row',
          primaryMuscle: MuscleGroup.back,
          secondaryMuscles: [MuscleGroup.biceps]),
      Exercise(
          id: _uuid.v4(),
          name: 'Face Pull',
          primaryMuscle: MuscleGroup.back,
          secondaryMuscles: [MuscleGroup.shoulders]),
      // SHOULDERS
      Exercise(
          id: _uuid.v4(),
          name: 'Overhead Press',
          primaryMuscle: MuscleGroup.shoulders,
          secondaryMuscles: [MuscleGroup.triceps]),
      Exercise(
          id: _uuid.v4(),
          name: 'Dumbbell Shoulder Press',
          primaryMuscle: MuscleGroup.shoulders,
          secondaryMuscles: [MuscleGroup.triceps]),
      Exercise(
          id: _uuid.v4(),
          name: 'Lateral Raise',
          primaryMuscle: MuscleGroup.shoulders,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Front Raise',
          primaryMuscle: MuscleGroup.shoulders,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Rear Delt Fly',
          primaryMuscle: MuscleGroup.shoulders,
          secondaryMuscles: []),
      // BICEPS
      Exercise(
          id: _uuid.v4(),
          name: 'Barbell Curl',
          primaryMuscle: MuscleGroup.biceps,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Dumbbell Curl',
          primaryMuscle: MuscleGroup.biceps,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Hammer Curl',
          primaryMuscle: MuscleGroup.biceps,
          secondaryMuscles: [MuscleGroup.forearms]),
      Exercise(
          id: _uuid.v4(),
          name: 'Preacher Curl',
          primaryMuscle: MuscleGroup.biceps,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Cable Curl',
          primaryMuscle: MuscleGroup.biceps,
          secondaryMuscles: []),
      // TRICEPS
      Exercise(
          id: _uuid.v4(),
          name: 'Tricep Pushdown',
          primaryMuscle: MuscleGroup.triceps,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Skull Crusher',
          primaryMuscle: MuscleGroup.triceps,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Overhead Tricep Extension',
          primaryMuscle: MuscleGroup.triceps,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Diamond Push Up',
          primaryMuscle: MuscleGroup.triceps,
          secondaryMuscles: [MuscleGroup.chest]),
      Exercise(
          id: _uuid.v4(),
          name: 'Tricep Dip',
          primaryMuscle: MuscleGroup.triceps,
          secondaryMuscles: []),
      // LEGS
      Exercise(
          id: _uuid.v4(),
          name: 'Squat',
          primaryMuscle: MuscleGroup.quads,
          secondaryMuscles: [MuscleGroup.glutes, MuscleGroup.hamstrings]),
      Exercise(
          id: _uuid.v4(),
          name: 'Leg Press',
          primaryMuscle: MuscleGroup.quads,
          secondaryMuscles: [MuscleGroup.glutes]),
      Exercise(
          id: _uuid.v4(),
          name: 'Leg Extension',
          primaryMuscle: MuscleGroup.quads,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Romanian Deadlift',
          primaryMuscle: MuscleGroup.hamstrings,
          secondaryMuscles: [MuscleGroup.glutes]),
      Exercise(
          id: _uuid.v4(),
          name: 'Leg Curl',
          primaryMuscle: MuscleGroup.hamstrings,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Hip Thrust',
          primaryMuscle: MuscleGroup.glutes,
          secondaryMuscles: [MuscleGroup.hamstrings]),
      Exercise(
          id: _uuid.v4(),
          name: 'Bulgarian Split Squat',
          primaryMuscle: MuscleGroup.quads,
          secondaryMuscles: [MuscleGroup.glutes]),
      Exercise(
          id: _uuid.v4(),
          name: 'Lunge',
          primaryMuscle: MuscleGroup.quads,
          secondaryMuscles: [MuscleGroup.glutes]),
      Exercise(
          id: _uuid.v4(),
          name: 'Calf Raise',
          primaryMuscle: MuscleGroup.calves,
          secondaryMuscles: []),
      // ABS
      Exercise(
          id: _uuid.v4(),
          name: 'Crunch',
          primaryMuscle: MuscleGroup.abs,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Plank',
          primaryMuscle: MuscleGroup.abs,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Leg Raise',
          primaryMuscle: MuscleGroup.abs,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Russian Twist',
          primaryMuscle: MuscleGroup.abs,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Ab Wheel Rollout',
          primaryMuscle: MuscleGroup.abs,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Cable Crunch',
          primaryMuscle: MuscleGroup.abs,
          secondaryMuscles: []),
      // CARDIO
      Exercise(
          id: _uuid.v4(),
          name: 'Treadmill Run',
          primaryMuscle: MuscleGroup.cardio,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Stationary Bike',
          primaryMuscle: MuscleGroup.cardio,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Rowing Machine',
          primaryMuscle: MuscleGroup.cardio,
          secondaryMuscles: [MuscleGroup.back]),
      Exercise(
          id: _uuid.v4(),
          name: 'Jump Rope',
          primaryMuscle: MuscleGroup.cardio,
          secondaryMuscles: []),
      Exercise(
          id: _uuid.v4(),
          name: 'Burpees',
          primaryMuscle: MuscleGroup.fullBody,
          secondaryMuscles: []),
    ];
    for (final ex in exercises) {
      await _db.insertExercise(ex);
    }
  }

  Future<void> _seedFoods() async {
    final foods = [
      FoodItem(
          id: _uuid.v4(),
          name: 'Chicken Breast',
          nutritionPer100g: const NutritionFacts(
              calories: 165, protein: 31, carbs: 0, fat: 3.6, sodium: 74)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Brown Rice (cooked)',
          nutritionPer100g: const NutritionFacts(
              calories: 112, protein: 2.6, carbs: 24, fat: 0.9, fiber: 1.8)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Whole Egg',
          nutritionPer100g: const NutritionFacts(
              calories: 143, protein: 13, carbs: 1, fat: 10)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Egg White',
          nutritionPer100g: const NutritionFacts(
              calories: 52, protein: 11, carbs: 0.7, fat: 0.2)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Greek Yogurt (0% fat)',
          nutritionPer100g: const NutritionFacts(
              calories: 59, protein: 10, carbs: 3.6, fat: 0.4)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Oats (dry)',
          nutritionPer100g: const NutritionFacts(
              calories: 389, protein: 17, carbs: 66, fat: 7, fiber: 10.6)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Banana',
          nutritionPer100g: const NutritionFacts(
              calories: 89,
              protein: 1.1,
              carbs: 23,
              fat: 0.3,
              fiber: 2.6,
              sugar: 12)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Apple',
          nutritionPer100g: const NutritionFacts(
              calories: 52,
              protein: 0.3,
              carbs: 14,
              fat: 0.2,
              fiber: 2.4,
              sugar: 10)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Almonds',
          nutritionPer100g: const NutritionFacts(
              calories: 579, protein: 21, carbs: 22, fat: 50, fiber: 12.5)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Salmon',
          nutritionPer100g: const NutritionFacts(
              calories: 208, protein: 20, carbs: 0, fat: 13)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Tuna (canned in water)',
          nutritionPer100g: const NutritionFacts(
              calories: 116, protein: 26, carbs: 0, fat: 1, sodium: 320)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Sweet Potato',
          nutritionPer100g: const NutritionFacts(
              calories: 86, protein: 1.6, carbs: 20, fat: 0.1, fiber: 3)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Broccoli',
          nutritionPer100g: const NutritionFacts(
              calories: 34, protein: 2.8, carbs: 7, fat: 0.4, fiber: 2.6)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Spinach',
          nutritionPer100g: const NutritionFacts(
              calories: 23, protein: 2.9, carbs: 3.6, fat: 0.4, fiber: 2.2)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Whey Protein Powder',
          nutritionPer100g: const NutritionFacts(
              calories: 400, protein: 80, carbs: 8, fat: 6)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Milk (whole)',
          nutritionPer100g: const NutritionFacts(
              calories: 61, protein: 3.2, carbs: 4.8, fat: 3.3)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Cottage Cheese',
          nutritionPer100g: const NutritionFacts(
              calories: 98, protein: 11, carbs: 3.4, fat: 4.3)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Avocado',
          nutritionPer100g: const NutritionFacts(
              calories: 160, protein: 2, carbs: 9, fat: 15, fiber: 6.7)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Olive Oil',
          nutritionPer100g: const NutritionFacts(
              calories: 884, protein: 0, carbs: 0, fat: 100)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Quinoa (cooked)',
          nutritionPer100g: const NutritionFacts(
              calories: 120, protein: 4.4, carbs: 22, fat: 1.9, fiber: 2.8)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Pasta (cooked)',
          nutritionPer100g: const NutritionFacts(
              calories: 131, protein: 5, carbs: 25, fat: 1.1)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Whole Wheat Bread',
          nutritionPer100g: const NutritionFacts(
              calories: 247, protein: 13, carbs: 41, fat: 4.2, fiber: 6.8)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Lean Beef',
          nutritionPer100g: const NutritionFacts(
              calories: 215, protein: 26, carbs: 0, fat: 12)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Turkey Breast',
          nutritionPer100g: const NutritionFacts(
              calories: 135, protein: 30, carbs: 0, fat: 1)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Blueberries',
          nutritionPer100g: const NutritionFacts(
              calories: 57,
              protein: 0.7,
              carbs: 14,
              fat: 0.3,
              fiber: 2.4,
              sugar: 10)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Peanut Butter',
          nutritionPer100g: const NutritionFacts(
              calories: 588, protein: 25, carbs: 20, fat: 50, fiber: 6)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Black Beans',
          nutritionPer100g: const NutritionFacts(
              calories: 132, protein: 8.9, carbs: 24, fat: 0.5, fiber: 8.7)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Lentils (cooked)',
          nutritionPer100g: const NutritionFacts(
              calories: 116, protein: 9, carbs: 20, fat: 0.4, fiber: 7.9)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Orange',
          nutritionPer100g: const NutritionFacts(
              calories: 47,
              protein: 0.9,
              carbs: 12,
              fat: 0.1,
              fiber: 2.4,
              sugar: 9)),
      FoodItem(
          id: _uuid.v4(),
          name: 'Strawberries',
          nutritionPer100g: const NutritionFacts(
              calories: 32,
              protein: 0.7,
              carbs: 7.7,
              fat: 0.3,
              fiber: 2,
              sugar: 4.9)),
    ];
    for (final food in foods) {
      await _db.insertFoodItem(food);
    }
  }

  Future<void> seedFoodDatabase() async {
    final db = await _db.db;
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/south_indian_foods.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      final foods = jsonList
          .map((item) => FoodItem.fromMap(item as Map<String, dynamic>))
          .toList(growable: false);

      // Refresh only catalog-owned rows. Custom foods and barcode saves stay
      // untouched, while existing installs receive corrected catalog values.
      await db.transaction((txn) async {
        await txn.delete(
          'food_items',
          where: '''is_custom = 0 AND
            (id LIKE 'si_%' OR id LIKE 'regional_%')''',
        );
        final batch = txn.batch();
        for (final food in foods) {
          batch.insert(
            'food_items',
            food.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error seeding food database: $e');
    }
  }
}
