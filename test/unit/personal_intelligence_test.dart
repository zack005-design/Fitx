import 'package:fitx/core/engines/motion_classifier.dart';
import 'package:fitx/core/engines/personal_intelligence_engine.dart';
import 'package:fitx/core/models/user_profile.dart';
import 'package:fitx/core/services/device_sensor_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/health_fixture.dart';

void main() {
  const profile = UserProfile(
    name: 'Local user',
    age: 30,
    gender: Gender.other,
    heightCm: 170,
    weightKg: 70,
  );

  test('biological age requires seven observed days', () {
    final days = List.generate(
      6,
      (index) => healthFixture(date: DateTime(2026, 9, index + 1)),
    );
    expect(BiologicalAgeEngine.estimate(profile, days), isNull);
    days.add(healthFixture(date: DateTime(2026, 9, 7)));
    final estimate = BiologicalAgeEngine.estimate(profile, days);
    expect(estimate, isNotNull);
    expect(estimate!.observedDays, 7);
    expect(estimate.factors, isNotEmpty);
    expect(estimate.contributors, isNotEmpty);
    expect(estimate.weeklyFocus, isNotNull);
    expect(estimate.paceOfAging, isNull);
  });

  test('healthspan compares recent habits with the preceding period', () {
    final days = List.generate(
      60,
      (index) => healthFixture(date: DateTime(2026, 7, index + 1)),
    );
    final estimate = BiologicalAgeEngine.estimate(profile, days);
    expect(estimate, isNotNull);
    expect(estimate!.paceOfAging, closeTo(1, .01));
    expect(estimate.confidence, closeTo(60 / 90, .01));
    expect(
      estimate.contributors.map((item) => item.title),
      containsAll(<String>[
        'Sleep duration',
        'Sleep consistency',
        'Daily movement',
        'Active time',
        'Strength training',
        'Resting heart rate',
      ]),
    );
  });

  test('private coach cites the local observations it uses', () {
    final cards = PrivateCoachEngine.recommendations(
      healthFixture(scoreValue: 40),
      profile,
    );
    expect(cards, isNotEmpty);
    expect(cards.every((card) => card.evidence.isNotEmpty), isTrue);
    expect(cards.any((card) => card.tone == CoachingTone.restore), isTrue);
  });

  test('local coach creates a weighted, confidence-scored assessment', () {
    final history = List.generate(
      14,
      (index) => healthFixture(
        date: DateTime(2026, 8, index + 1),
        scoreValue: 65 + index / 2,
      ),
    );
    final assessment = PrivateCoachEngine.assess(
      healthFixture(date: DateTime(2026, 9, 1), scoreValue: 78),
      profile,
      history: history,
    );

    expect(assessment.score, inInclusiveRange(0, 100));
    expect(assessment.confidence, greaterThan(.8));
    expect(assessment.historyDays, 14);
    expect(assessment.forecastScore, isNotNull);
    expect(assessment.trend, CoachTrend.rising);
    expect(assessment.stability, inInclusiveRange(0, 1));
    expect(assessment.signals, isNotEmpty);
    expect(assessment.signals.every((signal) => signal.evidence.isNotEmpty),
        isTrue);
    expect(assessment.signals.first.deviation, isNotNull);
    expect(
        assessment.signals.every(
            (signal) => signal.reliability >= 0 && signal.reliability <= 1),
        isTrue);
  });

  test('local coach remains useful without historical data', () {
    final assessment = PrivateCoachEngine.assess(
      healthFixture(scoreValue: 60),
      profile,
    );
    expect(assessment.score, inInclusiveRange(0, 100));
    expect(assessment.historyDays, 0);
    expect(
        assessment.signals.every((signal) => signal.deviation == null), isTrue);
    expect(assessment.forecastScore, isNull);
    expect(assessment.trend, CoachTrend.learning);
  });

  test('local coach detects strong deviations in local history', () {
    final history = List.generate(
      21,
      (index) => healthFixture(
        date: DateTime(2026, 8, index + 1),
        scoreValue: 67 + (index % 5),
      ),
    );
    final assessment = PrivateCoachEngine.assess(
      healthFixture(date: DateTime(2026, 9, 1), scoreValue: 20),
      profile,
      history: history,
    );

    expect(assessment.anomalyCount, greaterThan(0));
    expect(assessment.cards.first.title, contains('unusual pattern'));
    expect(assessment.confidence, inInclusiveRange(0, 1));
  });

  test('motion classifier recognizes step cadence without naming an exercise',
      () {
    final classifier = MotionClassifier();
    MotionGuidance? result;
    for (var i = 0; i < 8; i++) {
      final time = 1000000000 + i * 400000000;
      result = classifier.add(DeviceSensorSample(
        type: 'accelerometer',
        timestampNanos: time,
        values: const [0, 0, 9.81],
      ));
      if (i.isEven) {
        result = classifier.add(DeviceSensorSample(
          type: 'stepDetector',
          timestampNanos: time + 1,
          values: const [1],
        ));
      }
    }
    expect(result!.motion, GuidedMotion.walking);
    expect(result.cadence, greaterThanOrEqualTo(45));
  });
}
