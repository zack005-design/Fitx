import 'package:fitx/core/models/journal_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('journal definition serializes without losing its input contract', () {
    const definition = JournalDefinition(
      id: 'sunlight',
      title: 'Sunlight',
      section: JournalSection.daytime,
      type: JournalEntryType.number,
      unit: 'min',
      minimum: 0,
      maximum: 1440,
      sortOrder: 30,
    );

    expect(JournalDefinition.fromMap(definition.toMap()), definition);
  });

  test('journal entry preserves typed values and optional note', () {
    final entry = JournalEntry(
      id: 'entry-1',
      definitionId: 'caffeine_time',
      date: DateTime(2026, 9, 13),
      source: JournalEntrySource.manual,
      timeMinutes: 14 * 60 + 35,
      note: 'One espresso',
      createdAt: DateTime.utc(2026, 9, 13, 15),
      updatedAt: DateTime.utc(2026, 9, 13, 15),
    );

    final restored = JournalEntry.fromMap(entry.toMap());
    expect(restored, entry);
    expect(restored.displayValue, '14:35');
    expect(restored.note, 'One espresso');
  });

  test('insight stays locked until both groups contain five outcomes', () {
    const definition = JournalDefinition(
      id: 'alcohol',
      title: 'Alcohol',
      section: JournalSection.nighttime,
      type: JournalEntryType.yesNoNeutral,
      sortOrder: 1,
    );
    const locked = JournalInsight(
      definition: definition,
      metric: JournalInsightMetric.recovery,
      positiveCount: 5,
      negativeCount: 4,
      averageWithFactor: 60,
      averageWithoutFactor: 70,
    );
    const ready = JournalInsight(
      definition: definition,
      metric: JournalInsightMetric.recovery,
      positiveCount: 5,
      negativeCount: 5,
      averageWithFactor: 60,
      averageWithoutFactor: 70,
    );

    expect(locked.isReady, isFalse);
    expect(locked.difference, isNull);
    expect(ready.isReady, isTrue);
    expect(ready.difference, -10);
    expect(ready.summary, contains('associated with'));
    expect(ready.summary, isNot(contains('caused')));
  });

  test('JournalDay returns definitions by section and an entry by id', () {
    final day = JournalDay(
      date: DateTime(2026, 9, 13),
      definitions: defaultJournalDefinitions,
      entries: [
        JournalEntry(
          id: 'entry-1',
          definitionId: 'mood',
          date: DateTime(2026, 9, 13),
          source: JournalEntrySource.manual,
          numberValue: 4,
          createdAt: DateTime(2026, 9, 13),
          updatedAt: DateTime(2026, 9, 13),
        ),
      ],
    );

    expect(day.entryFor('mood')?.numberValue, 4);
    expect(day.definitionsFor(JournalSection.automatic), hasLength(4));
  });
}
