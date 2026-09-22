import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

class BackupSummary {
  const BackupSummary({required this.createdAt, required this.rowCount, required this.appVersion});
  final DateTime createdAt;
  final int rowCount;
  final String appVersion;
}

enum BackupFailureCode { notFitX, unsupportedFormat, newerSchema, corrupt, malformed }

class BackupValidationException implements Exception {
  const BackupValidationException(this.code, this.message);
  final BackupFailureCode code;
  final String message;
  @override
  String toString() => message;
}

abstract interface class DataFileGateway {
  Future<bool> saveText({required String suggestedName, required String content});
  Future<String?> openText();
}

class AndroidDataFileGateway implements DataFileGateway {
  const AndroidDataFileGateway();
  static const _channel = MethodChannel('fitx/data_files');
  @override
  Future<String?> openText() => _channel.invokeMethod<String>('openText');
  @override
  Future<bool> saveText({required String suggestedName, required String content}) async =>
      await _channel.invokeMethod<bool>('saveText', {
        'suggestedName': suggestedName,
        'content': content,
      }) ?? false;
}

/// Creates exact, machine-readable FitX backups. Restore uses a replace-all
/// policy inside one SQLite transaction, so any invalid row rolls the complete
/// import back and leaves the previous local data intact.
class DataBackupService {
  DataBackupService({DatabaseService? database, DataFileGateway? files})
      : _database = database ?? DatabaseService(),
        _files = files ?? const AndroidDataFileGateway();

  static const formatVersion = 2;
  static const schemaVersion = 9;
  static const appVersion = '1.0.0+1';
  final DatabaseService _database;
  final DataFileGateway _files;

  static const _tables = <String>[
    'user_profile', 'health_scores', 'meal_entries', 'water_entries',
    'caffeine_entries', 'workout_logs', 'workout_log_exercises',
    'exercise_sets', 'personal_records', 'hrv_baseline', 'rhr_baseline',
    'daily_health_snapshots', 'journal_definitions', 'journal_entries',
    'journal_correlations', 'sync_state', 'data_sources', 'app_preferences',
    'phone_sleep_sessions', 'favorite_foods', 'saved_meals',
  ];

  Future<BackupSummary?> exportToFile() async {
    final backup = await createBackup();
    final createdAt = DateTime.parse(backup['exportedAtUtc']! as String);
    final saved = await _files.saveText(
      suggestedName: 'fitx-backup-${createdAt.toIso8601String().substring(0, 10)}.json',
      content: encodeBackup(backup),
    );
    return saved ? summary(backup) : null;
  }

  Future<Map<String, Object?>?> pickBackup() async {
    final text = await _files.openText();
    return text == null ? null : decodeBackup(text);
  }

  static BackupSummary summary(Map<String, Object?> backup) => BackupSummary(
        createdAt: DateTime.parse(backup['exportedAtUtc']! as String),
        rowCount: _rowCount(backup),
        appVersion: backup['appVersion']! as String,
      );

  Future<Map<String, Object?>> createBackup() async {
    final database = await _database.db;
    final tables = <String, Object?>{};
    for (final table in _tables) {
      tables[table] = await database.query(table, orderBy: 'rowid ASC');
    }
    tables['custom_food_items'] = await database.query(
      'food_items', where: 'is_custom = 1', orderBy: 'id ASC');
    tables['custom_exercises'] = await database.query(
      'exercises', where: 'is_custom = 1', orderBy: 'id ASC');
    final payload = <String, Object?>{'tables': tables};
    final payloadText = jsonEncode(payload);
    return {
      'formatVersion': formatVersion,
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'payloadSha256': _checksum(payloadText),
      'payload': payload,
    };
  }

  static String encodeBackup(Map<String, Object?> backup) {
    final payloadText = jsonEncode(backup['payload']);
    return jsonEncode({
      'formatVersion': backup['formatVersion'],
      'schemaVersion': backup['schemaVersion'],
      'appVersion': backup['appVersion'],
      'exportedAtUtc': backup['exportedAtUtc'],
      'payloadSha256': _checksum(payloadText),
      'payload': payloadText,
    });
  }

