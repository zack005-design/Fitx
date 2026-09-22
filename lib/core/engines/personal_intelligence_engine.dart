import 'dart:math' as math;

import '../models/activity_data.dart';
import '../models/daily_health_summary.dart';
import '../models/user_profile.dart';

enum HealthspanImpact { supportive, steady, focus, unavailable }

class HealthspanContributor {
  const HealthspanContributor({
    required this.title,
    required this.value,
    required this.detail,
    required this.impact,
    this.score,
  });

  final String title;
  final String value;
  final String detail;
  final HealthspanImpact impact;
  final double? score;
}

class HealthspanFocus {
  const HealthspanFocus({
    required this.title,
    required this.message,
    required this.progressLabel,
  });

  final String title;
  final String message;
  final String progressLabel;
}

class BiologicalAgeEstimate {
  const BiologicalAgeEstimate({
    required this.age,
    required this.chronologicalAge,
    required this.observedDays,
    required this.confidence,
    required this.factors,
    this.paceOfAging,
    this.contributors = const [],
    this.weeklyFocus,
  });

  final double age;
  final int chronologicalAge;
  final int observedDays;
  final double confidence;
  final List<String> factors;

  /// 1.0x means the latest 30-day wellness pattern is unchanged from the
  /// preceding period. This is not a clinical rate of aging.
  final double? paceOfAging;
  final List<HealthspanContributor> contributors;
  final HealthspanFocus? weeklyFocus;

  bool get isFullyCalibrated => observedDays >= 90;
}

class BiologicalAgePoint {
  const BiologicalAgePoint(this.date, this.age);
  final DateTime date;
  final double age;
}

/// A transparent wellness trend, not a clinical or diagnostic biological age.
/// It uses only local inputs and does not reproduce a vendor's proprietary
/// population model.
abstract final class BiologicalAgeEngine {
  static BiologicalAgeEstimate? estimate(
      UserProfile? profile, List<DailyHealthSummary> days) {
    if (profile == null) return null;
    final usable = _usable(days);
    if (usable.length < 7) return null;

    final contributors = _contributors(profile, usable);
    final scored = contributors.where((item) => item.score != null).toList();
    if (scored.isEmpty) return null;
    final wellness = scored
            .map((item) => item.score!)
            .reduce((value, item) => value + item) /
        scored.length;
    final adjustment = ((70 - wellness) * .11).clamp(-8.0, 8.0);

    final recent =
        usable.length > 30 ? usable.sublist(usable.length - 30) : usable;
    final previousStart = math.max(0, usable.length - 60);
    final previousEnd = math.max(0, usable.length - 30);
    final previous = usable.sublist(previousStart, previousEnd);
    final pace = previous.length < 7
        ? null
        : (1 -
                (_wellnessScore(profile, recent) -
                        _wellnessScore(profile, previous)) /
                    10)
            .clamp(-1.0, 2.0)
            .toDouble();

    return BiologicalAgeEstimate(
      age: (profile.age + adjustment).clamp(18, 100),
      chronologicalAge: profile.age,
      observedDays: usable.length,
      confidence: (usable.length / 90).clamp(.1, 1),
      factors: contributors
          .where((item) => item.score != null)
          .map((item) => '${item.title}: ${item.value}')
          .toList(growable: false),
      paceOfAging: pace,
      contributors: contributors,
      weeklyFocus: _focusFor(contributors),
    );
  }

  static List<BiologicalAgePoint> trend(
      UserProfile? profile, List<DailyHealthSummary> days) {
    if (profile == null) return const [];
    final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
    final points = <BiologicalAgePoint>[];
    for (var end = 6; end < sorted.length; end++) {
      final start = math.max(0, end - 89);
      final result = estimate(profile, sorted.sublist(start, end + 1));
      if (result != null) {
        points.add(BiologicalAgePoint(sorted[end].date, result.age));
      }
    }
    return points;
  }

  static List<DailyHealthSummary> _usable(List<DailyHealthSummary> days) {
    final usable = days
        .where((day) =>
            day.hasSleepData ||
            day.hasActivityData ||
            day.vitals.restingHeartRate != null)
        .toList();
    usable.sort((a, b) => a.date.compareTo(b.date));
    return usable;
  }

