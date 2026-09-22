import 'package:shared_preferences/shared_preferences.dart';

class OnboardingProgress {
  const OnboardingProgress(
      {this.step = 0,
      this.name = '',
      this.age = 30,
      this.heightCm = 170,
      this.weightKg = 70,
      this.sleepGoalMinutes = 480,
      this.morningReminder = false,
      this.sleepReminder = false});
  final int step;
  final String name;
  final int age;
  final double heightCm;
  final double weightKg;
  final int sleepGoalMinutes;
  final bool morningReminder;
  final bool sleepReminder;

  OnboardingProgress copyWith(
          {int? step,
          String? name,
          int? age,
          double? heightCm,
          double? weightKg,
          int? sleepGoalMinutes,
          bool? morningReminder,
          bool? sleepReminder}) =>
      OnboardingProgress(
        step: step ?? this.step,
        name: name ?? this.name,
        age: age ?? this.age,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        sleepGoalMinutes: sleepGoalMinutes ?? this.sleepGoalMinutes,
        morningReminder: morningReminder ?? this.morningReminder,
        sleepReminder: sleepReminder ?? this.sleepReminder,
      );
}

abstract interface class OnboardingProgressStore {
  Future<OnboardingProgress> load();
  Future<void> save(OnboardingProgress progress);
  Future<void> complete();
}

class SharedPreferencesOnboardingStore implements OnboardingProgressStore {
  static const completeKey = 'onboarding_complete';
  static const _stepKey = 'onboarding_step';
  static const _nameKey = 'onboarding_name';
  static const _ageKey = 'onboarding_age';
  static const _heightKey = 'onboarding_height_cm';
  static const _weightKey = 'onboarding_weight_kg';
  static const _sleepKey = 'onboarding_sleep_minutes';
  static const _morningKey = 'onboarding_morning_reminder';
  static const _windDownKey = 'onboarding_sleep_reminder';
  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<OnboardingProgress> load() async {
    final p = await _preferences;
    return OnboardingProgress(
      step: (p.getInt(_stepKey) ?? 0).clamp(0, 4),
      name: p.getString(_nameKey) ?? '',
      age: p.getInt(_ageKey) ?? 30,
      heightCm: p.getDouble(_heightKey) ?? 170,
      weightKg: p.getDouble(_weightKey) ?? 70,
      sleepGoalMinutes: p.getInt(_sleepKey) ?? 480,
      morningReminder: p.getBool(_morningKey) ?? false,
      sleepReminder: p.getBool(_windDownKey) ?? false,
    );
  }

  @override
  Future<void> save(OnboardingProgress progress) async {
    final p = await _preferences;
    await Future.wait([
      p.setInt(_stepKey, progress.step),
      p.setString(_nameKey, progress.name),
      p.setInt(_ageKey, progress.age),
      p.setDouble(_heightKey, progress.heightCm),
      p.setDouble(_weightKey, progress.weightKg),
      p.setInt(_sleepKey, progress.sleepGoalMinutes),
      p.setBool(_morningKey, progress.morningReminder),
      p.setBool(_windDownKey, progress.sleepReminder),
    ]);
  }

  @override
  Future<void> complete() async {
    final p = await _preferences;
    await p.setBool(completeKey, true);
    await p.remove(_stepKey);
  }
}