  static Map<String, Object?> decodeBackup(String text) {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const BackupValidationException(
          BackupFailureCode.notFitX, 'This is not a FitX backup file.');
    }
    if (decoded is! Map) {
      throw const BackupValidationException(
          BackupFailureCode.notFitX, 'This is not a FitX backup file.');
    }
    final envelope = Map<String, Object?>.from(decoded);
    if (envelope['formatVersion'] != formatVersion) {
      throw const BackupValidationException(BackupFailureCode.unsupportedFormat,
          'This FitX backup format is not supported by this app version.');
    }
    final backupSchema = envelope['schemaVersion'];
    if (backupSchema is! int) {
      throw const BackupValidationException(
          BackupFailureCode.malformed, 'The backup schema version is missing.');
    }
    if (backupSchema > schemaVersion) {
      throw BackupValidationException(BackupFailureCode.newerSchema,
          'This backup was created by a newer FitX version (${envelope['appVersion'] ?? 'unknown'}). Update FitX before restoring it.');
    }
    if (backupSchema < schemaVersion) {
      throw const BackupValidationException(BackupFailureCode.unsupportedFormat,
          'This older FitX backup cannot be migrated by this app version.');
    }
    final payloadText = envelope['payload'];
    final expectedChecksum = envelope['payloadSha256'];
    if (payloadText is! String || expectedChecksum is! String ||
        _checksum(payloadText) != expectedChecksum) {
      throw const BackupValidationException(BackupFailureCode.corrupt,
          'The backup is incomplete or has been changed.');
    }
    Object? payloadValue;
    try {
      payloadValue = jsonDecode(payloadText);
    } on FormatException {
      throw const BackupValidationException(
          BackupFailureCode.malformed, 'The backup contents are malformed.');
    }
    if (payloadValue is! Map ||
        DateTime.tryParse(envelope['exportedAtUtc'] as String? ?? '') == null ||
        envelope['appVersion'] is! String) {
      throw const BackupValidationException(
          BackupFailureCode.malformed, 'The FitX backup is incomplete.');
    }
    final payload = Map<String, Object?>.from(payloadValue);
    _validateTables(payload);
    return {...envelope, 'payload': payload};
  }

  Future<void> restoreBackup(Map<String, Object?> backup) async {
    final payload = Map<String, Object?>.from(backup['payload']! as Map);
    _validateTables(payload);
    final rawTables = Map<String, Object?>.from(payload['tables']! as Map);
    final database = await _database.db;
    await database.transaction((txn) async {
      await _clearPersonalData(txn);
      for (final table in _tables) {
        await _insertRows(txn, table, rawTables[table]);
      }
      await _insertRows(txn, 'food_items', rawTables['custom_food_items']);
      await _insertRows(txn, 'exercises', rawTables['custom_exercises']);
    });
  }

  Future<void> deleteAllPersonalData() async {
    final database = await _database.db;
    await database.transaction(_clearPersonalData);
  }

  static void _validateTables(Map<String, Object?> payload) {
    final rawTables = payload['tables'];
    if (rawTables is! Map) {
      throw const BackupValidationException(
          BackupFailureCode.malformed, 'The backup tables are missing.');
    }
    final tables = Map<String, Object?>.from(rawTables);
    for (final name in [..._tables, 'custom_food_items', 'custom_exercises']) {
      final rows = tables[name];
      if (rows is! List || rows.any((row) => row is! Map)) {
        throw BackupValidationException(BackupFailureCode.malformed,
            'The $name backup records are malformed.');
      }
    }
  }

  static Future<void> _insertRows(Transaction txn, String table, Object? rawRows) async {
    for (final rawRow in rawRows! as List) {
      await txn.insert(table, Map<String, Object?>.from(rawRow as Map),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> _clearPersonalData(Transaction txn) async {
    for (final table in const <String>[
      'exercise_sets', 'workout_log_exercises', 'workout_logs', 'meal_entries',
      'water_entries', 'caffeine_entries', 'personal_records', 'health_scores',
      'hrv_baseline', 'rhr_baseline', 'daily_health_snapshots', 'journal_entries',
      'journal_correlations', 'journal_definitions', 'sync_state', 'data_sources',
      'app_preferences', 'phone_sleep_sessions', 'user_profile', 'favorite_foods',
      'saved_meals',
    ]) {
      await txn.delete(table);
    }
    await txn.delete('food_items', where: 'is_custom = 1');
    await txn.delete('exercises', where: 'is_custom = 1');
  }

  static int _rowCount(Map<String, Object?> backup) {
    final payload = Map<Object?, Object?>.from(backup['payload']! as Map);
    final tables = Map<Object?, Object?>.from(payload['tables']! as Map);
    return tables.values.fold<int>(
        0, (total, rows) => total + (rows is List ? rows.length : 0));
  }

  static String _checksum(String payloadText) =>
      sha256.convert(utf8.encode(payloadText)).toString();
}
