import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'rental_reminder_plan.dart';

/// Quien programa los avisos del sistema en este aparato.
abstract class ReminderBackend {
  /// Si puede dejar avisos programados que suenen con IRIS cerrada.
  bool get schedulesWhenClosed;

  Future<void> replaceAll(List<RentalReminder> reminders);

  factory ReminderBackend.forPlatform() => (Platform.isIOS || Platform.isMacOS)
      ? _DarwinReminderBackend()
      : const _NoReminderBackend();
}

class _NoReminderBackend implements ReminderBackend {
  const _NoReminderBackend();

  @override
  bool get schedulesWhenClosed => false;

  @override
  Future<void> replaceAll(List<RentalReminder> reminders) async {}
}

class _DarwinReminderBackend implements ReminderBackend {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  bool get schedulesWhenClosed => true;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(iOS: darwin, macOS: darwin),
    );
    _ready = true;
  }

  Future<bool> _requestPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final mac = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    final granted =
        await ios?.requestPermissions(alert: true, sound: true) ??
        await mac?.requestPermissions(alert: true, sound: true);
    return granted ?? false;
  }

  @override
  Future<void> replaceAll(List<RentalReminder> reminders) async {
    await _init();
    await _plugin.cancelAll();
    if (reminders.isEmpty) return;
    if (!await _requestPermission()) return;
    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );
    for (final r in reminders) {
      await _plugin.zonedSchedule(
        r.id,
        r.title,
        r.body,
        tz.TZDateTime.from(r.at.toUtc(), tz.UTC),
        details,
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
