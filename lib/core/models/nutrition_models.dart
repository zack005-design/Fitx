import 'package:equatable/equatable.dart';

class FoodItem extends Equatable {
  final String id;
  final String name;
  final String? brand;
  final String? barcode;
  final NutritionFacts nutritionPer100g;
  final bool isCustom;
  final String? states;
  final String? category;
  final String? aliases;
  final String? servingName;
  final double? servingGrams;
  final bool? isVegetarian;
  final String? source;
  final String? sourceCode;
  final String? dataQuality;

  const FoodItem({
    required this.id,
    required this.name,
    this.brand,
    this.barcode,
    required this.nutritionPer100g,
    this.isCustom = false,
    this.states,
    this.category,
    this.aliases,
    this.servingName,
    this.servingGrams,
    this.isVegetarian,
    this.source,
    this.sourceCode,
    this.dataQuality,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'brand': brand,
        'barcode': barcode,
        'calories_per100': nutritionPer100g.calories,
        'protein_per100': nutritionPer100g.protein,
        'carbs_per100': nutritionPer100g.carbs,
        'fat_per100': nutritionPer100g.fat,
        'fiber_per100': nutritionPer100g.fiber,
        'sugar_per100': nutritionPer100g.sugar,
        'sodium_per100': nutritionPer100g.sodium,
        'saturated_fat_per100': nutritionPer100g.saturatedFat,
        'cholesterol_per100': nutritionPer100g.cholesterol,
        'potassium_per100': nutritionPer100g.potassium,
        'calcium_per100': nutritionPer100g.calcium,
        'iron_per100': nutritionPer100g.iron,
        'magnesium_per100': nutritionPer100g.magnesium,
        'phosphorus_per100': nutritionPer100g.phosphorus,
        'zinc_per100': nutritionPer100g.zinc,
        'vitamin_a_per100': nutritionPer100g.vitaminA,
        'vitamin_c_per100': nutritionPer100g.vitaminC,
        'folate_per100': nutritionPer100g.folate,
        'states': states,
        'category': category,
        'aliases': aliases,
        'serving_name': servingName,
        'serving_grams': servingGrams,
        'is_vegetarian': isVegetarian == null ? null : (isVegetarian! ? 1 : 0),
        'source': source,
        'source_code': sourceCode,
        'data_quality': dataQuality,
        'is_custom': isCustom ? 1 : 0,
      };

  factory FoodItem.fromMap(Map<String, dynamic> m) => FoodItem(
        id: m['id'] as String,
        name: m['name'] as String,
        brand: m['brand'] as String?,
        barcode: m['barcode'] as String?,
        isCustom: (m['is_custom'] as int? ?? 0) == 1,
        nutritionPer100g: NutritionFacts(
          calories: (m['calories_per100'] as num).toDouble(),
          protein: (m['protein_per100'] as num).toDouble(),
          carbs: (m['carbs_per100'] as num).toDouble(),
          fat: (m['fat_per100'] as num).toDouble(),
          fiber: (m['fiber_per100'] as num?)?.toDouble(),
          sugar: (m['sugar_per100'] as num?)?.toDouble(),
          sodium: (m['sodium_per100'] as num?)?.toDouble(),
          saturatedFat: (m['saturated_fat_per100'] as num?)?.toDouble(),
          cholesterol: (m['cholesterol_per100'] as num?)?.toDouble(),
          potassium: (m['potassium_per100'] as num?)?.toDouble(),
          calcium: (m['calcium_per100'] as num?)?.toDouble(),
          iron: (m['iron_per100'] as num?)?.toDouble(),
          magnesium: (m['magnesium_per100'] as num?)?.toDouble(),
          phosphorus: (m['phosphorus_per100'] as num?)?.toDouble(),
          zinc: (m['zinc_per100'] as num?)?.toDouble(),
          vitaminA: (m['vitamin_a_per100'] as num?)?.toDouble(),
          vitaminC: (m['vitamin_c_per100'] as num?)?.toDouble(),
          folate: (m['folate_per100'] as num?)?.toDouble(),
        ),
        states: m['states'] as String?,
        category: m['category'] as String?,
        aliases: m['aliases'] as String?,
        servingName: m['serving_name'] as String?,
        servingGrams: (m['serving_grams'] as num?)?.toDouble(),
        isVegetarian: m['is_vegetarian'] == null
            ? null
            : (m['is_vegetarian'] as num).toInt() == 1,
        source: m['source'] as String?,
        sourceCode: m['source_code'] as String?,
        dataQuality: m['data_quality'] as String?,
      );

  NutritionFacts nutritionForAmount(double grams) {
    final factor = grams / 100;
    return NutritionFacts(
      calories: nutritionPer100g.calories * factor,
      protein: nutritionPer100g.protein * factor,
      carbs: nutritionPer100g.carbs * factor,
      fat: nutritionPer100g.fat * factor,
      fiber: nutritionPer100g.fiber != null
          ? nutritionPer100g.fiber! * factor
          : null,
      sugar: nutritionPer100g.sugar != null
          ? nutritionPer100g.sugar! * factor
          : null,
      sodium: nutritionPer100g.sodium != null
          ? nutritionPer100g.sodium! * factor
          : null,
      saturatedFat: nutritionPer100g.saturatedFat == null
          ? null
          : nutritionPer100g.saturatedFat! * factor,
      cholesterol: nutritionPer100g.cholesterol == null
          ? null
          : nutritionPer100g.cholesterol! * factor,
      potassium: nutritionPer100g.potassium == null
          ? null
          : nutritionPer100g.potassium! * factor,
      calcium: nutritionPer100g.calcium == null
          ? null
          : nutritionPer100g.calcium! * factor,
      iron: nutritionPer100g.iron == null
          ? null
          : nutritionPer100g.iron! * factor,
      magnesium: nutritionPer100g.magnesium == null
          ? null
          : nutritionPer100g.magnesium! * factor,
      phosphorus: nutritionPer100g.phosphorus == null
          ? null
          : nutritionPer100g.phosphorus! * factor,
      zinc: nutritionPer100g.zinc == null
          ? null
          : nutritionPer100g.zinc! * factor,
      vitaminA: nutritionPer100g.vitaminA == null
          ? null
          : nutritionPer100g.vitaminA! * factor,
      vitaminC: nutritionPer100g.vitaminC == null
          ? null
          : nutritionPer100g.vitaminC! * factor,
      folate: nutritionPer100g.folate == null
          ? null
          : nutritionPer100g.folate! * factor,
    );
  }

  @override
  List<Object?> get props => [id, name, barcode];
}

class NutritionFacts extends Equatable {
  final double calories;
  final double protein; // g
  final double carbs; // g
  final double fat; // g
  final double? fiber; // g
  final double? sugar; // g
  final double? sodium; // mg
  final double? saturatedFat; // g
  final double? cholesterol; // mg
  final double? potassium; // mg
  final double? calcium; // mg
  final double? iron; // mg
  final double? magnesium; // mg
  final double? phosphorus; // mg
  final double? zinc; // mg
  final double? vitaminA; // µg
  final double? vitaminC; // mg
  final double? folate; // µg

