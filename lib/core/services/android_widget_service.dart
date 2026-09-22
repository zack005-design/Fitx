import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Keeps the Android launcher widget in sync with the daily FitX briefing.
/// This is deliberately platform-native so the widget works without a third-party
/// plugin and remains available when the Flutter UI is not open.
class AndroidWidgetService {
  AndroidWidgetService._();

  static const _channel = MethodChannel('fitx/android_widget');
  static String? _lastSignature;

  static Future<void> updateDailyOverview({
    required int? recovery,
    required int? sleep,
    required String? strain,
    required DateTime? syncedAt,
  }) async {
    if (!Platform.isAndroid) return;
    final sourceLabel = syncedAt == null
        ? 'Open FitX to sync Health Connect'
        : 'Health Connect · ${DateFormat('MMM d, HH:mm').format(syncedAt)}';
    final signature = '$recovery:$sleep:$strain:$sourceLabel';
    if (_lastSignature == signature) return;

    try {
      await _channel.invokeMethod<void>('updateDailyOverview', {
        'recovery': recovery,
        'sleep': sleep,
        'strain': strain,
        'sourceLabel': sourceLabel,
      });
      _lastSignature = signature;
    } on MissingPluginException {
      // Widget channel may be absent in tests.
    } on PlatformException {
      // The in-app briefing should remain available if the launcher cannot update.
    }
  }
}
