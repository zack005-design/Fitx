import 'package:uuid/uuid.dart';

import '../models/nutrition_models.dart';
import '../services/database_service.dart';

class NutritionRepository {
  NutritionRepository({DatabaseService? db, DateTime Function()? now})
      : _db = db ?? DatabaseService(),
        _now = now ?? DateTime.now;

  final DatabaseService _db;
  final DateTime Function() _now;
  static const _uuid = Uuid();

  static DateTime day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _writeTime(DateTime? targetDate) {
    final current = _now();
    if (targetDate != null && day(targetDate) != day(current)) {
      throw StateError('Nutrition can only be logged for today.');
    }
    return current;
  }

  Future<DailyNutrition> getDailyNutrition(DateTime date) async {
    final entries = await _db.getMealEntriesForDate(date);
    final water = await _db.getWaterForDate(date);
    final caffeine = await _db.getCaffeineForDate(date);
    return DailyNutrition(
      date: day(date),
      entries: entries,
      waterMl: water,
      caffeineMg: caffeine,
    );
  }

  Future<MealEntry> logMeal({
    required FoodItem food,
    required double amountGrams,
    required MealType mealType,
    DateTime? date,
  }) async {
    if (!amountGrams.isFinite || amountGrams <= 0 || amountGrams > 10000) {
      throw ArgumentError.value(
          amountGrams, 'amountGrams', 'must be between 0 and 10,000 g');
    }
    final entry = MealEntry(
      id: _uuid.v4(),
      foodItemId: food.id,
      foodName: food.name,
      amountGrams: amountGrams,
      mealType: mealType,
      loggedAt: _writeTime(date),
      nutrition: food.nutritionForAmount(amountGrams),
    );
    await _db.insertMealEntry(entry);
    return entry;
  }

  Future<void> deleteMealEntry(String id) => _db.deleteMealEntry(id);

  Future<MealEntry> updateMeal({
    required MealEntry entry,
    required double amountGrams,
    required MealType mealType,
  }) async {
    if (!amountGrams.isFinite || amountGrams <= 0 || amountGrams > 10000) {
      throw ArgumentError.value(
          amountGrams, 'amountGrams', 'must be between 0 and 10,000 g');
    }
    final factor =
        entry.amountGrams <= 0 ? 1.0 : amountGrams / entry.amountGrams;
    final old = entry.nutrition;
    final updated = entry.copyWith(
      amountGrams: amountGrams,
      mealType: mealType,
      nutrition: NutritionFacts(
        calories: old.calories * factor,
        protein: old.protein * factor,
        carbs: old.carbs * factor,
        fat: old.fat * factor,
        fiber: old.fiber == null ? null : old.fiber! * factor,
        sugar: old.sugar == null ? null : old.sugar! * factor,
        sodium: old.sodium == null ? null : old.sodium! * factor,
        saturatedFat:
            old.saturatedFat == null ? null : old.saturatedFat! * factor,
        cholesterol: old.cholesterol == null ? null : old.cholesterol! * factor,
        potassium: old.potassium == null ? null : old.potassium! * factor,
        calcium: old.calcium == null ? null : old.calcium! * factor,
        iron: old.iron == null ? null : old.iron! * factor,
        magnesium: old.magnesium == null ? null : old.magnesium! * factor,
        phosphorus: old.phosphorus == null ? null : old.phosphorus! * factor,
        zinc: old.zinc == null ? null : old.zinc! * factor,
        vitaminA: old.vitaminA == null ? null : old.vitaminA! * factor,
        vitaminC: old.vitaminC == null ? null : old.vitaminC! * factor,
        folate: old.folate == null ? null : old.folate! * factor,
      ),
    );
    await _db.updateMealEntry(updated);
    return updated;
  }

  Future<MealEntry> quickAdd({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required MealType mealType,
    DateTime? date,
  }) async {
    if ([calories, protein, carbs, fat]
        .any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError('Nutrition values must be finite and non-negative.');
    }
    if (calories > 20000 ||
        [protein, carbs, fat].any((value) => value > 2000)) {
      throw ArgumentError('Nutrition values exceed a plausible single entry.');
    }
    final entry = MealEntry(
      id: _uuid.v4(),
      foodItemId: 'manual',
      foodName: name.trim().isEmpty ? 'Quick add' : name.trim(),
      amountGrams: 1,
      mealType: mealType,
      loggedAt: _writeTime(date),
      nutrition: NutritionFacts(
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      ),
    );
    await _db.insertMealEntry(entry);
    return entry;
  }

  Future<List<FoodItem>> searchFoods(String query) => _db.searchFoods(query);
  Future<FoodItem?> getFoodByBarcode(String barcode) =>
      _db.getFoodByBarcode(barcode);
  Future<void> addCustomFood(FoodItem food) => _db.insertFoodItem(food);

  Future<List<FoodItem>> getFavoriteFoods() => _db.getFavoriteFoods();

  Future<void> setFoodFavorite(String foodItemId, bool favorite) =>
      _db.setFoodFavorite(foodItemId, favorite);

  Future<int> repeatPreviousDay({DateTime? date}) async {
    final target = _writeTime(date);
    final previous = target.subtract(const Duration(days: 1));
    final entries = await _db.getMealEntriesForDate(previous);
    for (final entry in entries) {
      await _db.insertMealEntry(MealEntry(
        id: _uuid.v4(),
        foodItemId: entry.foodItemId,
        foodName: entry.foodName,
        amountGrams: entry.amountGrams,
        mealType: entry.mealType,
        loggedAt: target,
        nutrition: entry.nutrition,
      ));
    }
    return entries.length;
  }

  Future<SavedMeal> saveCurrentMeals(String name, {DateTime? date}) async {
    final target = _writeTime(date);
    final entries = await _db.getMealEntriesForDate(target);
    if (entries.isEmpty) {
      throw StateError('Log at least one food before saving a meal.');
    }
    final meal = SavedMeal(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'Saved meal' : name.trim(),
      entries: entries,
      createdAt: target,
    );
    await _db.saveMealPreset(meal);
    return meal;
  }

  Future<List<SavedMeal>> getSavedMeals() => _db.getSavedMeals();

  Future<int> logSavedMeal(SavedMeal meal, {DateTime? date}) async {
    final target = _writeTime(date);
    for (final entry in meal.entries) {
      await _db.insertMealEntry(MealEntry(
        id: _uuid.v4(),
        foodItemId: entry.foodItemId,
        foodName: entry.foodName,
        amountGrams: entry.amountGrams,
        mealType: entry.mealType,
        loggedAt: target,
        nutrition: entry.nutrition,
      ));
    }
    return meal.entries.length;
  }

  Future<void> deleteSavedMeal(String id) => _db.deleteSavedMeal(id);

  Future<void> addWater(double ml, {DateTime? date}) {
    if (!ml.isFinite || ml <= 0 || ml > 5000) {
      throw ArgumentError.value(ml, 'ml', 'must be between 0 and 5,000 ml');
    }
    return _db.addWater(_writeTime(date), ml);
  }

  Future<void> addCaffeine(double mg, {DateTime? date}) {
    if (!mg.isFinite || mg <= 0 || mg > 2000) {
      throw ArgumentError.value(mg, 'mg', 'must be between 0 and 2,000 mg');
    }
    return _db.addCaffeine(_writeTime(date), mg);
  }

  Future<List<DailyNutrition>> getNutritionHistory({int days = 30}) async {
    final result = <DailyNutrition>[];
    for (var i = 0; i < days; i++) {
      result.add(await getDailyNutrition(_now().subtract(Duration(days: i))));
    }
    return result;
  }
}
