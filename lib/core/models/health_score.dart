import 'package:equatable/equatable.dart';

enum ScoreLevel { poor, fair, good, optimal }

extension ScoreLevelExt on ScoreLevel {
  String get label {
    switch (this) {
      case ScoreLevel.poor:
        return 'Poor';
      case ScoreLevel.fair:
        return 'Fair';
      case ScoreLevel.good:
        return 'Good';
      case ScoreLevel.optimal:
        return 'Optimal';
    }
  }

  // 0-40: poor, 41-60: fair, 61-80: good, 81-100: optimal
  static ScoreLevel fromScore(double score) {
    if (score <= 40) return ScoreLevel.poor;
    if (score <= 60) return ScoreLevel.fair;
    if (score <= 80) return ScoreLevel.good;
    return ScoreLevel.optimal;
  }
}

class HealthScore extends Equatable {
  final double value; // 0-100
  final DateTime date;
  final ScoreLevel level;
  final Map<String, double> breakdown; // contributing factors

  const HealthScore({
    required this.value,
    required this.date,
    required this.level,
    required this.breakdown,
  });

  factory HealthScore.empty(DateTime date) => HealthScore(
        value: 0,
        date: date,
        level: ScoreLevel.poor,
        breakdown: {},
      );

  Map<String, dynamic> toMap() => {
        'value': value,
        'date': date.toIso8601String(),
        'level': level.index,
        'breakdown':
            breakdown.entries.map((e) => '${e.key}:${e.value}').join(','),
      };

  factory HealthScore.fromMap(Map<String, dynamic> map) {
    final breakdownStr = map['breakdown'] as String? ?? '';
    final breakdown = <String, double>{};
    if (breakdownStr.isNotEmpty) {
      for (final part in breakdownStr.split(',')) {
        final kv = part.split(':');
        if (kv.length == 2) breakdown[kv[0]] = double.tryParse(kv[1]) ?? 0;
      }
    }
    return HealthScore(
      value: (map['value'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      level: ScoreLevel.values[map['level'] as int],
      breakdown: breakdown,
    );
  }

  @override
  List<Object?> get props => [value, date, level];
}