  const NutritionFacts({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber,
    this.sugar,
    this.sodium,
    this.saturatedFat,
    this.cholesterol,
    this.potassium,
    this.calcium,
    this.iron,
    this.magnesium,
    this.phosphorus,
    this.zinc,
    this.vitaminA,
    this.vitaminC,
    this.folate,
  });

  NutritionFacts operator +(NutritionFacts other) => NutritionFacts(
        calories: calories + other.calories,
        protein: protein + other.protein,
        carbs: carbs + other.carbs,
        fat: fat + other.fat,
        fiber: (fiber ?? 0) + (other.fiber ?? 0),
        sugar: (sugar ?? 0) + (other.sugar ?? 0),
        sodium: (sodium ?? 0) + (other.sodium ?? 0),
        saturatedFat: (saturatedFat ?? 0) + (other.saturatedFat ?? 0),
        cholesterol: (cholesterol ?? 0) + (other.cholesterol ?? 0),
        potassium: (potassium ?? 0) + (other.potassium ?? 0),
        calcium: (calcium ?? 0) + (other.calcium ?? 0),
        iron: (iron ?? 0) + (other.iron ?? 0),
        magnesium: (magnesium ?? 0) + (other.magnesium ?? 0),
        phosphorus: (phosphorus ?? 0) + (other.phosphorus ?? 0),
        zinc: (zinc ?? 0) + (other.zinc ?? 0),
        vitaminA: (vitaminA ?? 0) + (other.vitaminA ?? 0),
        vitaminC: (vitaminC ?? 0) + (other.vitaminC ?? 0),
        folate: (folate ?? 0) + (other.folate ?? 0),
      );

  @override
  List<Object?> get props => [calories, protein, carbs, fat];
}

enum MealType { breakfast, lunch, dinner, snack, water }

extension MealTypeExt on MealType {
  String get label {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snack:
        return 'Snack';
      case MealType.water:
        return 'Water';
    }
  }
}

