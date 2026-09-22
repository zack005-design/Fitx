import 'package:fitx/core/providers/providers.dart';
import 'package:fitx/features/reference_ui/recovery_reference_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/health_fixture.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, Widget screen,
      {double width = 390, double scale = 1}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(body: screen)));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'demo ring and strain action render with explicit sample labeling',
      (tester) async {
    String? route;
    var backed = false;
    await pumpScreen(
        tester,
        RecoveryReferenceScreen(
            onNavigate: (value) => route = value, onBack: () => backed = true));
    expect(find.text('FitX · Demo data'), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);
    await tester.tap(find.byTooltip('Go back'));
    expect(backed, isTrue);
    await tester.scrollUntilVisible(find.text('Explore Strain'), 450);
    await tester.tap(find.text('Explore Strain'));
    expect(route, 'strain');
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar selection updates the header and notifies the host',
      (tester) async {
    DateTime? picked;
    await pumpScreen(
        tester,
        RecoveryReferenceScreen(
            selectedDate: DateTime(2025, 10, 24),
            onDateChanged: (value) => picked = value));
    await tester.tap(find.text('Oct 24'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('23'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(picked, DateTime(2025, 10, 23));
    expect(find.text('Oct 23'), findsOneWidget);
  });

  testWidgets('live data uses repository values and SDNN units',
      (tester) async {
    final day = DateTime(2026, 9, 13);
    await pumpScreen(
        tester,
        ProviderScope(overrides: [
          dailySummaryProvider(day)
              .overrideWith((ref) async => healthFixture(date: day))
        ], child: RecoveryReferenceScreen(demoMode: false, selectedDate: day)));
    expect(find.text('72%'), findsOneWidget);
    expect(find.text('HRV SDNN'), findsOneWidget);
    expect(find.text('HRV RMSSD'), findsNothing);
    expect(find.text('FitX · Demo data'), findsNothing);
    await tester.scrollUntilVisible(find.text('24h HRV Timeline'), 350);
    expect(find.text('No timeline'), findsOneWidget);
    expect(find.text('Avg 58 ms'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty or calibrating data never exposes neutral fallback score',
      (tester) async {
    final day = DateTime(2026, 9, 13);
    for (final empty in [true, false]) {
      await pumpScreen(
          tester,
          ProviderScope(
              key: ValueKey(empty),
              overrides: [
                dailySummaryProvider(day).overrideWith((ref) async =>
                    healthFixture(date: day, empty: empty, baselineDays: 3))
              ],
              child:
                  RecoveryReferenceScreen(demoMode: false, selectedDate: day)));
      expect(
          find.text('Not enough data for a recovery score.'), findsOneWidget);
      expect(find.text('72%'), findsNothing);
      expect(find.text('88%'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('320px and 200 percent text stays scrollable without overflow',
      (tester) async {
    await pumpScreen(tester, const RecoveryReferenceScreen(),
        width: 320, scale: 2);
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 9; i++) {
      await tester.drag(
          find.byKey(const Key('recovery-scroll')), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.ensureVisible(find.text('Explore Strain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore Strain'));
    await tester.pumpAndSettle();
    expect(find.text('Navigation unavailable'), findsOneWidget);
  });

  testWidgets('failed provider exposes a working retry', (tester) async {
    final day = DateTime(2026, 9, 13);
    var attempts = 0;
    await pumpScreen(
        tester,
        ProviderScope(overrides: [
          dailySummaryProvider(day).overrideWith((ref) async {
            if (attempts++ == 0) throw StateError('offline');
            return healthFixture(date: day);
          })
        ], child: RecoveryReferenceScreen(demoMode: false, selectedDate: day)));
    expect(find.text('Recovery data could not be loaded.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('72%'), findsOneWidget);
  });
}
