import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

abstract interface class NotificationService {
  Future<void> initialize();
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required tz.TZDateTime scheduledAt,
  });
  Future<void> cancel(int notificationId);
}

final class LocalNotificationService implements NotificationService {
  LocalNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
  }

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required tz.TZDateTime scheduledAt,
  }) async {
    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Reminders',
          channelDescription: 'Scheduled reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int notificationId) => _plugin.cancel(notificationId);
}
