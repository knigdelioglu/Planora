import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

enum NotificationScheduleMode { exact, inexact }

final class NotificationScheduleResult {
  const NotificationScheduleResult({required this.mode, this.warning});

  final NotificationScheduleMode mode;
  final String? warning;

  bool get isExact => mode == NotificationScheduleMode.exact;
}

final class NotificationPermissionState {
  const NotificationPermissionState({
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
  });

  final bool notificationsAllowed;
  final bool exactAlarmsAllowed;

  bool get fullyGranted => notificationsAllowed && exactAlarmsAllowed;
  bool get hasInexactFallbackOnly =>
      notificationsAllowed && !exactAlarmsAllowed;
  bool get isDenied => !notificationsAllowed;
}

abstract interface class NotificationService {
  Future<void> initialize();
  Future<void> refreshTimeZone();
  Future<NotificationPermissionState> requestPermissions();
  Future<NotificationPermissionState> permissionState();
  Future<bool> openAppSettings();
  Future<NotificationScheduleResult> schedule({
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
    await refreshTimeZone();
    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
  }

  @override
  Future<void> refreshTimeZone() async {
    try {
      final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
      _localTimeZoneId = info.identifier;
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      _localTimeZoneId = 'UTC';
      tz.setLocalLocation(tz.UTC);
    }
  }

  @override
  Future<NotificationPermissionState> requestPermissions() async {
    bool notifications = true;
    bool exact = true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (Platform.isAndroid || android != null) {
      notifications = await android?.requestNotificationsPermission() ?? true;
      exact = await android?.requestExactAlarmsPermission() ?? true;
    } else if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      notifications =
          await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } else if (Platform.isMacOS) {
      final mac = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      notifications =
          await mac?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return NotificationPermissionState(
      notificationsAllowed: notifications,
      exactAlarmsAllowed: exact,
    );
  }

  @override
  Future<NotificationPermissionState> permissionState() async {
    bool notifications = true;
    bool exact = true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (Platform.isAndroid || android != null) {
      notifications = await android?.areNotificationsEnabled() ?? true;
      exact = await android?.canScheduleExactNotifications() ?? true;
    }
    return NotificationPermissionState(
      notificationsAllowed: notifications,
      exactAlarmsAllowed: exact,
    );
  }

  @override
  Future<bool> openAppSettings() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (Platform.isAndroid || android != null) {
      final bool? requested = await android?.requestExactAlarmsPermission();
      if (requested == true) return true;
      try {
        final uri = Uri.parse('package:com.example.not_app');
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri);
        }
      } catch (_) {}
      return false;
    } else if (Platform.isIOS || Platform.isMacOS) {
      try {
        final uri = Uri.parse('app-settings:');
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri);
        }
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<NotificationScheduleResult> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAtUtc,
    required String timeZoneId,
    String? payload,
  }) async {
    tz.Location location;
    if (timeZoneId.toUpperCase() == 'UTC' || timeZoneId.isEmpty) {
      location = tz.UTC;
    } else {
      try {
        location = tz.getLocation(timeZoneId);
      } catch (_) {
        if (_localTimeZoneId.toUpperCase() == 'UTC' ||
            _localTimeZoneId.isEmpty) {
          location = tz.UTC;
        } else {
          try {
            location = tz.getLocation(_localTimeZoneId);
          } catch (_) {
            location = tz.UTC;
          }
        }
      }
    }
    final tz.TZDateTime scheduled = tz.TZDateTime.from(
      scheduledAtUtc.toUtc(),
      location,
    );
    if (!scheduled.isAfter(tz.TZDateTime.now(location))) {
      throw ArgumentError('Reminder time must be in the future.');
    }

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders',
        'Hatırlatıcılar',
        channelDescription: 'Not ve kart hatırlatıcıları',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final bool isAndroid = Platform.isAndroid || android != null;

    if (isAndroid) {
      final bool canExact =
          await android?.canScheduleExactNotifications() ?? true;

      if (canExact) {
        try {
          await _plugin.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: scheduled,
            notificationDetails: notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: payload,
          );
          return const NotificationScheduleResult(
            mode: NotificationScheduleMode.exact,
          );
        } catch (_) {
          // If exact scheduling fails with exact alarm permission error, fall back to inexactAllowWhileIdle
          await _plugin.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: scheduled,
            notificationDetails: notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: payload,
          );
          return const NotificationScheduleResult(
            mode: NotificationScheduleMode.inexact,
            warning:
                'Kesin alarm izni bulunamadı; hatırlatıcı inexact modunda planlandı.',
          );
        }
      } else {
        // Controlled fallback without crashing
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduled,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
        return const NotificationScheduleResult(
          mode: NotificationScheduleMode.inexact,
          warning:
              'Kesin alarm izni verilmediği için yaklaşık zamanlı planlama yapıldı.',
        );
      }
    }

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      return const NotificationScheduleResult(
        mode: NotificationScheduleMode.exact,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      return const NotificationScheduleResult(
        mode: NotificationScheduleMode.inexact,
        warning:
            'Kesin alarm planlaması desteklenmiyor; yaklaşık mod kullanıldı.',
      );
    }
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<Set<int>> pendingIds() async {
    final List<PendingNotificationRequest> pending = await _plugin
        .pendingNotificationRequests();
    return pending.map((item) => item.id).toSet();
  }
}
