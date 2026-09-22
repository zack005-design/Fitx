import 'package:fitx/core/models/app_preferences.dart';
import 'package:fitx/core/models/sync_state.dart';
import 'package:fitx/core/models/user_profile.dart';
import 'package:fitx/core/repositories/health_repository.dart';
import 'package:fitx/core/services/database_service.dart';
import 'package:fitx/core/services/health_connect_service.dart';
import 'package:fitx/core/services/health_sync_service.dart';
import 'package:fitx/features/onboarding/onboarding_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/health_fixture.dart';

class _HealthSource implements HealthConnectService {
  bool available = true;
  bool permitted = true;
  @override
  Future<bool> checkAvailability() async => available;
  @override
  Future<bool> checkPermissions() async => permitted;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SyncStore implements DatabaseService {
  HealthSyncState state = const HealthSyncState();
  String? sourceStatus;
  @override
  Future<HealthSyncState> getSyncState() async => state;
  @override
  Future<void> saveSyncState(HealthSyncState value) async => state = value;
  @override
  Future<void> updateHealthConnectSource(
      {required String status, DateTime? lastSeenAt}) async {
    sourceStatus = status;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository implements HealthRepository {
  final reads = <DateTime>[];
  DateTime? failingDay;
  @override
  Future<DailyHealthSummary> getDailySummary(
      DateTime date, UserProfile? profile,
      {bool refresh = false}) async {
    final day = DateTime(date.year, date.month, date.day);
    reads.add(day);
    final summary = healthFixture(date: day);
    return day == failingDay ? summary.withReadErrors(['SLEEP']) : summary;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('resumable onboarding', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('persists the current step and draft choices across store instances',
        () async {
      final first = SharedPreferencesOnboardingStore();
      await first.save(const OnboardingProgress(
          step: 3,
          name: 'Sam',
          age: 35,
          heightCm: 172,
          weightKg: 68,
          sleepGoalMinutes: 510,
          morningReminder: true));
      final restored = await SharedPreferencesOnboardingStore().load();
      expect(restored.step, 3);
      expect(restored.name, 'Sam');
      expect(restored.sleepGoalMinutes, 510);
      expect(restored.morningReminder, isTrue);
    });

    test('completion is durable and clears only transient navigation state',
        () async {
      final store = SharedPreferencesOnboardingStore();
      await store.save(const OnboardingProgress(step: 4, name: 'Sam'));
      await store.complete();
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool(SharedPreferencesOnboardingStore.completeKey),
          isTrue);
      expect((await store.load()).step, 0);
      expect((await store.load()).name, 'Sam');
    });
  });

  group('incremental Health Connect sync', () {
    final today = DateTime(2026, 9, 14, 10);
    late _HealthSource source;
    late _SyncStore store;
    late _Repository repository;
    late HealthSyncService sync;
    setUp(() {
      source = _HealthSource();
      store = _SyncStore();
      repository = _Repository();
      sync = HealthSyncService(
          healthConnect: source,
          repository: repository,
          database: store,
          clock: () => today);
    });

    test('permission revocation is explicit and performs no destructive reads',
        () async {
      source.permitted = false;
      final result = await sync.sync(null);
      expect(result.phase, SyncPhase.permissionRequired);
      expect(store.sourceStatus, 'permission_required');
      expect(repository.reads, isEmpty);
    });

    test('first run is bounded and retry overlaps one day idempotently',
        () async {
      final first = await sync.sync(null, initialDays: 3);
      expect(first.phase, SyncPhase.success);
      expect(first.checkpoint, DateTime(2026, 9, 14));
      expect(repository.reads, hasLength(3));
      repository.reads.clear();
      final second = await sync.sync(null, initialDays: 3);
      expect(second.phase, SyncPhase.success);
      expect(repository.reads, [DateTime(2026, 9, 13), DateTime(2026, 9, 14)]);
    });

    test('failed category preserves the last clean checkpoint for retry',
        () async {
      repository.failingDay = DateTime(2026, 9, 13);
      final result = await sync.sync(null, initialDays: 3);
      expect(result.phase, SyncPhase.error);
      expect(result.checkpoint, DateTime(2026, 9, 12));
      expect(result.message, contains('Saved history was kept'));
      expect(store.sourceStatus, 'error');
    });
  });

  test('phase 5 migration preserves rows and stores sync/settings state',
      () async {
    sqfliteFfiInit();
    final database =
        await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(database.close);
    await database.execute(
        'CREATE TABLE meal_entries (id TEXT PRIMARY KEY, calories REAL)');
    await database.insert('meal_entries', {'id': 'kept', 'calories': 420.0});
    await DatabaseService.migrateVersion6(database);
    final store = DatabaseService.forDatabase(database);
    await store.saveSyncState(HealthSyncState(
        phase: SyncPhase.success,
        checkpoint: DateTime(2026, 9, 14),
        lastSuccessfulSync: DateTime(2026, 9, 14, 10)));
    await store.saveAppPreferences(const AppPreferences(
        useMetric: false,
        baselineWindowDays: 60,
        sourcePriority: 'Health Connect aggregate'));
    expect((await database.query('meal_entries')).single['id'], 'kept');
    expect((await store.getSyncState()).phase, SyncPhase.success);
    expect((await store.getAppPreferences()).baselineWindowDays, 60);
  });
}
