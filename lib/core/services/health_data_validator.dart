import 'dart:math' as math;

/// Physiological plausibility checks prevent corrupt imports and unit mistakes
/// from entering scores. These broad bounds are not diagnostic reference ranges.
class HealthDataValidator {
  static double? heartRate(num? value) => _bounded(value, 25, 250);
  static double? restingHeartRate(num? value) => _bounded(value, 25, 220);
  static double? hrvSdnn(num? value) => _bounded(value, 1, 500);
  static double? respiratoryRate(num? value) => _bounded(value, 3, 80);

  static double? oxygenSaturation(num? value) {
    var number = _finite(value);
    if (number == null) return null;
    if (number > 0 && number <= 1) number *= 100;
    return number >= 50 && number <= 100 ? number : null;
  }

  static double nonNegative(num? value, {double maximum = 1000000}) {
    final number = _finite(value);
    if (number == null || number < 0 || number > maximum) return 0;
    return number;
  }

  static double? median(Iterable<double?> values) {
    final valid = values.whereType<double>().where((v) => v.isFinite).toList()
      ..sort();
    if (valid.isEmpty) return null;
    final middle = valid.length ~/ 2;
    return valid.length.isOdd
        ? valid[middle]
        : (valid[middle - 1] + valid[middle]) / 2;
  }

  static double? _bounded(num? value, double minimum, double maximum) {
    final number = _finite(value);
    return number != null && number >= minimum && number <= maximum
        ? number
        : null;
  }

  static double? _finite(num? value) {
    final number = value?.toDouble();
    return number != null && number.isFinite && !number.isNaN ? number : null;
  }

  static Duration validDuration(DateTime start, DateTime end,
      {Duration maximum = const Duration(hours: 24)}) {
    final duration = end.difference(start);
    return duration > Duration.zero && duration <= maximum
        ? duration
        : Duration.zero;
  }

  static int roundedNonNegative(num? value, {int maximum = 1000000}) => math
      .min(maximum, nonNegative(value, maximum: maximum.toDouble()).round());
}