  static double _wellnessScore(
      UserProfile profile, List<DailyHealthSummary> days) {
    final values = _contributors(profile, days)
        .map((item) => item.score)
        .whereType<double>()
        .toList();
    return values.isEmpty
        ? 50
        : values.reduce((value, item) => value + item) / values.length;
  }

  static List<HealthspanContributor> _contributors(
      UserProfile profile, List<DailyHealthSummary> days) {
    final result = <HealthspanContributor>[];
    final sleepDays = days.where((day) => day.hasSleepData).toList();
    if (sleepDays.isEmpty) {
      result.addAll(const [
        HealthspanContributor(
          title: 'Sleep duration',
          value: 'No data',
          detail: 'Record sleep to include this contributor.',
          impact: HealthspanImpact.unavailable,
        ),
        HealthspanContributor(
          title: 'Sleep consistency',
          value: 'No data',
          detail: 'Bedtime records are needed to measure consistency.',
          impact: HealthspanImpact.unavailable,
        ),
      ]);
    } else {
      final averageMinutes = _average(sleepDays
          .map((day) => day.sleepData.totalSleep.inMinutes.toDouble()))!;
      final goalMinutes = profile.sleepGoal.inMinutes.toDouble();
      final durationScore = (100 - (averageMinutes - goalMinutes).abs() / 3)
          .clamp(0, 100)
          .toDouble();
      result.add(HealthspanContributor(
        title: 'Sleep duration',
        value: _durationLabel(averageMinutes.round()),
        detail:
            '${sleepDays.length}-night average · goal ${_durationLabel(goalMinutes.round())}',
        impact: _impact(durationScore),
        score: durationScore,
      ));

      final bedtimes = sleepDays
          .map((day) => day.sleepData.bedtime)
          .whereType<DateTime>()
          .map((time) => time.hour * 60 + time.minute)
          .toList();
      if (bedtimes.length >= 3) {
        final spread = _circularMeanDeviation(bedtimes);
        final consistencyScore = (100 - spread / 1.2).clamp(0, 100).toDouble();
        result.add(HealthspanContributor(
          title: 'Sleep consistency',
          value: '±${spread.round()} min',
          detail: 'Average bedtime variation across ${bedtimes.length} nights',
          impact: _impact(consistencyScore),
          score: consistencyScore,
        ));
      } else {
        result.add(const HealthspanContributor(
          title: 'Sleep consistency',
          value: 'More nights needed',
          detail: 'At least 3 recorded bedtimes are required.',
          impact: HealthspanImpact.unavailable,
        ));
      }
    }

    final activityDays = days.where((day) => day.hasActivityData).toList();
    if (activityDays.isEmpty) {
      result.add(const HealthspanContributor(
        title: 'Daily movement',
        value: 'No data',
        detail: 'Steps or active minutes are needed.',
        impact: HealthspanImpact.unavailable,
      ));
    } else {
      final steps =
          _average(activityDays.map((day) => day.activity.steps.toDouble()))!;
      final score =
          (steps / profile.dailyStepGoal * 100).clamp(0, 100).toDouble();
      result.add(HealthspanContributor(
        title: 'Daily movement',
        value: '${steps.round()} steps',
        detail:
            '${activityDays.length}-day average · goal ${profile.dailyStepGoal}',
        impact: _impact(score),
        score: score,
      ));

      final activeMinutes = _average(activityDays
          .map((day) => day.activity.activeTime.inMinutes.toDouble()))!;
      final weeklyMinutes = activeMinutes * 7;
      final activeScore = (weeklyMinutes / 150 * 100).clamp(0, 100).toDouble();
      result.add(HealthspanContributor(
        title: 'Active time',
        value: '${weeklyMinutes.round()} min/week',
        detail: 'Projected from recorded active minutes',
        impact: _impact(activeScore),
        score: activeScore,
      ));

      final strengthSessions = activityDays
          .expand((day) => day.activity.workouts)
          .where((workout) => workout.type == WorkoutType.weightTraining)
          .length;
      final weeks = math.max(1.0, activityDays.length / 7);
      final strengthPerWeek = strengthSessions / weeks;
      final strengthScore =
          (strengthPerWeek / 2 * 100).clamp(0, 100).toDouble();
      result.add(HealthspanContributor(
        title: 'Strength training',
        value: '${strengthPerWeek.toStringAsFixed(1)} sessions/week',
        detail: 'Based on recorded weight-training workouts',
        impact: _impact(strengthScore),
        score: strengthScore,
      ));
    }

    final rhrDays =
        days.where((day) => day.vitals.restingHeartRate != null).toList();
    if (rhrDays.isEmpty) {
      result.add(const HealthspanContributor(
        title: 'Resting heart rate',
        value: 'No data',
        detail: 'A wearable or compatible Health Connect source is needed.',
        impact: HealthspanImpact.unavailable,
      ));
    } else {
      final rhr = _average(rhrDays.map((day) => day.vitals.restingHeartRate!))!;
      final baseline =
          _average(rhrDays.map((day) => day.rhrBaseline).whereType<double>());
      final score = baseline == null
          ? 70.0
          : (75 - (rhr - baseline) * 5).clamp(0, 100).toDouble();
      result.add(HealthspanContributor(
        title: 'Resting heart rate',
        value: '${rhr.round()} bpm',
        detail: baseline == null
            ? '${rhrDays.length}-day recorded average'
            : '${rhr >= baseline ? '+' : ''}${(rhr - baseline).toStringAsFixed(1)} bpm versus your baseline',
        impact: _impact(score),
        score: score,
      ));
    }
    return result;
  }

