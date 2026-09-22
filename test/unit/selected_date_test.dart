import 'package:fitx/core/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selected date is normalized and cannot move into the future', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(selectedDateProvider.notifier);

    notifier.select(DateTime(2025, 3, 9, 23, 45));
    expect(container.read(selectedDateProvider), DateTime(2025, 3, 9));
    notifier.nextDay();
    expect(container.read(selectedDateProvider), DateTime(2025, 3, 10));
    notifier.select(DateTime.now().add(const Duration(days: 2)));
    expect(container.read(selectedDateProvider), DateTime(2025, 3, 10));
  });
}
