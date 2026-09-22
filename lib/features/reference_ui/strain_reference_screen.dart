import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/activity_data.dart';
import '../../core/models/daily_health_summary.dart';
import '../../core/providers/providers.dart';

const _background = Color(0xFFF2F2F7);
const _ink = Color(0xFF1C1C1E);
const _muted = Color(0xFF686870);
const _border = Color(0xFFE5E5EA);
const _rose = Color(0xFFFF2D55);
const _green = Color(0xFF006E28);
const _blue = Color(0xFF0058BC);
const _zoneColors = [
  Color(0xFFAEAEB2),
  Color(0xFF32ADE6),
  Color(0xFF34C759),
  Color(0xFFFF3B30),
  _rose
];

/// Reference strain body. The host supplies bottom navigation and ProviderScope
/// when [demoMode] is false.
class StrainReferenceScreen extends StatefulWidget {
  const StrainReferenceScreen(
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
  State<StrainReferenceScreen> createState() => _StrainReferenceScreenState();
}

class _StrainReferenceScreenState extends State<StrainReferenceScreen> {
  late DateTime _date = _day(widget.selectedDate ?? DateTime.now());
  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @override
  void didUpdateWidget(covariant StrainReferenceScreen oldWidget) {
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
        firstDate: DateTime(1900),
        lastDate: today);
    if (!mounted || picked == null) return;
    setState(() => _date = picked);
    widget.onDateChanged?.call(picked);
  }

