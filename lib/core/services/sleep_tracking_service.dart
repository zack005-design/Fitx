import 'package:flutter/services.dart';

import '../models/sleep_tracking.dart';

class SleepTrackingService {
  static const _channel = MethodChannel('fitx/sleep_tracking');

  Future<NativeSleepTrackingState> state() async {
    final map = await _channel.invokeMapMethod<Object?, Object?>('getState');
    return NativeSleepTrackingState.fromMap(map ?? const {});
  }

  Future<NativeSleepTrackingState> start() async {
    final map = await _channel.invokeMapMethod<Object?, Object?>('start');
    return NativeSleepTrackingState.fromMap(map ?? const {});
  }

  Future<NativeSleepTrackingState> stop() async {
    final map = await _channel.invokeMapMethod<Object?, Object?>('stop');
    return NativeSleepTrackingState.fromMap(map ?? const {});
  }
}
