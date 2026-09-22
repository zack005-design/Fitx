import 'package:equatable/equatable.dart';

enum Gender { male, female, other }

class UserProfile extends Equatable {
  final String name;
  final int age;
  final Gender gender;
  final double heightCm;
  final double weightKg;
  final bool useMetric;
  final int dailyStepGoal;
  final double dailyCalorieGoal;
  final double dailyProteinGoal;
  final Duration sleepGoal;
  final int dailyWaterGoal;
  final double strainTarget;

  const UserProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    this.useMetric = true,
    this.dailyStepGoal = 8000,
    this.dailyCalorieGoal = 2000,
    this.dailyProteinGoal = 120,
    this.sleepGoal = const Duration(hours: 8),
    this.dailyWaterGoal = 2500,
    this.strainTarget = 14,
  });

  double get bmr {
    if (gender == Gender.male) {
      return 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
    } else {
      return 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
    }
  }

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  int get maxHeartRate => 220 - age;

  Map<int, (double, double)> get hrZoneBounds => {
        1: (maxHeartRate * 0.50, maxHeartRate * 0.60),
        2: (maxHeartRate * 0.60, maxHeartRate * 0.70),
        3: (maxHeartRate * 0.70, maxHeartRate * 0.80),
        4: (maxHeartRate * 0.80, maxHeartRate * 0.90),
        5: (maxHeartRate * 0.90, maxHeartRate * 1.00),
      };

  Map<String, dynamic> toMap() => {
        'name': name,
        'age': age,
        'gender': gender.index,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'use_metric': useMetric ? 1 : 0,
        'daily_step_goal': dailyStepGoal,
        'daily_calorie_goal': dailyCalorieGoal,
        'daily_protein_goal': dailyProteinGoal,
        'sleep_goal_minutes': sleepGoal.inMinutes,
        'daily_water_goal': dailyWaterGoal,
        'strain_target': strainTarget,
      };

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        name: m['name'] as String,
        age: m['age'] as int,
        gender: Gender.values[m['gender'] as int],
        heightCm: (m['height_cm'] as num).toDouble(),
        weightKg: (m['weight_kg'] as num).toDouble(),
        useMetric: (m['use_metric'] as int? ?? 1) == 1,
        dailyStepGoal: m['daily_step_goal'] as int? ?? 8000,
        dailyCalorieGoal: (m['daily_calorie_goal'] as num?)?.toDouble() ?? 2000,
        dailyProteinGoal: (m['daily_protein_goal'] as num?)?.toDouble() ?? 120,
        sleepGoal: Duration(minutes: m['sleep_goal_minutes'] as int? ?? 480),
        dailyWaterGoal: m['daily_water_goal'] as int? ?? 2500,
        strainTarget: (m['strain_target'] as num?)?.toDouble() ?? 14,
      );

  UserProfile copyWith({
    String? name,
    int? age,
    Gender? gender,
    double? heightCm,
    double? weightKg,
    bool? useMetric,
    int? dailyStepGoal,
    double? dailyCalorieGoal,
    double? dailyProteinGoal,
    Duration? sleepGoal,
    int? dailyWaterGoal,
    double? strainTarget,
  }) =>
      UserProfile(
        name: name ?? this.name,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        useMetric: useMetric ?? this.useMetric,
        dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
        dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
        dailyProteinGoal: dailyProteinGoal ?? this.dailyProteinGoal,
        sleepGoal: sleepGoal ?? this.sleepGoal,
        dailyWaterGoal: dailyWaterGoal ?? this.dailyWaterGoal,
        strainTarget: strainTarget ?? this.strainTarget,
      );

  @override
  List<Object?> get props => [
        name,
        age,
        gender,
        heightCm,
        weightKg,
        useMetric,
        dailyStepGoal,
        dailyCalorieGoal,
        dailyProteinGoal,
        sleepGoal,
        dailyWaterGoal,
        strainTarget,
      ];
}
