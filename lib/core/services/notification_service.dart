import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ReminderStatus {
  const ReminderStatus(
      {required this.notificationsEnabled,
      required this.exactAlarmsAllowed,
      required this.timeZone,
      required this.reminders});

  final bool notificationsEnabled;
  final bool exactAlarmsAllowed;
  final String timeZone;
  final List<Map<String, Object?>> reminders;

  bool hasReminder(int id) => reminders.any((item) => item['id'] == id);
  bool get hasHydration =>
      reminders.any((item) => (item['id'] as int? ?? -1) >= 100);
  bool get hasSmartAlarm => reminders.any(
      (item) => (item['id'] as int? ?? -1) >= 10 && (item['id'] as int) <= 22);

  factory ReminderStatus.fromMap(Map<Object?, Object?> map) => ReminderStatus(
        notificationsEnabled: map['notificationsEnabled'] as bool? ?? false,
        exactAlarmsAllowed: map['exactAlarmsAllowed'] as bool? ?? false,
        timeZone: map['timeZone'] as String? ?? 'Unknown',
        reminders: ((map['reminders'] as List<Object?>?) ?? const [])
            .map((item) => Map<String, Object?>.from(item! as Map))
            .toList(growable: false),
      );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const _channel = MethodChannel('fitx/reminders');
  static const _morningBriefingId = 1;
  static const _sleepWindDownId = 2;
  static const _workoutReminderId = 3;
  static const _smartAlarmIds = <int>[
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22
  ];
  static const _hydrationIds = <int>[
    100,
    101,
    102,
    103,
    104,
    105,
    106,
    107,
    108,
    109,
    110,
    111,
    112,
    113,
    114,
    115,
    116,
    117,
    118,
    119,
    120,
    121,
    122,
    123,
  ];

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;

  Future<void> init() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
    );
    await _plugin.initialize(settings: settings);
    await _channel.invokeMethod<void>('reconcile');
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<bool> requestNotificationPermission() async {
    await init();
    await _android?.requestNotificationsPermission();
    return (await status()).notificationsEnabled;
  }

  Future<bool> requestExactAlarmAccess() async {
    await init();
    await _android?.requestExactAlarmsPermission();
    return (await status()).exactAlarmsAllowed;
  }

  Future<void> openNotificationSettings() async {
    await init();
    await _channel.invokeMethod<void>('openNotificationSettings');
  }

  Future<ReminderStatus> status() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>('status');
    return ReminderStatus.fromMap(result ?? const {});
  }

  Future<ReminderStatus> reconcile() async {
    final result =
        await _channel.invokeMapMethod<Object?, Object?>('reconcile');
    return ReminderStatus.fromMap(result ?? const {});
  }

  Future<void> scheduleMorningBriefing({int hour = 7, int minute = 0}) =>
      _update([
        _morningBriefingId
      ], [
        _reminder(_morningBriefingId, hour, minute, 'Morning briefing',
            'Open FitX to review the health data available for today.'),
      ]);

  Future<void> cancelMorningBriefing() => _update([_morningBriefingId], []);

  Future<void> scheduleSleepWindDown(
      {required int bedtimeHour, required int bedtimeMinute}) {
    final totalMinutes = (bedtimeHour * 60 + bedtimeMinute - 60) % 1440;
    return _update([
      _sleepWindDownId
    ], [
      _reminder(_sleepWindDownId, totalMinutes ~/ 60, totalMinutes % 60,
          'Sleep wind-down', 'Your chosen bedtime is in one hour.'),
    ]);
  }

  Future<void> cancelSleepWindDown() => _update([_sleepWindDownId], []);

  Future<void> scheduleWorkoutReminder(
          {required int hour,
          required int minute,
          String message =
              'Open FitX when you are ready to plan or log training.'}) =>
      _update([
        _workoutReminderId
      ], [
        _reminder(
            _workoutReminderId, hour, minute, 'Training reminder', message),
      ]);

  Future<void> cancelWorkoutReminder() => _update([_workoutReminderId], []);

  /// Schedules five-minute checks across a wake window. Android only delivers
  /// an early check when ongoing phone sleep tracking detects recent movement;
  /// the final check always rings. No raw motion leaves the device.
  Future<void> scheduleSmartAlarm({
    required int latestHour,
    required int latestMinute,
    int windowMinutes = 30,
  }) {
    if (windowMinutes < 10 || windowMinutes > 60) {
      throw ArgumentError.value(windowMinutes, 'windowMinutes');
    }
    final latest = latestHour * 60 + latestMinute;
    final checks = <Map<String, Object?>>[];
    var idIndex = 0;
    for (var offset = windowMinutes; offset >= 0; offset -= 5) {
      final minuteOfDay = (latest - offset + 1440) % 1440;
      checks.add({
        ..._reminder(
          _smartAlarmIds[idIndex++],
          minuteOfDay ~/ 60,
          minuteOfDay % 60,
          'Good morning',
          'Your FitX wake window found a good time to get up.',
        ),
        'smart': true,
        'final': offset == 0,
      });
    }
    return _update(_smartAlarmIds, checks);
  }

  Future<void> cancelSmartAlarm() => _update(_smartAlarmIds, []);

  Future<void> scheduleHydrationReminders(
      {int startHour = 8, int endHour = 21}) {
    if (startHour < 0 || endHour > 23 || startHour > endHour) {
      throw ArgumentError('Hydration hours must form a valid same-day range.');
    }
    final reminders = <Map<String, Object?>>[];
    for (var hour = startHour; hour <= endHour; hour++) {
      reminders.add(_reminder(_hydrationIds[hour - startHour], hour, 0,
          'Hydration check', 'Open FitX if you want to log water.',
          precise: false));
    }
    return _update(_hydrationIds, reminders);
  }

  Future<void> cancelHydrationReminders() => _update(_hydrationIds, []);

  Map<String, Object?> _reminder(
          int id, int hour, int minute, String title, String body,
          {bool precise = true}) =>
      {
        'id': id,
        'hour': hour,
        'minute': minute,
        'title': title,
        'body': body,
        'precise': precise
      };

  Future<void> _update(
      List<int> replaceIds, List<Map<String, Object?>> reminders) async {
    await init();
    await _channel.invokeMethod<void>(
        'update', {'replaceIds': replaceIds, 'reminders': reminders});
  }

  Future<void> showImmediateNotification(
      {required String title, required String body, int id = 999}) async {
    await init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'fitx_main',
          'FitX Notifications',
          channelDescription: 'Optional local FitX reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
      ),
    );
  }

  Future<void> cancelAll() => _update([
        _morningBriefingId,
        _sleepWindDownId,
        _workoutReminderId,
        ..._smartAlarmIds,
        ..._hydrationIds
      ], []);
}
