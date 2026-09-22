import '../models/daily_health_summary.dart';
import '../models/nutrition_models.dart';
import '../models/workout_models.dart';

class WeeklyMetric {
  const WeeklyMetric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

class WeeklyReview {
  const WeeklyReview({
    required this.metrics,
    required this.focus,
    required this.focusReason,
    required this.recordedHealthDays,
  });

  final List<WeeklyMetric> metrics;
  final String focus;
  final String focusReason;
  final int recordedHealthDays;
}

abstract final class WeeklyReviewEngine {
  static WeeklyReview build({
    required List<DailyHealthSummary> health,
    required List<DailyNutrition> nutrition,
    required List<WorkoutLog> workouts,
  }) {
    final recovery = _values(health, 'recovery');
    final sleep = _values(health, 'sleep');
    final stepDays = health.where((day) => day.activity.steps > 0).toList();
    final meals = nutrition.expand((day) => day.entries).length;
    final weekStart = DateTime.now().subtract(const Duration(days: 7));
    final weeklyWorkouts =
        workouts.where((workout) => workout.startedAt.isAfter(weekStart));

    final metrics = <WeeklyMetric>[
      WeeklyMetric('Recovery', _averageLabel(recovery, suffix: '%'),
          '${recovery.length} of 7 days available'),
      WeeklyMetric('Sleep', _averageLabel(sleep, suffix: '%'),
          '${sleep.length} of 7 nights available'),
      WeeklyMetric(
          'Steps',
          stepDays.isEmpty
              ? '—'
              : '${(stepDays.fold<int>(0, (sum, day) => sum + day.activity.steps) / stepDays.length).round()}',
          '${stepDays.length} of 7 days recorded'),
      WeeklyMetric('Training', '${weeklyWorkouts.length}',
          '${weeklyWorkouts.fold<int>(0, (sum, item) => sum + item.duration.inMinutes)} minutes'),
      WeeklyMetric('Meals', '$meals',
          '${nutrition.where((day) => day.entries.isNotEmpty).length} days logged'),
    ];

    if (sleep.length < 4) {
      return WeeklyReview(
          metrics: metrics,
          focus: 'Record sleep consistently',
          focusReason:
              'At least four recorded nights make the weekly pattern more useful.',
          recordedHealthDays: health.where((day) => day.hasVitalsData).length);
    }
    if (_average(sleep) < 70) {
      return WeeklyReview(
          metrics: metrics,
          focus: 'Protect your sleep window',
          focusReason:
              'Your average recorded sleep score was below 70 this week.',
          recordedHealthDays: health.where((day) => day.hasVitalsData).length);
    }
    if (stepDays.length < 4) {
      return WeeklyReview(
          metrics: metrics,
          focus: 'Build a movement baseline',
          focusReason:
              'More recorded activity days will make strain guidance clearer.',
          recordedHealthDays: health.where((day) => day.hasVitalsData).length);
    }
    return WeeklyReview(
        metrics: metrics,
        focus: 'Keep the rhythm steady',
        focusReason:
            'Your core signals are consistently recorded. Aim for repeatable habits rather than a larger jump.',
        recordedHealthDays: health.where((day) => day.hasVitalsData).length);
  }

  static List<double> _values(List<DailyHealthSummary> days, String metric) =>
      days
          .map((day) => day.metricFor(metric).valueOrNull)
          .whereType<double>()
          .toList();

  static double _average(List<double> values) =>
      values.fold<double>(0, (sum, value) => sum + value) / values.length;

  static String _averageLabel(List<double> values, {String suffix = ''}) =>
      values.isEmpty ? '—' : '${_average(values).round()}$suffix';
}
