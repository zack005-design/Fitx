import 'package:equatable/equatable.dart';

enum JournalEntryType { yesNoNeutral, scalar, number, time, note }

enum JournalSection { daytime, nighttime, automatic }

enum JournalEntrySource { manual, automatic }

enum JournalChoice { no, neutral, yes }

enum JournalInsightMetric { recovery, sleep }

extension JournalInsightMetricLabel on JournalInsightMetric {
  String get label => switch (this) {
        JournalInsightMetric.recovery => 'Recovery',
        JournalInsightMetric.sleep => 'Sleep',
      };

  String get databaseKey => name;
}

class JournalDefinition extends Equatable {
  const JournalDefinition({
    required this.id,
    required this.title,
    required this.section,
    required this.type,
    required this.sortOrder,
    this.description,
    this.unit,
    this.minimum,
    this.maximum,
    this.enabled = true,
  });

  final String id;
  final String title;
  final String? description;
  final JournalSection section;
  final JournalEntryType type;
  final String? unit;
  final double? minimum;
  final double? maximum;
  final int sortOrder;
  final bool enabled;

  bool get isAutomatic => section == JournalSection.automatic;

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'section': section.index,
        'entry_type': type.index,
        'unit': unit,
        'minimum_value': minimum,
        'maximum_value': maximum,
        'sort_order': sortOrder,
        'enabled': enabled ? 1 : 0,
      };

  factory JournalDefinition.fromMap(Map<String, Object?> map) =>
      JournalDefinition(
        id: map['id']! as String,
        title: map['title']! as String,
        description: map['description'] as String?,
        section: JournalSection.values[map['section']! as int],
        type: JournalEntryType.values[map['entry_type']! as int],
        unit: map['unit'] as String?,
        minimum: (map['minimum_value'] as num?)?.toDouble(),
        maximum: (map['maximum_value'] as num?)?.toDouble(),
        sortOrder: map['sort_order']! as int,
        enabled: (map['enabled'] as int? ?? 1) == 1,
      );

  @override
  List<Object?> get props => [id, title, section, type, enabled, sortOrder];
}

class JournalEntry extends Equatable {
  const JournalEntry({
    required this.id,
    required this.definitionId,
    required this.date,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.choice,
    this.numberValue,
    this.timeMinutes,
    this.textValue,
    this.note,
  });

  final String id;
  final String definitionId;
  final DateTime date;
  final JournalEntrySource source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final JournalChoice? choice;
  final double? numberValue;
  final int? timeMinutes;
  final String? textValue;
  final String? note;

  String get displayValue {
    if (choice != null) {
      return switch (choice!) {
        JournalChoice.no => 'No',
        JournalChoice.neutral => 'Neutral',
        JournalChoice.yes => 'Yes',
      };
    }
    if (timeMinutes != null) {
      final hours = timeMinutes! ~/ 60;
      final minutes = timeMinutes! % 60;
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}';
    }
    return textValue ?? numberValue?.toString() ?? 'Not logged';
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'definition_id': definitionId,
        'entry_date': _dateKey(date),
        'choice_value': choice?.index,
        'number_value': numberValue,
        'time_minutes': timeMinutes,
        'text_value': textValue,
        'note': note,
        'source': source.index,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory JournalEntry.fromMap(Map<String, Object?> map) => JournalEntry(
        id: map['id']! as String,
        definitionId: map['definition_id']! as String,
        date: DateTime.parse(map['entry_date']! as String),
        choice: map['choice_value'] == null
            ? null
            : JournalChoice.values[map['choice_value']! as int],
        numberValue: (map['number_value'] as num?)?.toDouble(),
        timeMinutes: map['time_minutes'] as int?,
        textValue: map['text_value'] as String?,
        note: map['note'] as String?,
        source: JournalEntrySource.values[map['source']! as int],
        createdAt: DateTime.parse(map['created_at']! as String),
        updatedAt: DateTime.parse(map['updated_at']! as String),
      );

  @override
  List<Object?> get props => [
        id,
        definitionId,
        date,
        source,
        choice,
        numberValue,
        timeMinutes,
        textValue,
        note,
        updatedAt,
      ];
}

class JournalDay extends Equatable {
  const JournalDay({
    required this.date,
    required this.definitions,
    required this.entries,
  });

  final DateTime date;
  final List<JournalDefinition> definitions;
  final List<JournalEntry> entries;

  JournalEntry? entryFor(String definitionId) {
    for (final entry in entries) {
      if (entry.definitionId == definitionId) return entry;
    }
    return null;
  }

  List<JournalDefinition> definitionsFor(JournalSection section) => definitions
      .where((definition) => definition.section == section)
      .toList(growable: false);

  @override
  List<Object?> get props => [date, definitions, entries];
}

