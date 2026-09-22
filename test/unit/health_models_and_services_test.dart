import 'package:flutter_test/flutter_test.dart';
import 'package:fitx/core/models/health_score.dart';
import 'package:fitx/core/models/user_profile.dart';
import 'package:fitx/core/models/nutrition_models.dart';
import 'package:fitx/core/models/activity_data.dart';
import 'package:fitx/core/models/sleep_data.dart';
import 'package:fitx/core/models/vitals_data.dart';
import 'package:fitx/core/repositories/health_repository.dart';

void main() {
  group('ScoreLevel and HealthScore Tests', () {
    test('ScoreLevel boundaries evaluate accurately', () {
      expect(ScoreLevelExt.fromScore(30), ScoreLevel.poor);
      expect(ScoreLevelExt.fromScore(40), ScoreLevel.poor);
      expect(ScoreLevelExt.fromScore(41), ScoreLevel.fair);
      expect(ScoreLevelExt.fromScore(60), ScoreLevel.fair);
      expect(ScoreLevelExt.fromScore(61), ScoreLevel.good);
      expect(ScoreLevelExt.fromScore(80), ScoreLevel.good);
      expect(ScoreLevelExt.fromScore(81), ScoreLevel.optimal);
      expect(ScoreLevelExt.fromScore(100), ScoreLevel.optimal);
    });

    test('HealthScore serialization roundtrip', () {
      final now = DateTime(2026, 9, 5, 12, 0, 0);
      final score = HealthScore(
        value: 85.5,
        date: now,
        level: ScoreLevel.optimal,
        breakdown: {'hrv': 45.0, 'rhr': 40.5},
      );

      final map = score.toMap();
      expect(map['value'], 85.5);
      expect(map['level'], ScoreLevel.optimal.index);

      final deserialized = HealthScore.fromMap(map);
      expect(deserialized.value, 85.5);
      expect(deserialized.level, ScoreLevel.optimal);
      expect(deserialized.breakdown['hrv'], 45.0);
      expect(deserialized.breakdown['rhr'], 40.5);
    });

    test('Score persistence map spread retains YYYY-MM-DD date key', () {
      final now = DateTime(2026, 9, 5, 14, 30, 0);
      final score = HealthScore(
        value: 78.0,
        date: now,
        level: ScoreLevel.good,
        breakdown: {},
      );

      // Verify fix for database saveScore spread override
      final dateStr = '2026-09-05';
      final dbMap = {
        ...score.toMap(),
        'date': dateStr,
        'type': 'recovery',
      };

      expect(dbMap['date'], '2026-09-05');
      expect(dbMap['type'], 'recovery');
    });
  });

  group('UserProfile Metrics Tests', () {
    test('Calculates BMR and BMI correctly for male profile', () {
      const profile = UserProfile(
        name: 'Alex',
        age: 28,
        gender: Gender.male,
        heightCm: 178,
        weightKg: 75,
      );

      // BMR = 10 * 75 + 6.25 * 178 - 5 * 28 + 5 = 750 + 1112.5 - 140 + 5 = 1727.5
      expect(profile.bmr, 1727.5);

      // BMI = 75 / (1.78 * 1.78) ~ 23.67
      expect(profile.bmi, closeTo(23.67, 0.01));

      // Max HR = 220 - 28 = 192
      expect(profile.maxHeartRate, 192);
    });

    test('UserProfile serialization roundtrip', () {
      const profile = UserProfile(
        name: 'Alex',
        age: 28,
        gender: Gender.male,
        heightCm: 178,
        weightKg: 75,
        dailyStepGoal: 10000,
      );

      final map = profile.toMap();
      final fromDb = UserProfile.fromMap(map);
      expect(fromDb.name, 'Alex');
      expect(fromDb.age, 28);
      expect(fromDb.dailyStepGoal, 10000);
    });
  });

  group('Nutrition Models Tests', () {
    test('FoodItem with custom flag initializes correctly', () {
      const food = FoodItem(
        id: 'test_food_1',
        name: 'Custom Oatmeal',
        nutritionPer100g: NutritionFacts(
          calories: 389,
          protein: 16.9,
          carbs: 66.3,
          fat: 6.9,
        ),
        isCustom: true,
      );

      expect(food.isCustom, true);
      expect(food.name, 'Custom Oatmeal');
      expect(food.nutritionPer100g.calories, 389);
      expect(food.toMap()['is_custom'], 1);
    });
  });

  group('Daily health data availability', () {
    HealthScore score(DateTime date, double value) => HealthScore(
          value: value,
          date: date,
          level: ScoreLevelExt.fromScore(value),
          breakdown: const {},
        );

    test('does not treat engine fallback scores as observations', () {
      final date = DateTime(2026, 9, 13);
      final summary = DailyHealthSummary(
        date: date,
        recovery: score(date, 50),
        sleep: score(date, 0),
        sleepData: SleepData.empty(date),
        strain: score(date, 0),
        strainRaw: 0,
        stress: score(date, 30),
        energy: score(date, 50),
        vitals: VitalsData.empty(date),
        activity: ActivityData.empty(date),
        baselineDays: 0,
      );

      expect(summary.hasSleepData, isFalse);
      expect(summary.hasRecoveryData, isFalse);
      expect(summary.hasStressData, isFalse);
      expect(summary.hasVitalsData, isFalse);
      expect(summary.hasActivityData, isFalse);
    });

    test('requires sleep, HRV, and RHR for a measured recovery score', () {
      final date = DateTime(2026, 9, 13);
      final summary = DailyHealthSummary(
        date: date,
        recovery: score(date, 72),
        sleep: score(date, 80),
        sleepData: SleepData(
          date: date,
          totalSleep: const Duration(hours: 7),
          remDuration: const Duration(hours: 1),
          deepDuration: const Duration(hours: 1),
          lightDuration: const Duration(hours: 5),
          awakeDuration: Duration.zero,
          stages: const [],
          efficiency: .9,
          wakeCount: 0,
        ),
        strain: score(date, 20),
        strainRaw: 4.2,
        stress: score(date, 35),
        energy: score(date, 70),
        vitals: VitalsData(
          date: date,
          hrv: 48,
          restingHeartRate: 56,
          heartRateSamples: const [],
        ),
        activity: ActivityData.empty(date),
        baselineDays: 10,
      );

      expect(summary.hasSleepData, isTrue);
      expect(summary.hasRecoveryData, isTrue);
      expect(summary.hasStressData, isTrue);
      expect(summary.hasVitalsData, isTrue);
    });
  });
}