  static HealthspanFocus? _focusFor(List<HealthspanContributor> contributors) {
    final scored = contributors.where((item) => item.score != null).toList()
      ..sort((a, b) => a.score!.compareTo(b.score!));
    if (scored.isEmpty) return null;
    final item = scored.first;
    return switch (item.title) {
      'Sleep duration' => const HealthspanFocus(
          title: 'Protect your sleep window',
          message:
              'For the next seven nights, leave enough time for your saved sleep goal. Consistency matters more than one perfect night.',
          progressLabel: 'Review again after 7 recorded nights',
        ),
      'Sleep consistency' => const HealthspanFocus(
          title: 'Anchor your bedtime',
          message:
              'Choose a realistic bedtime and keep it within the same 60-minute window this week.',
          progressLabel: 'Target: bedtime variation under 60 minutes',
        ),
      'Daily movement' => HealthspanFocus(
          title: 'Build daily movement',
          message:
              'Add one comfortable walk or movement break each day. Build gradually toward ${item.detail.split('goal ').last} steps.',
          progressLabel: 'Track the 7-day step average',
        ),
      'Active time' => const HealthspanFocus(
          title: 'Accumulate active minutes',
          message:
              'Spread comfortable activity across the week instead of trying to catch up in one session.',
          progressLabel: 'Reference target: 150 min/week',
        ),
      'Strength training' => const HealthspanFocus(
          title: 'Make room for strength',
          message:
              'Schedule up to two manageable strength sessions this week, leaving recovery time between them.',
          progressLabel: 'Reference target: 2 sessions/week',
        ),
      'Resting heart rate' => const HealthspanFocus(
          title: 'Support recovery habits',
          message:
              'Prioritize sleep, hydration, and manageable training while watching your resting-heart-rate trend.',
          progressLabel: 'Compare with your personal baseline',
        ),
      _ => null,
    };
  }

  static HealthspanImpact _impact(double score) {
    if (score >= 80) return HealthspanImpact.supportive;
    if (score >= 60) return HealthspanImpact.steady;
    return HealthspanImpact.focus;
  }

  static double _circularMeanDeviation(List<int> minutes) {
    const fullDay = 24 * 60;
    final angles = minutes.map((value) => value / fullDay * 2 * math.pi);
    final x = angles.map(math.cos).reduce((a, b) => a + b) / minutes.length;
    final y = angles.map(math.sin).reduce((a, b) => a + b) / minutes.length;
    var mean = math.atan2(y, x) / (2 * math.pi) * fullDay;
    if (mean < 0) mean += fullDay;
    return minutes.map((value) {
          final difference = (value - mean).abs();
          return math.min(difference, fullDay - difference);
        }).reduce((a, b) => a + b) /
        minutes.length;
  }

  static String _durationLabel(int minutes) =>
      '${minutes ~/ 60}h ${minutes.remainder(60)}m';

