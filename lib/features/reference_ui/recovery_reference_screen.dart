import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/daily_health_summary.dart';
import '../../core/models/health_score.dart';
import '../../core/providers/providers.dart';

const _ink = Color(0xFF1C1C1E);
const _muted = Color(0xFF74747B);
const _green = Color(0xFF34C759);
const _purple = Color(0xFF5856D6);
const _blue = Color(0xFF0070EB);
const _track = Color(0xFFEEEDF3);

/// Recovery detail body. The host owns bottom navigation and live ProviderScope.
class RecoveryReferenceScreen extends StatefulWidget {
  const RecoveryReferenceScreen({
    super.key,
    this.demoMode = true,
    this.selectedDate,
    this.onDateChanged,
    this.onBack,
    this.onNavigate,
  });

  final bool demoMode;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDateChanged;
  final VoidCallback? onBack;
  final ValueChanged<String>? onNavigate;

  @override
  State<RecoveryReferenceScreen> createState() =>
      _RecoveryReferenceScreenState();
}

class _RecoveryReferenceScreenState extends State<RecoveryReferenceScreen> {
  late DateTime _date = _day(widget.selectedDate ?? DateTime.now());

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @override
  void didUpdateWidget(covariant RecoveryReferenceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate &&
        widget.selectedDate != null) {
      _date = _day(widget.selectedDate!);
    }
  }

  Future<void> _pickDate() async {
    final today = _day(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(math.min(2000, _date.year)),
      lastDate: today,
    );
    if (!mounted || picked == null) return;
    setState(() => _date = picked);
    widget.onDateChanged?.call(picked);
  }

  void _navigate(String route) {
    if (widget.onNavigate case final navigate?) {
      navigate(route);
    } else {
      _explain(
          'Navigation unavailable', 'Open this screen in FitX to view $route.');
    }
  }

  void _explain(String title, String message) {
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got it'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData.light(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      colorScheme:
          ColorScheme.fromSeed(seedColor: _blue, brightness: Brightness.light),
      textTheme: Theme.of(context)
          .textTheme
          .apply(fontFamily: 'Inter', bodyColor: _ink, displayColor: _ink),
    );
    return Theme(
        data: theme,
        child: Material(
          color: const Color(0xFFF2F2F7),
          child: SafeArea(
              bottom: false,
              child: Column(children: [
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final largeText =
                        MediaQuery.textScalerOf(context).scale(17) > 25;
                    final title = Row(children: [
                      IconButton(
                          tooltip: 'Go back',
                          onPressed: () {
                            if (widget.onBack != null) {
                              widget.onBack!();
                            } else if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              _navigate('today');
                            }
                          },
                          icon: const Icon(Icons.chevron_left, color: _ink)),
                      const Expanded(
                          child: Text('Recovery',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700))),
                    ]);
                    final calendar = TextButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                          '${_date == _day(DateTime.now()) ? 'Today, ' : ''}${DateFormat('MMM d').format(_date)}',
                          style: const TextStyle(fontSize: 13, color: _muted)),
                    );
                    return largeText || constraints.maxWidth < 320
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                title,
                                Align(
                                    alignment: Alignment.centerRight,
                                    child: calendar)
                              ])
                        : Row(children: [Expanded(child: title), calendar]);
                  }),
                ),
                Expanded(
                    child: widget.demoMode
                        ? _content(context, null)
                        : Consumer(
                            builder: (context, ref, child) {
                              final summary =
                                  ref.watch(dailySummaryProvider(_date));
                              return summary.when(
                                data: (data) => _content(context, data),
                                loading: () => const Center(
                                    child: CircularProgressIndicator(
                                        semanticsLabel: 'Loading recovery')),
                                error: (error, stack) => Center(
                                    child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                  'Recovery data could not be loaded.',
                                                  textAlign: TextAlign.center),
                                              const SizedBox(height: 12),
                                              FilledButton(
                                                  onPressed: () =>
                                                      ref.invalidate(
                                                          dailySummaryProvider(
                                                              _date)),
                                                  child: const Text('Retry')),
                                            ]))),
                              );
                            },
                          )),
              ])),
        ));
  }

  Widget _content(BuildContext context, DailyHealthSummary? data) {
    final demo = widget.demoMode;
    final score = demo ? 88.0 : data?.metricFor('recovery').valueOrNull;
    final hrv = demo ? 64.0 : data?.vitals.hrv;
    final rhr = demo ? 48.0 : data?.vitals.restingHeartRate;
    final respiration = demo ? 14.2 : data?.vitals.respiratoryRate;
    final hrvDelta = hrv != null && (data?.hrvBaseline ?? 0) > 0
        ? (hrv / data!.hrvBaseline! - 1) * 100
        : null;
    final rhrDelta = rhr != null && (data?.rhrBaseline ?? 0) > 0
        ? rhr - data!.rhrBaseline!
        : null;
    String delta(double value, String suffix) =>
        '${value >= 0 ? '+' : ''}${value.round()}$suffix';
    final color = score == null
        ? _muted
        : score > 60
            ? _green
            : score > 40
                ? const Color(0xFFE6A024)
                : const Color(0xFFFF3B30);
    return SingleChildScrollView(
      key: const Key('recovery-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
      child: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (demo)
                    const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text('FitX · Demo data',
                            style: TextStyle(fontSize: 11, color: _muted))),
                  _card(Column(children: [
                    _pair(
                        Text(
                            score == null
                                ? 'AWAITING DATA'
                                : '${ScoreLevelExt.fromScore(score).label.toUpperCase()} STATE',
                            style: TextStyle(
                                color: color, fontSize: 11, letterSpacing: .5)),
                        _badge(
                            demo ? '+6% vs 7d Baseline' : 'Personal recovery',
                            green: demo)),
                    const SizedBox(height: 8),
                    Semantics(
                        label: score == null
                            ? 'Recovery score unavailable'
                            : 'Recovery ${score.round()} percent',
                        child: ExcludeSemantics(
                            child: SizedBox.square(
                                dimension: math.min(
                                  math.min(MediaQuery.sizeOf(context).width,
                                          552) -
                                      74,
                                  176 *
                                      MediaQuery.textScalerOf(context)
                                          .scale(14) /
                                      14,
                                ),
                                child: CustomPaint(
                                  painter: _RecoveryRingPainter(
                                      score == null ? 0 : score / 100, color),
                                  child: Center(
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                        Text(
                                            score == null
                                                ? '—'
                                                : '${score.round()}%',
                                            style: const TextStyle(
                                                fontSize: 34,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -1)),
                                        const Text('RECOVERY',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: _muted,
                                                letterSpacing: 1.3)),
                                      ])),
                                )))),
                    const SizedBox(height: 8),
                    Text(
                        demo
                            ? 'Your autonomic nervous system is fully primed.'
                            : score == null
                                ? 'Not enough data for a recovery score.'
                                : 'Your recorded recovery score',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(
                        demo
                            ? 'Sample insight: high cardiovascular tolerance and strong recovery.'
                            : data!.baselineMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, height: 1.35, color: _muted)),
                    if (!demo && data!.readErrors.isNotEmpty)
                      const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                              'Some health data could not be read. Values may be incomplete.',
                              style: TextStyle(fontSize: 13, color: _muted))),
                  ])),
                  const SizedBox(height: 16),
                  _pair(
                      _heading('Core Biometrics'),
                      const Text('Overnight vs Baseline',
                          style: TextStyle(fontSize: 11, color: _muted))),
                  const SizedBox(height: 8),
                  LayoutBuilder(builder: (context, constraints) {
                    final single = constraints.maxWidth < 280 ||
                        MediaQuery.textScalerOf(context).scale(14) > 22;
                    final metrics = [
                      _metric(
                          demo ? 'HRV RMSSD' : 'HRV SDNN',
                          hrv?.toStringAsFixed(0),
                          'ms',
                          Icons.monitor_heart_outlined,
                          _purple,
                          demo
                              ? '+14%'
                              : hrvDelta == null
                                  ? 'No baseline'
                                  : delta(hrvDelta, '%')),
                      _metric(
                          'Resting HR',
                          rhr?.toStringAsFixed(0),
                          'bpm',
                          Icons.favorite_border,
                          const Color(0xFFFF3B30),
                          demo
                              ? '-3 bpm'
                              : rhrDelta == null
                                  ? 'No baseline'
                                  : delta(rhrDelta, ' bpm')),
                      _metric(
                          'Skin Temp',
                          demo ? '+0.2' : null,
                          '°F',
                          Icons.device_thermostat,
                          const Color(0xFFFF2D55),
                          demo ? 'Normal' : 'Unavailable'),
                      _metric(
                          'Resp Rate',
                          respiration?.toStringAsFixed(1),
                          'rpm',
                          Icons.air,
                          const Color(0xFF32ADE6),
                          demo
                              ? 'Optimal'
                              : respiration == null
                                  ? 'No data'
                                  : 'Recorded'),
                    ];
                    return Wrap(spacing: 12, runSpacing: 12, children: [
                      for (final metric in metrics)
                        SizedBox(
                            width: single
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 12) / 2,
                            child: metric)
                    ]);
                  }),
                  const SizedBox(height: 16),
                  _card(Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _pair(
                            _heading('Recovery Contributors'),
                            const Text('Impact Score',
                                style: TextStyle(fontSize: 11, color: _muted))),
                        const SizedBox(height: 14),
                        _contributor(
                            'HRV Balance',
                            demo
                                ? 94
                                : score == null
                                    ? null
                                    : data?.recovery.breakdown['hrv'],
                            _green,
                            demo ? 'Excellent' : null),
                        _contributor(
                            'Sleep Restoration',
                            demo
                                ? 86
                                : score == null
                                    ? null
                                    : data?.recovery.breakdown['sleep'],
                            _purple,
                            demo ? 'Optimal' : null),
                        _contributor(
                            'Resting HR Stability',
                            demo
                                ? 82
                                : score == null
                                    ? null
                                    : data?.recovery.breakdown['rhr'],
                            _green,
                            demo ? 'Elevated' : null),
                      ])),
                  const SizedBox(height: 16),
                  _card(Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _pair(_heading('24h HRV Timeline'),
                            _badge(demo ? 'Avg 58 ms' : 'No timeline')),
                        const SizedBox(height: 4),
                        Text(
                            demo
                                ? 'Nightly peaks indicate deep parasympathetic tone'
                                : 'Intraday HRV samples are not available from the current data source.',
                            style: const TextStyle(
                                fontSize: 11, height: 1.4, color: _muted)),
                        if (demo) ...[
                          const SizedBox(height: 24),
                          Semantics(
                              label:
                                  'Demo HRV timeline: rising overnight, peaking near wake time, then falling and recovering.',
                              child: SizedBox(
                                  height: 112,
                                  child: CustomPaint(
                                      painter: _RecoveryTimelinePainter()))),
                          const Divider(color: _track, height: 20),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final label in [
                                  '12 AM',
                                  '4 AM',
                                  '8 AM\n(Wake)',
                                  '12 PM',
                                  '4 PM',
                                  'Now'
                                ])
                                  Expanded(
                                      child: Text(label,
                                          style: TextStyle(
                                              fontSize: 10, color: _muted))),
                              ]),
                        ] else
                          const SizedBox(height: 24),
                      ])),
                  const SizedBox(height: 16),
                  _card(Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(children: [
                          Icon(Icons.auto_awesome, color: _blue, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                              child: Text('FitX Intelligence',
                                  style: TextStyle(
                                      color: _blue,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)))
                        ]),
                        const SizedBox(height: 12),
                        Text(
                            demo
                                ? 'Sample insight: sustained recovery (+14% HRV overnight) paired with stable resting heart rate suggests lower fatigue. Explore your strain and activity details to plan your day.'
                                : 'Review your recovery alongside sleep and recent activity. FitX does not estimate remaining workout hours from these readings.',
                            style: const TextStyle(fontSize: 15, height: 1.6)),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: () => _navigate('strain'),
                            style: FilledButton.styleFrom(
                                backgroundColor: _ink,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.local_fire_department_outlined,
                                      size: 20),
                                  SizedBox(width: 8),
                                  Flexible(
                                      child: Text('Explore Strain',
                                          textAlign: TextAlign.center))
                                ])),
                      ])),
                ],
              ))),
    );
  }

  Widget _metric(String label, String? value, String unit, IconData icon,
          Color color, String badge) =>
      _card(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _pair(
              Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: _track, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 18)),
              _badge(badge, green: widget.demoMode && label != 'Skin Temp')),
          const SizedBox(height: 12),
          Text.rich(TextSpan(children: [
            TextSpan(
                text: value ?? '—',
                style: const TextStyle(
                    fontSize: 26,
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.5)),
            TextSpan(
                text: ' $unit',
                style: const TextStyle(
                    fontSize: 11, color: _muted, fontWeight: FontWeight.w600))
          ])),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: _muted, fontWeight: FontWeight.w500)),
        ]),
        padding: 14,
      );

  Widget _contributor(
          String title, double? value, Color color, String? label) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _pair(
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              Text(
                  value == null
                      ? 'Unavailable'
                      : '${label ?? 'Contribution'} (${value.round()}%)',
                  style: const TextStyle(fontSize: 11, color: _muted))),
          const SizedBox(height: 6),
          if (value != null)
            LinearProgressIndicator(
                value: (value / 100).clamp(0, 1),
                minHeight: 8,
                color: color,
                backgroundColor: _track,
                borderRadius: BorderRadius.circular(5),
                semanticsLabel: title),
        ]),
      );

  Widget _pair(Widget left, Widget right) =>
      LayoutBuilder(builder: (context, constraints) {
        if (MediaQuery.textScalerOf(context).scale(14) > 22) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [left, const SizedBox(height: 8), right]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: left),
          const SizedBox(width: 8),
          Flexible(
              flex: 2,
              child: Align(alignment: Alignment.centerRight, child: right))
        ]);
      });

  Widget _badge(String text, {bool green = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: green ? const Color(0xFFE1FDE7) : const Color(0xFFF3F5FF),
            borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: green ? const Color(0xFF006E28) : _muted)),
      );

  Widget _heading(String text) => Text(text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600));

  Widget _card(Widget child, {double padding = 20}) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E5EA)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x08000000), blurRadius: 3, offset: Offset(0, 1))
            ]),
        child: child,
      );
}