class JournalHistoryDay extends Equatable {
  const JournalHistoryDay({required this.date, required this.entryCount});

  final DateTime date;
  final int entryCount;

  @override
  List<Object?> get props => [date, entryCount];
}

class JournalInsight extends Equatable {
  const JournalInsight({
    required this.definition,
    required this.metric,
    required this.positiveCount,
    required this.negativeCount,
    this.averageWithFactor,
    this.averageWithoutFactor,
  });

  static const minimumPerGroup = 5;

  final JournalDefinition definition;
  final JournalInsightMetric metric;
  final int positiveCount;
  final int negativeCount;
  final double? averageWithFactor;
  final double? averageWithoutFactor;

  bool get isReady =>
      positiveCount >= minimumPerGroup &&
      negativeCount >= minimumPerGroup &&
      averageWithFactor != null &&
      averageWithoutFactor != null;

  double? get difference =>
      isReady ? averageWithFactor! - averageWithoutFactor! : null;

  double? get associationMagnitude => difference?.abs();

  String get summary {
    if (!isReady) {
      return '$positiveCount yes and $negativeCount no observations. '
          'Insights need at least 5 of each.';
    }
    final direction = difference! >= 0 ? 'higher' : 'lower';
    return '${definition.title} was associated with a '
        '${associationMagnitude!.toStringAsFixed(1)} point $direction '
        'next-day ${metric.label.toLowerCase()} score.';
  }

  @override
  List<Object?> get props => [
        definition,
        metric,
        positiveCount,
        negativeCount,
        averageWithFactor,
        averageWithoutFactor,
      ];
}

String journalDateKey(DateTime date) => _dateKey(date);

String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

const defaultJournalDefinitions = <JournalDefinition>[
  JournalDefinition(
      id: 'stress',
      title: 'Stress',
      section: JournalSection.daytime,
      type: JournalEntryType.scalar,
      minimum: 1,
      maximum: 5,
      sortOrder: 10),
  JournalDefinition(
      id: 'mood',
      title: 'Mood',
      section: JournalSection.daytime,
      type: JournalEntryType.scalar,
      minimum: 1,
      maximum: 5,
      sortOrder: 20),
  JournalDefinition(
      id: 'sunlight',
      title: 'Sunlight',
      section: JournalSection.daytime,
      type: JournalEntryType.number,
      unit: 'min',
      minimum: 0,
      maximum: 1440,
      sortOrder: 30),
  JournalDefinition(
      id: 'caffeine_time',
      title: 'Last caffeine',
      section: JournalSection.daytime,
      type: JournalEntryType.time,
      sortOrder: 40),
  JournalDefinition(
      id: 'medication',
      title: 'Medication / supplements',
      section: JournalSection.daytime,
      type: JournalEntryType.note,
      sortOrder: 50),
  JournalDefinition(
      id: 'alcohol',
      title: 'Alcohol',
      section: JournalSection.nighttime,
      type: JournalEntryType.yesNoNeutral,
      sortOrder: 10),
  JournalDefinition(
      id: 'late_meal',
      title: 'Late meal',
      section: JournalSection.nighttime,
      type: JournalEntryType.yesNoNeutral,
      sortOrder: 20),
  JournalDefinition(
      id: 'illness',
      title: 'Illness',
      section: JournalSection.nighttime,
      type: JournalEntryType.yesNoNeutral,
      sortOrder: 30),
  JournalDefinition(
      id: 'soreness',
      title: 'Soreness',
      section: JournalSection.nighttime,
      type: JournalEntryType.scalar,
      minimum: 1,
      maximum: 5,
      sortOrder: 40),
  JournalDefinition(
      id: 'screen_time',
      title: 'Screen time',
      section: JournalSection.nighttime,
      type: JournalEntryType.number,
      unit: 'min',
      minimum: 0,
      maximum: 1440,
      sortOrder: 50),
  JournalDefinition(
      id: 'hydration_goal',
      title: 'Hydration goal',
      section: JournalSection.automatic,
      type: JournalEntryType.yesNoNeutral,
      sortOrder: 10),
  JournalDefinition(
      id: 'workout_completed',
      title: 'Workout completed',
      section: JournalSection.automatic,
      type: JournalEntryType.yesNoNeutral,
      sortOrder: 20),
  JournalDefinition(
      id: 'sleep_duration',
      title: 'Sleep recorded',
      section: JournalSection.automatic,
      type: JournalEntryType.number,
      unit: 'hr',
      minimum: 0,
      maximum: 24,
      sortOrder: 30),
  JournalDefinition(
      id: 'nutrition_calories',
      title: 'Nutrition recorded',
      section: JournalSection.automatic,
      type: JournalEntryType.number,
      unit: 'kcal',
      minimum: 0,
      sortOrder: 40),
];
