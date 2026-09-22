import 'package:fitx/core/models/journal_models.dart';
import 'package:fitx/core/models/nutrition_models.dart';
import 'package:fitx/core/models/user_profile.dart';
import 'package:fitx/core/repositories/journal_repository.dart';
import 'package:fitx/core/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/health_fixture.dart';

void main() {
  late Database database;
  late DatabaseService store;
  final today = DateTime(2026, 9, 14, 12);

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createSourceSchema(database);
    await DatabaseService.createHealthSnapshotTable(database);
    await DatabaseService.createPhase4Tables(database);
    store = DatabaseService.forDatabase(database);
  });

  tearDown(() => database.close());

  test('all manual input types persist, edit, and retain optional notes',
      () async {
    final repository = JournalRepository(db: store, now: () => today);
    final definitions = {
      for (final value in await repository.getDefinitions()) value.id: value,
    };

    await repository.saveManualEntry(
      definition: definitions['alcohol']!,
      date: today,
      choice: JournalChoice.neutral,
      note: 'Dinner out',
    );
    await repository.saveManualEntry(
      definition: definitions['mood']!,
      date: today,
      numberValue: 4,
      note: 'Steady',
    );
    await repository.saveManualEntry(
      definition: definitions['sunlight']!,
      date: today,
      numberValue: 35,
    );
    await repository.saveManualEntry(
      definition: definitions['caffeine_time']!,
      date: today,
      timeMinutes: 14 * 60 + 30,
    );
    await repository.saveManualEntry(
      definition: definitions['medication']!,
      date: today,
      textValue: 'Vitamin D',
    );
    final beforeEdit = await repository.getDay(today);
    final alcoholId = beforeEdit.entryFor('alcohol')!.id;

    await repository.saveManualEntry(
      definition: definitions['alcohol']!,
      date: today,
      choice: JournalChoice.no,
      note: 'Corrected',
    );
    final day = await repository.getDay(today);

    expect(day.entryFor('alcohol')!.id, alcoholId);
    expect(day.entryFor('alcohol')!.choice, JournalChoice.no);
    expect(day.entryFor('alcohol')!.note, 'Corrected');
    expect(day.entryFor('mood')!.numberValue, 4);
    expect(day.entryFor('sunlight')!.numberValue, 35);
    expect(day.entryFor('caffeine_time')!.displayValue, '14:30');
    expect(day.entryFor('medication')!.textValue, 'Vitamin D');
  });

  test('past manual entries are editable and future entries are rejected',
      () async {
    final repository = JournalRepository(db: store, now: () => today);
    final alcohol = (await repository.getDefinitions())
        .singleWhere((value) => value.id == 'alcohol');
    final yesterday = DateTime(2026, 9, 13);

    await repository.saveManualEntry(
      definition: alcohol,
      date: yesterday,
      choice: JournalChoice.yes,
    );
    await repository.saveManualEntry(
      definition: alcohol,
      date: yesterday,
      choice: JournalChoice.no,
    );

    expect((await repository.getDay(yesterday)).entryFor('alcohol')!.choice,
        JournalChoice.no);
    expect(
      () => repository.saveManualEntry(
        definition: alcohol,
        date: DateTime(2026, 9, 15),
        choice: JournalChoice.yes,
      ),
      throwsStateError,
    );
  });

  test(
      'automatic entries exist only for recorded source data and are immutable',
      () async {
    final repository = JournalRepository(db: store, now: () => today);
    expect((await repository.getDay(today)).entries, isEmpty);

    await store.saveProfile(const UserProfile(
      name: 'Test',
      age: 30,
      gender: Gender.other,
      heightCm: 170,
      weightKg: 70,
      dailyWaterGoal: 2000,
    ));
    await store.addWater(today, 1500);
    await store.insertMealEntry(MealEntry(
      id: 'meal',
      foodItemId: 'manual',
      foodName: 'Recorded meal',
      amountGrams: 1,
      mealType: MealType.lunch,
      loggedAt: today,
      nutrition: const NutritionFacts(
        calories: 500,
        protein: 20,
        carbs: 60,
        fat: 15,
      ),
    ));
    await database.insert('workout_logs', {
      'id': 'workout',
      'name': 'Walk',
      'started_at': DateTime(2026, 9, 14, 8).toIso8601String(),
      'finished_at': DateTime(2026, 9, 14, 9).toIso8601String(),
      'notes': null,
    });
    await store.saveHealthSnapshot(healthFixture(date: today));

    final day = await repository.getDay(today);
    final automatic = day.entries
        .where((entry) => entry.source == JournalEntrySource.automatic)
        .toList();
    expect(
        automatic.map((entry) => entry.definitionId),
        containsAll([
          'hydration_goal',
          'workout_completed',
          'sleep_duration',
          'nutrition_calories',
        ]));
    expect(day.entryFor('hydration_goal')!.choice, JournalChoice.no);
    expect(day.entryFor('sleep_duration')!.numberValue, 7);
    expect(day.entryFor('nutrition_calories')!.numberValue, 500);

    final automaticDefinition = day.definitions
        .singleWhere((definition) => definition.id == 'hydration_goal');
    expect(
      () => repository.saveManualEntry(
        definition: automaticDefinition,
        date: today,
        choice: JournalChoice.yes,
      ),
      throwsArgumentError,
    );
    expect(
      () => store.saveManualJournalEntry(JournalEntry(
        id: 'forged',
        definitionId: 'hydration_goal',
        date: today,
        source: JournalEntrySource.manual,
        choice: JournalChoice.yes,
        createdAt: today,
        updatedAt: today,
      )),
      throwsStateError,
    );
    await store.deleteJournalEntry('hydration_goal', today);
    expect(
        (await store.getJournalEntriesForDate(today))
            .any((entry) => entry.definitionId == 'hydration_goal'),
        isTrue);
  });

  test('Recovery and Sleep unlock independently at five Yes and five No',
      () async {
    final repository = JournalRepository(db: store, now: () => today);
    final alcohol = (await repository.getDefinitions())
        .singleWhere((definition) => definition.id == 'alcohol');
    for (var index = 0; index < 10; index++) {
      final observationDay = DateTime(2026, 8, 20 + index);
      final yes = index < 5;
      await repository.saveManualEntry(
        definition: alcohol,
        date: observationDay,
        choice: yes ? JournalChoice.yes : JournalChoice.no,
      );
      await store.saveHealthSnapshot(healthFixture(
        date: observationDay.add(const Duration(days: 1)),
        scoreValue: yes ? 80 : 60,
      ));
    }

    final insights = await repository.getInsights(days: 60);
    final alcoholInsights = insights
        .where((insight) => insight.definition.id == 'alcohol')
        .toList();

    expect(alcoholInsights, hasLength(2));
    for (final insight in alcoholInsights) {
      expect(insight.isReady, isTrue);
      expect(insight.positiveCount, 5);
      expect(insight.negativeCount, 5);
      expect(insight.associationMagnitude, 20);
      expect(insight.summary, contains('associated with'));
      expect(insight.summary, isNot(contains('caused')));
    }
    expect(await database.query('journal_correlations'), isNotEmpty);
  });

  test('insight remains gated when either observation group is insufficient',
      () async {
    final repository = JournalRepository(db: store, now: () => today);
    final alcohol = (await repository.getDefinitions())
        .singleWhere((definition) => definition.id == 'alcohol');
    for (var index = 0; index < 9; index++) {
      final observationDay = DateTime(2026, 8, 20 + index);
      await repository.saveManualEntry(
        definition: alcohol,
        date: observationDay,
        choice: index < 5 ? JournalChoice.yes : JournalChoice.no,
      );
      await store.saveHealthSnapshot(healthFixture(
        date: observationDay.add(const Duration(days: 1)),
      ));
    }

    final recovery = (await repository.getInsights(days: 60)).singleWhere(
      (insight) =>
          insight.definition.id == 'alcohol' &&
          insight.metric == JournalInsightMetric.recovery,
    );
    expect(recovery.positiveCount, 5);
    expect(recovery.negativeCount, 4);
    expect(recovery.isReady, isFalse);
    expect(recovery.associationMagnitude, isNull);
  });

  test('v5 migration is additive and preserves existing journal entries',
      () async {
    await store.upsertJournalDefinitions(defaultJournalDefinitions);
    final alcohol = (await store.getJournalDefinitions())
        .singleWhere((definition) => definition.id == 'alcohol');
    await store.saveManualJournalEntry(JournalEntry(
      id: 'existing',
      definitionId: alcohol.id,
      date: today,
      source: JournalEntrySource.manual,
      choice: JournalChoice.yes,
      createdAt: today,
      updatedAt: today,
    ));

    await DatabaseService.migrateVersion5(database);

    expect((await store.getJournalEntriesForDate(today)).single.id, 'existing');
    expect(
      (await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='journal_correlations'",
      )),
      hasLength(1),
    );
  });
}

