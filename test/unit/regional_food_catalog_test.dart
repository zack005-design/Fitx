import 'dart:convert';
import 'dart:io';

import 'package:fitx/core/models/nutrition_models.dart';
import 'package:fitx/core/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late List<Map<String, dynamic>> catalog;

  setUpAll(() {
    final decoded = jsonDecode(
      File('assets/data/south_indian_foods.json').readAsStringSync(),
    ) as List<dynamic>;
    catalog = decoded.cast<Map<String, dynamic>>();
  });

  test('catalog covers all three requested states', () {
    expect(catalog.length, greaterThanOrEqualTo(250));
    for (final state in ['Kerala', 'Tamil Nadu', 'Karnataka']) {
      expect(
        catalog
            .where((food) => (food['states'] as String).contains(state))
            .length,
        greaterThanOrEqualTo(90),
        reason: '$state should have broad regional coverage',
      );
    }
  });

  test('catalog IDs are unique and every row parses as a FoodItem', () {
    final ids = catalog.map((food) => food['id'] as String).toSet();
    expect(ids.length, catalog.length);
    for (final row in catalog) {
      final food = FoodItem.fromMap(row);
      expect(food.name, isNotEmpty);
      expect(food.servingGrams, greaterThan(0));
      expect(food.nutritionPer100g.calories, greaterThan(0));
      expect(food.nutritionPer100g.protein, greaterThanOrEqualTo(0));
      expect(food.nutritionPer100g.carbs, greaterThanOrEqualTo(0));
      expect(food.nutritionPer100g.fat, greaterThanOrEqualTo(0));
    }
  });

  test('source-backed rows include provenance and extended nutrients', () {
    final sourced = catalog.where(
      (food) => food['data_quality'] == 'recipe_calculated',
    );
    expect(sourced.length, greaterThanOrEqualTo(40));
    for (final food in sourced) {
      expect(food['source'], 'INDB 2024.11');
      expect(food['source_code'], isNotEmpty);
      expect(food['potassium_per100'], isA<num>());
      expect(food['calcium_per100'], isA<num>());
      expect(food['iron_per100'], isA<num>());
    }
  });

  test('serving nutrition scales from per-100 gram values', () {
    final idli = FoodItem.fromMap(
      catalog.singleWhere((food) => food['id'] == 'si_001'),
    );
    final serving = idli.nutritionForAmount(idli.servingGrams!);
    expect(
      serving.calories,
      closeTo(
        idli.nutritionPer100g.calories * idli.servingGrams! / 100,
        0.001,
      ),
    );
    expect(idli.nutritionPer100g.sugar, lessThan(1));
  });

  test('v8 migration preserves rows and accepts extended catalog data',
      () async {
    sqfliteFfiInit();
    final database =
        await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(database.close);
    await database.execute('''CREATE TABLE food_items (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, brand TEXT, barcode TEXT,
      calories_per100 REAL NOT NULL, protein_per100 REAL NOT NULL,
      carbs_per100 REAL NOT NULL, fat_per100 REAL NOT NULL, fiber_per100 REAL,
      sugar_per100 REAL, sodium_per100 REAL,
      is_custom INTEGER NOT NULL DEFAULT 0
    )''');
    await database.execute('''CREATE TABLE meal_entries (
      id TEXT PRIMARY KEY, food_item_id TEXT NOT NULL, food_name TEXT NOT NULL,
      amount_grams REAL NOT NULL, meal_type INTEGER NOT NULL,
      logged_at TEXT NOT NULL, calories REAL NOT NULL, protein REAL NOT NULL,
      carbs REAL NOT NULL, fat REAL NOT NULL, fiber REAL, sugar REAL, sodium REAL
    )''');
    await database.insert('food_items', {
      'id': 'custom',
      'name': 'Saved custom food',
      'calories_per100': 100,
      'protein_per100': 1,
      'carbs_per100': 20,
      'fat_per100': 1,
      'is_custom': 1,
    });

    await DatabaseService.migrateVersion8(database);
    final store = DatabaseService.forDatabase(database);
    await store.insertFoodItem(FoodItem.fromMap(catalog.first));

    expect(await store.searchFoods('idli'), isNotEmpty);
    expect(
        (await database
            .query('food_items', where: 'id = ?', whereArgs: ['custom'])),
        hasLength(1));
    final columns = await database.rawQuery('PRAGMA table_info(food_items)');
    expect(
        columns.map((column) => column['name']), contains('potassium_per100'));
    expect(columns.map((column) => column['name']), contains('serving_grams'));
  });
}