  void _back() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (widget.onNavigate != null) {
      widget.onNavigate!('today');
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      _details(context, 'Today',
          'Open this screen from the FitX dashboard to return to Today.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bold = MediaQuery.boldTextOf(context);
    final theme = ThemeData.light(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: _background,
      colorScheme:
          ColorScheme.fromSeed(seedColor: _blue, brightness: Brightness.light),
      textTheme: ThemeData.light()
          .textTheme
          .apply(fontFamily: 'Inter', bodyColor: _ink, displayColor: _ink),
    );
    return Theme(
        data: theme,
        child: DefaultTextStyle(
          style: TextStyle(
              fontFamily: 'Inter',
              color: _ink,
              fontSize: 13,
              height: 1.4,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              fontFeatures: const [FontFeature.tabularFigures()]),
          child: ColoredBox(
            color: _background,
            child: SafeArea(
                bottom: false,
                child: Column(children: [
                  ColoredBox(
                      color: const Color(0xFFFAF9FE),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(children: [
                            Semantics(
                                sortKey: const OrdinalSortKey(0),
                                child: IconButton(
                                    tooltip: 'Back',
                                    onPressed: _back,
                                    icon: const ExcludeSemantics(
                                        child: Icon(Icons.chevron_left,
                                            color: _ink)))),
                            const Expanded(
                                child: _Text('Strain',
                                    size: 18, weight: FontWeight.w700)),
                            Flexible(
                                child: _Text(
                                    '${_date == _day(DateTime.now()) ? 'Today, ' : ''}${DateFormat('MMM d').format(_date)}',
                                    color: _muted,
                                    size: 13)),
                            Semantics(
                                sortKey: const OrdinalSortKey(1),
                                child: IconButton(
                                    tooltip: 'Select date',
                                    onPressed: _pickDate,
                                    icon: const ExcludeSemantics(
                                        child: Icon(
                                            Icons.calendar_today_outlined,
                                            size: 21,
                                            color: _ink)))),
                          ]))),
                  Expanded(
                      child: widget.demoMode
                          ? _content(context, null)
                          : Consumer(builder: (context, ref, child) {
                              final summary =
                                  ref.watch(dailySummaryProvider(_date));
                              return summary.when(
                                data: (value) => _content(context, value),
                                loading: () => const Center(
                                    child: CircularProgressIndicator(
                                        semanticsLabel: 'Loading strain data')),
                                error: (error, stack) => Center(
                                    child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const _Text(
                                                  'Unable to load strain data',
                                                  size: 18,
                                                  weight: FontWeight.w700),
                                              const _Text(
                                                  'Your health data could not be read. Try again or check your health connection.'),
                                              TextButton(
                                                  onPressed: () =>
                                                      ref.invalidate(
                                                          dailySummaryProvider(
                                                              _date)),
                                                  child: const Text('Retry')),
                                            ]))),
                              );
                            })),
                ])),
          ),
        ));
  }

  Widget _content(BuildContext context, DailyHealthSummary? summary) {
    final demo = widget.demoMode;
    final hasStrain = summary?.metricFor('strain').valueOrNull != null;
    final strain = demo
        ? 14.2
        : hasStrain
            ? summary!.strainRaw
            : null;
    final target = demo ? 16.5 : summary?.strainTarget;
    final workouts = summary?.activity.workouts ?? <WorkoutSession>[];
    final peakValues =
        workouts.map((w) => w.maxHeartRate).whereType<double>().toList();
    final weighted = workouts
        .where((w) => w.avgHeartRate != null && w.duration.inSeconds > 0)
        .toList();
    final totalSeconds =
        weighted.fold<int>(0, (sum, w) => sum + w.duration.inSeconds);
    final average = totalSeconds == 0
        ? null
        : weighted.fold<double>(
                0, (sum, w) => sum + w.avgHeartRate! * w.duration.inSeconds) /
            totalSeconds;
    return SingleChildScrollView(
      key: const ValueKey('strain-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      child: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (demo)
            const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: _Text('FitX • Demo data', size: 11, color: _muted)),
          if (summary != null && summary.readErrors.isNotEmpty)
            const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: _Text(
                    'Some health sources could not be read. These readings may be incomplete.',
                    color: _muted)),
          _Card(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const _Heading('DAY STRAIN TARGET',
                          icon: Icons.local_fire_department, color: _rose),
                      _Badge(
                          demo
                              ? 'IN TARGET ZONE'
                              : hasStrain
                                  ? 'RECORDED STRAIN'
                                  : 'NO DATA',
                          color: demo ? _green : _muted),
                    ]),
                const SizedBox(height: 14),
                _Reflow(breakpoint: 280, children: [
                  _Ring(value: strain, target: target, demo: demo),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Text('TARGET EXERTION',
                            size: 11, color: _muted, weight: FontWeight.w600),
                        _Text(
                            demo
                                ? '14.0 – 16.5'
                                : target?.toStringAsFixed(1) ?? 'Not set',
                            size: 17,
                            weight: FontWeight.w700),
                        _Text(
                            demo
                                ? 'Calculated from 88% Recovery'
                                : 'Your FitX strain target',
                            size: 12,
                            color: _muted),
                        const SizedBox(height: 16),
                        _Text(demo ? 'TOLERANCE CAPACITY' : 'TARGET PROGRESS',
                            size: 11, color: _muted, weight: FontWeight.w600),
                        _Text(
                            strain != null && target != null && target > 0
                                ? '${(strain / target * 100).round()}%'
                                : 'Unavailable',
                            size: 12,
                            weight: FontWeight.w700),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                            value:
                                strain != null && target != null && target > 0
                                    ? (strain / target).clamp(0, 1)
                                    : 0,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(9),
                            backgroundColor: _background,
                            color: _rose,
                            semanticsLabel: 'Strain target progress'),
                      ]),
                ]),
              ])),
          const SizedBox(height: 16),
          _loadCard(demo),
          const SizedBox(height: 16),
          _Reflow(breakpoint: 240, children: [
            _Metric(
                'ACTIVE ENERGY',
                demo
                    ? '780'
                    : summary != null && summary.activity.activeCalories > 0
                        ? summary.activity.activeCalories.round().toString()
                        : '—',
                'KCAL',
                demo ? '↑ +14% vs avg' : 'Recorded active energy',
                Icons.bolt,
                _rose,
                positive: demo),
            _Metric(
                'PEAK HEART RATE',
                demo
                    ? '178'
                    : peakValues.isEmpty
                        ? '—'
                        : peakValues.reduce(math.max).round().toString(),
                'BPM',
                demo ? 'Interval 4 (07:42)' : 'Recorded workout peak',
                Icons.favorite_border,
                const Color(0xFFFF3B30)),
          ]),
          const SizedBox(height: 12),
          _Reflow(breakpoint: 240, children: [
            _Metric(
                'AVG WORKOUT HR',
                demo ? '146' : average?.round().toString() ?? '—',
                'BPM',
                demo ? 'Aerobic threshold' : 'Duration-weighted average',
                Icons.monitor_heart_outlined,
                _blue,
                positive: demo),
            _Metric(
                'ACTIVE EXERTION',
                demo
                    ? '1h 24m'
                    : summary != null &&
                            summary.activity.activeTime > Duration.zero
                        ? _duration(summary.activity.activeTime)
                        : '—',
                'DUR',
                demo
                    ? 'Across 2 sessions'
                    : '${workouts.length} recorded sessions',
                Icons.timer_outlined,
                const Color(0xFF00857F)),
          ]),
          const SizedBox(height: 16),
          _zonesCard(demo, workouts),
          const SizedBox(height: 8),
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Text('Logged Workouts (${demo ? 2 : workouts.length})',
                    size: 15, weight: FontWeight.w700),
                TextButton(
                    onPressed: () => _details(
                        context,
                        'Workout splits',
                        demo
                            ? 'Demo preview: detailed interval and kilometre splits are not included in this reference. No personal workout data is shown.'
                            : 'Split-level data is not available from the current health repository. Recorded workout totals are shown below.'),
                    child: const Text('View Splits')),
              ]),
          if (demo) ...[
            _workout('Morning Tempo Run', '06:45 AM • Outdoor GPS • 6.20 km',
                '11.8', '42m', Icons.directions_run, _rose, const [
              ('AVG PACE', '4:52 /km'),
              ('ENERGY', '492 kcal'),
              ('AVG HR', '158 bpm')
            ]),
            const SizedBox(height: 8),
            _workout(
                'Functional Hypertrophy',
                '01:15 PM • Upper Body Power • 14 Sets',
                '7.4',
                '41m',
                Icons.fitness_center,
                const Color(0xFF5856D6), const [
              ('LOAD VOLUME', '8,420 kg'),
              ('ENERGY', '288 kcal'),
              ('AVG HR', '126 bpm')
            ]),
          ] else if (workouts.isEmpty)
            const _Card(
                child:
                    _Text('No recorded workouts for this date.', color: _muted))
          else
            ...workouts.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _workout(
                    w.type.label,
                    DateFormat('h:mm a').format(w.start),
                    w.strainContribution.toStringAsFixed(1),
                    _duration(w.duration),
                    w.type == WorkoutType.running
                        ? Icons.directions_run
                        : Icons.fitness_center,
                    _rose,
                    [
                      ('DURATION', _duration(w.duration)),
                      ('ENERGY', '${w.calories.round()} kcal'),
                      (
                        'AVG HR',
                        w.avgHeartRate == null
                            ? 'Unavailable'
                            : '${w.avgHeartRate!.round()} bpm'
                      )
                    ]))),
          const SizedBox(height: 16),
          _Card(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const _Heading('EVENING STRAIN GUIDANCE',
                    icon: Icons.bedtime_outlined, color: _blue),
                const SizedBox(height: 8),
                _Text(
                    demo ? 'Make room for recovery.' : 'Review your recovery.',
                    size: 17,
                    weight: FontWeight.w500),
                const SizedBox(height: 4),
                _Text(
                    demo
                        ? 'This demo illustrates a day in the target zone. Training guidance and bedtime predictions require your personal recovery data.'
                        : 'Consider your recorded recovery and how you feel when planning further activity. Personalized evening guidance is not available here.',
                    color: _muted),
                const Divider(color: _border, height: 24),
                Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Text(
                          demo
                              ? 'Demo bedtime: 10:45 PM'
                              : 'FitX recovery overview',
                          size: 11,
                          color: _muted),
                      TextButton(
                          onPressed: () {
                            if (widget.onNavigate != null) {
                              widget.onNavigate!('recovery');
                            } else {
                              _details(context, 'Recovery',
                                  'Open the Recovery tab in FitX to review your recovery inputs.');
                            }
                          },
                          child: const Text('View Recovery')),
                    ]),
              ])),
        ]),
      )),
    );
  }

  Widget _loadCard(bool demo) => _Card(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              const _Heading('CARDIOVASCULAR LOAD RATIO',
                  icon: Icons.trending_up, color: _blue),
              _Badge(demo ? '1.14 • Productive' : 'Unavailable',
                  color: demo ? _green : _muted),
            ]),
        const SizedBox(height: 8),
        _Text(
            demo
                ? 'Acute 7-day load relative to a 28-day chronic baseline. Demo illustration of training-load balance.'
                : 'A comparable 7-day and 28-day cardiovascular load baseline is not available.',
            color: _muted),
        if (demo) ...[
          const SizedBox(height: 20),
          const ExcludeSemantics(
              child: SizedBox(
                  height: 16, child: CustomPaint(painter: _LoadPainter()))),
          const SizedBox(height: 4),
          const _Reflow(breakpoint: 250, children: [
            _ScaleLabel('0.7', 'Detraining'),
            _ScaleLabel('1.0', 'Steady'),
            _ScaleLabel('1.14', 'Optimal', optimal: true),
            _ScaleLabel('1.4', 'Overreaching'),
          ]),
          const Divider(color: _border, height: 28),
          const _Reflow(breakpoint: 260, children: [
            _Well('7-Day Acute', '824 AU'),
            _Well('28-Day Chronic', '722 AU')
          ]),
        ],
      ]));

  Widget _zonesCard(bool demo, List<WorkoutSession> workouts) {
    final minutes = List<double>.filled(5, 0);
    final ranges = List<String>.filled(5, '');
    if (demo) {
      minutes.setAll(0, [12, 23, 27, 15, 7]);
      ranges.setAll(0, ['100–117', '118–135', '136–153', '154–171', '172+']);
    } else {
      for (final workout in workouts) {
        for (final zone in workout.hrZones) {
          if (zone.zone < 1 || zone.zone > 5) continue;
          final index = zone.zone - 1;
          minutes[index] += zone.duration.inSeconds / 60;
          final range = '${zone.minBpm.round()}–${zone.maxBpm.round()}';
          ranges[index] = ranges[index].isEmpty || ranges[index] == range
              ? range
              : 'Varied thresholds';
        }
      }
    }
    final total = minutes.reduce((a, b) => a + b);
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          runSpacing: 8,
          children: [
            const _Heading('5 CARDIAC ZONES',
                icon: Icons.monitor_heart_outlined, color: Color(0xFFD82E28)),
            _Text('${total.round()} min total recorded',
                size: 11, color: _muted),
          ]),
      const SizedBox(height: 10),
      if (total == 0)
        const _Text('No recorded heart-rate zones for this date.',
            color: _muted)
      else ...[
        ExcludeSemantics(
            child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(children: [
                  for (var i = 0; i < 5; i++)
                    if (minutes[i] > 0)
                      Expanded(
                          flex: (minutes[i] * 60).round().clamp(1, 1000000),
                          child: Container(height: 7, color: _zoneColors[i])),
                ]))),
        const SizedBox(height: 16),
        for (var i = 4; i >= 0; i--) ...[
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ExcludeSemantics(
                    child: Container(
                        margin: const EdgeInsets.only(top: 5, right: 8),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: _zoneColors[i], shape: BoxShape.circle))),
                Expanded(
                    child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: 'Zone ${i + 1} ',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(
                      text: ranges[i].isEmpty
                          ? '(No samples)'
                          : '(${ranges[i]}${ranges[i] == 'Varied thresholds' ? '' : ' bpm'})',
                      style: const TextStyle(color: _muted)),
                ]))),
                const SizedBox(width: 8),
                _Text('${minutes[i].round()}m', weight: FontWeight.w600),
                const SizedBox(width: 12),
                _Text('${(minutes[i] / total * 100).round()}%',
                    size: 11, color: _muted),
              ])),
          if (i > 0) const Divider(height: 1, color: _border),
        ],
      ],
    ]));
  }

  Widget _workout(String title, String subtitle, String strain, String duration,
          IconData icon, Color color, List<(String, String)> metrics) =>
      _Card(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ExcludeSemantics(
              child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 24))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _Text(title, size: 15, weight: FontWeight.w700),
                _Text(subtitle, size: 12, color: _muted),
              ])),
        ]),
        const SizedBox(height: 10),
        Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _Badge('STRAIN $strain • $duration',
                color: color == _rose ? const Color(0xFFBA0034) : color)),
        const Divider(color: _border, height: 24),
        _Reflow(
            breakpoint: 280,
            children: metrics.map((m) => _Well(m.$1, m.$2)).toList()),
      ]));
}

