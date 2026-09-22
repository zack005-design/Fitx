import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitx/main.dart';

void main() {
  testWidgets('FitX app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FitXApp());
    expect(find.byType(FitXApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
