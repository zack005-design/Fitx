import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitx/features/reference_ui/today_reference_screen.dart';
import 'package:fitx/features/reference_ui/reference_theme.dart';
import 'package:fitx/core/providers/providers.dart';

void main() {
  testWidgets('Today labels sample data and opens recovery', (tester) async {
    String? route;
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            theme: referenceTheme(),
            home: Scaffold(
                body: TodayReferenceScreen(
                    onNavigate: (value) => route = value)))));
    expect(find.textContaining('Demo · Sample data'), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);
    await tester.tap(find.text('View recovery'));
    expect(route, 'recovery');
  });
  testWidgets('Today calendar changes date', (tester) async {
    DateTime? chosen;
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: Scaffold(
                body: TodayReferenceScreen(
                    selectedDate: DateTime(2026, 1, 10),
                    onDateChanged: (date) => chosen = date)))));
    await tester.tap(find.byTooltip('Choose date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(chosen, DateTime(2026, 1, 9));
  });
  testWidgets('Today real data error never displays demo readings',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          dailySummaryProvider
              .overrideWith((ref, date) => Future.error(StateError('offline')))
        ],
        child: MaterialApp(
            home: Scaffold(body: TodayReferenceScreen(demoMode: false)))));
    await tester.pumpAndSettle();
    expect(find.text('88%'), findsNothing);
    expect(find.textContaining('Health data could not'), findsOneWidget);
    expect(find.text('Building your picture'), findsOneWidget);
  });
  testWidgets('Today scrolls all content at 320px and 200 percent text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            theme: referenceTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: child!),
            home: const Scaffold(body: TodayReferenceScreen()))));
    for (var i = 0; i < 12; i++) {
      expect(tester.takeException(), isNull);
      await tester.drag(
          find.byType(SingleChildScrollView).first, const Offset(0, -550));
      await tester.pump();
    }
    expect(find.text('Vascular Strain'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