  static double? _average(Iterable<double> values) {
    final list = values.toList();
    return list.isEmpty ? null : list.reduce((a, b) => a + b) / list.length;
  }
}

enum CoachingTone { restore, maintain, build, information }

enum CoachState { restore, steady, build }

enum CoachTrend { rising, stable, falling, learning }

class CoachSignal {
  const CoachSignal({
    required this.label,
    required this.score,
    required this.weight,
    required this.evidence,
    required this.reliability,
    this.deviation,
    this.baseline,
    this.trendPerDay,
  });

  final String label;
  final double score;
  final double weight;
  final String evidence;
  final double reliability;
  final double? baseline;
  final double? trendPerDay;

  /// Robust standard deviations from the user's recent median. Null until
  /// enough comparable history exists.
  final double? deviation;
}

class CoachAssessment {
  const CoachAssessment({
    required this.score,
    required this.confidence,
    required this.state,
    required this.summary,
    required this.signals,
    required this.cards,
    required this.historyDays,
    required this.forecastScore,
    required this.trend,
    required this.stability,
    required this.anomalyCount,
  });

  final double score;
  final double confidence;
  final CoachState state;
  final String summary;
  final List<CoachSignal> signals;
  final List<CoachingCard> cards;
  final int historyDays;
  final double? forecastScore;
  final CoachTrend trend;
  final double stability;
  final int anomalyCount;

  String get stateLabel => switch (state) {
        CoachState.restore => 'Recovery favored',
        CoachState.steady => 'Steady day',
        CoachState.build => 'Capacity available',
      };

  String get trendLabel => switch (trend) {
        CoachTrend.rising => 'Improving trend',
        CoachTrend.stable => 'Stable trend',
        CoachTrend.falling => 'Declining trend',
        CoachTrend.learning => 'Learning trend',
      };
}

class CoachingCard {
  const CoachingCard({
    required this.title,
    required this.message,
    required this.tone,
    required this.evidence,
  });
  final String title;
  final String message;
  final CoachingTone tone;
  final String evidence;
}

/// A deterministic, on-device decision model.
///
/// The model combines robust statistics, exponential smoothing, least-squares
/// trend estimation, signal reliability, cross-signal interactions, anomaly
/// detection, and uncertainty calibration. No model, prompt, or health
/// observation leaves the device.
abstract final class PrivateCoachEngine {
  static const algorithmVersion = 2;

  static const _weights = <String, double>{
    'Recovery': .32,
    'Sleep': .24,
    'Energy': .18,
    'Low stress': .14,
    'Training balance': .12,
  };

