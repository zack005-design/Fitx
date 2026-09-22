import 'package:fitx/core/models/sleep_data.dart';
import 'package:fitx/core/providers/providers.dart';
import 'package:fitx/features/reference_ui/sleep_reference_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 9, 20);

  Widget host(Widget screen, {double scale = 1}) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: screen),
      );

  testWidgets('demo is labeled and navigation returns to today',
      (tester) async {
    String? route;
    await tester.pumpWidget(host(SleepReferenceScreen(
        selectedDate: date, onNavigate: (value) => route = value)));
    expect(find.text('FitX • Demo data'), findsOneWidget);
    expect(find.text('91'), findsOneWidget);
    await tester.tap(find.byTooltip('Go back'));
    expect(route, 'today');
    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('date picker updates local date and notifies host',
      (tester) async {
    DateTime? selected;
    await tester.pumpWidget(host(SleepReferenceScreen(
        selectedDate: date, onDateChanged: (value) => selected = value)));
    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('19').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2026, 9, 19));
    expect(find.text('Sep 19, 2026'), findsOneWidget);
  });

  testWidgets('empty real data never shows demo measurements', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      sleepDataProvider(date)
          .overrideWith((ref) async => SleepData.empty(date)),
    ], child: host(SleepReferenceScreen(demoMode: false, selectedDate: date))));
    await tester.pumpAndSettle();
    expect(find.text('FitX • No sleep recorded for this date'), findsOneWidget);
    expect(find.text('91'), findsNothing);
    expect(find.text('8h 12m'), findsNothing);
    expect(find.text('Score unavailable'), findsOneWidget);
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('14.1 rpm'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recorded duration and efficiency come from existing provider',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      sleepDataProvider(date).overrideWith((ref) async => SleepData(
          date: date,
          totalSleep: const Duration(hours: 6, minutes: 30),
          remDuration: const Duration(hours: 1),
          deepDuration: const Duration(hours: 1),
          lightDuration: const Duration(hours: 4, minutes: 30),
          awakeDuration: const Duration(minutes: 15),
          stages: const [],
          efficiency: .87,
          wakeCount: 2,
          source: SleepDataSource.healthConnect)),
    ], child: host(SleepReferenceScreen(demoMode: false, selectedDate: date))));
    await tester.pumpAndSettle();
    expect(find.text('6h 30m'), findsOneWidget);
    expect(find.text('87%'), findsOneWidget);
    expect(find.text('FitX • Health Connect'), findsOneWidget);
    expect(find.text('91'), findsNothing);
  });

  testWidgets('narrow display supports 200 percent text through all cards',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(host(SleepReferenceScreen(selectedDate: date), scale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 8; i++) {
      await tester.drag(
          find.byType(SingleChildScrollView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Sleep Intelligence'), findsOneWidget);
  });
}
