import 'package:fitx/core/models/metric_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 9, 12, 22);
  final end = DateTime.utc(2026, 9, 13, 6);

  final metadata = MetricMetadata(
    range: MetricTimeRange(start: start, end: end),
    source: const MetricSource(
      type: MetricSourceType.healthConnect,
      name: 'Health Connect',
      id: 'health_connect',
    ),
    freshness: MetricFreshness.current,
    confidence: MetricConfidence.high,
    lastSyncedAt: DateTime.utc(2026, 9, 13, 6, 5),
  );

  group('MetricValue', () {
    test('available state exposes its value and provenance', () {
      final metric = MetricValue<double>.available(
        value: 82.5,
        metadata: metadata,
      );

      expect(metric.status, MetricStatus.available);
      expect(metric.isAvailable, isTrue);
      expect(metric.valueOrNull, 82.5);
      expect(metric.metadata.source.name, 'Health Connect');
      expect(metric.metadata.range.duration, const Duration(hours: 8));
      expect(metric.metadata.freshness, MetricFreshness.current);
      expect(metric.metadata.confidence, MetricConfidence.high);
    });

    test('calibrating state never presents a placeholder value', () {
      final metric = MetricValue<double>.calibrating(
        metadata: metadata,
        progress: 0.4,
        message: 'Two more nights needed',
      );

      expect(metric.status, MetricStatus.calibrating);
      expect(metric.isAvailable, isFalse);
      expect(metric.valueOrNull, isNull);
      expect(metric, isA<CalibratingMetricValue<double>>());
      final calibrating = metric as CalibratingMetricValue<double>;
      expect(calibrating.progress, 0.4);
      expect(calibrating.message, 'Two more nights needed');
    });

    test('unavailable state carries a typed reason instead of a zero', () {
      final metric = MetricValue<int>.unavailable(
        metadata: metadata,
        reason: MetricUnavailableReason.permissionDenied,
        message: 'Allow sleep access to calculate recovery',
      );

      expect(metric.status, MetricStatus.unavailable);
      expect(metric.isAvailable, isFalse);
      expect(metric.valueOrNull, isNull);
      expect(metric, isA<UnavailableMetricValue<int>>());
      expect(
        (metric as UnavailableMetricValue<int>).reason,
        MetricUnavailableReason.permissionDenied,
      );
    });

    test('equivalent values compare by value and metadata', () {
      final first = MetricValue<double>.available(
        value: 82.5,
        metadata: metadata,
      );
      final second = MetricValue<double>.available(
        value: 82.5,
        metadata: metadata,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });

  group('MetricTimeRange', () {
    test('instant range has no duration', () {
      final instant = DateTime.utc(2026, 9, 13, 9, 30);

      final range = MetricTimeRange.instant(instant);

      expect(range.start, instant);
      expect(range.end, instant);
      expect(range.duration, Duration.zero);
    });

    test('rejects an end before its start', () {
      expect(
        () => MetricTimeRange(start: end, end: start),
        throwsAssertionError,
      );
    });
  });

  test('calibration progress must remain within zero and one', () {
    expect(
      () => MetricValue<double>.calibrating(
        metadata: metadata,
        progress: 1.1,
      ),
      throwsAssertionError,
    );
  });
}
