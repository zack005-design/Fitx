import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitx/app/app.dart';
import 'package:fitx/features/reference_ui/recovery_reference_screen.dart';
import 'package:fitx/features/reference_ui/strain_reference_screen.dart';
import 'package:fitx/features/reference_ui/sleep_reference_screen.dart';
import 'package:fitx/features/reference_ui/today_reference_screen.dart';

void main() {
  testWidgets('All five destinations and demo toggle work', (tester) async {
    await tester.pumpWidget(const FitXApp());
    await tester.tap(find.byKey(const ValueKey('nav-recovery')));
    await tester.pumpAndSettle();
    expect(find.byType(RecoveryReferenceScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-strain')));
    await tester.pumpAndSettle();
    expect(find.byType(StrainReferenceScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-sleep')));
    await tester.pumpAndSettle();
    expect(find.byType(SleepReferenceScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('demo-toggle')));
    await tester.pumpAndSettle();
    expect(
        find.text('Your data · missing readings stay empty'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-today')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TodayReferenceScreen>(find.byType(TodayReferenceScreen))
            .demoMode,
        isFalse);
    expect(find.text('88%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Every destination fits narrow width and large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const FitXApp());
    for (final route in ['today', 'recovery', 'strain', 'sleep', 'profile']) {
      await tester.tap(find.byKey(ValueKey('nav-$route')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -550));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$route scroll $i');
      }
    }
  });
}
