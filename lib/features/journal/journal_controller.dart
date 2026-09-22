import '../../core/models/journal_models.dart';
import '../../core/repositories/journal_repository.dart';

class JournalController {
  const JournalController({
    required JournalRepository repository,
    required void Function() onChanged,
  })  : _repository = repository,
        _onChanged = onChanged;

  final JournalRepository _repository;
  final void Function() _onChanged;

  Future<void> save({
    required JournalDefinition definition,
    required DateTime date,
    JournalChoice? choice,
    double? numberValue,
    int? timeMinutes,
    String? textValue,
    String? note,
  }) async {
    await _repository.saveManualEntry(
      definition: definition,
      date: date,
      choice: choice,
      numberValue: numberValue,
      timeMinutes: timeMinutes,
      textValue: textValue,
      note: note,
    );
    _onChanged();
  }

  Future<void> delete(JournalDefinition definition, DateTime date) async {
    await _repository.deleteManualEntry(definition, date);
    _onChanged();
  }
}
