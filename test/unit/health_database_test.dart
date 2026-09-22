import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fitx/core/models/health_day.dart';
import 'package:fitx/core/services/database_service.dart';
import '../support/health_fixture.dart';

void main() {
  late Database database;
  late DatabaseService store;
  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute(
        'CREATE TABLE health_scores (date TEXT, score_type TEXT, value REAL, level INTEGER, breakdown TEXT, UNIQUE(date,score_type))');
    await database
        .execute('CREATE TABLE hrv_baseline (date TEXT, hrv_value REAL)');
    await database
        .execute('CREATE TABLE rhr_baseline (date TEXT, rhr_value REAL)');
    await database.execute(
        'CREATE TABLE meal_entries (id TEXT PRIMARY KEY, calories REAL)');
    await database
        .insert('meal_entries', {'id': 'existing-meal', 'calories': 450});
    await database.insert('health_scores', {
      'date': '2026-09-01',
      'score_type': 'recovery',
      'value': 50,
      'level': 1,
      'breakdown': 'hrv:50'
    });
    await DatabaseService.migrateVersion3(database);
    store = DatabaseService.forDatabase(database);
  });
  tearDown(() async => database.close());
  test('v3 migration preserves logs and marks legacy formulas', () async {
    expect((await database.query('meal_entries')).single['calories'], 450);
    expect(
        (await database.query('health_scores')).single['formula_version'], 1);
    expect(await store.getHealthSnapshots(DateTime(2026, 9, 13)), isEmpty);
    await store.saveScore('recovery', healthFixture().recovery);
    expect(
        (await database.query('health_scores',
                where: 'date = ?', whereArgs: ['2026-09-13']))
            .single['formula_version'],
        2);
  });
  test('snapshots replace one day and range boundaries are inclusive',
      () async {
    final end = DateTime(2026, 9, 13);
    for (var i = -1; i <= 90; i++) {
      await store
          .saveHealthSnapshot(healthFixture(date: shiftHealthDay(end, -i)));
    }
    await store.saveHealthSnapshot(healthFixture(date: end, scoreValue: 81));
    for (final days in [7, 30, 90]) {
      final rows = await store.getHealthSnapshots(end, days: days);
      expect(rows.length, days);
      expect(rows.first.date, shiftHealthDay(end, 1 - days));
      expect(rows.last.date, end);
      expect(rows.last.recovery.value, 81);
      expect(rows.last.sleepData.stages, hasLength(4));
    }
  });
  test('baseline uses paired prior days only and deduplicates old rows',
      () async {
    final end = DateTime(2026, 9, 13);
    for (var i = 1; i <= 14; i++) {
      await store.saveHrvReading(shiftHealthDay(end, -i), 50);
      await store.saveRhrReading(shiftHealthDay(end, -i), 60);
    }
    await store.saveHrvReading(shiftHealthDay(end, -15), 900); // No paired RHR.
    await store.saveHrvReading(end, 900);
    await store.saveRhrReading(end, 900);
    await store.saveHrvReading(shiftHealthDay(end, 1), 900);
    await store.saveRhrReading(shiftHealthDay(end, 1), 900);
    await store.saveHrvReading(shiftHealthDay(end, -31), 900);
    await store.saveRhrReading(shiftHealthDay(end, -31), 900);
    await database.insert('hrv_baseline',
        {'date': healthDayKey(shiftHealthDay(end, -1)), 'hrv_value': 50});
    final baseline = await store.getPersonalBaseline(end);
    expect(baseline.days, 14);
    expect(baseline.hrv, 50);
    expect(baseline.rhr, 60);
  });
}
