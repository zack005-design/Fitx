import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceSensorCapabilities {
  const DeviceSensorCapabilities({
    required this.stepCounter,
    required this.stepDetector,
    required this.accelerometer,
    required this.gyroscope,
    required this.activityRecognitionGranted,
  });

  final bool stepCounter;
  final bool stepDetector;
  final bool accelerometer;
  final bool gyroscope;
  final bool activityRecognitionGranted;

  bool get hasMotionSensors => accelerometer || gyroscope;
  bool get hasStepSensor => stepCounter || stepDetector;

  factory DeviceSensorCapabilities.fromMap(Map<Object?, Object?> map) =>
      DeviceSensorCapabilities(
        stepCounter: map['stepCounter'] == true,
        stepDetector: map['stepDetector'] == true,
        accelerometer: map['accelerometer'] == true,
        gyroscope: map['gyroscope'] == true,
        activityRecognitionGranted: map['activityRecognitionGranted'] == true,
      );
}

class DeviceSensorSample {
  const DeviceSensorSample({
    required this.type,
    required this.timestampNanos,
    required this.values,
  });

  final String type;
  final int timestampNanos;
  final List<double> values;

  factory DeviceSensorSample.fromMap(Map<Object?, Object?> map) =>
      DeviceSensorSample(
        type: map['type'] as String? ?? 'unknown',
        timestampNanos: map['timestampNanos'] as int? ?? 0,
        values: (map['values'] as List<Object?>? ?? const [])
            .whereType<num>()
            .map((value) => value.toDouble())
            .toList(growable: false),
      );
}

/// Native Android sensor access used for live, foreground workout tracking.
/// Long-term health history continues to come from Health Connect, which is
/// substantially more battery-efficient than keeping raw sensors registered.
class DeviceSensorService {
  static const _methods = MethodChannel('fitx/device_sensors');
  static const _events = EventChannel('fitx/device_sensor_events');

  Future<DeviceSensorCapabilities> getCapabilities() async {
    final result = await _methods.invokeMapMethod<Object?, Object?>(
      'getCapabilities',
    );
    return DeviceSensorCapabilities.fromMap(result ?? const {});
  }

  Future<bool> requestActivityRecognition() async {
    final status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  Stream<DeviceSensorSample> get samples => _events
      .receiveBroadcastStream()
      .where((event) => event is Map<Object?, Object?>)
      .map(
        (event) => DeviceSensorSample.fromMap(
          event as Map<Object?, Object?>,
        ),
      );
}