String _duration(Duration duration) => duration.inHours > 0
    ? '${duration.inHours}h ${duration.inMinutes.remainder(60)}m'
    : '${duration.inMinutes}m';

Future<void> _details(BuildContext context, String title, String message) =>
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(title),
                content: SingleChildScrollView(child: Text(message)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'))
                ]));

class _Text extends StatelessWidget {
  const _Text(this.text,
      {this.size = 13, this.color = _ink, this.weight = FontWeight.w400});
  final String text;
  final double size;
  final Color color;
  final FontWeight weight;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: MediaQuery.boldTextOf(context) ? FontWeight.w700 : weight,
          height: 1.35,
          fontFeatures: const [FontFeature.tabularFigures()]));
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x07000000), blurRadius: 3, offset: Offset(0, 2))
          ]),
      child: child);
}

class _Heading extends StatelessWidget {
  const _Heading(this.label, {required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        ExcludeSemantics(
            child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(7)),
                child: Icon(icon, size: 15, color: color))),
        const SizedBox(width: 7),
        Flexible(
            child:
                _Text(label, size: 11, color: _muted, weight: FontWeight.w600)),
      ]);
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(20)),
      child: _Text(label, size: 11, color: color, weight: FontWeight.w700));
}

class _Reflow extends StatelessWidget {
  const _Reflow({required this.children, required this.breakpoint});
  final List<Widget> children;
  final double breakpoint;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final stack = constraints.maxWidth < breakpoint ||
            MediaQuery.textScalerOf(context).scale(13) > 19;
        if (stack) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  children[i]
                ],
              ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: children[i])
          ],
        ]);
      });
}

