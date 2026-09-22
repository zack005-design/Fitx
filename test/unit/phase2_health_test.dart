import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitx/core/models/health_day.dart';
import 'package:fitx/core/models/health_snapshot_codec.dart';
import 'package:fitx/core/models/metric_value.dart';
import 'package:fitx/core/models/sleep_data.dart';
import 'package:fitx/core/engines/sleep_engine.dart';
import 'package:fitx/features/score_detail/score_detail_model.dart';
import 'package:fitx/features/trends/trend_model.dart';
import '../support/health_fixture.dart';

void main() {
  test('empty data never exposes engine fallbacks', () {
    final s = healthFixture(empty: true);
    for (final type in ['recovery', 'sleep', 'stress', 'energy', 'strain']) {
      expect(s.statusFor(type), MetricStatus.unavailable);
      expect(s.metricFor(type).valueOrNull, isNull);
    }
    expect(ScoreDetailModel(s, 'recovery').contributors.first.value, isNull);
  });
  test('partial data keeps readings but hides unsupported scores', () {
    final s = healthFixture(partial: true);
    expect(s.statusFor('sleep'), MetricStatus.available);
    for (final type in ['recovery', 'stress', 'energy']) {
      expect(s.statusFor(type), MetricStatus.unavailable);
    }
    final rows = ScoreDetailModel(s, 'recovery').contributors;
    expect(rows.first.value, '55.0 ms');
    expect(rows[1].value, isNull);
  });
  test('calibration requires fourteen prior paired days', () {
    for (final days in [0, 1, 13]) {
      final s = healthFixture(baselineDays: days);
      for (final type in ['recovery', 'stress', 'energy']) {
        expect(s.statusFor(type), MetricStatus.calibrating);
        expect(s.metricFor(type).valueOrNull, isNull);
      }
      expect(s.metricFor('sleep').valueOrNull, isNotNull);
    }
    expect(healthFixture().statusFor('recovery'), MetricStatus.available);
  });
  test(
      'snapshot round trip preserves raw night, baseline, source freshness and formula',
      () {
    final original = healthFixture();
    final restored = HealthSnapshotCodec.decode(
        jsonDecode(jsonEncode(HealthSnapshotCodec.encode(original))));
    expect(restored.sleepData.stages, original.sleepData.stages);
    expect(restored.sleepData.bedtime, original.sleepData.bedtime);
    expect(restored.vitals.hrv, 55);
    expect(restored.hrvBaseline, 50);
    expect(restored.syncedAt, original.syncedAt);
    expect(restored.formulaVersion, 2);
    expect(ScoreDetailModel(restored, 'recovery').explanation,
        ScoreDetailModel(original, 'recovery').explanation);
  });
  test('duration-only sleep does not invent stage or efficiency scores', () {
    final day = DateTime(2026, 9, 13);
    final sleep = SleepData(
        date: day,
        totalSleep: const Duration(hours: 7),
        remDuration: Duration.zero,
        deepDuration: Duration.zero,
        lightDuration: Duration.zero,
        awakeDuration: Duration.zero,
        stages: [],
        efficiency: 0,
        wakeCount: 0);
    final score =
        SleepEngine.compute(sleep: sleep, sleepGoal: const Duration(hours: 8));
    expect(score.breakdown.keys, ['duration']);
    expect(score.value, 87.5);
  });
  for (final days in [7, 30, 90]) {
    test(
        '$days-day history is inclusive, date anchored and excludes unavailable data',
        () {
      final end = DateTime(2026, 9, 13);
      final snapshots = [
        for (var i = -1; i <= days; i++)
          healthFixture(
              date: shiftHealthDay(end, -i),
              empty: i == 2,
              baselineDays: i == 3 ? 1 : 14,
              scoreValue: 70 + i.toDouble())
      ];
      final s = TrendSeries(
          end: end, days: days, metric: 'recovery', snapshots: snapshots);
      expect(s.start, shiftHealthDay(end, 1 - days));
      expect(s.points.length, days - 2);
      expect(s.points.first.date, s.start);
      expect(s.points.last.date, end);
      expect(s.dayIndex(end), days - 1);
      expect(s.change, -(days - 1));
    });
  }
  test('empty and single-point histories have honest statistics', () {
    final end = DateTime(2026, 9, 13);
    final empty =
        TrendSeries(end: end, days: 7, metric: 'recovery', snapshots: []);
    expect(empty.average, isNull);
    expect(empty.change, isNull);
    expect(empty.band, isNull);
    final single = TrendSeries(
        end: end, days: 7, metric: 'recovery', snapshots: [healthFixture()]);
    expect(single.average, 72);
    expect(single.change, isNull);
    expect(single.band, isNull);
  });
  test('sleep duration history remains available during recovery calibration',
      () {
    final s = TrendSeries(
        end: DateTime(2026, 9, 13),
        days: 7,
        metric: 'sleep_duration',
        snapshots: [healthFixture(baselineDays: 1)]);
    expect(s.average, 7);
  });
  test('local calendar shifts handle month, year and leap boundaries', () {
    expect(shiftHealthDay(DateTime(2024, 3, 1, 23), -1), DateTime(2024, 2, 29));
    expect(shiftHealthDay(DateTime(2026, 1, 1), -1), DateTime(2025, 12, 31));
    expect(healthDayKey(DateTime(2026, 9, 13, 23, 59)), '2026-09-13');
  });
}
