class AppPreferences {
  const AppPreferences({
    this.useMetric = true,
    this.baselineWindowDays = 30,
    this.sourcePriority = 'Health Connect aggregate',
  });

  final bool useMetric;
  final int baselineWindowDays;
  final String sourcePriority;

  AppPreferences copyWith({
    bool? useMetric,
    int? baselineWindowDays,
    String? sourcePriority,
  }) =>
      AppPreferences(
        useMetric: useMetric ?? this.useMetric,
        baselineWindowDays: baselineWindowDays ?? this.baselineWindowDays,
        sourcePriority: sourcePriority ?? this.sourcePriority,
      );

  Map<String, Object?> toMap() => {
        'id': 1,
        'use_metric': useMetric ? 1 : 0,
        'baseline_window_days': baselineWindowDays,
        'source_priority': sourcePriority,
      };

  factory AppPreferences.fromMap(Map<String, Object?> map) => AppPreferences(
        useMetric: (map['use_metric'] as int? ?? 1) == 1,
        baselineWindowDays: map['baseline_window_days'] as int? ?? 30,
        sourcePriority:
            map['source_priority'] as String? ?? 'Health Connect aggregate',
      );
}
