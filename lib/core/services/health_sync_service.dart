import '../models/health_day.dart';
import '../models/sync_state.dart';
import '../models/user_profile.dart';
import '../repositories/health_repository.dart';
import 'database_service.dart';
import 'health_connect_service.dart';

/// Incremental, retry-safe synchronization that can be called from foreground
/// lifecycle events or a background entry point. Every day is an idempotent
/// database upsert and the checkpoint advances only after a clean source read.
class HealthSyncService {
  HealthSyncService({
    required HealthConnectService healthConnect,
    required HealthRepository repository,
    required DatabaseService database,
    DateTime Function()? clock,
  })  : _healthConnect = healthConnect,
        _repository = repository,
        _database = database,
        _clock = clock ?? DateTime.now;

  final HealthConnectService _healthConnect;
  final HealthRepository _repository;
  final DatabaseService _database;
  final DateTime Function() _clock;
  Future<HealthSyncState>? _activeSync;

  Future<HealthSyncState> sync(UserProfile? profile,
      {int initialDays = 7, int maximumDays = 31}) {
    return _activeSync ??=
        _run(profile, initialDays: initialDays, maximumDays: maximumDays)
            .whenComplete(() => _activeSync = null);
  }

  Future<HealthSyncState> _run(UserProfile? profile,
      {required int initialDays, required int maximumDays}) async {
    final now = _clock();
    final previous = await _database.getSyncState();
    var current = previous;
    try {
      if (previous.phase == SyncPhase.syncing &&
          previous.lastAttempt != null &&
          now.difference(previous.lastAttempt!).inMinutes < 10) {
        return previous;
      }
      if (!await _healthConnect.checkAvailability()) {
        return await _finish(
            previous.copyWith(
              phase: SyncPhase.unavailable,
              lastAttempt: now,
              message: 'Health Connect is not available on this device.',
            ),
            sourceStatus: 'unavailable');
      }
      if (!await _healthConnect.checkPermissions()) {
        return await _finish(
            previous.copyWith(
              phase: SyncPhase.permissionRequired,
              lastAttempt: now,
              message: 'Health Connect permission is required to sync.',
            ),
            sourceStatus: 'permission_required');
      }

      final today = healthDay(now);
      var start = previous.checkpoint == null
          ? shiftHealthDay(today, 1 - initialDays)
          : shiftHealthDay(previous.checkpoint!, -1);
      final earliest = shiftHealthDay(today, 1 - maximumDays);
      if (start.isBefore(earliest)) start = earliest;
      final total = today.difference(start).inDays + 1;
      var state = previous.copyWith(
        phase: SyncPhase.syncing,
        lastAttempt: now,
        completedDays: 0,
        totalDays: total,
        message: 'Reading Health Connect data…',
      );
      await _database.saveSyncState(state);
      current = state;

      var completed = 0;
      DateTime? checkpoint = previous.checkpoint;
      for (var day = start; !day.isAfter(today); day = shiftHealthDay(day, 1)) {
        final summary = await _repository.getDailySummary(day, profile,
            refresh: previous.checkpoint != null);
        if (summary.readErrors.isNotEmpty) {
          throw HealthSyncException(
              'Some Health Connect categories could not be read. Saved history was kept.');
        }
        completed++;
        checkpoint = day;
        state = state.copyWith(
          checkpoint: checkpoint,
          completedDays: completed,
          message: 'Synced $completed of $total days',
        );
        await _database.saveSyncState(state);
        current = state;
      }

      return await _finish(
          state.copyWith(
            phase: SyncPhase.success,
            checkpoint: checkpoint,
            lastSuccessfulSync: _clock(),
            completedDays: total,
            message: 'Health Connect is up to date.',
          ),
          sourceStatus: 'ready',
          lastSeenAt: _clock());
    } catch (error) {
      return _finish(
          current.copyWith(
            phase: SyncPhase.error,
            lastAttempt: now,
            message: error is HealthSyncException
                ? error.message
                : 'Health Connect sync failed. Your saved history is still available.',
          ),
          sourceStatus: 'error');
    }
  }

  Future<HealthSyncState> _finish(HealthSyncState state,
      {required String sourceStatus, DateTime? lastSeenAt}) async {
    await _database.saveSyncState(state);
    await _database.updateHealthConnectSource(
        status: sourceStatus, lastSeenAt: lastSeenAt);
    return state;
  }
}

class HealthSyncException implements Exception {
  const HealthSyncException(this.message);
  final String message;
}