class MealEntry extends Equatable {
  final String id;
  final String foodItemId;
  final String foodName;
  final double amountGrams;
  final MealType mealType;
  final DateTime loggedAt;
  final NutritionFacts nutrition;

  const MealEntry({
    required this.id,
    required this.foodItemId,
    required this.foodName,
    required this.amountGrams,
    required this.mealType,
    required this.loggedAt,
    required this.nutrition,
  });

  MealEntry copyWith({
    double? amountGrams,
    MealType? mealType,
    NutritionFacts? nutrition,
  }) =>
      MealEntry(
        id: id,
        foodItemId: foodItemId,
        foodName: foodName,
        amountGrams: amountGrams ?? this.amountGrams,
        mealType: mealType ?? this.mealType,
        loggedAt: loggedAt,
        nutrition: nutrition ?? this.nutrition,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'food_item_id': foodItemId,
        'food_name': foodName,
        'amount_grams': amountGrams,
        'meal_type': mealType.index,
        'logged_at': loggedAt.toIso8601String(),
        'calories': nutrition.calories,
        'protein': nutrition.protein,
        'carbs': nutrition.carbs,
        'fat': nutrition.fat,
        'fiber': nutrition.fiber,
        'sugar': nutrition.sugar,
        'sodium': nutrition.sodium,
        'saturated_fat': nutrition.saturatedFat,
        'cholesterol': nutrition.cholesterol,
        'potassium': nutrition.potassium,
        'calcium': nutrition.calcium,
        'iron': nutrition.iron,
        'magnesium': nutrition.magnesium,
        'phosphorus': nutrition.phosphorus,
        'zinc': nutrition.zinc,
        'vitamin_a': nutrition.vitaminA,
        'vitamin_c': nutrition.vitaminC,
        'folate': nutrition.folate,
      };

  factory MealEntry.fromMap(Map<String, dynamic> m) => MealEntry(
        id: m['id'] as String,
        foodItemId: m['food_item_id'] as String,
        foodName: m['food_name'] as String,
        amountGrams: (m['amount_grams'] as num).toDouble(),
        mealType: MealType.values[m['meal_type'] as int],
        loggedAt: DateTime.parse(m['logged_at'] as String),
        nutrition: NutritionFacts(
          calories: (m['calories'] as num).toDouble(),
          protein: (m['protein'] as num).toDouble(),
          carbs: (m['carbs'] as num).toDouble(),
          fat: (m['fat'] as num).toDouble(),
          fiber: (m['fiber'] as num?)?.toDouble(),
          sugar: (m['sugar'] as num?)?.toDouble(),
          sodium: (m['sodium'] as num?)?.toDouble(),
          saturatedFat: (m['saturated_fat'] as num?)?.toDouble(),
          cholesterol: (m['cholesterol'] as num?)?.toDouble(),
          potassium: (m['potassium'] as num?)?.toDouble(),
          calcium: (m['calcium'] as num?)?.toDouble(),
          iron: (m['iron'] as num?)?.toDouble(),
          magnesium: (m['magnesium'] as num?)?.toDouble(),
          phosphorus: (m['phosphorus'] as num?)?.toDouble(),
          zinc: (m['zinc'] as num?)?.toDouble(),
          vitaminA: (m['vitamin_a'] as num?)?.toDouble(),
          vitaminC: (m['vitamin_c'] as num?)?.toDouble(),
          folate: (m['folate'] as num?)?.toDouble(),
        ),
      );

  @override
  List<Object?> get props => [id, loggedAt, foodItemId];
}

class DailyNutrition extends Equatable {
  final DateTime date;
  final List<MealEntry> entries;
  final double waterMl;
  final double caffeineMg;

  const DailyNutrition({
    required this.date,
    required this.entries,
    required this.waterMl,
    this.caffeineMg = 0,
  });

  NutritionFacts get totals => entries.fold(
        const NutritionFacts(calories: 0, protein: 0, carbs: 0, fat: 0),
        (acc, e) => acc + e.nutrition,
      );

  Map<MealType, List<MealEntry>> get byMeal {
    final map = <MealType, List<MealEntry>>{};
    for (final e in entries) {
      map.putIfAbsent(e.mealType, () => []).add(e);
    }
    return map;
  }

  @override
  List<Object?> get props => [date, entries, waterMl, caffeineMg];
}

class SavedMeal extends Equatable {
  const SavedMeal({
    required this.id,
    required this.name,
    required this.entries,
    required this.createdAt,
  });

  final String id;
  final String name;
  final List<MealEntry> entries;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, name, entries, createdAt];
}
