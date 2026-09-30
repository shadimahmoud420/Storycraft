import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/occasions.dart';
import 'app_settings.dart';

/// Local "story of the day" reminders — scheduled on the device, no server.
/// The next [_days] days are scheduled one by one so each notification can
/// mention the day's occasion (Friday, Ramadan, white days…); the schedule
/// is refreshed every time the app opens.
class ReminderService {
  ReminderService._();

  static final instance = ReminderService._();
  static const _days = 14;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> _init() async {
    if (_ready) return true;
    if (!_supported) return false;
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  /// Asks for notification permission. Returns false when denied.
  Future<bool> requestPermission() async {
    if (!await _init()) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Re-schedules (or clears) reminders from the current settings.
  /// [title] is the localized notification title.
  Future<void> sync({required String title}) async {
    if (!await _init()) return;
    try {
      await _plugin.cancelAll();
      final settings = AppSettings.instance.value;
      if (!settings.reminderOn) return;
      final now = tz.TZDateTime.now(tz.local);
      for (var i = 0; i <= _days; i++) {
        final day = now.add(Duration(days: i));
        final at = tz.TZDateTime(tz.local, day.year, day.month, day.day,
            settings.reminderHour, settings.reminderMinute);
        if (!at.isAfter(now)) continue;
        final info = DayInfo.of(DateTime(day.year, day.month, day.day));
        final body = info.title != null
            ? '${info.title} ✨ صمّم ستوري اليوم بضغطة'
            : info.tag != null
                ? '${info.tag} · تصميم جديد بتاريخ اليوم'
                : 'تصميم جديد بتاريخ اليوم ودعاء أو حكمة جديدة';
        await _plugin.zonedSchedule(
          id: 1000 + i,
          scheduledDate: at,
          title: title,
          body: body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_story',
              'Story of the day',
              channelDescription: 'Daily reminder for the story of the day',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // Scheduling is best-effort; the app works without it.
    }
  }
}
