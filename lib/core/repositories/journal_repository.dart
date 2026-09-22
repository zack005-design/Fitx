import 'package:uuid/uuid.dart';

import '../models/journal_models.dart';
import '../models/metric_value.dart';
import '../services/database_service.dart';

class JournalRepository {
  JournalRepository({DatabaseService? db, DateTime Function()? now})
      : _db = db ?? DatabaseService(),
        _now = now ?? DateTime.now;

  final DatabaseService _db;
  final DateTime Function() _now;
  static const _uuid = Uuid();

  Future<List<JournalDefinition>> getDefinitions() async {
    await _db.upsertJournalDefinitions(defaultJournalDefinitions);
    return _db.getJournalDefinitions();
  }

  Future<JournalDay> getDay(DateTime date) async {
    final definitions = await getDefinitions();
    await _refreshAutomaticEntries(date);
    final entries = await _db.getJournalEntriesForDate(date);
    return JournalDay(
      date: DateTime(date.year, date.month, date.day),
      definitions: definitions,
      entries: entries,
    );
  }

  Future<void> saveManualEntry({
    required JournalDefinition definition,
    required DateTime date,
    JournalChoice? choice,
    double? numberValue,
    int? timeMinutes,
    String? textValue,
    String? note,
  }) async {
    if (definition.isAutomatic) {
      throw ArgumentError('Automatic journal entries cannot be edited.');
    }
    _ensureWritableDate(date);
    _validateValue(
      definition,
      choice: choice,
      numberValue: numberValue,
      timeMinutes: timeMinutes,
      textValue: textValue,
    );
    final existing = (await _db.getJournalEntriesForDate(date))
        .where((entry) => entry.definitionId == definition.id)
        .firstOrNull;
    final now = _now();
    await _db.saveManualJournalEntry(
      JournalEntry(
        id: existing?.id ?? _uuid.v4(),
        definitionId: definition.id,
        date: DateTime(date.year, date.month, date.day),
        source: JournalEntrySource.manual,
        choice: choice,
        numberValue: numberValue,
        timeMinutes: timeMinutes,
        textValue: textValue?.trim(),
        note: note?.trim().isEmpty == true ? null : note?.trim(),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  Future<void> deleteManualEntry(
    JournalDefinition definition,
    DateTime date,
  ) async {
    if (definition.isAutomatic) {
      throw ArgumentError('Automatic journal entries cannot be edited.');
    }
    _ensureWritableDate(date);
    await _db.deleteJournalEntry(definition.id, date);
  }

  Future<List<JournalHistoryDay>> getHistory({int days = 30}) async {
    final today = _now();
    final since = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: days - 1));
    final entries = await _db.getJournalEntriesSince(since);
    final counts = <String, int>{};
    for (final entry in entries) {
      final key = journalDateKey(entry.date);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts.entries
        .map(
          (entry) => JournalHistoryDay(
            date: DateTime.parse(entry.key),
            entryCount: entry.value,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Compares yes/no observations with next-day Recovery and Sleep scores.
  ///
  /// Neutral answers and observations without a real stored next-day score are
  /// excluded. Results remain locked until each group has five observations.
  Future<List<JournalInsight>> getInsights({int days = 180}) async {
    final definitions = await getDefinitions();
    final binaryDefinitions = {
      for (final definition in definitions)
        if (definition.type == JournalEntryType.yesNoNeutral)
          definition.id: definition,
    };
    final today = _day(_now());
    final since = today.subtract(Duration(days: days));
    final entries = await _db.getJournalEntriesBetween(since, today);
    final values = <(String, JournalInsightMetric), _InsightAccumulator>{};
    for (final entry in entries) {
      if (!binaryDefinitions.containsKey(entry.definitionId) ||
          (entry.choice != JournalChoice.yes &&
              entry.choice != JournalChoice.no)) {
        continue;
      }
      final nextDay = _day(entry.date.add(const Duration(days: 1)));
      if (nextDay.isAfter(today)) continue;
      final snapshot = await _db.getHealthSnapshot(nextDay);
      if (snapshot == null) continue;
      for (final metric in JournalInsightMetric.values) {
        if (snapshot.statusFor(metric.databaseKey) != MetricStatus.available) {
          continue;
        }
        final accumulator = values.putIfAbsent(
          (entry.definitionId, metric),
          _InsightAccumulator.new,
        );
        final score = snapshot.scoreFor(metric.databaseKey).value;
        if (entry.choice == JournalChoice.yes) {
          accumulator.withFactor.add(score);
        } else {
          accumulator.withoutFactor.add(score);
        }
      }
    }
    final insights = <JournalInsight>[
      for (final metric in JournalInsightMetric.values)
        for (final definition in binaryDefinitions.values)
          JournalInsight(
            definition: definition,
            metric: metric,
            positiveCount:
                (values[(definition.id, metric)] ?? _InsightAccumulator())
                    .withFactor
                    .length,
            negativeCount:
                (values[(definition.id, metric)] ?? _InsightAccumulator())
                    .withoutFactor
                    .length,
            averageWithFactor: _average(
                (values[(definition.id, metric)] ?? _InsightAccumulator())
                    .withFactor),
            averageWithoutFactor: _average(
                (values[(definition.id, metric)] ?? _InsightAccumulator())
                    .withoutFactor),
          ),
    ];
    await _db.saveJournalInsights(
      insights,
      windowStart: since,
      windowEnd: today,
      computedAt: _now(),
    );
    return insights;
  }

  Future<void> _refreshAutomaticEntries(DateTime date) async {
    final now = _now();
    final normalized = _day(date);
    if (normalized.isAfter(_day(now))) return;
    final existing = {
      for (final entry in await _db.getJournalEntriesForDate(date))
        if (entry.source == JournalEntrySource.automatic)
          entry.definitionId: entry,
    };
    final automatic = <JournalEntry>[];

    void add({
      required String definitionId,
      JournalChoice? choice,
      double? numberValue,
    }) {
      automatic.add(JournalEntry(
        id: 'automatic:$definitionId:${journalDateKey(date)}',
        definitionId: definitionId,
        date: normalized,
        source: JournalEntrySource.automatic,
        choice: choice,
        numberValue: numberValue,
        createdAt: existing[definitionId]?.createdAt ?? now,
        updatedAt: now,
      ));
    }

    final profile = await _db.getProfile();
    final water = await _db.getWaterForDate(date);
    if (profile != null && water > 0) {
      add(
        definitionId: 'hydration_goal',
        choice: water >= profile.dailyWaterGoal
            ? JournalChoice.yes
            : JournalChoice.no,
      );
    }
    final hasWorkout = await _db.hasWorkoutForDate(date);
    if (hasWorkout) {
      add(
        definitionId: 'workout_completed',
        choice: JournalChoice.yes,
      );
    }
    final snapshot = await _db.getHealthSnapshot(date);
    if (snapshot != null && snapshot.hasSleepData) {
      add(
        definitionId: 'sleep_duration',
        numberValue: snapshot.sleepData.totalSleep.inMinutes / 60,
      );
    }
    final meals = await _db.getMealEntriesForDate(date);
    if (meals.isNotEmpty) {
      add(
        definitionId: 'nutrition_calories',
        numberValue: meals.fold<double>(
          0,
          (total, meal) => total + meal.nutrition.calories,
        ),
      );
    }
    await _db.replaceAutomaticJournalEntries(date, automatic);
  }

  void _validateValue(
    JournalDefinition definition, {
    JournalChoice? choice,
    double? numberValue,
    int? timeMinutes,
    String? textValue,
  }) {
    final valid = switch (definition.type) {
      JournalEntryType.yesNoNeutral => choice != null,
      JournalEntryType.scalar || JournalEntryType.number => numberValue !=
              null &&
          numberValue.isFinite &&
          (definition.minimum == null || numberValue >= definition.minimum!) &&
          (definition.maximum == null || numberValue <= definition.maximum!),
      JournalEntryType.time =>
        timeMinutes != null && timeMinutes >= 0 && timeMinutes < 1440,
      JournalEntryType.note => textValue?.trim().isNotEmpty == true,
    };
    if (!valid) throw ArgumentError('Invalid value for ${definition.title}.');
  }

  void _ensureWritableDate(DateTime date) {
    if (_day(date).isAfter(_day(_now()))) {
      throw StateError('Journal entries cannot be logged for a future day.');
    }
  }
}

class _InsightAccumulator {
  final withFactor = <double>[];
  final withoutFactor = <double>[];
}

double? _average(List<double> values) => values.isEmpty
    ? null
    : values.reduce((first, second) => first + second) / values.length;

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