class _Metric extends StatelessWidget {
  const _Metric(
      this.label, this.value, this.unit, this.caption, this.icon, this.color,
      {this.positive = false});
  final String label, value, unit, caption;
  final IconData icon;
  final Color color;
  final bool positive;
  @override
  Widget build(BuildContext context) => _Card(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _Text(label, size: 11, color: _muted)),
          ExcludeSemantics(child: Icon(icon, size: 17, color: color))
        ]),
        const SizedBox(height: 4),
        Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              _Text(value, size: 26, weight: FontWeight.w700),
              _Text(unit, size: 11, color: _muted, weight: FontWeight.w600)
            ]),
        const SizedBox(height: 4),
        _Text(caption,
            size: 12,
            color: positive ? _green : _muted,
            weight: FontWeight.w500),
      ]));
}

class _Well extends StatelessWidget {
  const _Well(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: _background, borderRadius: BorderRadius.circular(9)),
      child: Column(children: [
        _Text(label, size: 10, color: _muted),
        _Text(value, size: 14, weight: FontWeight.w600)
      ]));
}

class _ScaleLabel extends StatelessWidget {
  const _ScaleLabel(this.value, this.label, {this.optimal = false});
  final String value, label;
  final bool optimal;
  @override
  Widget build(BuildContext context) => Column(children: [
        _Text(value,
            size: 11, color: optimal ? _green : _ink, weight: FontWeight.w700),
        _Text(label, size: 10, color: optimal ? _green : _muted),
      ]);
}