class _RecoveryRingPainter extends CustomPainter {
  const _RecoveryRingPainter(this.value, this.color);
  final double value;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
        center: size.center(Offset.zero), radius: size.shortestSide / 2 - 16);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE5E5EA);
    canvas.drawArc(rect, 0, math.pi * 2, false, paint);
    if (value > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value.clamp(0, 1), false,
          paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_RecoveryRingPainter oldDelegate) =>
      value != oldDelegate.value || color != oldDelegate.color;
}

class _RecoveryTimelinePainter extends CustomPainter {
  const _RecoveryTimelinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 320, size.height / 100);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 40, 320, 32), const Radius.circular(4)),
        Paint()..color = const Color(0xFFF4F3F8));
    final dash = Paint()
      ..color = const Color(0xFFE5E5EA)
      ..strokeWidth = 1;
    for (double x = 0; x < 320; x += 6) {
      canvas.drawLine(Offset(x, 55), Offset(x + 3, 55), dash);
    }
    final path = Path()
      ..moveTo(0, 76)
      ..cubicTo(35, 83, 48, 44, 82, 49)
      ..cubicTo(112, 56, 130, 46, 150, 26)
      ..cubicTo(180, -2, 193, 88, 227, 77)
      ..cubicTo(250, 72, 263, 35, 297, 44)
      ..quadraticBezierTo(320, 50, 320, 40);
    canvas.drawPath(
        path,
        Paint()
          ..color = _blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(
        const Offset(150, 26), 4.5, Paint()..color = Colors.white);
    canvas.drawCircle(
        const Offset(150, 26),
        4.5,
        Paint()
          ..color = _blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RecoveryTimelinePainter oldDelegate) => false;
}
