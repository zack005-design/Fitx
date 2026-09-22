enum SyncPhase {
  idle,
  syncing,
  success,
  permissionRequired,
  unavailable,
  error
}

class HealthSyncState {
  const HealthSyncState({
    this.phase = SyncPhase.idle,
    this.lastSuccessfulSync,
    this.checkpoint,
    this.lastAttempt,
    this.message,
    this.completedDays = 0,
    this.totalDays = 0,
  });

  final SyncPhase phase;
  final DateTime? lastSuccessfulSync;
  final DateTime? checkpoint;
  final DateTime? lastAttempt;
  final String? message;
  final int completedDays;
  final int totalDays;

  bool get isRunning => phase == SyncPhase.syncing;

  HealthSyncState copyWith({
    SyncPhase? phase,
    DateTime? lastSuccessfulSync,
    DateTime? checkpoint,
    DateTime? lastAttempt,
    String? message,
    int? completedDays,
    int? totalDays,
  }) =>
      HealthSyncState(
        phase: phase ?? this.phase,
        lastSuccessfulSync: lastSuccessfulSync ?? this.lastSuccessfulSync,
        checkpoint: checkpoint ?? this.checkpoint,
        lastAttempt: lastAttempt ?? this.lastAttempt,
        message: message,
        completedDays: completedDays ?? this.completedDays,
        totalDays: totalDays ?? this.totalDays,
      );

  Map<String, Object?> toMap() => {
        'id': 1,
        'phase': phase.name,
        'last_successful_sync': lastSuccessfulSync?.toIso8601String(),
        'checkpoint': checkpoint?.toIso8601String(),
        'last_attempt': lastAttempt?.toIso8601String(),
        'message': message,
      };

  factory HealthSyncState.fromMap(Map<String, Object?> map) => HealthSyncState(
        phase: SyncPhase.values.firstWhere(
          (value) => value.name == map['phase'],
          orElse: () => SyncPhase.idle,
        ),
        lastSuccessfulSync:
            DateTime.tryParse(map['last_successful_sync'] as String? ?? ''),
        checkpoint: DateTime.tryParse(map['checkpoint'] as String? ?? ''),
        lastAttempt: DateTime.tryParse(map['last_attempt'] as String? ?? ''),
        message: map['message'] as String?,
      );
}
