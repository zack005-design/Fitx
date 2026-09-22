import 'package:fitx/core/providers/providers.dart';
import 'package:fitx/features/reference_ui/strain_reference_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/health_fixture.dart';

void main() {
  final date = DateTime(2026, 9, 13);

  Future<void> pumpScreen(WidgetTester tester, Widget screen,
      {double scale = 1, double width = 390}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(
                size: Size(width, 900), textScaler: TextScaler.linear(scale)),
            child: Scaffold(body: screen))));
    await tester.pumpAndSettle();
  }

  testWidgets('demo is labeled and displays the reference strain metrics',
      (tester) async {
    await pumpScreen(tester, StrainReferenceScreen(selectedDate: date));
    expect(find.text('FitX • Demo data'), findsOneWidget);
    expect(find.text('14.2'), findsOneWidget);
    expect(find.text('1.14 • Productive'), findsOneWidget);
    expect(find.text('780'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'live readings use the daily summary and never show demo readings',
      (tester) async {
    await pumpScreen(
        tester,
        ProviderScope(overrides: [
          dailySummaryProvider(date)
              .overrideWith((ref) async => healthFixture(date: date)),
        ], child: StrainReferenceScreen(demoMode: false, selectedDate: date)));
    expect(find.text('8.0'), findsOneWidget);
    expect(find.text('230'), findsOneWidget);
    expect(find.text('FitX • Demo data'), findsNothing);
    expect(find.text('14.2'), findsNothing);
    expect(find.text('1.14 • Productive'), findsNothing);
    expect(find.text('No recorded workouts for this date.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'missing live data does not present fallback strain as a measurement',
      (tester) async {
    await pumpScreen(
        tester,
        ProviderScope(overrides: [
          dailySummaryProvider(date).overrideWith(
              (ref) async => healthFixture(date: date, empty: true)),
        ], child: StrainReferenceScreen(demoMode: false, selectedDate: date)));
    expect(find.text('NO STRAIN DATA'), findsOneWidget);
    expect(find.text('8.0'), findsNothing);
    expect(find.text('No recorded heart-rate zones for this date.'),
        findsOneWidget);
  });

  testWidgets('back, date selection, splits and recovery controls respond',
      (tester) async {
    var back = false;
    DateTime? picked;
    String? route;
    await pumpScreen(
        tester,
        StrainReferenceScreen(
            selectedDate: date,
            onBack: () => back = true,
            onDateChanged: (value) => picked = value,
            onNavigate: (value) => route = value));
    await tester.tap(find.byTooltip('Back'));
    expect(back, isTrue);
    await tester.tap(find.byTooltip('Select date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(picked, DateTime(2026, 9, 12));
    expect(find.text('Sep 12'), findsOneWidget);
    await tester.ensureVisible(find.text('View Splits'));
    await tester.tap(find.text('View Splits'));
    await tester.pumpAndSettle();
    expect(find.text('Workout splits'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View Recovery'));
    await tester.tap(find.text('View Recovery'));
    expect(route, 'recovery');
  });

  testWidgets('320 width and 200 percent text reflow throughout the screen',
      (tester) async {
    await pumpScreen(tester, StrainReferenceScreen(selectedDate: date),
        width: 320, scale: 2);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('View Recovery'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Functional Hypertrophy'), findsOneWidget);
  });

  testWidgets('load failure offers a working retry', (tester) async {
    var attempts = 0;
    await pumpScreen(
        tester,
        ProviderScope(overrides: [
          dailySummaryProvider(date).overrideWith((ref) async {
            attempts++;
            if (attempts == 1) throw StateError('test read error');
            return healthFixture(date: date);
          }),
        ], child: StrainReferenceScreen(demoMode: false, selectedDate: date)));
    expect(find.text('Unable to load strain data'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('8.0'), findsOneWidget);
  });
}
