import 'dart:convert';
import '../models/daily_health_summary.dart';
import '../models/health_snapshot_codec.dart';
import '../models/health_day.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/nutrition_models.dart';
import '../models/workout_models.dart';
import '../models/user_profile.dart';
import '../models/health_score.dart';
import '../models/journal_models.dart';
import '../models/app_preferences.dart';
import '../models/sync_state.dart';
import '../models/sleep_data.dart';
import '../models/sleep_tracking.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal() : _provided = null;
  DatabaseService.forDatabase(Database database) : _provided = database;
  final Database? _provided;

  static Database? _db;
  static Future<Database>? _openingDb;

  Future<Database> get db async {
    if (_provided != null) return _provided;
    if (_db != null) return _db!;
    _openingDb ??= _initDb();
    _db = await _openingDb!;
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fitx.db');
    return openDatabase(
      path,
      version: 9,
      onCreate: createSchema,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        gender INTEGER NOT NULL,
        height_cm REAL NOT NULL,
        weight_kg REAL NOT NULL,
        use_metric INTEGER NOT NULL DEFAULT 1,
        daily_step_goal INTEGER NOT NULL DEFAULT 8000,
        daily_calorie_goal REAL NOT NULL DEFAULT 2000,
        daily_protein_goal REAL NOT NULL DEFAULT 120,
        sleep_goal_minutes INTEGER NOT NULL DEFAULT 480,
        daily_water_goal INTEGER NOT NULL DEFAULT 2500,
        strain_target REAL NOT NULL DEFAULT 14
      )
    ''');

    await db.execute('''
      CREATE TABLE health_scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        score_type TEXT NOT NULL,
        value REAL NOT NULL,
        level INTEGER NOT NULL,
        breakdown TEXT NOT NULL DEFAULT '',
        formula_version INTEGER NOT NULL DEFAULT 1,
        UNIQUE(date, score_type)
      )
    ''');

    await db.execute('''
      CREATE TABLE meal_entries (
        id TEXT PRIMARY KEY,
        food_item_id TEXT NOT NULL,
        food_name TEXT NOT NULL,
        amount_grams REAL NOT NULL,
        meal_type INTEGER NOT NULL,
        logged_at TEXT NOT NULL,
        calories REAL NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fat REAL NOT NULL,
        fiber REAL,
        sugar REAL,
        sodium REAL,
        saturated_fat REAL,
        cholesterol REAL,
        potassium REAL,
        calcium REAL,
        iron REAL,
        magnesium REAL,
        phosphorus REAL,
        zinc REAL,
        vitamin_a REAL,
        vitamin_c REAL,
        folate REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE water_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        amount_ml REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE food_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        brand TEXT,
        barcode TEXT,
        calories_per100 REAL NOT NULL,
        protein_per100 REAL NOT NULL,
        carbs_per100 REAL NOT NULL,
        fat_per100 REAL NOT NULL,
        fiber_per100 REAL,
        sugar_per100 REAL,
        sodium_per100 REAL,
        saturated_fat_per100 REAL,
        cholesterol_per100 REAL,
        potassium_per100 REAL,
        calcium_per100 REAL,
        iron_per100 REAL,
        magnesium_per100 REAL,
        phosphorus_per100 REAL,
        zinc_per100 REAL,
        vitamin_a_per100 REAL,
        vitamin_c_per100 REAL,
        folate_per100 REAL,
        states TEXT,
        category TEXT,
        aliases TEXT,
        serving_name TEXT,
        serving_grams REAL,
        is_vegetarian INTEGER,
        source TEXT,
        source_code TEXT,
        data_quality TEXT,
        is_custom INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        primary_muscle INTEGER NOT NULL,
        secondary_muscles TEXT NOT NULL DEFAULT '',
        is_custom INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_logs (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        started_at TEXT NOT NULL,
        finished_at TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_log_exercises (
        id TEXT PRIMARY KEY,
        workout_log_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        FOREIGN KEY(workout_log_id) REFERENCES workout_logs(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE exercise_sets (
        id TEXT PRIMARY KEY,
        log_exercise_id TEXT NOT NULL,
        set_number INTEGER NOT NULL,
        weight_kg REAL,
        reps INTEGER,
        duration_seconds INTEGER,
        is_warmup INTEGER NOT NULL DEFAULT 0,
        is_completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(log_exercise_id) REFERENCES workout_log_exercises(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE personal_records (
        exercise_id TEXT PRIMARY KEY,
        exercise_name TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        reps INTEGER NOT NULL,
        achieved_at TEXT NOT NULL
      )
    ''');

    await createPhase3Tables(db);

    await db.execute('''
      CREATE TABLE hrv_baseline (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        hrv_value REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE rhr_baseline (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        rhr_value REAL NOT NULL
      )
    ''');

    await createPhase4Tables(db);
    await createHealthSnapshotTable(db);
    await createPhase5Tables(db);
    await createPhoneSleepTables(db);
    await createQuickLoggingTables(db);
  }

  /// Every migration is additive. Existing health, nutrition, workout, and
  /// journal rows are intentionally left untouched.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await createPhase4Tables(db);
    if (oldVersion < 3) await migrateVersion3(db);
    if (oldVersion < 4) await migrateVersion4(db);
    if (oldVersion < 5) await migrateVersion5(db);
    if (oldVersion < 6) await migrateVersion6(db);
    if (oldVersion < 7) await createPhoneSleepTables(db);
    if (oldVersion < 8) await migrateVersion8(db);
    if (oldVersion < 9) await createQuickLoggingTables(db);
  }

  static Future<void> createQuickLoggingTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS favorite_foods (
      food_item_id TEXT PRIMARY KEY,
      added_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS saved_meals (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      entries_json TEXT NOT NULL,
      created_at TEXT NOT NULL
    )''');
  }

  /// Adds regional catalog metadata and micronutrients without changing logs.
  static Future<void> migrateVersion8(DatabaseExecutor db) async {
    const foodColumns = <String, String>{
      'saturated_fat_per100': 'REAL',
      'cholesterol_per100': 'REAL',
      'potassium_per100': 'REAL',
      'calcium_per100': 'REAL',
      'iron_per100': 'REAL',
      'magnesium_per100': 'REAL',
      'phosphorus_per100': 'REAL',
      'zinc_per100': 'REAL',
      'vitamin_a_per100': 'REAL',
      'vitamin_c_per100': 'REAL',
      'folate_per100': 'REAL',
      'states': 'TEXT',
      'category': 'TEXT',
      'aliases': 'TEXT',
      'serving_name': 'TEXT',
      'serving_grams': 'REAL',
      'is_vegetarian': 'INTEGER',
      'source': 'TEXT',
      'source_code': 'TEXT',
      'data_quality': 'TEXT',
    };
    const mealColumns = <String, String>{
      'saturated_fat': 'REAL',
      'cholesterol': 'REAL',
      'potassium': 'REAL',
      'calcium': 'REAL',
      'iron': 'REAL',
      'magnesium': 'REAL',
      'phosphorus': 'REAL',
      'zinc': 'REAL',
      'vitamin_a': 'REAL',
      'vitamin_c': 'REAL',
      'folate': 'REAL',
    };
    for (final column in foodColumns.entries) {
      await db.execute(
          'ALTER TABLE food_items ADD COLUMN ${column.key} ${column.value}');
    }
    for (final column in mealColumns.entries) {
      await db.execute(
          'ALTER TABLE meal_entries ADD COLUMN ${column.key} ${column.value}');
    }
    await db.execute('''CREATE INDEX IF NOT EXISTS food_items_region_index
      ON food_items(states, category)''');
  }

  static Future<void> migrateVersion3(DatabaseExecutor db) async {
    await createHealthSnapshotTable(db);
    await db.execute(
        'ALTER TABLE health_scores ADD COLUMN formula_version INTEGER NOT NULL DEFAULT 1');
  }

  /// Additive v3 migration; legacy scores and all user logs remain intact.
  static Future<void> createHealthSnapshotTable(DatabaseExecutor db) =>
      db.execute('''CREATE TABLE IF NOT EXISTS daily_health_snapshots (
    date TEXT PRIMARY KEY, synced_at TEXT, formula_version INTEGER NOT NULL, payload TEXT NOT NULL
  )''');

  /// Additive Phase 3 storage. Existing meals, water and workout rows remain
  /// untouched; the indexes only make recovery and date reads deterministic.
  static Future<void> migrateVersion4(DatabaseExecutor db) async {
    await createPhase3Tables(db);
  }

  static Future<void> createPhase3Tables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS caffeine_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      amount_mg REAL NOT NULL,
      logged_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE INDEX IF NOT EXISTS water_entries_date_index
      ON water_entries(date)''');
    await db.execute('''CREATE INDEX IF NOT EXISTS caffeine_entries_date_index
      ON caffeine_entries(date)''');
    await db.execute('''CREATE INDEX IF NOT EXISTS workout_logs_started_index
      ON workout_logs(started_at)''');
    await db
        .execute('''CREATE INDEX IF NOT EXISTS workout_log_exercises_log_index
      ON workout_log_exercises(workout_log_id, order_index)''');
    await db.execute('''CREATE INDEX IF NOT EXISTS exercise_sets_exercise_index
      ON exercise_sets(log_exercise_id, set_number)''');
  }

  /// Additive Phase 4 storage. The correlation table is a transparent cache;
  /// source observations remain in journal entries and recorded health data.
  static Future<void> migrateVersion5(DatabaseExecutor db) async {
    await createPhase4Tables(db);
  }

  static Future<void> migrateVersion6(DatabaseExecutor db) =>
      createPhase5Tables(db);

  static Future<void> createPhase5Tables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS sync_state (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      phase TEXT NOT NULL,
      last_successful_sync TEXT,
      checkpoint TEXT,
      last_attempt TEXT,
      message TEXT
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS data_sources (
      id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      last_seen_at TEXT,
      status TEXT NOT NULL DEFAULT 'unknown'
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS app_preferences (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      use_metric INTEGER NOT NULL DEFAULT 1,
      baseline_window_days INTEGER NOT NULL DEFAULT 30,
      source_priority TEXT NOT NULL DEFAULT 'Health Connect aggregate'
    )''');
    await db.insert(
      'data_sources',
      {
        'id': 'health_connect',
        'display_name': 'Health Connect',
        'enabled': 1,
        'status': 'unknown',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static Future<void> createPhoneSleepTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS phone_sleep_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sleep_date TEXT NOT NULL,
      started_at TEXT NOT NULL,
      ended_at TEXT NOT NULL,
      confidence REAL NOT NULL,
      coverage REAL NOT NULL,
      algorithm_version INTEGER NOT NULL,
      sleep_payload TEXT NOT NULL,
      epochs_payload TEXT NOT NULL,
      UNIQUE(started_at, ended_at)
    )''');
    await db.execute('''CREATE INDEX IF NOT EXISTS phone_sleep_date_index
      ON phone_sleep_sessions(sleep_date, ended_at DESC)''');
  }

  Future<void> savePhoneSleepEstimate(PhoneSleepEstimate estimate,
      {required int algorithmVersion,
      List<SleepSensorEpoch> epochs = const []}) async {
    final sleep = estimate.sleep;
    await (await db).insert(
      'phone_sleep_sessions',
      {
        'sleep_date': healthDayKey(sleep.date),
        'started_at': sleep.bedtime!.toIso8601String(),
        'ended_at': sleep.wakeTime!.toIso8601String(),
        'confidence': estimate.confidence,
        'coverage': estimate.coverage,
        'algorithm_version': algorithmVersion,
        'sleep_payload': jsonEncode(_encodePhoneSleep(sleep)),
        'epochs_payload': jsonEncode(epochs.map((e) => e.toMap()).toList()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await (await db).delete('daily_health_snapshots',
        where: 'date = ?', whereArgs: [healthDayKey(sleep.date)]);
  }

  Future<SleepData?> getPhoneSleep(DateTime date) async {
    final rows = await (await db).query('phone_sleep_sessions',
        where: 'sleep_date = ?',
        whereArgs: [healthDayKey(date)],
        orderBy: 'ended_at DESC',
        limit: 1);
    if (rows.isEmpty) return null;
    return _decodePhoneSleep(
        jsonDecode(rows.single['sleep_payload'] as String));
  }

  static Map<String, Object?> _encodePhoneSleep(SleepData sleep) => {
        'date': sleep.date.toIso8601String(),
        'bedtime': sleep.bedtime?.toIso8601String(),
        'wakeTime': sleep.wakeTime?.toIso8601String(),
        'total': sleep.totalSleep.inSeconds,
        'light': sleep.lightDuration.inSeconds,
        'awake': sleep.awakeDuration.inSeconds,
        'efficiency': sleep.efficiency,
        'wakeCount': sleep.wakeCount,
        'confidence': sleep.confidence,
        'limitations': sleep.limitations,
        'stages': [
          for (final stage in sleep.stages)
            {
              'start': stage.start.toIso8601String(),
              'end': stage.end.toIso8601String(),
              'stage': stage.stage.index,
            }
        ],
      };

  static SleepData _decodePhoneSleep(Map<String, dynamic> map) => SleepData(
        date: DateTime.parse(map['date'] as String),
        bedtime: DateTime.tryParse(map['bedtime'] as String? ?? ''),
        wakeTime: DateTime.tryParse(map['wakeTime'] as String? ?? ''),
        totalSleep: Duration(seconds: (map['total'] as num).toInt()),
        remDuration: Duration.zero,
        deepDuration: Duration.zero,
        lightDuration: Duration(seconds: (map['light'] as num).toInt()),
        awakeDuration: Duration(seconds: (map['awake'] as num).toInt()),
        efficiency: (map['efficiency'] as num).toDouble(),
        wakeCount: (map['wakeCount'] as num).toInt(),
        source: SleepDataSource.phoneSensors,
        confidence: (map['confidence'] as num?)?.toDouble(),
        limitations: List<String>.from(map['limitations'] ?? const []),
        stages: [
          for (final stage in map['stages'] as List<dynamic>? ?? const [])
            SleepStageSegment(
              start: DateTime.parse(stage['start'] as String),
              end: DateTime.parse(stage['end'] as String),
              stage: SleepStage.values[(stage['stage'] as num).toInt()],
            ),
        ],
      );

  Future<HealthSyncState> getSyncState() async {
    final rows = await (await db).query('sync_state', where: 'id = 1');
    return rows.isEmpty
        ? const HealthSyncState()
        : HealthSyncState.fromMap(rows.single);
  }

  Future<void> saveSyncState(HealthSyncState state) async {
    await (await db).insert('sync_state', state.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<AppPreferences> getAppPreferences() async {
    final rows = await (await db).query('app_preferences', where: 'id = 1');
    return rows.isEmpty
        ? const AppPreferences()
        : AppPreferences.fromMap(rows.single);
  }

  Future<void> saveAppPreferences(AppPreferences preferences) async {
    await (await db).insert('app_preferences', preferences.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateHealthConnectSource({
    required String status,
    DateTime? lastSeenAt,
  }) async {
    await (await db).insert(
      'data_sources',
      {
        'id': 'health_connect',
        'display_name': 'Health Connect',
        'enabled': 1,
        'last_seen_at': lastSeenAt?.toIso8601String(),
        'status': status,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveHealthSnapshot(DailyHealthSummary summary) async {
    final d = await db;
    await d.insert(
        'daily_health_snapshots',
        {
          'date': healthDayKey(summary.date),
          'synced_at': summary.syncedAt?.toIso8601String(),
          'formula_version': summary.formulaVersion,
          'payload': jsonEncode(HealthSnapshotCodec.encode(summary)),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DailyHealthSummary?> getHealthSnapshot(DateTime date) async {
    final d = await db;
    final rows = await d.query('daily_health_snapshots',
        where: 'date = ?', whereArgs: [healthDayKey(date)]);
    return rows.isEmpty
        ? null
        : HealthSnapshotCodec.decode(
            jsonDecode(rows.first['payload'] as String));
  }

  Future<List<DailyHealthSummary>> getHealthSnapshots(DateTime end,
      {int days = 30}) async {
    final d = await db;
    final rows = await d.query('daily_health_snapshots',
        where: 'date >= ? AND date <= ?',
        whereArgs: [
          healthDayKey(shiftHealthDay(end, 1 - days)),
          healthDayKey(end)
        ],
        orderBy: 'date ASC');
    return rows
        .map((r) =>
            HealthSnapshotCodec.decode(jsonDecode(r['payload'] as String)))
        .toList();
  }

  /// Paired observations in the preceding 30 local days; never include future
  /// readings or the day currently being explained.
  Future<({double? hrv, double? rhr, int days})> getPersonalBaseline(
      DateTime date) async {
    final d = await db;
    var windowDays = 30;
    try {
      final preferences =
          await d.query('app_preferences', where: 'id = 1', limit: 1);
      if (preferences.isNotEmpty) {
        windowDays =
            preferences.single['baseline_window_days'] as int? ?? windowDays;
      }
    } on DatabaseException {
      // Older test/restore databases may not have completed the additive v6
      // migration yet. The established 30-day window remains safe.
    }
    final rows = await d.rawQuery('''
      SELECT AVG(h.hrv_value) AS hrv, AVG(r.rhr_value) AS rhr, COUNT(*) AS days
      FROM (SELECT date, AVG(hrv_value) AS hrv_value FROM hrv_baseline GROUP BY date) h
      JOIN (SELECT date, AVG(rhr_value) AS rhr_value FROM rhr_baseline GROUP BY date) r ON h.date = r.date
      WHERE h.date >= ? AND h.date < ?
    ''', [healthDayKey(shiftHealthDay(date, -windowDays)), healthDayKey(date)]);
    final row = rows.first;
    return (
      hrv: (row['hrv'] as num?)?.toDouble(),
      rhr: (row['rhr'] as num?)?.toDouble(),
      days: (row['days'] as num).toInt()
    );
  }

  static Future<void> createPhase4Tables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal_definitions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        section INTEGER NOT NULL,
        entry_type INTEGER NOT NULL,
        unit TEXT,
        minimum_value REAL,
        maximum_value REAL,
        sort_order INTEGER NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal_entries (
        id TEXT PRIMARY KEY,
        definition_id TEXT NOT NULL,
        entry_date TEXT NOT NULL,
        choice_value INTEGER,
        number_value REAL,
        time_minutes INTEGER,
        text_value TEXT,
        note TEXT,
        source INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(definition_id, entry_date),
        FOREIGN KEY(definition_id) REFERENCES journal_definitions(id)
          ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS journal_entries_date_index
      ON journal_entries(entry_date)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal_correlations (
        definition_id TEXT NOT NULL,
        metric TEXT NOT NULL,
        positive_count INTEGER NOT NULL,
        negative_count INTEGER NOT NULL,
        average_with_factor REAL,
        average_without_factor REAL,
        window_start TEXT NOT NULL,
        window_end TEXT NOT NULL,
        computed_at TEXT NOT NULL,
        PRIMARY KEY(definition_id, metric),
        FOREIGN KEY(definition_id) REFERENCES journal_definitions(id)
          ON DELETE CASCADE
      )
    ''');
  }

  // ── USER PROFILE ──────────────────────────────────────────────────────

  Future<UserProfile?> getProfile() async {
    final d = await db;
    final rows = await d.query('user_profile', limit: 1);
    if (rows.isEmpty) return null;
    return UserProfile.fromMap(rows.first);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final d = await db;
    final rows = await d.query('user_profile', limit: 1);
    if (rows.isEmpty) {
      await d.insert('user_profile', {'id': 1, ...profile.toMap()});
    } else {
      await d.update('user_profile', profile.toMap(), where: 'id = 1');
    }
  }

  // ── HEALTH SCORES ──────────────────────────────────────────────────────

  Future<void> saveScore(String type, HealthScore score) async {
    final d = await db;
    final map = score.toMap();
    map['date'] = score.date.toIso8601String().substring(0, 10);
    map['score_type'] = type;
    map['formula_version'] = 2;
    await d.insert(
      'health_scores',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<HealthScore>> getScoreHistory(String type,
      {int days = 30}) async {
    final d = await db;
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await d.query(
      'health_scores',
      where: 'score_type = ? AND date >= ?',
      whereArgs: [type, since.toIso8601String().substring(0, 10)],
      orderBy: 'date ASC',
    );
    return rows.map(HealthScore.fromMap).toList();
  }

  Future<HealthScore?> getScoreForDate(String type, DateTime date) async {
    final d = await db;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await d.query(
      'health_scores',
      where: 'score_type = ? AND date = ?',
      whereArgs: [type, dateStr],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return HealthScore.fromMap(rows.first);
  }

  // ── NUTRITION ─────────────────────────────────────────────────────────

  Future<void> insertMealEntry(MealEntry entry) async {
    final d = await db;
    await d.insert('meal_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateMealEntry(MealEntry entry) async {
    final d = await db;
    await d.update('meal_entries', entry.toMap(),
        where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<void> deleteMealEntry(String id) async {
    final d = await db;
    await d.delete('meal_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MealEntry>> getMealEntriesForDate(DateTime date) async {
    final d = await db;
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day)
        .add(const Duration(days: 1))
        .toIso8601String();
    final rows = await d.query(
      'meal_entries',
      where: 'logged_at >= ? AND logged_at < ?',
      whereArgs: [start, end],
      orderBy: 'logged_at ASC',
    );
    return rows.map(MealEntry.fromMap).toList();
  }

  Future<void> addWater(DateTime date, double ml) async {
    final d = await db;
    await d.insert('water_entries', {
      'date': date.toIso8601String().substring(0, 10),
      'amount_ml': ml,
    });
  }

  Future<double> getWaterForDate(DateTime date) async {
    final d = await db;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await d.rawQuery(
      'SELECT SUM(amount_ml) as total FROM water_entries WHERE date = ?',
      [dateStr],
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> addCaffeine(DateTime date, double mg) async {
    final d = await db;
    await d.insert('caffeine_entries', {
      'date': date.toIso8601String().substring(0, 10),
      'amount_mg': mg,
      'logged_at': date.toIso8601String(),
    });
  }

  Future<double> getCaffeineForDate(DateTime date) async {
    final d = await db;
    final rows = await d.rawQuery(
      'SELECT SUM(amount_mg) as total FROM caffeine_entries WHERE date = ?',
      [date.toIso8601String().substring(0, 10)],
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }

  // ── FOOD DATABASE ─────────────────────────────────────────────────────

  Future<List<FoodItem>> searchFoods(String query) async {
    final d = await db;
    final rows = await d.query(
      'food_items',
      where: '''name LIKE ? OR brand LIKE ? OR aliases LIKE ?
          OR states LIKE ? OR category LIKE ?''',
      whereArgs: List.filled(5, '%$query%'),
      orderBy: 'name COLLATE NOCASE ASC',
      limit: 50,
    );
    return rows.map(FoodItem.fromMap).toList();
  }

  Future<FoodItem?> getFoodByBarcode(String barcode) async {
    final d = await db;
    final rows = await d.query(
      'food_items',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FoodItem.fromMap(rows.first);
  }

  Future<void> insertFoodItem(FoodItem item) async {
    final d = await db;
    await d.insert('food_items', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<FoodItem>> getFavoriteFoods() async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT f.* FROM favorite_foods favorite
      JOIN food_items f ON f.id = favorite.food_item_id
      ORDER BY favorite.added_at DESC
    ''');
    return rows.map(FoodItem.fromMap).toList();
  }

  Future<void> setFoodFavorite(String foodItemId, bool favorite) async {
    final d = await db;
    if (favorite) {
      await d.insert(
          'favorite_foods',
          {
            'food_item_id': foodItemId,
            'added_at': DateTime.now().toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await d.delete('favorite_foods',
          where: 'food_item_id = ?', whereArgs: [foodItemId]);
    }
  }

  Future<void> saveMealPreset(SavedMeal meal) async {
    final d = await db;
    await d.insert(
      'saved_meals',
      {
        'id': meal.id,
        'name': meal.name,
        'entries_json':
            jsonEncode(meal.entries.map((entry) => entry.toMap()).toList()),
        'created_at': meal.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SavedMeal>> getSavedMeals() async {
    final rows = await (await db)
        .query('saved_meals', orderBy: 'created_at DESC', limit: 20);
    return rows
        .map((row) => SavedMeal(
              id: row['id'] as String,
              name: row['name'] as String,
              entries: (jsonDecode(row['entries_json'] as String) as List)
                  .map((item) => MealEntry.fromMap(
                      Map<String, dynamic>.from(item as Map)))
                  .toList(),
              createdAt: DateTime.parse(row['created_at'] as String),
            ))
        .toList();
  }

  Future<void> deleteSavedMeal(String id) async {
    await (await db)
        .delete('saved_meals', where: 'id = ?', whereArgs: [id]);
  }

  // ── WORKOUTS ──────────────────────────────────────────────────────────

  Future<void> insertWorkoutLog(WorkoutLog log) async {
    final d = await db;
    await d.insert('workout_logs', log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateWorkoutLog(WorkoutLog log) async {
    final d = await db;
    await d.update('workout_logs', log.toMap(),
        where: 'id = ?', whereArgs: [log.id]);
  }

  Future<List<WorkoutLog>> getWorkoutLogs({int limit = 20}) async {
    final d = await db;
    final rows = await d.query('workout_logs',
        where: 'finished_at IS NOT NULL',
        orderBy: 'started_at DESC',
        limit: limit);
    return Future.wait(rows.map((row) => _hydrateWorkout(d, row)));
  }

  Future<WorkoutLog?> getActiveWorkout() async {
    final d = await db;
    final rows = await d.query('workout_logs',
        where: 'finished_at IS NULL', orderBy: 'started_at DESC', limit: 1);
    return rows.isEmpty ? null : _hydrateWorkout(d, rows.first);
  }

  Future<List<WorkoutLog>> getWorkoutLogsForDate(DateTime date) async {
    final d = await db;
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day + 1).toIso8601String();
    final rows = await d.query('workout_logs',
        where: 'started_at >= ? AND started_at < ? AND finished_at IS NOT NULL',
        whereArgs: [start, end],
        orderBy: 'started_at ASC');
    return Future.wait(rows.map((row) => _hydrateWorkout(d, row)));
  }

  Future<WorkoutLog> _hydrateWorkout(
      DatabaseExecutor d, Map<String, Object?> row) async {
    final log = WorkoutLog.fromMap(row);
    final exerciseRows = await d.rawQuery('''
      SELECT wle.id, wle.workout_log_id, wle.order_index,
             e.id AS exercise_id, e.name, e.primary_muscle,
             e.secondary_muscles, e.is_custom
      FROM workout_log_exercises wle
      JOIN exercises e ON e.id = wle.exercise_id
      WHERE wle.workout_log_id = ? ORDER BY wle.order_index ASC
    ''', [log.id]);
    final exercises = <WorkoutLogExercise>[];
    for (final row in exerciseRows) {
      final setRows = await d.query('exercise_sets',
          where: 'log_exercise_id = ?',
          whereArgs: [row['id']],
          orderBy: 'set_number ASC');
      exercises.add(WorkoutLogExercise(
        id: row['id'] as String,
        workoutLogId: row['workout_log_id'] as String,
        exercise: Exercise.fromMap({
          'id': row['exercise_id'],
          'name': row['name'],
          'primary_muscle': row['primary_muscle'],
          'secondary_muscles': row['secondary_muscles'],
          'is_custom': row['is_custom'],
        }),
        sets: setRows.map(ExerciseSet.fromMap).toList(),
        orderIndex: row['order_index'] as int,
      ));
    }
    return WorkoutLog(
      id: log.id,
      name: log.name,
      startedAt: log.startedAt,
      finishedAt: log.finishedAt,
      exercises: exercises,
      notes: log.notes,
    );
  }

  Future<void> deleteWorkoutLog(String id) async {
    final d = await db;
    await d.transaction((transaction) async {
      final exercises = await transaction.query('workout_log_exercises',
          columns: ['id'], where: 'workout_log_id = ?', whereArgs: [id]);
      for (final exercise in exercises) {
        await transaction.delete('exercise_sets',
            where: 'log_exercise_id = ?', whereArgs: [exercise['id']]);
      }
      await transaction.delete('workout_log_exercises',
          where: 'workout_log_id = ?', whereArgs: [id]);
      await transaction
          .delete('workout_logs', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> insertWorkoutLogExercise(WorkoutLogExercise wle) async {
    final d = await db;
    await d.insert(
        'workout_log_exercises',
        {
          'id': wle.id,
          'workout_log_id': wle.workoutLogId,
          'exercise_id': wle.exercise.id,
          'order_index': wle.orderIndex,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
    for (final set in wle.sets) {
      await d.insert('exercise_sets', set.toMap(wle.id),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> upsertExerciseSet(String logExerciseId, ExerciseSet set) async {
    final d = await db;
    await d.insert('exercise_sets', set.toMap(logExerciseId),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Exercise>> searchExercises(String query) async {
    final d = await db;
    final rows = await d.query(
      'exercises',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      limit: 50,
    );
    return rows.map(Exercise.fromMap).toList();
  }

  Future<void> insertExercise(Exercise ex) async {
    final d = await db;
    await d.insert('exercises', ex.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Exercise>> getExercisesByMuscle(MuscleGroup muscle) async {
    final d = await db;
    final rows = await d.query(
      'exercises',
      where: 'primary_muscle = ?',
      whereArgs: [muscle.index],
    );
    return rows.map(Exercise.fromMap).toList();
  }

  // ── PERSONAL RECORDS ──────────────────────────────────────────────────

  Future<PersonalRecord?> getPersonalRecord(String exerciseId) async {
    final d = await db;
    final rows = await d.query('personal_records',
        where: 'exercise_id = ?', whereArgs: [exerciseId], limit: 1);
    if (rows.isEmpty) return null;
    return PersonalRecord.fromMap(rows.first);
  }

  Future<void> upsertPersonalRecord(PersonalRecord pr) async {
    final d = await db;
    await d.insert('personal_records', pr.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PersonalRecord>> getAllPersonalRecords() async {
    final d = await db;
    final rows = await d.query('personal_records', orderBy: 'achieved_at DESC');
    return rows.map(PersonalRecord.fromMap).toList();
  }

  // ── HRV / RHR BASELINE ────────────────────────────────────────────────

  Future<void> saveHrvReading(DateTime date, double value) async {
    final d = await db;
    final dateStr = date.toIso8601String().substring(0, 10);
    await d.delete('hrv_baseline', where: 'date = ?', whereArgs: [dateStr]);
    await d.insert('hrv_baseline', {
      'date': dateStr,
      'hrv_value': value,
    });
  }

  Future<double?> getHrvBaseline({int days = 30}) async {
    final d = await db;
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await d.rawQuery(
      'SELECT AVG(hrv_value) as avg FROM hrv_baseline WHERE date >= ?',
      [since.toIso8601String().substring(0, 10)],
    );
    return (rows.first['avg'] as num?)?.toDouble();
  }

  /// Number of distinct days contributing to the current HRV baseline.
  Future<int> getHrvBaselineDays({int days = 30}) async {
    final d = await db;
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await d.rawQuery(
      'SELECT COUNT(DISTINCT date) as count FROM hrv_baseline WHERE date >= ?',
      [since.toIso8601String().substring(0, 10)],
    );
    return (rows.first['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> saveRhrReading(DateTime date, double value) async {
    final d = await db;
    final dateStr = date.toIso8601String().substring(0, 10);
    await d.delete('rhr_baseline', where: 'date = ?', whereArgs: [dateStr]);
    await d.insert('rhr_baseline', {
      'date': dateStr,
      'rhr_value': value,
    });
  }

  Future<double?> getRhrBaseline({int days = 30}) async {
    final d = await db;
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await d.rawQuery(
      'SELECT AVG(rhr_value) as avg FROM rhr_baseline WHERE date >= ?',
      [since.toIso8601String().substring(0, 10)],
    );
    return (rows.first['avg'] as num?)?.toDouble();
  }

  /// Number of distinct days contributing to the current resting-HR baseline.
  Future<int> getRhrBaselineDays({int days = 30}) async {
    final d = await db;
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await d.rawQuery(
      'SELECT COUNT(DISTINCT date) as count FROM rhr_baseline WHERE date >= ?',
      [since.toIso8601String().substring(0, 10)],
    );
    return (rows.first['count'] as num?)?.toInt() ?? 0;
  }

  // ── JOURNAL ───────────────────────────────────────────────────────────

  Future<void> upsertJournalDefinitions(
    Iterable<JournalDefinition> definitions,
  ) async {
    final d = await db;
    await d.transaction((transaction) async {
      for (final definition in definitions) {
        await transaction.insert(
          'journal_definitions',
          definition.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<List<JournalDefinition>> getJournalDefinitions() async {
    final d = await db;
    final rows = await d.query(
      'journal_definitions',
      where: 'enabled = 1',
      orderBy: 'section ASC, sort_order ASC',
    );
    return rows.map(JournalDefinition.fromMap).toList(growable: false);
  }

  /// Writes a user-authored entry. Automatic definitions and automatic rows
  /// are guarded here so UI changes cannot turn derived facts into claims.
  Future<void> saveManualJournalEntry(JournalEntry entry) async {
    if (entry.source != JournalEntrySource.manual) {
      throw ArgumentError('Manual journal writes require a manual source.');
    }
    final d = await db;
    final definitions = await d.query(
      'journal_definitions',
      columns: ['section'],
      where: 'id = ?',
      whereArgs: [entry.definitionId],
      limit: 1,
    );
    if (definitions.isEmpty ||
        definitions.single['section'] == JournalSection.automatic.index) {
      throw StateError('Automatic journal entries cannot be edited.');
    }
    final existing = await d.query(
      'journal_entries',
      columns: ['source'],
      where: 'definition_id = ? AND entry_date = ?',
      whereArgs: [entry.definitionId, journalDateKey(entry.date)],
      limit: 1,
    );
    if (existing.isNotEmpty &&
        existing.single['source'] == JournalEntrySource.automatic.index) {
      throw StateError('Automatic journal entries cannot be edited.');
    }
    await d.insert(
      'journal_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Replaces only the derived rows for a day in one transaction. Callers
  /// must provide facts reconstructed from recorded FitX data.
  Future<void> replaceAutomaticJournalEntries(
    DateTime date,
    Iterable<JournalEntry> entries,
  ) async {
    final values = entries.toList(growable: false);
    if (values.any((entry) =>
        entry.source != JournalEntrySource.automatic ||
        journalDateKey(entry.date) != journalDateKey(date))) {
      throw ArgumentError('Invalid automatic journal replacement.');
    }
    final d = await db;
    await d.transaction((transaction) async {
      await transaction.delete(
        'journal_entries',
        where: 'entry_date = ? AND source = ?',
        whereArgs: [journalDateKey(date), JournalEntrySource.automatic.index],
      );
      for (final entry in values) {
        final definitions = await transaction.query(
          'journal_definitions',
          columns: ['section'],
          where: 'id = ?',
          whereArgs: [entry.definitionId],
          limit: 1,
        );
        if (definitions.isEmpty ||
            definitions.single['section'] != JournalSection.automatic.index) {
          throw StateError('Automatic data requires an automatic definition.');
        }
        await transaction.insert('journal_entries', entry.toMap());
      }
    });
  }

  Future<void> deleteJournalEntry(String definitionId, DateTime date) async {
    final d = await db;
    await d.delete(
      'journal_entries',
      where: 'definition_id = ? AND entry_date = ? AND source = ?',
      whereArgs: [
        definitionId,
        journalDateKey(date),
        JournalEntrySource.manual.index,
      ],
    );
  }

  Future<List<JournalEntry>> getJournalEntriesForDate(DateTime date) async {
    final d = await db;
    final rows = await d.query(
      'journal_entries',
      where: 'entry_date = ?',
      whereArgs: [journalDateKey(date)],
      orderBy: 'updated_at ASC',
    );
    return rows.map(JournalEntry.fromMap).toList(growable: false);
  }

  Future<List<JournalEntry>> getJournalEntriesSince(DateTime date) async {
    final d = await db;
    final rows = await d.query(
      'journal_entries',
      where: 'entry_date >= ?',
      whereArgs: [journalDateKey(date)],
      orderBy: 'entry_date DESC, updated_at DESC',
    );
    return rows.map(JournalEntry.fromMap).toList(growable: false);
  }

  Future<List<JournalEntry>> getJournalEntriesBetween(
    DateTime start,
    DateTime end,
  ) async {
    final d = await db;
    final rows = await d.query(
      'journal_entries',
      where: 'entry_date >= ? AND entry_date <= ?',
      whereArgs: [journalDateKey(start), journalDateKey(end)],
      orderBy: 'entry_date ASC, updated_at ASC',
    );
    return rows.map(JournalEntry.fromMap).toList(growable: false);
  }

  Future<void> saveJournalInsights(
    Iterable<JournalInsight> insights, {
    required DateTime windowStart,
    required DateTime windowEnd,
    required DateTime computedAt,
  }) async {
    final d = await db;
    await d.transaction((transaction) async {
      for (final insight in insights) {
        await transaction.insert(
          'journal_correlations',
          {
            'definition_id': insight.definition.id,
            'metric': insight.metric.databaseKey,
            'positive_count': insight.positiveCount,
            'negative_count': insight.negativeCount,
            'average_with_factor': insight.averageWithFactor,
            'average_without_factor': insight.averageWithoutFactor,
            'window_start': journalDateKey(windowStart),
            'window_end': journalDateKey(windowEnd),
            'computed_at': computedAt.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<bool> hasWorkoutForDate(DateTime date) async {
    final d = await db;
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day)
        .add(const Duration(days: 1))
        .toIso8601String();
    final rows = await d.rawQuery(
      'SELECT COUNT(*) AS count FROM workout_logs '
      'WHERE started_at >= ? AND started_at < ? AND finished_at IS NOT NULL',
      [start, end],
    );
    return (rows.first['count'] as num?)?.toInt() != 0;
  }
}
