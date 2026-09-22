import 'package:fitx/core/engines/weekly_review_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/health_fixture.dart';

void main() {
  test('weekly review averages only available recorded days', () {
    final days = [
      for (var i = 0; i < 7; i++)
        healthFixture(
          date: DateTime(2026, 9, 8 + i),
          empty: i >= 5,
          scoreValue: 72 + i.toDouble(),
        ),
    ];

    final review = WeeklyReviewEngine.build(
      health: days,
      nutrition: const [],
      workouts: const [],
    );

    expect(review.metrics.first.value, '74%');
    expect(review.metrics.first.detail, '5 of 7 days available');
    expect(review.recordedHealthDays, 5);
    expect(review.focus, 'Keep the rhythm steady');
  });

  test('insufficient sleep history produces a recording focus', () {
    final review = WeeklyReviewEngine.build(
      health: [
        healthFixture(date: DateTime(2026, 9, 13)),
        healthFixture(date: DateTime(2026, 9, 14)),
      ],
      nutrition: const [],
      workouts: const [],
    );

    expect(review.focus, 'Record sleep consistently');
    expect(review.focusReason, contains('four recorded nights'));
  });
}
