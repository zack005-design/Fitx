import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/providers.dart';
import '../features/reference_ui/reference_theme.dart';
import '../features/reference_ui/today_reference_screen.dart';
import '../features/reference_ui/recovery_reference_screen.dart';
import '../features/reference_ui/strain_reference_screen.dart';
import '../features/reference_ui/sleep_reference_screen.dart';
import '../features/reference_ui/profile_reference_screen.dart';

class FitXApp extends StatelessWidget {
  const FitXApp({super.key});
  @override
  Widget build(BuildContext context) => ProviderScope(
      child: MaterialApp(
          title: 'FitX',
          debugShowCheckedModeBanner: false,
          theme: referenceTheme(),
          home: const ReferenceAppShell()));
}

class ReferenceAppShell extends ConsumerStatefulWidget {
  const ReferenceAppShell({super.key});
  @override
  ConsumerState<ReferenceAppShell> createState() => _ReferenceAppShellState();
}

class _ReferenceAppShellState extends ConsumerState<ReferenceAppShell> {
  String route = 'today';
  bool demo = true;
  void navigate(String next) {
    if (const ['today', 'recovery', 'strain', 'sleep', 'profile']
        .contains(next)) {
      setState(() => route = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(selectedDateProvider);
    void changeDate(DateTime value) =>
        ref.read(selectedDateProvider.notifier).select(value);
    void back() => navigate('today');
    final screen = switch (route) {
      'recovery' => RecoveryReferenceScreen(
          demoMode: demo,
          selectedDate: date,
          onDateChanged: changeDate,
          onBack: back,
          onNavigate: navigate),
      'strain' => StrainReferenceScreen(
          demoMode: demo,
          selectedDate: date,
          onDateChanged: changeDate,
          onBack: back,
          onNavigate: navigate),
      'sleep' => SleepReferenceScreen(
          demoMode: demo,
          selectedDate: date,
          onDateChanged: changeDate,
          onBack: back,
          onNavigate: navigate),
      'profile' => ProfileReferenceScreen(
          demoMode: demo,
          onDemoChanged: (value) => setState(() => demo = value)),
      _ => TodayReferenceScreen(
          demoMode: demo,
          selectedDate: date,
          onDateChanged: changeDate,
          onNavigate: navigate),
    };
    return PopScope(
        canPop: route == 'today',
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) back();
        },
        child: Scaffold(
          body: SafeArea(child: screen),
          bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Center(
                      heightFactor: 1,
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                      color: const Color(0xffe5e5ea)),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Color(0x08000000),
                                        blurRadius: 12)
                                  ]),
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 8),
                                  child: LayoutBuilder(
                                      builder: (context, constraints) {
                                    final largeText =
                                        MediaQuery.textScalerOf(context)
                                                .scale(11) >
                                            16;
                                    const destinations = [
                                      (
                                        'today',
                                        'Today',
                                        Icons.monitor_heart_outlined
                                      ),
                                      (
                                        'recovery',
                                        'Recovery',
                                        Icons.battery_charging_full
                                      ),
                                      (
                                        'strain',
                                        'Strain',
                                        Icons.local_fire_department_outlined
                                      ),
                                      (
                                        'sleep',
                                        'Sleep',
                                        Icons.bedtime_outlined
                                      ),
                                      (
                                        'profile',
                                        'Profile',
                                        Icons.person_outline
                                      )
                                    ];
                                    return Row(
                                        children: destinations
                                            .map((item) => Expanded(
                                                child: Semantics(
                                                    selected: route == item.$1,
                                                    label: item.$2,
                                                    button: true,
                                                    child: Tooltip(
                                                        message: item.$2,
                                                        child: InkWell(
                                                            key: ValueKey(
                                                                'nav-${item.$1}'),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        24),
                                                            onTap: () =>
                                                                navigate(
                                                                    item.$1),
                                                            child: Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                        vertical:
                                                                            5),
                                                                child: Column(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      Icon(
                                                                          item
                                                                              .$3,
                                                                          color: route == item.$1
                                                                              ? referenceBlue
                                                                              : referenceMuted,
                                                                          size:
                                                                              24),
                                                                      if (!largeText)
                                                                        Padding(
                                                                            padding:
                                                                                const EdgeInsets.only(top: 4),
                                                                            child: Text(item.$2, style: TextStyle(fontSize: 10, color: route == item.$1 ? referenceBlue : referenceMuted)))
                                                                    ])))))))
                                            .toList());
                                  }))))))),
        ));
  }
}
