import 'package:equatable/equatable.dart';

/// The lifecycle state of a health metric.
enum MetricStatus { available, calibrating, unavailable }

/// How recently a metric was refreshed for the context in which it is shown.
///
/// Freshness is deliberately supplied by the repository that understands the
/// metric's cadence. For example, yesterday's sleep can be current while a
/// heart-rate sample of the same age is stale.
enum MetricFreshness { current, recent, stale, unknown }

/// A coarse, user-explainable estimate of confidence in a metric.
enum MetricConfidence { high, medium, low, unknown }

/// The broad origin of a metric.
enum MetricSourceType {
  healthConnect,
  device,
  manual,
  derived,
  imported,
  unknown
}

/// Why a metric cannot currently be provided.
enum MetricUnavailableReason {
  noData,
  permissionDenied,
  notSupported,
  disconnected,
  syncFailed,
  unknown,
}

/// The interval represented by a metric or aggregate.
class MetricTimeRange extends Equatable {
  // DateTime ordering is not a const operation, so this constructor performs
  // its invariant check at runtime.
  // ignore: prefer_const_constructors_in_immutables
  MetricTimeRange({required this.start, required this.end})
      : assert(!end.isBefore(start), 'end must not be before start');

  /// Creates a point-in-time range.
  // ignore: prefer_const_constructors_in_immutables
  MetricTimeRange.instant(DateTime instant)
      : start = instant,
        end = instant;

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  @override
  List<Object?> get props => [start, end];
}

/// Identifies where a metric came from without tying the domain to a plugin.
class MetricSource extends Equatable {
  const MetricSource({
    required this.type,
    required this.name,
    this.id,
  });

  const MetricSource.unknown()
      : type = MetricSourceType.unknown,
        name = 'Unknown',
        id = null;

  final MetricSourceType type;
  final String name;

  /// Optional stable provider or device identifier.
  final String? id;

  @override
  List<Object?> get props => [type, name, id];
}

/// Provenance and quality information shared by every metric state.
class MetricMetadata extends Equatable {
  const MetricMetadata({
    required this.range,
    required this.source,
    this.freshness = MetricFreshness.unknown,
    this.confidence = MetricConfidence.unknown,
    this.lastSyncedAt,
  });

  final MetricTimeRange range;
  final MetricSource source;
  final MetricFreshness freshness;
  final MetricConfidence confidence;
  final DateTime? lastSyncedAt;

  @override
  List<Object?> get props => [
        range,
        source,
        freshness,
        confidence,
        lastSyncedAt,
      ];
}

/// A metric whose availability is explicit rather than encoded as `null` or 0.
///
/// Consumers should branch on [status] (or the concrete subtype) before
/// rendering. Only [AvailableMetricValue] exposes a non-null [valueOrNull].
sealed class MetricValue<T> extends Equatable {
  const MetricValue({required this.metadata});

  const factory MetricValue.available({
    required T value,
    required MetricMetadata metadata,
  }) = AvailableMetricValue<T>;

  const factory MetricValue.calibrating({
    required MetricMetadata metadata,
    double? progress,
    String? message,
  }) = CalibratingMetricValue<T>;

  const factory MetricValue.unavailable({
    required MetricMetadata metadata,
    required MetricUnavailableReason reason,
    String? message,
  }) = UnavailableMetricValue<T>;

  final MetricMetadata metadata;

  MetricStatus get status;
  T? get valueOrNull;

  bool get isAvailable => status == MetricStatus.available;
}

/// A metric backed by an observed or computed value.
final class AvailableMetricValue<T> extends MetricValue<T> {
  const AvailableMetricValue({
    required this.value,
    required super.metadata,
  });

  final T value;

  @override
  MetricStatus get status => MetricStatus.available;

  @override
  T get valueOrNull => value;

  @override
  List<Object?> get props => [value, metadata];
}

/// A metric that needs more observations before a value can be trusted.
final class CalibratingMetricValue<T> extends MetricValue<T> {
  const CalibratingMetricValue({
    required super.metadata,
    this.progress,
    this.message,
  }) : assert(
          progress == null || (progress >= 0 && progress <= 1),
          'progress must be between 0 and 1',
        );

  /// Optional completion ratio in the inclusive range 0–1.
  final double? progress;
  final String? message;

  @override
  MetricStatus get status => MetricStatus.calibrating;

  @override
  T? get valueOrNull => null;

  @override
  List<Object?> get props => [metadata, progress, message];
}

/// A metric that cannot be produced under current conditions.
final class UnavailableMetricValue<T> extends MetricValue<T> {
  const UnavailableMetricValue({
    required super.metadata,
    required this.reason,
    this.message,
  });

  final MetricUnavailableReason reason;
  final String? message;

  @override
  MetricStatus get status => MetricStatus.unavailable;

  @override
  T? get valueOrNull => null;

  @override
  List<Object?> get props => [metadata, reason, message];
}
