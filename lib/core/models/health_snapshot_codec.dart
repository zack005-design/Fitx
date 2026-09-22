import 'activity_data.dart';
import 'daily_health_summary.dart';
import 'health_score.dart';
import 'sleep_data.dart';
import 'vitals_data.dart';

/// Versioned raw daily aggregates preserve the inputs used for explanations.
class HealthSnapshotCodec {
  static Map<String, dynamic> encode(DailyHealthSummary s) => {
        'date': s.date.toIso8601String(),
        'syncedAt': s.syncedAt?.toIso8601String(),
        'formulaVersion': s.formulaVersion,
        'baselineDays': s.baselineDays,
        'hrvBaseline': s.hrvBaseline,
        'rhrBaseline': s.rhrBaseline,
        'sleepGoal': s.sleepGoal?.inSeconds,
        'strainTarget': s.strainTarget,
        'readErrors': s.readErrors,
        'scores': {
          for (final type in [
            'recovery',
            'sleep',
            'strain',
            'stress',
            'energy'
          ])
            type: s.scoreFor(type).toMap()
        },
        'strainRaw': s.strainRaw,
        'sleep': {
          'bedtime': s.sleepData.bedtime?.toIso8601String(),
          'wakeTime': s.sleepData.wakeTime?.toIso8601String(),
          'total': s.sleepData.totalSleep.inSeconds,
          'deep': s.sleepData.deepDuration.inSeconds,
          'rem': s.sleepData.remDuration.inSeconds,
          'light': s.sleepData.lightDuration.inSeconds,
          'awake': s.sleepData.awakeDuration.inSeconds,
          'efficiency': s.sleepData.efficiency,
          'wakeCount': s.sleepData.wakeCount,
          'source': s.sleepData.source.index,
          'confidence': s.sleepData.confidence,
          'limitations': s.sleepData.limitations,
          'stages': [
            for (final x in s.sleepData.stages)
              {
                'start': x.start.toIso8601String(),
                'end': x.end.toIso8601String(),
                'stage': x.stage.index
              }
          ],
        },
        'vitals': {
          'hrv': s.vitals.hrv,
          'rhr': s.vitals.restingHeartRate,
          'spo2': s.vitals.spo2,
          'rr': s.vitals.respiratoryRate,
          'samples': [
            for (final x in s.vitals.heartRateSamples)
              {'time': x.time.toIso8601String(), 'bpm': x.bpm}
          ]
        },
        'activity': {
          'steps': s.activity.steps,
          'activeCalories': s.activity.activeCalories,
          'totalCalories': s.activity.totalCalories,
          'activeTime': s.activity.activeTime.inSeconds,
          'workouts': [
            for (final w in s.activity.workouts)
              {
                'id': w.id,
                'type': w.type.index,
                'start': w.start.toIso8601String(),
                'end': w.end.toIso8601String(),
                'calories': w.calories,
                'avgHr': w.avgHeartRate,
                'maxHr': w.maxHeartRate,
                'strain': w.strainContribution,
                'zones': [
                  for (final z in w.hrZones)
                    {
                      'zone': z.zone,
                      'duration': z.duration.inSeconds,
                      'min': z.minBpm,
                      'max': z.maxBpm
                    }
                ],
              }
          ]
        },
      };

  static DailyHealthSummary decode(Map<String, dynamic> m) {
    final date = DateTime.parse(m['date']);
    final sl = m['sleep'] as Map<String, dynamic>;
    final v = m['vitals'] as Map<String, dynamic>;
    final a = m['activity'] as Map<String, dynamic>;
    HealthScore score(String key) => HealthScore.fromMap(m['scores'][key]);
    DateTime? time(dynamic value) =>
        value == null ? null : DateTime.parse(value as String);
    double? number(dynamic value) => (value as num?)?.toDouble();
    return DailyHealthSummary(
      date: date,
      recovery: score('recovery'),
      sleep: score('sleep'),
      strain: score('strain'),
      stress: score('stress'),
      energy: score('energy'),
      strainRaw: number(m['strainRaw'])!,
      baselineDays: m['baselineDays'],
      hrvBaseline: number(m['hrvBaseline']),
      rhrBaseline: number(m['rhrBaseline']),
      syncedAt: time(m['syncedAt']),
      formulaVersion: m['formulaVersion'],
      sleepGoal:
          m['sleepGoal'] == null ? null : Duration(seconds: m['sleepGoal']),
      strainTarget: number(m['strainTarget']),
      readErrors: List<String>.from(m['readErrors'] ?? []),
      sleepData: SleepData(
          date: date,
          bedtime: time(sl['bedtime']),
          wakeTime: time(sl['wakeTime']),
          totalSleep: Duration(seconds: sl['total']),
          remDuration: Duration(seconds: sl['rem']),
          deepDuration: Duration(seconds: sl['deep']),
          lightDuration: Duration(seconds: sl['light']),
          awakeDuration: Duration(seconds: sl['awake']),
          efficiency: number(sl['efficiency'])!,
          wakeCount: sl['wakeCount'],
          source: SleepDataSource.values[(sl['source'] as num?)?.toInt() ?? 0],
          confidence: number(sl['confidence']),
          limitations: List<String>.from(sl['limitations'] ?? const []),
          stages: [
            for (final x in sl['stages'])
              SleepStageSegment(
                  start: time(x['start'])!,
                  end: time(x['end'])!,
                  stage: SleepStage.values[x['stage']])
          ]),
      vitals: VitalsData(
          date: date,
          hrv: number(v['hrv']),
          restingHeartRate: number(v['rhr']),
          spo2: number(v['spo2']),
          respiratoryRate: number(v['rr']),
          heartRateSamples: [
            for (final x in v['samples'])
              HeartRateSample(time: time(x['time'])!, bpm: number(x['bpm'])!)
          ]),
      activity: ActivityData(
          date: date,
          steps: a['steps'],
          activeCalories: number(a['activeCalories'])!,
          totalCalories: number(a['totalCalories'])!,
          activeTime: Duration(seconds: a['activeTime']),
          workouts: [
            for (final w in a['workouts'])
              WorkoutSession(
                  id: w['id'],
                  type: WorkoutType.values[w['type']],
                  start: time(w['start'])!,
                  end: time(w['end'])!,
                  calories: number(w['calories'])!,
                  avgHeartRate: number(w['avgHr']),
                  maxHeartRate: number(w['maxHr']),
                  strainContribution: number(w['strain'])!,
                  hrZones: [
                    for (final z in w['zones'])
                      HrZoneData(
                          zone: z['zone'],
                          duration: Duration(seconds: z['duration']),
                          minBpm: number(z['min'])!,
                          maxBpm: number(z['max'])!)
                  ])
          ]),
    );
  }
}
