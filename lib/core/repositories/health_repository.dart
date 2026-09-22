import '../models/health_score.dart';
import '../models/sleep_data.dart';
import '../models/vitals_data.dart';
import '../models/activity_data.dart';
import '../models/daily_health_summary.dart';
import '../models/health_day.dart';
import '../models/metric_value.dart';
import '../services/health_connect_service.dart';
import '../services/database_service.dart';
import '../engines/recovery_engine.dart';
import '../engines/sleep_engine.dart';
import '../engines/strain_engine.dart';
import '../engines/stress_engine.dart';
import '../engines/energy_engine.dart';
import '../models/user_profile.dart';
export '../models/daily_health_summary.dart';

class HealthRepository {
  final HealthConnectService _hc;
  final DatabaseService _db;
  final DateTime Function() clock;
  final Map<DateTime, List<String>> _readFailures = {};
  final Map<DateTime, Future<DailyHealthSummary>> _activeReads = {};
  HealthRepository(
      {HealthConnectService? hc,
      DatabaseService? db,
      DateTime Function()? clock})
      : _hc = hc ?? HealthConnectService(),
        _db = db ?? DatabaseService(),
        clock = clock ?? DateTime.now;

  Future<DailyHealthSummary> getDailySummary(
      DateTime requested, UserProfile? profile,
      {bool refresh = false}) async {
    final date = healthDay(requested);
    final active = _activeReads[date];
    if (active != null) return active;
    final read = _loadDailySummary(date, profile, refresh: refresh);
    _activeReads[date] = read;
    try {
      return await read;
    } finally {
      _activeReads.remove(date);
    }
  }

  Future<DailyHealthSummary> _loadDailySummary(
      DateTime date, UserProfile? profile,
      {required bool refresh}) async {
    final cached = await _db.getHealthSnapshot(date);
    if (!refresh &&
        cached != null &&
        (date != healthDay(clock()) ||
            (cached.syncedAt != null &&
                clock().difference(cached.syncedAt!).inMinutes < 15))) {
      return cached.withReadErrors(_readFailures[date] ?? cached.readErrors);
    }
    final vitals = await _hc.fetchVitals(date);
    final healthConnectSleep = await _hc.fetchSleep(date);
    final phoneSleep = await _db.getPhoneSleep(date);
    final sleepData = _preferredSleep(healthConnectSleep, phoneSleep);
    final activity = await _hc.fetchActivity(date);
    final baseline = await _db.getPersonalBaseline(date);
    if (vitals.hrv != null) await _db.saveHrvReading(date, vitals.hrv!);
    if (vitals.restingHeartRate != null) {
      await _db.saveRhrReading(date, vitals.restingHeartRate!);
    }
    final sleep = profile == null || sleepData.totalSleep == Duration.zero
        ? HealthScore.empty(date)
        : SleepEngine.compute(sleep: sleepData, sleepGoal: profile.sleepGoal);
    final recovery = RecoveryEngine.compute(
        date: date,
        vitals: vitals,
        sleepScore: sleep,
        hrvBaseline: baseline.hrv,
        rhrBaseline: baseline.rhr);
    final strain = profile == null
        ? (score: HealthScore.empty(date), raw: 0.0)
        : StrainEngine.compute(
            date: date, activity: activity, profile: profile);
    final stress = StressEngine.compute(
        date: date,
        vitals: vitals,
        hrvBaseline: baseline.hrv,
        rhrBaseline: baseline.rhr);
    final energy = profile == null
        ? HealthScore.empty(date)
        : EnergyEngine.compute(
            date: date,
            recoveryScore: recovery,
            strainRaw: strain.raw,
            strainTarget: profile.strainTarget);
    final summary = DailyHealthSummary(
        date: date,
        recovery: recovery,
        sleep: sleep,
        sleepData: sleepData,
        strain: strain.score,
        strainRaw: strain.raw,
        stress: stress,
        energy: energy,
        vitals: vitals,
        activity: activity,
        baselineDays: baseline.days,
        hrvBaseline: baseline.hrv,
        rhrBaseline: baseline.rhr,
        syncedAt: clock(),
        sleepGoal: profile?.sleepGoal,
        strainTarget: profile?.strainTarget,
        readErrors: [
          ...vitals.readErrors,
          ...sleepData.readErrors,
          ...activity.readErrors
        ]);
    // Never replace a useful saved day after a source read failed.
    if (summary.readErrors.isNotEmpty) {
      _readFailures[date] = summary.readErrors;
      if (cached != null) return cached.withReadErrors(summary.readErrors);
    } else {
      _readFailures.remove(date);
    }
    await _db.saveHealthSnapshot(summary);
    for (final type in ['recovery', 'sleep', 'strain', 'stress', 'energy']) {
      if (summary.statusFor(type) == MetricStatus.available) {
        await _db.saveScore(type, summary.scoreFor(type));
      }
    }
    return summary;
  }

  /// Only reconstructed, provenance-bearing days enter history. Legacy cached
  /// scores may contain neutral fallbacks, so they are deliberately excluded.
  Future<List<DailyHealthSummary>> getHistory(DateTime end, {int days = 30}) =>
      _db.getHealthSnapshots(end, days: days);
  Future<List<HealthScore>> getScoreHistory(String type,
          {int days = 30, DateTime? endDate}) async =>
      (await getHistory(endDate ?? clock(), days: days))
          .where((s) => s.statusFor(type) == MetricStatus.available)
          .map((s) => s.scoreFor(type))
          .toList();
  Future<SleepData> getSleep(DateTime date) => _hc.fetchSleep(date);
  Future<VitalsData> getVitals(DateTime date) => _hc.fetchVitals(date);
  Future<ActivityData> getActivity(DateTime date) => _hc.fetchActivity(date);

  static SleepData _preferredSleep(SleepData healthConnect, SleepData? phone) {
    if (phone == null || phone.totalSleep <= Duration.zero) {
      return healthConnect;
    }
    // A staged wearable record contains signals the phone cannot infer. When
    // Health Connect has only a duration, prefer the locally measured session
    // if its sensor coverage is good enough to provide sleep/wake timing.
    final hasWearableStages = healthConnect.stages
        .any((s) => s.stage == SleepStage.deep || s.stage == SleepStage.rem);
    if (hasWearableStages) return healthConnect;
    if (healthConnect.totalSleep <= Duration.zero ||
        (phone.confidence ?? 0) >= .65) {
      return phone;
    }
    return healthConnect;
  }
}