  static CoachAssessment assess(
    DailyHealthSummary day,
    UserProfile? profile, {
    List<DailyHealthSummary> history = const [],
  }) {
    final prior = history.where((item) => item.date.isBefore(day.date)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final recent = prior.length > 42 ? prior.sublist(prior.length - 42) : prior;

    final inputs = <({String label, double value, String evidence})>[];
    void addMetric(String label, String key, {bool invert = false}) {
      final value = day.metricFor(key).valueOrNull;
      if (value == null) return;
      inputs.add((
        label: label,
        value: invert ? 100 - value : value,
        evidence: invert
            ? '${value.round()}/100 recorded stress (lower is better)'
            : '${value.round()}/100 recorded ${key.toLowerCase()}',
      ));
    }

    addMetric('Recovery', 'recovery');
    addMetric('Sleep', 'sleep');
    addMetric('Energy', 'energy');
    addMetric('Low stress', 'stress', invert: true);
    if (day.hasActivityData && profile != null && profile.strainTarget > 0) {
      final ratio = day.strainRaw / profile.strainTarget;
      final balance = ratio <= 1
          ? (55 + ratio * 45).clamp(0, 100).toDouble()
          : (100 - (ratio - 1) * 85).clamp(0, 100).toDouble();
      inputs.add((
        label: 'Training balance',
        value: balance,
        evidence:
            '${day.strainRaw.toStringAsFixed(1)} strain / ${profile.strainTarget.toStringAsFixed(1)} target',
      ));
    }

    final signals = <CoachSignal>[];
    for (final input in inputs) {
      final historical = _historyFor(input.label, recent, profile);
      final deviation = _robustDeviation(input.value, historical);
      final baseline = historical.length < 3 ? null : _median(historical);
      final smoothed = historical.isEmpty ? null : _ewma(historical);
      final trend = historical.length < 7 ? null : _linearSlope(historical);
      final scale = historical.length < 7 ? null : _robustScale(historical);
      final sampleReliability =
          (.55 + .45 * (historical.length / 21)).clamp(.55, 1.0).toDouble();
      final stabilityReliability =
          scale == null ? .8 : (1 - scale / 45).clamp(.55, 1.0).toDouble();
      final reliability = sampleReliability * stabilityReliability;
      final personalScore = deviation == null
          ? input.value
          : (50 + deviation * 12).clamp(0, 100).toDouble();
      final projectedTrend = smoothed == null
          ? input.value
          : (smoothed + (trend ?? 0) * 3).clamp(0, 100).toDouble();
      final adaptiveScore = deviation == null
          ? input.value
          : (.55 * input.value + .25 * personalScore + .20 * projectedTrend)
              .clamp(0, 100)
              .toDouble();
      signals.add(CoachSignal(
        label: input.label,
        score: adaptiveScore,
        weight: _weights[input.label]!,
        evidence: input.evidence,
        reliability: reliability,
        deviation: deviation,
        baseline: baseline,
        trendPerDay: trend,
      ));
    }

    final availableWeight = signals.fold<double>(0, (sum, s) => sum + s.weight);
    final reliableWeight =
        signals.fold<double>(0, (sum, s) => sum + s.weight * s.reliability);
    var score = reliableWeight == 0
        ? 50.0
        : signals.fold<double>(
                0, (sum, s) => sum + s.score * s.weight * s.reliability) /
            reliableWeight;

    final sleepSignal = _signal(signals, 'Sleep');
    final recoverySignal = _signal(signals, 'Recovery');
    if (sleepSignal != null && recoverySignal != null) {
      final synergy = math.sqrt(sleepSignal.score * recoverySignal.score);
      score = score * .9 + synergy * .1;
      if (sleepSignal.score < 45 && recoverySignal.score < 50) score -= 4;
    }
    final stressSignal = _signal(signals, 'Low stress');
    final loadSignal = _signal(signals, 'Training balance');
    if (stressSignal != null &&
        loadSignal != null &&
        stressSignal.score < 40 &&
        loadSignal.score < 50) {
      score -= 5;
    }
    score = score.clamp(0, 100).toDouble();

    final historicalScores = recent
        .map((item) => _rawComposite(item, profile))
        .whereType<double>()
        .toList();
    final compositeSlope =
        historicalScores.length < 7 ? null : _linearSlope(historicalScores);
    final forecast = historicalScores.length < 5
        ? null
        : (.55 * score +
                .45 * (_ewma(historicalScores) + (compositeSlope ?? 0) * 2))
            .clamp(0, 100)
            .toDouble();
    final trendState = compositeSlope == null
        ? CoachTrend.learning
        : compositeSlope > .25
            ? CoachTrend.rising
            : compositeSlope < -.25
                ? CoachTrend.falling
                : CoachTrend.stable;
    final agreement = signals.length < 2
        ? .5
        : (1 - _standardDeviation(signals.map((s) => s.score).toList()) / 35)
            .clamp(0.0, 1.0)
            .toDouble();
    final stability = historicalScores.length < 7
        ? .5
        : (1 - _robustScale(historicalScores) / 30).clamp(0.0, 1.0).toDouble();
    final coverage = availableWeight;
    final baseline = (day.baselineDays / 14).clamp(0.0, 1.0);
    final historyConfidence = (recent.length / 21).clamp(0.0, 1.0);
    final meanReliability = signals.isEmpty
        ? 0.0
        : signals.fold<double>(0, (sum, s) => sum + s.reliability) /
            signals.length;
    final rawConfidence = .35 * coverage +
        .2 * baseline +
        .2 * historyConfidence +
        .15 * meanReliability +
        .1 * agreement;
    final confidence = math
        .min(rawConfidence, .25 + .75 * coverage)
        .clamp(0.0, 1.0)
        .toDouble();
    final anomalyCount =
        signals.where((s) => (s.deviation?.abs() ?? 0) >= 2.5).length;
    final state = score < 50
        ? CoachState.restore
        : score >= 72
            ? CoachState.build
            : CoachState.steady;
    final summary = switch (state) {
      CoachState.restore =>
        'Today’s available signals lean toward recovery. Keep the plan flexible and use how you feel as the final check.',
      CoachState.steady =>
        'Your signals are mixed or near their usual range. A normal, sustainable day is the strongest fit.',
      CoachState.build =>
        'Your available signals support planned activity, provided you also feel ready. Increase load gradually.',
    };

    return CoachAssessment(
      score: score,
      confidence: confidence,
      state: state,
      summary: summary,
      signals: signals..sort((a, b) => b.weight.compareTo(a.weight)),
      cards: _advancedRecommendations(
        day,
        profile,
        trendState,
        anomalyCount,
        score,
      ),
      historyDays: recent.length,
      forecastScore: forecast,
      trend: trendState,
      stability: stability,
      anomalyCount: anomalyCount,
    );
  }

  static List<CoachingCard> _advancedRecommendations(
    DailyHealthSummary day,
    UserProfile? profile,
    CoachTrend trend,
    int anomalyCount,
    double score,
  ) {
    final cards = [...recommendations(day, profile)];
    if (anomalyCount > 0) {
      cards.insert(
        0,
        CoachingCard(
          title: 'An unusual pattern was detected',
          message:
              'One or more readings differ strongly from your recent pattern. Check the source data and favor how you feel over the score.',
          tone: CoachingTone.information,
          evidence:
              '$anomalyCount robust statistical outlier${anomalyCount == 1 ? '' : 's'}',
        ),
      );
    } else if (trend == CoachTrend.falling && score < 65) {
      cards.insert(
        0,
        const CoachingCard(
          title: 'Protect the direction of travel',
          message:
              'Your smoothed readiness trend has been declining. Consider reducing optional load and prioritizing repeatable recovery habits.',
          tone: CoachingTone.restore,
          evidence: 'Negative least-squares trend across recent local days',
        ),
      );
    }
    return cards.take(4).toList(growable: false);
  }

  static List<CoachingCard> recommendations(
      DailyHealthSummary day, UserProfile? profile) {
    final cards = <CoachingCard>[];
    final sleep = day.metricFor('sleep').valueOrNull;
    final recovery = day.metricFor('recovery').valueOrNull;
    final strain = day.metricFor('strain').valueOrNull;

    if (sleep != null && sleep < 65) {
      cards.add(CoachingCard(
        title: 'Protect tonight’s sleep window',
        message: profile == null
            ? 'Keep a consistent bedtime and leave a full sleep window tonight.'
            : 'Aim for your ${profile.sleepGoal.inHours}h ${profile.sleepGoal.inMinutes.remainder(60)}m sleep window and begin winding down an hour earlier.',
        tone: CoachingTone.restore,
        evidence: 'Recorded sleep score ${sleep.round()}/100',
      ));
    }
    if (recovery != null && recovery < 45) {
      cards.add(CoachingCard(
        title: 'Choose an easier training day',
        message:
            'Prefer technique work, mobility, or comfortable aerobic movement. Stop if you feel unwell.',
        tone: CoachingTone.restore,
        evidence: 'Recovery ${recovery.round()}/100 versus your baseline',
      ));
    } else if (recovery != null && recovery >= 70) {
      cards.add(CoachingCard(
        title: 'Capacity looks supportive',
        message:
            'If you feel good, today may suit a planned quality session. Increase load gradually.',
        tone: CoachingTone.build,
        evidence: 'Recovery ${recovery.round()}/100 versus your baseline',
      ));
    }
    if (strain != null &&
        profile != null &&
        day.strainRaw > profile.strainTarget) {
      cards.add(CoachingCard(
        title: 'Your training target is covered',
        message:
            'Favor recovery for the rest of the day instead of chasing more load.',
        tone: CoachingTone.maintain,
        evidence:
            'Recorded strain ${day.strainRaw.toStringAsFixed(1)}; target ${profile.strainTarget.toStringAsFixed(1)}',
      ));
    }
    if (day.activity.steps < (profile?.dailyStepGoal ?? 8000) * .45) {
      cards.add(CoachingCard(
        title: 'Add gentle movement if it suits you',
        message:
            'A short comfortable walk can break up inactive time; it does not need to become a workout.',
        tone: CoachingTone.information,
        evidence: '${day.activity.steps} recorded steps today',
      ));
    }
    if (cards.isEmpty) {
      cards.add(const CoachingCard(
        title: 'Keep the day steady',
        message:
            'There is no strong signal to change course. Follow your plan and check how you feel.',
        tone: CoachingTone.maintain,
        evidence: 'No large deviation in the available daily inputs',
      ));
    }
    return cards.take(4).toList(growable: false);
  }

  static List<double> _historyFor(
    String label,
    List<DailyHealthSummary> history,
    UserProfile? profile,
  ) {
    if (label == 'Training balance') {
      if (profile == null || profile.strainTarget <= 0) return const [];
      return history.where((day) => day.hasActivityData).map((day) {
        final ratio = day.strainRaw / profile.strainTarget;
        return ratio <= 1
            ? (55 + ratio * 45).clamp(0, 100).toDouble()
            : (100 - (ratio - 1) * 85).clamp(0, 100).toDouble();
      }).toList();
    }
    final key = switch (label) {
      'Recovery' => 'recovery',
      'Sleep' => 'sleep',
      'Energy' => 'energy',
      'Low stress' => 'stress',
      _ => '',
    };
    return history
        .map((day) => day.metricFor(key).valueOrNull)
        .whereType<double>()
        .map((value) => label == 'Low stress' ? 100 - value : value)
        .toList();
  }

  static double? _robustDeviation(double value, List<double> history) {
    if (history.length < 7) return null;
    final median = _median(history);
    final scale = _robustScale(history);
    if (scale < .5) return 0;
    return ((value - median) / scale).clamp(-3.0, 3.0).toDouble();
  }

  static CoachSignal? _signal(List<CoachSignal> signals, String label) {
    for (final signal in signals) {
      if (signal.label == label) return signal;
    }
    return null;
  }

  static double? _rawComposite(DailyHealthSummary day, UserProfile? profile) {
    var total = 0.0;
    var weight = 0.0;
    void add(String key, double? value) {
      if (value == null) return;
      final itemWeight = _weights[key]!;
      total += value * itemWeight;
      weight += itemWeight;
    }

    add('Recovery', day.metricFor('recovery').valueOrNull);
    add('Sleep', day.metricFor('sleep').valueOrNull);
    add('Energy', day.metricFor('energy').valueOrNull);
    final stress = day.metricFor('stress').valueOrNull;
    add('Low stress', stress == null ? null : 100 - stress);
    if (day.hasActivityData && profile != null && profile.strainTarget > 0) {
      final ratio = day.strainRaw / profile.strainTarget;
      add(
        'Training balance',
        ratio <= 1
            ? (55 + ratio * 45).clamp(0, 100).toDouble()
            : (100 - (ratio - 1) * 85).clamp(0, 100).toDouble(),
      );
    }
    return weight == 0 ? null : total / weight;
  }

  /// Recent observations matter more: alpha=.25 gives roughly 86% of the
  /// influence to the latest seven available observations.
  static double _ewma(List<double> values) {
    var result = values.first;
    for (final value in values.skip(1)) {
      result = .25 * value + .75 * result;
    }
    return result;
  }

  /// Ordinary least-squares slope in score points per observed day.
  static double _linearSlope(List<double> values) {
    if (values.length < 2) return 0;
    final xMean = (values.length - 1) / 2;
    final yMean = values.reduce((a, b) => a + b) / values.length;
    var numerator = 0.0;
    var denominator = 0.0;
    for (var i = 0; i < values.length; i++) {
      final xDelta = i - xMean;
      numerator += xDelta * (values[i] - yMean);
      denominator += xDelta * xDelta;
    }
    return denominator == 0 ? 0 : numerator / denominator;
  }

  static double _robustScale(List<double> values) {
    if (values.isEmpty) return 0;
    final median = _median(values);
    final mad = _median(values.map((item) => (item - median).abs()).toList());
    return 1.4826 * mad;
  }

  static double _standardDeviation(List<double> values) {
    if (values.length < 2) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
            .map((value) => math.pow(value - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        values.length;
    return math.sqrt(variance);
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
