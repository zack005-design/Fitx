import '../../core/models/daily_health_summary.dart';
import '../../core/models/health_day.dart';

const trendMetrics = <String, String>{
  'recovery': 'Recovery',
  'sleep': 'Sleep score',
  'sleep_duration': 'Sleep duration',
  'stress': 'Stress',
  'energy': 'Energy',
  'strain': 'Strain score',
  'hrv': 'Heart-rate variability',
  'rhr': 'Resting heart rate',
  'spo2': 'Blood oxygen',
  'respiratory_rate': 'Respiratory rate',
};
String trendUnit(String metric) => switch (metric) {
      'sleep_duration' => 'h',
      'hrv' => 'ms',
      'rhr' => 'bpm',
      'spo2' => '%',
      'respiratory_rate' => '/min',
      _ => '/100',
    };
double? trendValue(DailyHealthSummary s, String metric) => switch (metric) {
      'sleep_duration' =>
        s.hasSleepData ? s.sleepData.totalSleep.inMinutes / 60 : null,
      'hrv' => s.vitals.hrv,
      'rhr' => s.vitals.restingHeartRate,
      'spo2' => s.vitals.spo2,
      'respiratory_rate' => s.vitals.respiratoryRate,
      _ => s.metricFor(metric).valueOrNull,
    };

class TrendPoint {
  const TrendPoint(this.date, this.value);
  final DateTime date;
  final double value;
}

class TrendSeries {
  TrendSeries(
      {required this.end,
      required this.days,
      required this.metric,
      required List<DailyHealthSummary> snapshots}) {
    final byDate = <DateTime, double>{};
    for (final s in snapshots) {
      final v = trendValue(s, metric);
      if (v != null &&
          v.isFinite &&
          !healthDay(s.date).isAfter(healthDay(end))) {
        byDate[healthDay(s.date)] = v;
      }
    }
    points = byDate.entries
        .where((e) => !e.key.isBefore(start))
        .map((e) => TrendPoint(e.key, e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final baseline = byDate.entries
        .where((e) =>
            e.key.isBefore(healthDay(end)) &&
            !e.key.isBefore(shiftHealthDay(end, -30)) &&
            !e.key.isBefore(start))
        .map((e) => e.value)
        .toList()
      ..sort();
    // An observed range, not a medical reference interval or confidence interval.
    band = baseline.length >= 5
        ? (low: baseline.first, high: baseline.last)
        : null;
    baselineCount = baseline.length;
  }
  final DateTime end;
  final int days;
  final String metric;
  late final List<TrendPoint> points;
  late final ({double low, double high})? band;
  late final int baselineCount;
  DateTime get start => shiftHealthDay(end, 1 - days);
  double? get average => points.isEmpty
      ? null
      : points.fold(0.0, (sum, p) => sum + p.value) / points.length;
  double? get change =>
      points.length < 2 ? null : points.last.value - points.first.value;
  int dayIndex(DateTime date) => DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(start.year, start.month, start.day))
      .inDays;
}
