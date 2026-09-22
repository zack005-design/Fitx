import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/providers.dart';
import 'reference_theme.dart';

class TodayReferenceScreen extends ConsumerStatefulWidget {
  const TodayReferenceScreen(
      {super.key,
      this.demoMode = true,
      this.selectedDate,
      this.onDateChanged,
      this.onBack,
      this.onNavigate});
  final bool demoMode;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDateChanged;
  final VoidCallback? onBack;
  final ValueChanged<String>? onNavigate;
  @override
  ConsumerState<TodayReferenceScreen> createState() =>
      _TodayReferenceScreenState();
}

class _TodayReferenceScreenState extends ConsumerState<TodayReferenceScreen> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  DateTime get date => widget.selectedDate ?? _date;
  void navigate(String route) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(route);
    } else {
      details('Open $route',
          'This destination is available from the FitX app navigation.');
    }
  }

  void details(String title, String message) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(child: Text(message)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ]));
  Future<void> calendar() async {
    final selected = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (selected == null || !mounted) return;
    setState(() => _date = selected);
    widget.onDateChanged?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    final state =
        widget.demoMode ? null : ref.watch(dailySummaryProvider(date));
    final data = state?.value;
    final recovery =
        widget.demoMode ? 88.0 : data?.metricFor('recovery').valueOrNull;
    final energy =
        widget.demoMode ? 68.0 : data?.metricFor('energy').valueOrNull;
    final sleep = widget.demoMode
        ? const Duration(hours: 7, minutes: 48)
        : data?.sleepData.totalSleep;
    final strain = widget.demoMode
        ? 14.2
        : data?.metricFor('strain').valueOrNull == null
            ? null
            : data?.strainRaw;
    String metric(double? real, String sample, [String suffix = '']) => widget
            .demoMode
        ? sample
        : real == null
            ? '—'
            : '${real.toStringAsFixed(real == real.roundToDouble() ? 0 : 1)}$suffix';
    return ColoredBox(
        color: referenceBackground,
        child: Column(children: [
          Container(
              color: const Color(0xfffaf9fe),
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              child: Row(children: [
                if (widget.onBack != null)
                  IconButton(
                      onPressed: widget.onBack,
                      tooltip: 'Go back',
                      icon: const Icon(Icons.chevron_left)),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('FITX VITALITY', style: referenceCaption),
                      const Text('Today',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700))
                    ])),
                IconButton(
                    onPressed: calendar,
                    tooltip: 'Choose date',
                    icon: const Icon(Icons.calendar_today_outlined)),
              ])),
          Expanded(
              child: SingleChildScrollView(
                  key: const PageStorageKey('today-scroll'),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                  child: Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                        '${DateFormat.yMMMd().format(date)} · ${widget.demoMode ? 'Demo · Sample data' : 'Your health data'}',
                                        style: referenceCaption)),
                                if (state?.isLoading == true)
                                  const LinearProgressIndicator(),
                                if (state?.hasError == true)
                                  const Padding(
                                      padding: EdgeInsets.only(bottom: 12),
                                      child: Text(
                                          'Health data could not be loaded. Check your source in Profile.')),
                                ReferenceCard(
                                    child: Column(children: [
                                  Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      spacing: 18,
                                      runSpacing: 8,
                                      children: [
                                        const Text('●  DAILY READINESS',
                                            style: referenceCaption),
                                        Text(
                                            widget.demoMode
                                                ? 'PRIME'
                                                : recovery == null
                                                    ? 'AWAITING DATA'
                                                    : 'RECOVERY',
                                            style: const TextStyle(
                                                color: Color(0xff168235),
                                                fontSize: 11))
                                      ]),
                                  const SizedBox(height: 24),
                                  LayoutBuilder(
                                      builder: (context, constraints) {
                                    final ringSize =
                                        MediaQuery.textScalerOf(context)
                                            .scale(132)
                                            .clamp(132.0, constraints.maxWidth);
                                    final ring = SizedBox(
                                        width: ringSize,
                                        height: ringSize,
                                        child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              SizedBox.expand(
                                                  child:
                                                      CircularProgressIndicator(
                                                          value:
                                                              (recovery ?? 0) /
                                                                  100,
                                                          strokeWidth: 11,
                                                          strokeCap:
                                                              StrokeCap.round,
                                                          backgroundColor:
                                                              const Color(
                                                                  0xffe5e5ea),
                                                          color:
                                                              referenceGreen)),
                                              Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                        recovery == null
                                                            ? '—'
                                                            : '${recovery.round()}%',
                                                        style: referenceMetric),
                                                    const Text('RECOVERY',
                                                        style: referenceCaption)
                                                  ])
                                            ]));
                                    final narrative = Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              widget.demoMode
                                                  ? 'Optimal Recovery'
                                                  : recovery == null
                                                      ? 'Building your picture'
                                                      : 'Daily recovery',
                                              style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 8),
                                          Text(
                                              widget.demoMode
                                                  ? 'Autonomic nervous system is fully balanced. You are primed for peak strain.'
                                                  : recovery == null
                                                      ? 'Connect a source and build a personal baseline to see recovery.'
                                                      : 'Calculated from your available health signals and personal baseline.',
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  height: 1.5,
                                                  color: referenceMuted)),
                                          if (widget.demoMode)
                                            const Padding(
                                                padding:
                                                    EdgeInsets.only(top: 10),
                                                child: Text(
                                                    '↗  +6% vs 7-day baseline',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Color(0xff168235))))
                                        ]);
                                    return constraints.maxWidth > 310 &&
                                            MediaQuery.textScalerOf(context)
                                                    .scale(14) <
                                                22
                                        ? Row(children: [
                                            ring,
                                            const SizedBox(width: 24),
                                            Expanded(child: narrative)
                                          ])
                                        : Column(children: [
                                            ring,
                                            const SizedBox(height: 20),
                                            narrative
                                          ]);
                                  }),
                                  const SizedBox(height: 20),
                                  const Divider(),
                                  Wrap(
                                      spacing: 24,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.spaceBetween,
                                      children: [
                                        const Text('Suggested Target Strain',
                                            style: referenceCaption),
                                        Text(
                                            widget.demoMode
                                                ? '14.0 — 16.5'
                                                : 'Not prescribed',
                                            style:
                                                const TextStyle(fontSize: 12))
                                      ]),
                                  TextButton(
                                      onPressed: () => navigate('recovery'),
                                      child: const Text('View recovery')),
                                ])),
                                const SizedBox(height: 16),
                                _adaptiveCards(
                                    context,
                                    [
                                      _mini(
                                          'HRV',
                                          metric(data?.vitals.hrv, '64', ' ms'),
                                          widget.demoMode
                                              ? '↑ Optimal'
                                              : 'SDNN · ms',
                                          Icons.monitor_heart_outlined,
                                          referenceBlue),
                                      _mini(
                                          'RHR',
                                          metric(data?.vitals.restingHeartRate,
                                              '49', ' bpm'),
                                          widget.demoMode
                                              ? '⊙ -2 bpm'
                                              : 'Resting · bpm',
                                          Icons.favorite_border,
                                          const Color(0xffff3b30)),
                                      _mini(
                                          'SKIN TEMP',
                                          widget.demoMode ? '+0.2°F' : '—',
                                          widget.demoMode
                                              ? '— Normal'
                                              : 'Not available',
                                          Icons.thermostat,
                                          const Color(0xff32ade6)),
                                    ],
                                    3),
                                const SizedBox(height: 16),
                                _adaptiveCards(
                                    context,
                                    [
                                      _summary(
                                          'DAY STRAIN',
                                          strain?.toStringAsFixed(1) ?? '—',
                                          widget.demoMode
                                              ? 'Strenuous workout logged'
                                              : strain == null
                                                  ? 'No strain data'
                                                  : 'Your daily strain',
                                          const Color(0xffff2d55),
                                          widget.demoMode ? .788 : null,
                                          widget.demoMode
                                              ? '780 kcal     Target 15.5'
                                              : 'View strain details',
                                          () => navigate('strain')),
                                      _summary(
                                          'SLEEP REST',
                                          sleep == null ||
                                                  sleep == Duration.zero
                                              ? '—'
                                              : '${sleep.inHours}h ${sleep.inMinutes.remainder(60)}m',
                                          widget.demoMode
                                              ? '94% Sleep Performance'
                                              : 'Recorded sleep duration',
                                          const Color(0xff5856d6),
                                          widget.demoMode ? .94 : null,
                                          widget.demoMode
                                              ? 'Deep 1h 42m    REM 1h 50m'
                                              : 'View sleep details',
                                          () => navigate('sleep')),
                                    ],
                                    2),
                                const SizedBox(height: 16),
                                ReferenceCard(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      const Text('ENERGY BANK',
                                          style: referenceCaption),
                                      const SizedBox(height: 8),
                                      Text(
                                          energy == null
                                              ? 'Awaiting energy data'
                                              : '${energy.round()}% Capacity Remaining',
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 18),
                                      LinearProgressIndicator(
                                          value: (energy ?? 0) / 100,
                                          minHeight: 8,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          color: referenceGreen,
                                          backgroundColor:
                                              const Color(0xffe5e5ea)),
                                      const SizedBox(height: 10),
                                      Text(
                                          widget.demoMode
                                              ? 'Morning: 100%      Drain: -32%      Recharge ~6h'
                                              : 'An estimate based on available recovery and activity data.',
                                          style: referenceCaption)
                                    ])),
                                const SizedBox(height: 16),
                                ReferenceCard(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      const Text('PRESCRIBED PROTOCOL',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: referenceBlue)),
                                      const SizedBox(height: 6),
                                      Text(
                                          widget.demoMode
                                              ? 'High-Intensity Session Recommended'
                                              : 'Your next step',
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 8),
                                      Text(
                                          widget.demoMode
                                              ? 'Sample insight: cardiovascular readiness is in the top 10% bracket today. This demonstration is not personal training advice.'
                                              : 'Connect Health Connect in Profile to view your available readings. Recommendations require sufficient personal data.',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              height: 1.5,
                                              color: referenceMuted)),
                                      const SizedBox(height: 12),
                                      Wrap(spacing: 8, children: [
                                        FilledButton(
                                            onPressed: () => details(
                                                'Workout logging',
                                                'Workout logging is not available on this overview. Open Strain to review recorded activity.'),
                                            child: const Text('Log Workout')),
                                        OutlinedButton(
                                            onPressed: () => details(
                                                'About this insight',
                                                widget.demoMode
                                                    ? 'This is a static example from the supplied design. It is not calculated from your health data. Switch off demo mode in Profile for your available readings.'
                                                    : 'FitX needs connected health signals and a reliable baseline. Missing readings are never replaced with sample values.'),
                                            child: const Text('Details'))
                                      ])
                                    ])),
                                const SizedBox(height: 16),
                                ReferenceCard(
                                    child: Column(children: [
                                  Wrap(
                                      spacing: 18,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        const Text('CLINICAL BIOMETRICS',
                                            style: referenceCaption),
                                        TextButton(
                                            onPressed: () =>
                                                navigate('recovery'),
                                            child: const Text('View Trends'))
                                      ]),
                                  _clinical(
                                      'Blood Oxygen',
                                      'Peripheral Saturation',
                                      metric(data?.vitals.spo2, '98%', '%'),
                                      const Color(0xff00a9a1)),
                                  const Divider(),
                                  _clinical(
                                      'Respiratory Rate',
                                      'During Rest / Sleep',
                                      metric(data?.vitals.respiratoryRate,
                                          '14.1 rpm', ' rpm'),
                                      referenceBlue),
                                  const Divider(),
                                  _clinical(
                                      'Vascular Strain',
                                      'Aerobic threshold split',
                                      widget.demoMode ? '34 min' : '—',
                                      const Color(0xffff2d55))
                                ])),
                              ]))))),
        ]));
  }

  Widget _adaptiveCards(
          BuildContext context, List<Widget> cards, int columns) =>
      LayoutBuilder(builder: (context, c) {
        final count =
            c.maxWidth < 330 || MediaQuery.textScalerOf(context).scale(14) > 21
                ? 1
                : columns;
        return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map((card) => SizedBox(
                    width: (c.maxWidth - 12 * (count - 1)) / count,
                    child: card))
                .toList());
      });
  Widget _mini(String title, String value, String footer, IconData icon,
          Color color) =>
      ReferenceCard(
          padding: 12,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, children: [
              Text(title, style: referenceCaption),
              Icon(icon, size: 16, color: color)
            ]),
            const SizedBox(height: 10),
            Text(value, style: referenceMetric),
            const SizedBox(height: 8),
            Text(footer,
                style: const TextStyle(fontSize: 11, color: referenceMuted))
          ]));
  Widget _summary(String title, String value, String subtitle, Color color,
          double? progress, String footer, VoidCallback onTap) =>
      Semantics(
          button: true,
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: ReferenceCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title, style: referenceCaption),
                    const SizedBox(height: 12),
                    Text(value, style: referenceMetric),
                    const SizedBox(height: 8),
                    Text(subtitle,
                        style: const TextStyle(
                            color: referenceMuted, fontSize: 13)),
                    const SizedBox(height: 24),
                    LinearProgressIndicator(
                        value: progress ?? 0,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(8),
                        color: color,
                        backgroundColor: const Color(0xffe5e5ea)),
                    const SizedBox(height: 8),
                    Text(footer, style: referenceCaption)
                  ]))));
  Widget _clinical(String title, String subtitle, String value, Color color) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Wrap(
              spacing: 24,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text(subtitle, style: referenceCaption)
                ]),
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        color: color,
                        fontWeight: FontWeight.w600))
              ]));
}
