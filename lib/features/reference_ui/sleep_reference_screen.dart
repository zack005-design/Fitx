import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/sleep_data.dart';
import '../../core/providers/providers.dart';

const _ink = Color(0xFF1C1C1E);
const _muted = Color(0xFF71717A);
const _purple = Color(0xFF5856D6);
const _green = Color(0xFF006E28);
const _blue = Color(0xFF0058BC);
const _pink = Color(0xFFFF2D55);
const _cyan = Color(0xFF32ADE6);

/// Sleep detail body. The host supplies bottom navigation and a ProviderScope
/// when [demoMode] is false.
class SleepReferenceScreen extends StatefulWidget {
  const SleepReferenceScreen(
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
  State<SleepReferenceScreen> createState() => _SleepReferenceScreenState();
}

class _SleepReferenceScreenState extends State<SleepReferenceScreen> {
  late DateTime _date =
      DateUtils.dateOnly(widget.selectedDate ?? DateTime.now());

  @override
  void didUpdateWidget(covariant SleepReferenceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate &&
        widget.selectedDate != null) {
      _date = DateUtils.dateOnly(widget.selectedDate!);
    }
  }

  Future<void> _chooseDate() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final chosen = await showDatePicker(
        context: context,
        initialDate: _date.isAfter(now) ? now : _date,
        firstDate: DateTime(1900),
        lastDate: now);
    if (!mounted || chosen == null) return;
    setState(() => _date = chosen);
    widget.onDateChanged?.call(chosen);
  }

  void _back() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (widget.onNavigate != null) {
      widget.onNavigate!('today');
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
          content: Text('You are already at the sleep overview.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
              seedColor: _purple, brightness: Brightness.light),
          textTheme: ThemeData.light()
              .textTheme
              .apply(fontFamily: 'Inter', bodyColor: _ink, displayColor: _ink)),
      child: ColoredBox(
          color: const Color(0xFFF2F2F7),
          child: SafeArea(
              bottom: false,
              child: Column(children: [
                Container(
                    color: const Color(0xFFFAF9FE),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(children: [
                      IconButton(
                          onPressed: _back,
                          tooltip: 'Go back',
                          icon: const Icon(Icons.chevron_left, color: _ink)),
                      const Expanded(
                          child: Text('Sleep',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w700))),
                      Flexible(
                          child: TextButton.icon(
                              onPressed: _chooseDate,
                              icon: const Icon(Icons.calendar_today_outlined,
                                  size: 15),
                              label: Text(
                                  DateFormat('MMM d, yyyy').format(_date),
                                  style: const TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                  foregroundColor: _muted))),
                    ])),
                Expanded(
                    child: widget.demoMode
                        ? _content(context, null)
                        : Consumer(builder: (context, ref, child) {
                            final sleep = ref.watch(sleepDataProvider(_date));
                            return sleep.when(
                              data: (data) => _content(context, data),
                              loading: () => const Center(
                                  child: CircularProgressIndicator(
                                      semanticsLabel: 'Loading sleep')),
                              error: (error, stack) => Center(
                                  child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                                'Sleep data could not be loaded.'),
                                            TextButton(
                                                onPressed: () => ref.invalidate(
                                                    sleepDataProvider(_date)),
                                                child: const Text('Retry')),
                                          ]))),
                            );
                          })),
              ]))),
    );
  }

  Widget _content(BuildContext context, SleepData? data) {
    final demo = widget.demoMode;
    final recorded = data != null && data.totalSleep > Duration.zero;
    final stages = demo ||
        (recorded &&
            data.source != SleepDataSource.phoneSensors &&
            (data.remDuration + data.deepDuration + data.lightDuration) >
                Duration.zero);
    final asleep = demo
        ? '8h 12m'
        : recorded
            ? _duration(data.totalSleep)
            : '—';
    final period = demo
        ? '23:08 – 07:20'
        : recorded && data.bedtime != null && data.wakeTime != null
            ? '${DateFormat.Hm().format(data.bedtime!)} – ${DateFormat.Hm().format(data.wakeTime!)}'
            : 'Not recorded';
    final stageMinutes = demo
        ? [22, 120, 242, 108]
        : stages
            ? [
                data!.awakeDuration.inMinutes,
                data.remDuration.inMinutes,
                data.lightDuration.inMinutes,
                data.deepDuration.inMinutes
              ]
            : [0, 0, 0, 0];
    return SingleChildScrollView(
        child: Center(
            child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                    demo
                        ? 'FitX • Demo data'
                        : recorded
                            ? 'FitX • ${data.sourceLabel}'
                            : 'FitX • No sleep recorded for this date',
                    style: const TextStyle(color: _muted, fontSize: 11))),
            _card(Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _heading(Icons.bedtime, 'RECOVERY QUALITY', _purple,
                      demo ? '↗ Optimal' : 'Score unavailable',
                      small: true),
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (context, constraints) {
                    final ring = Semantics(
                        label: demo
                            ? 'Demo sleep score 91 out of 100'
                            : 'Sleep score unavailable',
                        child: SizedBox(
                            width: math.min(constraints.maxWidth, 128 * MediaQuery.textScalerOf(context).scale(1)),
                            height: math.min(constraints.maxWidth, 128 * MediaQuery.textScalerOf(context).scale(1)),
                            child: CustomPaint(
                                painter: _ScorePainter(demo),
                                child: Center(
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                      Text(demo ? '91' : '—',
                                          style: const TextStyle(
                                              fontSize: 34,
                                              fontWeight: FontWeight.w800,
                                              height: 1)),
                                      const Text('/ 100',
                                          style: TextStyle(
                                              fontSize: 11, color: _muted)),
                                    ])))));
                    final metrics = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TIME ASLEEP',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _muted,
                                  fontWeight: FontWeight.w600)),
                          Text(asleep,
                              style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.6)),
                          Text(
                              demo
                                  ? '+27m vs Sleep Need'
                                  : recorded
                                      ? 'Recorded duration'
                                      : 'No data available',
                              style:
                                  const TextStyle(fontSize: 11, color: _green)),
                          const Divider(color: Color(0xFFE5E5EA)),
                          Wrap(spacing: 18, runSpacing: 8, children: [
                            _value(
                                'Sleep Need', demo ? '7h 45m' : 'Unavailable'),
                            _value(
                                'Efficiency',
                                demo
                                    ? '94%'
                                    : recorded
                                        ? '${(data.efficiency * 100).round()}%'
                                        : '—',
                                color: _green),
                          ]),
                        ]);
                    if (constraints.maxWidth < 260 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.4) {
                      return Column(children: [
                        ring,
                        const SizedBox(height: 16),
                        metrics
                      ]);
                    }
                    return Row(children: [
                      ring,
                      const SizedBox(width: 16),
                      Expanded(child: metrics)
                    ]);
                  }),
                  if (!demo &&
                      data != null &&
                      (data.readErrors.isNotEmpty ||
                          data.limitations.isNotEmpty))
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                            [
                              ...data.limitations,
                              if (data.readErrors.isNotEmpty)
                                'Some sleep data could not be read.'
                            ].join(' '),
                            style:
                                const TextStyle(fontSize: 12, color: _muted))),
                ])),
            _card(Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _heading(
                      Icons.equalizer, 'Sleep Architecture', _blue, period),
                  const SizedBox(height: 12),
                  if (stages) ...[
                    Semantics(
                        label:
                            'Sleep stages: ${List.generate(4, (i) => '${_stageNames[i]} ${stageMinutes[i]} minutes').join(', ')}',
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: SizedBox(
                                height: 16,
                                child: Row(
                                    children: List.generate(
                                        4,
                                        (i) => Expanded(
                                            flex: math.max(1, stageMinutes[i]),
                                            child: Container(
                                                color: _stageColors[i],
                                                margin: const EdgeInsets.only(
                                                    right: 1)))))))),
                    const SizedBox(height: 14),
                    LayoutBuilder(builder: (context, c) {
                      final count = c.maxWidth >= 300 &&
                              MediaQuery.textScalerOf(context).scale(1) < 1.3
                          ? 4
                          : 2;
                      return Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: List.generate(
                              4,
                              (i) => Container(
                                  width: (c.maxWidth - (count - 1) * 6) / count,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFF4F3F8),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFE5E5EA))),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('● ${_stageNames[i]}',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: _stageColors[i])),
                                        const SizedBox(height: 5),
                                        Text(
                                            _duration(Duration(
                                                minutes: stageMinutes[i])),
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 4),
                                        Text(
                                            '${(100 * stageMinutes[i] / stageMinutes.reduce((a, b) => a + b)).round()}% total',
                                            style: const TextStyle(
                                                fontSize: 10, color: _muted)),
                                      ]))));
                    }),
                  ] else
                    const Text(
                        'Sleep stages are unavailable. A compatible sleep source is needed.',
                        style: TextStyle(fontSize: 13, color: _muted)),
                ])),
            _card(Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _heading(Icons.timelapse, 'Circadian Sleep Gate',
                      const Color(0xFF00AFA7), demo ? '96% Aligned' : null),
                  const SizedBox(height: 8),
                  Text(
                      demo
                          ? 'Example sleep onset falls within the illustrated window (22:45 – 23:30).'
                          : 'Circadian alignment is unavailable. Recorded sleep alone does not measure melatonin onset.',
                      style: const TextStyle(
                          fontSize: 13, color: _muted, height: 1.4)),
                  const SizedBox(height: 12),
                  Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF4F3F8),
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        _window(
                            'Optimal Window',
                            demo ? '22:45 – 07:00' : 'Unavailable',
                            const Color(0xFFC1C6D7),
                            demo,
                            .15),
                        const SizedBox(height: 12),
                        _window(
                            'Actual Sleep Period', period, _purple, demo, .18),
                      ])),
                ])),
            LayoutBuilder(builder: (context, c) {
              final columns = c.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.6
                  ? 1
                  : 2;
              final items = [
                _metric(
                    'SLEEP DEBT',
                    demo ? '-15 min' : '—',
                    demo ? 'Surplus achieved' : 'Not available',
                    Icons.check_circle_outline,
                    _green),
                _metric(
                    'SLEEP LATENCY',
                    demo ? '11 min' : '—',
                    demo ? 'Example latency' : 'Not recorded',
                    Icons.timer_outlined,
                    _purple),
                _metric(
                    'WAKE REGULARITY',
                    demo ? '92%' : '—',
                    demo ? '±14 min variance' : 'More history needed',
                    Icons.schedule,
                    const Color(0xFF00AFA7)),
                _metric(
                    'RESPIRATION',
                    demo ? '14.1 rpm' : '—',
                    demo ? 'Example breathing rate' : 'Not recorded',
                    Icons.air,
                    const Color(0xFFFF3B30)),
              ];
              return Wrap(
                  spacing: 12,
                  children: items
                      .map((item) => SizedBox(
                          width: (c.maxWidth - (columns - 1) * 12) / columns,
                          child: item))
                      .toList());
            }),
            _card(Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _heading(Icons.calendar_view_week, '7-Day Consistency', _blue,
                      demo ? 'Avg: 7h 56m' : null),
                  const SizedBox(height: 16),
                  if (demo) ...[
                    Semantics(
                        label:
                            'Illustrative seven-day sleep duration chart. Average 7 hours 56 minutes.',
                        child: const SizedBox(
                            height: 94,
                            child: CustomPaint(painter: _WeekPainter()))),
                    const SizedBox(height: 8),
                    Row(
                        children: List.generate(
                            7,
                            (i) => Expanded(
                                child: Center(
                                    child: Text(
                                        DateFormat.E().format(_date
                                            .subtract(Duration(days: 6 - i))),
                                        style: const TextStyle(
                                            fontSize: 10, color: _muted)))))),
                  ] else
                    const Text('A weekly summary is not available here yet.',
                        style: TextStyle(fontSize: 13, color: _muted)),
                ])),
            _card(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEEEEFC),
                      borderRadius: BorderRadius.circular(12)),
                  child:
                      const Icon(Icons.auto_awesome, color: _purple, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Sleep Intelligence',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const Text('FitX Engine',
                        style: TextStyle(fontSize: 11, color: _muted)),
                    const SizedBox(height: 6),
                    Text(
                        demo
                            ? 'This example includes 1h 48m of deep sleep. Explore your recorded sleep over time to understand your own patterns.'
                            : recorded
                                ? 'Your recorded sleep duration is $asleep. Sleep stages and phone estimates have limitations; they do not confirm physical recovery.'
                                : 'Record sleep with a supported source to see your overnight duration and available stages.',
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF414755))),
                  ])),
            ])),
          ])),
    )));
  }

  static const _stageNames = ['Awake', 'REM', 'Core', 'Deep'];
  static const _stageColors = [_pink, _purple, _cyan, _blue];

  Widget _card(Widget child) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E5EA)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x09000000), blurRadius: 5, offset: Offset(0, 2))
          ]),
      child: child);

  Widget _heading(IconData icon, String title, Color color, String? trailing,
          {bool small = false}) =>
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text.rich(
                TextSpan(children: [
                  WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(icon, size: 18, color: color))),
                  TextSpan(text: title)
                ]),
                style: TextStyle(
                    fontSize: small ? 11 : 15,
                    color: small ? _muted : _ink,
                    fontWeight: FontWeight.w700)),
            if (trailing != null)
              Text(trailing,
                  style: TextStyle(
                      fontSize: 11,
                      color: trailing.contains('Optimal') ||
                              trailing.contains('Aligned')
                          ? _green
                          : _muted)),
          ]);

  Widget _value(String label, String value, {Color color = _ink}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ]);

  Widget _window(
          String label, String value, Color color, bool bar, double left) =>
      Column(children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
              Text(value,
                  style: TextStyle(
                      fontSize: 11, color: color == _purple ? _purple : _ink)),
            ]),
        if (bar) ...[
          const SizedBox(height: 6),
          LayoutBuilder(
              builder: (context, c) => Container(
                  height: 9,
                  decoration: BoxDecoration(
                      color: const Color(0xFFEEEDF3),
                      borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.only(left: c.maxWidth * left),
                  child: Container(
                      width: c.maxWidth * .7,
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8)))))
        ],
      ]);

  Widget _metric(String label, String value, String note, IconData icon,
          Color color) =>
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: _muted,
                      fontWeight: FontWeight.w600))),
          Icon(icon, size: 16, color: color)
        ]),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.6)),
        Text(note,
            style: TextStyle(
                fontSize: 11, color: color == _green ? _green : _muted)),
      ]));

  String _duration(Duration value) => value.inHours == 0
      ? '${value.inMinutes}m'
      : '${value.inHours}h ${value.inMinutes.remainder(60).toString().padLeft(2, '0')}m';
}

class _ScorePainter extends CustomPainter {
  const _ScorePainter(this.demo);
  final bool demo;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        rect, 0, math.pi * 2, false, paint..color = const Color(0xFFECEBFA));
    if (demo) {
      canvas.drawArc(
          rect, -math.pi / 2, math.pi * 2 * .91, false, paint..color = _purple);
    }
  }

  @override
  bool shouldRepaint(covariant _ScorePainter oldDelegate) =>
      oldDelegate.demo != demo;
}

class _WeekPainter extends CustomPainter {
  const _WeekPainter();
  @override
  void paint(Canvas canvas, Size size) {
    const fractions = [.88, .82, .95, .70, .90, .98, 1.0];
    final width = size.width / 7;
    for (var i = 0; i < 7; i++) {
      final rect = Rect.fromLTWH(i * width + 3, 0, width - 6, size.height);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)),
          Paint()..color = const Color(0xFFEEEDF3));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(rect.left, size.height * (1 - fractions[i]),
                  rect.width, size.height * fractions[i]),
              const Radius.circular(24)),
          Paint()..color = i == 6 ? const Color(0xFF34C759) : _purple);
    }
  }

  @override
  bool shouldRepaint(covariant _WeekPainter oldDelegate) => false;
}
