import 'package:flutter_test/flutter_test.dart';
import 'package:fitx/core/models/activity_data.dart';
import 'package:fitx/core/models/health_score.dart';
import 'package:fitx/core/models/metric_value.dart';
import 'package:fitx/core/models/sleep_data.dart';
import 'package:fitx/core/models/vitals_data.dart';
import 'package:fitx/core/models/user_profile.dart';
import 'package:fitx/core/repositories/health_repository.dart';
import 'package:fitx/core/services/database_service.dart';
import 'package:fitx/core/services/health_connect_service.dart';
import '../support/health_fixture.dart';

class MemoryHealthStore implements DatabaseService {
  final snapshots = <DateTime, DailyHealthSummary>{};
  final scores = <String, HealthScore>{};
  DateTime? baselineDate;
  @override
  Future<DailyHealthSummary?> getHealthSnapshot(DateTime date) async =>
      snapshots[date];
  @override
  Future<void> saveHealthSnapshot(DailyHealthSummary summary) async {
    snapshots[summary.date] = summary;
  }

  @override
  Future<({double? hrv, double? rhr, int days})> getPersonalBaseline(
      DateTime date) async {
    baselineDate = date;
    return (hrv: 50.0, rhr: 60.0, days: 14);
  }

  @override
  Future<void> saveHrvReading(DateTime date, double value) async {}
  @override
  Future<void> saveRhrReading(DateTime date, double value) async {}
  @override
  Future<SleepData?> getPhoneSleep(DateTime date) async => null;
  @override
  Future<void> saveScore(String type, HealthScore score) async {
    scores[type] = score;
  }

  @override
  Future<List<DailyHealthSummary>> getHealthSnapshots(DateTime end,
          {int days = 30}) async =>
      snapshots.values.toList();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordedHealthSource implements HealthConnectService {
  RecordedHealthSource(this.summary);
  DailyHealthSummary summary;
  int reads = 0;
  bool fail = false;
  @override
  Future<VitalsData> fetchVitals(DateTime date) async {
    reads++;
    return fail
        ? VitalsData(
            date: date,
            heartRateSamples: [],
            readErrors: ['RESTING_HEART_RATE'])
        : summary.vitals;
  }

  @override
  Future<SleepData> fetchSleep(DateTime date) async => summary.sleepData;
  @override
  Future<ActivityData> fetchActivity(DateTime date) async => summary.activity;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const profile = UserProfile(
      name: 'Test',
      age: 30,
      gender: Gender.female,
      heightCm: 160,
      weightKg: 60);
  final day = DateTime(2026, 9, 13);
  test('empty sync persists raw state without publishing fallback scores',
      () async {
    final db = MemoryHealthStore();
    final source = RecordedHealthSource(healthFixture(empty: true));
    final repo = HealthRepository(
        hc: source, db: db, clock: () => day.add(const Duration(hours: 10)));
    final result = await repo.getDailySummary(day, profile);
    expect(result.statusFor('recovery'), MetricStatus.unavailable);
    expect(db.scores, isEmpty);
    expect(db.snapshots, hasLength(1));
  });
  test(
      'historical snapshot returns raw contributors without querying live source',
      () async {
    final db = MemoryHealthStore()..snapshots[day] = healthFixture();
    final source = RecordedHealthSource(healthFixture(empty: true));
    final repo = HealthRepository(
        hc: source, db: db, clock: () => DateTime(2026, 9, 14));
    final result = await repo.getDailySummary(day, null);
    expect(source.reads, 0);
    expect(result.vitals.hrv, 55);
    expect(result.sleepData.stages, hasLength(4));
    expect(result.baselineDays, 14);
  });
  test('refresh failure preserves cached readings and their original freshness',
      () async {
    final saved = healthFixture();
    final db = MemoryHealthStore()..snapshots[day] = saved;
    final source = RecordedHealthSource(saved)..fail = true;
    final repo = HealthRepository(
        hc: source, db: db, clock: () => DateTime(2026, 9, 14));
    final result = await repo.getDailySummary(day, profile, refresh: true);
    expect(result.vitals.hrv, 55);
    expect(result.syncedAt, saved.syncedAt);
    expect(result.readErrors, isNotEmpty);
    expect((await repo.getDailySummary(day, profile)).readErrors, isNotEmpty);
    expect(db.snapshots[day], same(saved));
  });
  test('complete sync uses selected-day baseline and persists available scores',
      () async {
    final db = MemoryHealthStore();
    final source = RecordedHealthSource(healthFixture());
    final repo = HealthRepository(
        hc: source, db: db, clock: () => day.add(const Duration(hours: 10)));
    final result =
        await repo.getDailySummary(day.add(const Duration(hours: 8)), profile);
    expect(db.baselineDate, day);
    expect(result.statusFor('recovery'), MetricStatus.available);
    expect(db.scores.keys,
        containsAll(['recovery', 'sleep', 'strain', 'stress', 'energy']));
    await repo.getDailySummary(day, profile);
    expect(source.reads, 1);
    await repo.getDailySummary(day, profile, refresh: true);
    expect(source.reads, 2);
  });
  test('no profile does not create a default sleep goal or score', () async {
    final repo = HealthRepository(
        hc: RecordedHealthSource(healthFixture()),
        db: MemoryHealthStore(),
        clock: () => day);
    final result = await repo.getDailySummary(day, null);
    expect(result.sleepGoal, isNull);
    expect(result.statusFor('sleep'), MetricStatus.unavailable);
    expect(result.hasSleepData, isTrue);
  });
}
