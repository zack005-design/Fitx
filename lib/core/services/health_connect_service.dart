import 'package:health/health.dart';
import '../models/sleep_data.dart';
import '../models/vitals_data.dart';
import '../models/activity_data.dart';
import 'health_data_validator.dart';

class HealthConnectService {
  static final HealthConnectService _instance =
      HealthConnectService._internal();
  factory HealthConnectService() => _instance;
  HealthConnectService._internal();

  final Health _health = Health();

  // Types we want both READ and WRITE access to
  static const List<HealthDataType> _types = [
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.STEPS,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.WORKOUT,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.RESPIRATORY_RATE,
  ];

  // All READ_WRITE — fixes the crash that occurred when the manifest declared
  // WRITE permissions but the Dart side only requested READ.
  static const List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
  ];

  bool _isAuthorized = false;
  bool get isAuthorized => _isAuthorized;

  Future<bool> checkAvailability() async {
    final status = await _health.getHealthConnectSdkStatus();
    return status == HealthConnectSdkStatus.sdkAvailable;
  }

  Future<bool> requestPermissions() async {
    try {
      await _health.configure();
      _isAuthorized = await _health.requestAuthorization(
        _types,
        permissions: _permissions,
      );
      return _isAuthorized;
    } catch (e) {
      _isAuthorized = false;
      return false;
    }
  }

  Future<bool> checkPermissions() async {
    try {
      _isAuthorized =
          await _health.hasPermissions(_types, permissions: _permissions) ??
              false;
      return _isAuthorized;
    } catch (_) {
      return false;
    }
  }

  Future<bool> checkHistoryPermission() =>
      _health.isHealthDataHistoryAuthorized();

  Future<bool> requestHistoryPermission() =>
      _health.requestHealthDataHistoryAuthorization();

  Future<bool> checkBackgroundPermission() =>
      _health.isHealthDataInBackgroundAuthorized();

  Future<bool> requestBackgroundPermission() =>
      _health.requestHealthDataInBackgroundAuthorization();

  // ── VITALS ──────────────────────────────────────────────────────────

  Future<VitalsData> fetchVitals(DateTime date) async {
    final errors = <String>[];
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day + 1);

    final hrData =
        await _fetchType(HealthDataType.HEART_RATE, start, end, errors: errors);
    final rhrData = await _fetchType(
        HealthDataType.RESTING_HEART_RATE, start, end,
        errors: errors);
    final hrvData = await _fetchType(
        HealthDataType.HEART_RATE_VARIABILITY_SDNN, start, end,
        errors: errors);
    final spo2Data = await _fetchType(HealthDataType.BLOOD_OXYGEN, start, end,
        errors: errors);
    final rrData = await _fetchType(HealthDataType.RESPIRATORY_RATE, start, end,
        errors: errors);

    final hrSamples = hrData
        .map((d) => (
              time: d.dateFrom,
              bpm: HealthDataValidator.heartRate(_extractDouble(d.value))
            ))
        .where((sample) => sample.bpm != null)
        .map((sample) => HeartRateSample(time: sample.time, bpm: sample.bpm!))
        .toList();

    final rhr = HealthDataValidator.median(rhrData.map(
        (d) => HealthDataValidator.restingHeartRate(_extractDouble(d.value))));
    final hrv = HealthDataValidator.median(hrvData
        .map((d) => HealthDataValidator.hrvSdnn(_extractDouble(d.value))));
    final spo2 = HealthDataValidator.median(spo2Data.map(
        (d) => HealthDataValidator.oxygenSaturation(_extractDouble(d.value))));
    final rr = HealthDataValidator.median(rrData.map(
        (d) => HealthDataValidator.respiratoryRate(_extractDouble(d.value))));

    return VitalsData(
      date: date,
      readErrors: errors,
      restingHeartRate: rhr,
      hrv: hrv,
      spo2: spo2,
      respiratoryRate: rr,
      heartRateSamples: hrSamples,
    );
  }

  // ── SLEEP ────────────────────────────────────────────────────────────

  Future<SleepData> fetchSleep(DateTime date) async {
    final errors = <String>[];
    // Sleep for a night spans the previous day evening to this morning
    final start = DateTime(date.year, date.month, date.day - 1, 18);
    final end = DateTime(date.year, date.month, date.day, 14);

    final sessionData = await _fetchType(
        HealthDataType.SLEEP_SESSION, start, end,
        errors: errors);
    final asleepData = await _fetchType(HealthDataType.SLEEP_ASLEEP, start, end,
        errors: errors);
    final deepData =
        await _fetchType(HealthDataType.SLEEP_DEEP, start, end, errors: errors);
    final remData =
        await _fetchType(HealthDataType.SLEEP_REM, start, end, errors: errors);
    final lightData = await _fetchType(HealthDataType.SLEEP_LIGHT, start, end,
        errors: errors);
    final awakeData = await _fetchType(HealthDataType.SLEEP_AWAKE, start, end,
        errors: errors);

    DateTime? bedtime;
    DateTime? wakeTime;
    if (sessionData.isNotEmpty) {
      bedtime = sessionData
          .map((d) => d.dateFrom)
          .reduce((first, next) => first.isBefore(next) ? first : next);
      wakeTime = sessionData
          .map((d) => d.dateTo)
          .reduce((last, next) => last.isAfter(next) ? last : next);
    }

    final rawStages = <SleepStageSegment>[];
    void addStages(List<HealthDataPoint> points, SleepStage stage) {
      for (final point in points) {
        if (HealthDataValidator.validDuration(point.dateFrom, point.dateTo) >
            Duration.zero) {
          rawStages.add(SleepStageSegment(
              start: point.dateFrom, end: point.dateTo, stage: stage));
        }
      }
    }

    addStages(deepData, SleepStage.deep);
    addStages(remData, SleepStage.rem);
    addStages(lightData, SleepStage.light);
    addStages(awakeData, SleepStage.awake);
    final stages = _normalizeSleepStages(rawStages);
    Duration stageDuration(SleepStage stage) => stages
        .where((segment) => segment.stage == stage)
        .fold(Duration.zero, (sum, segment) => sum + segment.duration);
    final deep = stageDuration(SleepStage.deep);
    final rem = stageDuration(SleepStage.rem);
    final light = stageDuration(SleepStage.light);
    final awake = stageDuration(SleepStage.awake);

    if (bedtime == null && stages.isNotEmpty) bedtime = stages.first.start;
    if (wakeTime == null && stages.isNotEmpty) wakeTime = stages.last.end;

    final stagedTotal = deep + rem + light;
    final total = stagedTotal > Duration.zero
        ? stagedTotal
        : _mergedDuration(asleepData
            .map((point) => (start: point.dateFrom, end: point.dateTo)));
    final totalWithAwake = total + awake;
    final sessionDuration = bedtime != null && wakeTime != null
        ? wakeTime.difference(bedtime)
        : Duration.zero;
    final measuredWindow =
        sessionDuration > Duration.zero ? sessionDuration : totalWithAwake;
    final efficiency = measuredWindow.inSeconds > 0
        ? (total.inSeconds / measuredWindow.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    final wakeCount = awakeData.length;

    return SleepData(
      date: date,
      readErrors: errors,
      bedtime: bedtime,
      wakeTime: wakeTime,
      totalSleep: total,
      deepDuration: deep,
      remDuration: rem,
      lightDuration: light,
      awakeDuration: awake,
      stages: stages,
      efficiency: efficiency,
      wakeCount: wakeCount,
      source: SleepDataSource.healthConnect,
    );
  }

  // ── ACTIVITY ──────────────────────────────────────────────────────────

  Future<ActivityData> fetchActivity(DateTime date) async {
    final errors = <String>[];
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day + 1);

    final stepsData =
        await _fetchType(HealthDataType.STEPS, start, end, errors: errors);
    final activeCalData = await _fetchType(
        HealthDataType.ACTIVE_ENERGY_BURNED, start, end,
        errors: errors);
    final totalCalData = await _fetchType(
        HealthDataType.TOTAL_CALORIES_BURNED, start, end,
        errors: errors);
    final workoutData =
        await _fetchType(HealthDataType.WORKOUT, start, end, errors: errors);

    // Health Connect's aggregate API applies the user's source priorities and
    // avoids double-counting phone, watch, and third-party step records.
    final steps = await _fetchStepTotal(start, end, stepsData);

    final activeCal = activeCalData.fold(
        0.0,
        (sum, d) =>
            sum +
            HealthDataValidator.nonNegative(_extractDouble(d.value),
                maximum: 20000));

    final totalCal = totalCalData.isNotEmpty
        ? totalCalData.fold(
            0.0,
            (sum, d) =>
                sum +
                HealthDataValidator.nonNegative(_extractDouble(d.value),
                    maximum: 30000))
        : 0.0;

    // Build workout sessions
    final workouts = workoutData
        .map((d) {
          final cal = HealthDataValidator.nonNegative(_extractDouble(d.value),
              maximum: 10000);
          final duration =
              HealthDataValidator.validDuration(d.dateFrom, d.dateTo);
          return WorkoutSession(
            id: '${d.dateFrom.millisecondsSinceEpoch}',
            type: WorkoutType.other,
            start: d.dateFrom,
            end: d.dateFrom.add(duration),
            calories: cal,
            strainContribution: 0,
            hrZones: [],
          );
        })
        .where((workout) => workout.duration > Duration.zero)
        .toList();

    final activeTime =
        workouts.fold(Duration.zero, (sum, w) => sum + w.duration);

    return ActivityData(
      date: date,
      readErrors: errors,
      steps: steps,
      activeCalories: activeCal,
      totalCalories: totalCal,
      workouts: workouts,
      activeTime: activeTime,
    );
  }

  // Fetch HR data for a time window (for stress monitoring)
  Future<List<HeartRateSample>> fetchHeartRateSamples(
      DateTime start, DateTime end) async {
    final data = await _fetchType(HealthDataType.HEART_RATE, start, end);
    return data
        .map((d) => HeartRateSample(
              time: d.dateFrom,
              bpm: _extractDouble(d.value),
            ))
        .toList();
  }

  // ── WRITE METHODS ─────────────────────────────────────────────────────

  /// Write a step count record to Google Health Connect.
  Future<bool> writeSteps(DateTime start, DateTime end, int steps) async {
    if (HealthDataValidator.validDuration(start, end) == Duration.zero ||
        steps < 0 ||
        steps > 200000) {
      return false;
    }
    try {
      return await _health.writeHealthData(
        value: steps.toDouble(),
        type: HealthDataType.STEPS,
        startTime: start,
        endTime: end,
      );
    } catch (_) {
      return false;
    }
  }

  /// Write a heart rate sample (single bpm reading at [time]) to Health Connect.
  Future<bool> writeHeartRate(DateTime time, double bpm) async {
    if (HealthDataValidator.heartRate(bpm) == null) return false;
    try {
      return await _health.writeHealthData(
        value: bpm,
        type: HealthDataType.HEART_RATE,
        startTime: time,
        endTime: time.add(const Duration(seconds: 1)),
      );
    } catch (_) {
      return false;
    }
  }

  /// Write a resting heart rate value for a given day.
  Future<bool> writeRestingHeartRate(DateTime date, double bpm) async {
    if (HealthDataValidator.restingHeartRate(bpm) == null) return false;
    try {
      final start = DateTime(date.year, date.month, date.day);
      final end = DateTime(date.year, date.month, date.day + 1);
      return await _health.writeHealthData(
        value: bpm,
        type: HealthDataType.RESTING_HEART_RATE,
        startTime: start,
        endTime: end,
      );
    } catch (_) {
      return false;
    }
  }

  /// Write an HRV (SDNN) value for a given day.
  Future<bool> writeHrv(DateTime date, double sdnnMs) async {
    if (HealthDataValidator.hrvSdnn(sdnnMs) == null) return false;
    try {
      final start = DateTime(date.year, date.month, date.day);
      final end = DateTime(date.year, date.month, date.day + 1);
      return await _health.writeHealthData(
        value: sdnnMs,
        type: HealthDataType.HEART_RATE_VARIABILITY_SDNN,
        startTime: start,
        endTime: end,
      );
    } catch (_) {
      return false;
    }
  }

  /// Write active calories burned over a time window.
  Future<bool> writeActiveCalories(
      DateTime start, DateTime end, double kcal) async {
    if (HealthDataValidator.validDuration(start, end) == Duration.zero ||
        !kcal.isFinite ||
        kcal < 0 ||
        kcal > 20000) {
      return false;
    }
    try {
      return await _health.writeHealthData(
        value: kcal,
        type: HealthDataType.ACTIVE_ENERGY_BURNED,
        startTime: start,
        endTime: end,
      );
    } catch (_) {
      return false;
    }
  }

  /// Write a blood oxygen (SpO2) reading (0–100 percent).
  Future<bool> writeBloodOxygen(DateTime time, double percent) async {
    final normalized = HealthDataValidator.oxygenSaturation(percent);
    if (normalized == null) return false;
    try {
      return await _health.writeHealthData(
        value: normalized,
        type: HealthDataType.BLOOD_OXYGEN,
        startTime: time,
        endTime: time.add(const Duration(seconds: 1)),
      );
    } catch (_) {
      return false;
    }
  }

  /// Write a respiratory rate reading (breaths per minute).
  Future<bool> writeRespiratoryRate(DateTime time, double breathsPerMin) async {
    if (HealthDataValidator.respiratoryRate(breathsPerMin) == null) {
      return false;
    }
    try {
      return await _health.writeHealthData(
        value: breathsPerMin,
        type: HealthDataType.RESPIRATORY_RATE,
        startTime: time,
        endTime: time.add(const Duration(seconds: 1)),
      );
    } catch (_) {
      return false;
    }
  }

  /// Write a sleep session to Health Connect.
  /// [deepMinutes], [remMinutes], [lightMinutes], [awakeMinutes] are optional breakdowns.
  Future<bool> writeSleepSession({
    required DateTime bedtime,
    required DateTime wakeTime,
    int deepMinutes = 0,
    int remMinutes = 0,
    int lightMinutes = 0,
    int awakeMinutes = 0,
  }) async {
    final session = HealthDataValidator.validDuration(bedtime, wakeTime);
    final stageMinutes = deepMinutes + remMinutes + lightMinutes + awakeMinutes;
    if (session == Duration.zero ||
        [deepMinutes, remMinutes, lightMinutes, awakeMinutes]
            .any((minutes) => minutes < 0) ||
        stageMinutes > session.inMinutes) {
      return false;
    }
    try {
      // Write the overall session
      final sessionOk = await _health.writeHealthData(
        value: 0,
        type: HealthDataType.SLEEP_SESSION,
        startTime: bedtime,
        endTime: wakeTime,
      );

      // Write stage breakdowns (starting from bedtime)
      DateTime cursor = bedtime;

      if (deepMinutes > 0) {
        final stageEnd = cursor.add(Duration(minutes: deepMinutes));
        await _health.writeHealthData(
          value: 0,
          type: HealthDataType.SLEEP_DEEP,
          startTime: cursor,
          endTime: stageEnd,
        );
        cursor = stageEnd;
      }
      if (remMinutes > 0) {
        final stageEnd = cursor.add(Duration(minutes: remMinutes));
        await _health.writeHealthData(
          value: 0,
          type: HealthDataType.SLEEP_REM,
          startTime: cursor,
          endTime: stageEnd,
        );
        cursor = stageEnd;
      }
      if (lightMinutes > 0) {
        final stageEnd = cursor.add(Duration(minutes: lightMinutes));
        await _health.writeHealthData(
          value: 0,
          type: HealthDataType.SLEEP_LIGHT,
          startTime: cursor,
          endTime: stageEnd,
        );
        cursor = stageEnd;
      }
      if (awakeMinutes > 0) {
        final stageEnd = cursor.add(Duration(minutes: awakeMinutes));
        await _health.writeHealthData(
          value: 0,
          type: HealthDataType.SLEEP_AWAKE,
          startTime: cursor,
          endTime: stageEnd,
        );
      }

      return sessionOk;
    } catch (_) {
      return false;
    }
  }

  /// Write a workout/exercise session to Health Connect.
  Future<bool> writeWorkout({
    required HealthWorkoutActivityType activityType,
    required DateTime start,
    required DateTime end,
    double? totalEnergyBurned,
  }) async {
    if (HealthDataValidator.validDuration(start, end) == Duration.zero ||
        (totalEnergyBurned != null &&
            (!totalEnergyBurned.isFinite ||
                totalEnergyBurned < 0 ||
                totalEnergyBurned > 10000))) {
      return false;
    }
    try {
      return await _health.writeWorkoutData(
        activityType: activityType,
        start: start,
        end: end,
        totalEnergyBurned: totalEnergyBurned?.toInt(),
        totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
      );
    } catch (_) {
      return false;
    }
  }

  // ── PRIVATE HELPERS ───────────────────────────────────────────────────

  double _extractDouble(HealthValue value) {
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    } else if (value is WorkoutHealthValue) {
      return value.totalEnergyBurned?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  Future<List<HealthDataPoint>> _fetchType(
      HealthDataType type, DateTime start, DateTime end,
      {List<String>? errors}) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [type],
      );
      return _health.removeDuplicates(points)
        ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    } catch (_) {
      errors?.add(type.name);
      return [];
    }
  }

  Future<int> _fetchStepTotal(
    DateTime start,
    DateTime end,
    List<HealthDataPoint> fallbackPoints,
  ) async {
    try {
      final total = await _health.getTotalStepsInInterval(start, end) ??
          fallbackPoints.fold<int>(
            0,
            (sum, point) => sum + _extractDouble(point.value).toInt(),
          );
      return HealthDataValidator.roundedNonNegative(total, maximum: 200000);
    } catch (_) {
      final total = fallbackPoints.fold<int>(
        0,
        (sum, point) => sum + _extractDouble(point.value).toInt(),
      );
      return HealthDataValidator.roundedNonNegative(total, maximum: 200000);
    }
  }

  List<SleepStageSegment> _normalizeSleepStages(List<SleepStageSegment> raw) {
    if (raw.isEmpty) return const [];
    final boundaries = raw.expand((s) => [s.start, s.end]).toSet().toList()
      ..sort();
    final result = <SleepStageSegment>[];
    const priority = [
      SleepStage.awake,
      SleepStage.deep,
      SleepStage.rem,
      SleepStage.light
    ];
    for (var i = 0; i < boundaries.length - 1; i++) {
      final start = boundaries[i];
      final end = boundaries[i + 1];
      if (!end.isAfter(start)) continue;
      final covering = raw
          .where((s) => !s.start.isAfter(start) && !s.end.isBefore(end))
          .map((s) => s.stage)
          .toSet();
      SleepStage? stage;
      for (final candidate in priority) {
        if (covering.contains(candidate)) {
          stage = candidate;
          break;
        }
      }
      if (stage == null) continue;
      if (result.isNotEmpty &&
          result.last.stage == stage &&
          result.last.end == start) {
        final previous = result.removeLast();
        result.add(
            SleepStageSegment(start: previous.start, end: end, stage: stage));
      } else {
        result.add(SleepStageSegment(start: start, end: end, stage: stage));
      }
    }
    return result;
  }

  Duration _mergedDuration(
      Iterable<({DateTime start, DateTime end})> intervals) {
    final valid = intervals
        .where((x) =>
            HealthDataValidator.validDuration(x.start, x.end) > Duration.zero)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    if (valid.isEmpty) return Duration.zero;
    var start = valid.first.start;
    var end = valid.first.end;
    var total = Duration.zero;
    for (final interval in valid.skip(1)) {
      if (!interval.start.isAfter(end)) {
        if (interval.end.isAfter(end)) end = interval.end;
      } else {
        total += end.difference(start);
        start = interval.start;
        end = interval.end;
      }
    }
    return total + end.difference(start);
  }
}
