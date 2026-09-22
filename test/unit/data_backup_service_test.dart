import 'dart:convert';

import 'package:fitx/core/services/data_backup_service.dart';
import 'package:fitx/core/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _tableNames = <String>[
  'user_profile', 'health_scores', 'meal_entries', 'water_entries',
  'caffeine_entries', 'workout_logs', 'workout_log_exercises', 'exercise_sets',
  'personal_records', 'hrv_baseline', 'rhr_baseline',
  'daily_health_snapshots', 'journal_definitions', 'journal_entries',
  'journal_correlations', 'sync_state', 'data_sources', 'app_preferences',
  'phone_sleep_sessions', 'favorite_foods', 'saved_meals',
  'custom_food_items', 'custom_exercises',
];

Map<String, Object?> _backup({int? schema, String? hostileText}) {
  final tables = <String, Object?>{
    for (final table in _tableNames) table: <Object?>[],
  };
  tables['meal_entries'] = [
    {'id': 'meal-1', 'food_name': hostileText ?? 'Idli'},
    {'id': 'meal-2', 'food_name': 'Dosa'},
  ];
  tables['workout_logs'] = [
    {'id': 'workout-1'},
  ];
  return {
    'formatVersion': DataBackupService.formatVersion,
    'schemaVersion': schema ?? DataBackupService.schemaVersion,
    'appVersion': DataBackupService.appVersion,
    'exportedAtUtc': '2026-09-14T12:00:00.000Z',
    'payloadSha256': '',
    'payload': {'tables': tables},
  };
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('supported backup reports provenance and complete record count', () {
    final decoded = DataBackupService.decodeBackup(
        DataBackupService.encodeBackup(_backup()));
    final summary = DataBackupService.summary(decoded);
    expect(summary.createdAt, DateTime.utc(2026, 9, 14, 12));
    expect(summary.rowCount, 3);
    expect(summary.appVersion, DataBackupService.appVersion);
  });

  test('hostile text round-trips byte-identically through the envelope', () {
    const hostile = ' =SUM(1,2)\n"quoted" 👟 مرحبا\u200f ';
    final first = DataBackupService.encodeBackup(_backup(hostileText: hostile));
    final second = DataBackupService.encodeBackup(
        DataBackupService.decodeBackup(first));
    expect(second, first);
  });

  test('changed payload is refused by checksum before restore', () {
    final encoded = DataBackupService.encodeBackup(_backup());
    final root = Map<String, Object?>.from(jsonDecode(encoded) as Map);
    root['payload'] = (root['payload']! as String).replaceFirst('Idli', 'Rice');
    expect(
      () => DataBackupService.decodeBackup(jsonEncode(root)),
      throwsA(isA<BackupValidationException>().having(
          (error) => error.code, 'code', BackupFailureCode.corrupt)),
    );
  });

  test('foreign and newer backup formats are refused', () {
    final badFormat = _backup()
      ..['formatVersion'] = DataBackupService.formatVersion + 1;
    expect(
      () => DataBackupService.decodeBackup(
          DataBackupService.encodeBackup(badFormat)),
      throwsA(isA<BackupValidationException>().having((error) => error.code,
          'code', BackupFailureCode.unsupportedFormat)),
    );

    expect(
      () => DataBackupService.decodeBackup(DataBackupService.encodeBackup(
          _backup(schema: DataBackupService.schemaVersion + 1))),
      throwsA(isA<BackupValidationException>().having(
          (error) => error.code, 'code', BackupFailureCode.newerSchema)),
    );
  });

  test('restore replaces all rows and a failed restore rolls back atomically',
      () async {
    final database =
        await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(database.close);
    await DatabaseService.createSchema(database, DataBackupService.schemaVersion);
    final store = DatabaseService.forDatabase(database);
    final service = DataBackupService(database: store);
    final profile = <String, Object?>{
      'id': 1,
      'name': 'Before backup',
      'age': 30,
      'gender': 0,
      'height_cm': 170.0,
      'weight_kg': 70.0,
      'use_metric': 1,
      'daily_step_goal': 8000,
      'daily_calorie_goal': 2000.0,
      'daily_protein_goal': 120.0,
      'sleep_goal_minutes': 480,
      'daily_water_goal': 2500,
      'strain_target': 14.0,
    };
    await database.insert('user_profile', profile);
    final backup = await service.createBackup();

    await database.update('user_profile', {'name': 'After backup'});
    await service.restoreBackup(backup);
    expect((await database.query('user_profile')).single['name'],
        'Before backup');

    await database.update('user_profile', {'name': 'Must survive failure'});
    final corrupt = Map<String, Object?>.from(backup);
    final payload = Map<String, Object?>.from(
        jsonDecode(jsonEncode(backup['payload'])) as Map);
    final tables = Map<String, Object?>.from(payload['tables']! as Map);
    final rows = List<Object?>.from(tables['user_profile']! as List);
    rows[0] = {...Map<String, Object?>.from(rows[0]! as Map), 'unknown': 1};
    tables['user_profile'] = rows;
    payload['tables'] = tables;
    corrupt['payload'] = payload;

    await expectLater(service.restoreBackup(corrupt), throwsA(anything));
    expect((await database.query('user_profile')).single['name'],
        'Must survive failure');
  });
}