class _Ring extends StatelessWidget {
  const _Ring({required this.value, required this.target, required this.demo});
  final double? value, target;
  final bool demo;
  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(13) > 19;
    final label = Column(mainAxisSize: MainAxisSize.min, children: [
      _Text(value?.toStringAsFixed(1) ?? '—',
          size: 32, weight: FontWeight.w800),
      _Text(
          value == null
              ? 'NO STRAIN DATA'
              : target == null
                  ? 'DAY STRAIN'
                  : 'OF ${target!.toStringAsFixed(1)} GOAL',
          size: 11,
          color: _muted,
          weight: FontWeight.w600),
    ]);
    return Column(children: [
      Semantics(
          label: value == null
              ? 'No strain data'
              : 'Day strain ${value!.toStringAsFixed(1)}${target == null ? '' : ' of ${target!.toStringAsFixed(1)} goal'}',
          child: ExcludeSemantics(
              child: SizedBox(
                  width: 148,
                  height: 148,
                  child: CustomPaint(
                      painter: _RingPainter(
                          value == null
                              ? 0
                              : demo
                                  ? .70
                                  : (value! / 21).clamp(0, 1),
                          demo),
                      child: largeText
                          ? null
                          : Center(
                              child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: label)))))),
      if (largeText) label,
    ]);
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress, this.demo);
  final double progress;
  final bool demo;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        rect, 0, math.pi * 2, false, paint..color = const Color(0xFFEEEEF2));
    if (demo) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * .80, false,
          paint..color = const Color(0xFFF8C9D3));
    }
    if (progress > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false,
          paint..color = _rose);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      progress != oldDelegate.progress || demo != oldDelegate.demo;
}

class _LoadPainter extends CustomPainter {
  const _LoadPainter();
  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xFFACE0F5),
      Color(0xFF9BE3AD),
      Color(0xFF34C759),
      Color(0xFFF9A9BB)
    ];
    final width = size.width / 4;
    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(i * width + 1, 6, width - 4, 5),
              const Radius.circular(2)),
          Paint()..color = colors[i]);
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .625 - 3, 1, 6, 15),
            const Radius.circular(3)),
        Paint()..color = _ink);
  }

  @override
  bool shouldRepaint(_LoadPainter oldDelegate) => false;
}
