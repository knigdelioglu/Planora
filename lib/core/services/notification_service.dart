import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final class NotificationPermissionState {
  const NotificationPermissionState({
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
  });

  final bool notificationsAllowed;
  final bool exactAlarmsAllowed;
}

abstract interface class NotificationService {
  Future<void> initialize();
  Future<NotificationPermissionState> requestPermissions();
  Future<NotificationPermissionState> permissionState();
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAtUtc,
    required String timeZoneId,
    String? payload,
  });
  Future<void> cancel(int id);
  Future<Set<int>> pendingIds();
  String get localTimeZoneId;
}

final class LocalNotificationService implements NotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  String _localTimeZoneId = 'UTC';

  @override
  String get localTimeZoneId => _localTimeZoneId;

  @override
  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    try {
      final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
      _localTimeZoneId = info.identifier;
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      _localTimeZoneId = 'UTC';
      tz.setLocalLocation(tz.UTC);
    }
    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      macOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    );
    await _plugin.initialize(settings: settings);
  }

  @override
  Future<NotificationPermissionState> requestPermissions() async {
    bool notifications = true;
    bool exact = true;
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      notifications = await android?.requestNotificationsPermission() ?? true;
      exact = await android?.requestExactAlarmsPermission() ?? true;
    } else if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      notifications = await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } else if (Platform.isMacOS) {
      final mac = _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
      notifications = await mac?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    return NotificationPermissionState(notificationsAllowed: notifications, exactAlarmsAllowed: exact);
  }

  @override
  Future<NotificationPermissionState> permissionState() async {
    bool notifications = true;
    bool exact = true;
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      notifications = await android?.areNotificationsEnabled() ?? true;
      exact = await android?.canScheduleExactNotifications() ?? true;
    }
    return NotificationPermissionState(notificationsAllowed: notifications, exactAlarmsAllowed: exact);
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAtUtc,
    required String timeZoneId,
    String? payload,
  }) async {
    final tz.Location location;
    try {
      location = tz.getLocation(timeZoneId);
    } catch (_) {
      throw ArgumentError.value(timeZoneId, 'timeZoneId', 'Unknown timezone.');
    }
    final tz.TZDateTime scheduled = tz.TZDateTime.from(scheduledAtUtc.toUtc(), location);
    if (!scheduled.isAfter(tz.TZDateTime.now(location))) {
      throw ArgumentError('Reminder time must be in the future.');
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Hatırlatıcılar',
          channelDescription: 'Not ve kart hatırlatıcıları',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<Set<int>> pendingIds() async {
    final List<PendingNotificationRequest> pending = await _plugin.pendingNotificationRequests();
    return pending.map((item) => item.id).toSet();
  }
}