Future<void> _createSourceSchema(Database database) async {
  await database.execute('''CREATE TABLE user_profile (
    id INTEGER PRIMARY KEY, name TEXT NOT NULL, age INTEGER NOT NULL,
    gender INTEGER NOT NULL, height_cm REAL NOT NULL, weight_kg REAL NOT NULL,
    use_metric INTEGER NOT NULL DEFAULT 1,
    daily_step_goal INTEGER NOT NULL DEFAULT 8000,
    daily_calorie_goal REAL NOT NULL DEFAULT 2000,
    daily_protein_goal REAL NOT NULL DEFAULT 120,
    sleep_goal_minutes INTEGER NOT NULL DEFAULT 480,
    daily_water_goal INTEGER NOT NULL DEFAULT 2500,
    strain_target REAL NOT NULL DEFAULT 14
  )''');
  await database.execute('''CREATE TABLE water_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, amount_ml REAL NOT NULL
  )''');
  await database.execute('''CREATE TABLE meal_entries (
    id TEXT PRIMARY KEY, food_item_id TEXT NOT NULL, food_name TEXT NOT NULL,
    amount_grams REAL NOT NULL, meal_type INTEGER NOT NULL,
    logged_at TEXT NOT NULL, calories REAL NOT NULL, protein REAL NOT NULL,
    carbs REAL NOT NULL, fat REAL NOT NULL, fiber REAL, sugar REAL, sodium REAL,
    saturated_fat REAL, cholesterol REAL, potassium REAL, calcium REAL,
    iron REAL, magnesium REAL, phosphorus REAL, zinc REAL, vitamin_a REAL,
    vitamin_c REAL, folate REAL
  )''');
  await database.execute('''CREATE TABLE workout_logs (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, started_at TEXT NOT NULL,
    finished_at TEXT, notes TEXT
  )''');
}
