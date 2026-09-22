import 'package:intl/intl.dart';
import '../../core/models/daily_health_summary.dart';
import '../../core/models/metric_value.dart';
import '../../core/models/sleep_data.dart';

class Contributor {
  const Contributor(this.label, this.value, this.comparison);
  final String label;
  final String? value;
  final String comparison;
}

String durationLabel(Duration d) =>
    '${d.inHours}h ${d.inMinutes.remainder(60)}m';
String reading(double? value, String unit) =>
    value == null ? 'Unavailable' : '${value.toStringAsFixed(1)} $unit';
String comparison(double? value, double? baseline, String unit) {
  if (value == null) return 'No reading for this day';
  if (baseline == null) return 'Personal baseline unavailable';
  final delta = value - baseline;
  return '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} $unit vs ${baseline.toStringAsFixed(1)} $unit baseline';
}

class ScoreDetailModel {
  const ScoreDetailModel(this.summary, this.type);
  final DailyHealthSummary summary;
  final String type;
  MetricStatus get status => summary.statusFor(type);
  String? get value => summary.metricFor(type).valueOrNull?.round().toString();
  String get source {
    final metadata = summary.metricFor(type).metadata;
    if (summary.sleepData.source != SleepDataSource.phoneSensors) {
      return 'Health Connect · ${DateFormat('MMM d, yyyy').format(summary.date)}\n'
          '${summary.syncedAt == null ? 'Sync time unavailable' : 'Last read ${DateFormat('MMM d, HH:mm').format(summary.syncedAt!)}'}'
          '\nDaily aggregates; individual source timestamps unavailable.';
    }
    final confidence = switch (metadata.confidence) {
      MetricConfidence.high => 'High input confidence',
      MetricConfidence.medium => 'Moderate input confidence',
      MetricConfidence.low => 'Low input confidence',
      MetricConfidence.unknown => 'Input confidence unavailable',
    };
    return '${metadata.source.name} · ${DateFormat('MMM d, yyyy').format(summary.date)}\n'
        '${summary.syncedAt == null ? 'Sync time unavailable' : 'Last read ${DateFormat('MMM d, HH:mm').format(summary.syncedAt!)}'}'
        '\n$confidence · Daily aggregate';
  }

  String get explanation {
    if (status == MetricStatus.calibrating) return summary.baselineMessage;
    if (status == MetricStatus.unavailable) {
      return switch (type) {
        'sleep' =>
          'Sleep scoring needs recorded sleep and a saved sleep goal. Review Health Connect and profile settings.',
        'recovery' =>
          'Recovery needs sleep, HRV, resting heart rate, and a saved sleep goal. Sync your device and review settings.',
        'stress' =>
          'Stress scoring needs HRV and resting heart rate from Health Connect.',
        'energy' =>
          'Energy needs recovery inputs, recorded activity, and saved goals for this day.',
        _ => 'Sync activity from Health Connect and review your saved goals.',
      };
    }
    return switch (type) {
      'recovery' =>
        'HRV is ${comparison(summary.vitals.hrv, summary.hrvBaseline, 'ms')}. '
            'Resting heart rate is ${comparison(summary.vitals.restingHeartRate, summary.rhrBaseline, 'bpm')}. '
            'Recorded sleep contributes ${summary.sleep.value.round()} / 100.',
      'sleep' =>
        '${durationLabel(summary.sleepData.totalSleep)} recorded against your ${durationLabel(summary.sleepGoal!)} saved goal. '
            'Only recorded contributors enter the score; missing stages are excluded.',
      'stress' =>
        'A daily estimate of physiological load from HRV and resting heart rate against your baseline'
            '${summary.vitals.spo2 == null ? '.' : ', with recorded blood oxygen.'} Higher scores indicate greater estimated load.',
      'energy' =>
        'An estimate combining recovery (${summary.recovery.value.round()} / 100) and recorded strain '
            '(${summary.strainRaw.toStringAsFixed(1)} / 21). This is a daily calculation, not a measured energy level.',
      _ => 'Calculated from recorded movement and workouts for this day.',
    };
  }

  List<Contributor> get contributors {
    final s = summary;
    final hrv = Contributor(
        'Heart-rate variability',
        s.vitals.hrv == null ? null : reading(s.vitals.hrv, 'ms'),
        comparison(s.vitals.hrv, s.hrvBaseline, 'ms'));
    final rhr = Contributor(
        'Resting heart rate',
        s.vitals.restingHeartRate == null
            ? null
            : reading(s.vitals.restingHeartRate, 'bpm'),
        comparison(s.vitals.restingHeartRate, s.rhrBaseline, 'bpm'));
    return switch (type) {
      'recovery' => [
          hrv,
          rhr,
          Contributor(
              'Sleep score',
              s.metricFor('sleep').valueOrNull == null
                  ? null
                  : '${s.sleep.value.round()} / 100',
              'Recorded sleep and saved sleep goal'),
          Contributor(
              'Respiratory rate',
              s.vitals.respiratoryRate == null
                  ? null
                  : reading(s.vitals.respiratoryRate, '/min'),
              'Context only; not part of this score')
        ],
      'sleep' => [
          Contributor(
              'Duration',
              s.hasSleepData ? durationLabel(s.sleepData.totalSleep) : null,
              s.sleepGoal == null
                  ? 'Save a sleep goal in your profile'
                  : '${durationLabel(s.sleepGoal!)} saved goal; sleep need is not estimated'),
          Contributor(
              'Efficiency',
              s.sleep.breakdown.containsKey('efficiency')
                  ? '${(s.sleepData.efficiency * 100).round()}%'
                  : null,
              'Recorded sleep divided by recorded session duration'),
          Contributor(
              'Interruptions',
              s.sleepData.stages.any((x) => x.stage.name == 'awake')
                  ? '${s.sleepData.wakeCount}'
                  : null,
              'Count of recorded awake segments; absent awake data is not zero interruptions'),
        ],
      'stress' => [
          hrv,
          rhr,
          Contributor(
              'Blood oxygen',
              s.vitals.spo2 == null ? null : reading(s.vitals.spo2, '%'),
              'Optional contributor; excluded when missing')
        ],
      'energy' => [
          Contributor(
              'Recovery',
              s.metricFor('recovery').valueOrNull == null
                  ? null
                  : '${s.recovery.value.round()} / 100',
              s.baselineMessage),
          Contributor(
              'Recorded strain',
              s.hasActivityData
                  ? '${s.strainRaw.toStringAsFixed(1)} / 21'
                  : null,
              'From Health Connect activity'),
          Contributor('Saved strain target', s.strainTarget?.toStringAsFixed(1),
              'Profile setting used by the energy calculation')
        ],
      _ => [],
    };
  }
}
