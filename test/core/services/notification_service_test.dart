import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_app/core/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class MockAndroidFlutterLocalNotificationsPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

class FakeInitializationSettings extends Fake
    implements InitializationSettings {}

class FakeNotificationDetails extends Fake implements NotificationDetails {}

class FakeTZDateTime extends Fake implements tz.TZDateTime {}

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    registerFallbackValue(FakeInitializationSettings());
    registerFallbackValue(FakeNotificationDetails());
    registerFallbackValue(FakeTZDateTime());
    registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
  });

  group('NotificationPermissionState & NotificationScheduleResult', () {
    test('permission state helper properties', () {
      const state1 = NotificationPermissionState(
        notificationsAllowed: true,
        exactAlarmsAllowed: true,
      );
      expect(state1.fullyGranted, isTrue);
      expect(state1.hasInexactFallbackOnly, isFalse);
      expect(state1.isDenied, isFalse);

      const state2 = NotificationPermissionState(
        notificationsAllowed: true,
        exactAlarmsAllowed: false,
      );
      expect(state2.fullyGranted, isFalse);
      expect(state2.hasInexactFallbackOnly, isTrue);
      expect(state2.isDenied, isFalse);

      const state3 = NotificationPermissionState(
        notificationsAllowed: false,
        exactAlarmsAllowed: false,
      );
      expect(state3.fullyGranted, isFalse);
      expect(state3.hasInexactFallbackOnly, isFalse);
      expect(state3.isDenied, isTrue);
    });

    test('schedule result properties', () {
      const resExact = NotificationScheduleResult(
        mode: NotificationScheduleMode.exact,
      );
      expect(resExact.isExact, isTrue);
      expect(resExact.warning, isNull);

      const resInexact = NotificationScheduleResult(
        mode: NotificationScheduleMode.inexact,
        warning: 'Fallback warning',
      );
      expect(resInexact.isExact, isFalse);
      expect(resInexact.warning, 'Fallback warning');
    });
  });

  group('LocalNotificationService', () {
    late MockFlutterLocalNotificationsPlugin mockPlugin;
    late LocalNotificationService service;

    setUp(() {
      mockPlugin = MockFlutterLocalNotificationsPlugin();
      service = LocalNotificationService(plugin: mockPlugin);
    });

    test('cancel delegates to plugin cancel', () async {
      when(() => mockPlugin.cancel(id: 42)).thenAnswer((_) async {});

      await service.cancel(42);
      verify(() => mockPlugin.cancel(id: 42)).called(1);
    });

    test('pendingIds maps pending notification requests correctly', () async {
      when(() => mockPlugin.pendingNotificationRequests()).thenAnswer(
        (_) async => const <PendingNotificationRequest>[
          PendingNotificationRequest(1, 'Title 1', 'Body 1', 'payload1'),
          PendingNotificationRequest(2, 'Title 2', 'Body 2', 'payload2'),
        ],
      );

      final ids = await service.pendingIds();
      expect(ids, <int>{1, 2});
      verify(() => mockPlugin.pendingNotificationRequests()).called(1);
    });

    test(
      'schedule throws ArgumentError when scheduled time is in the past',
      () async {
        final pastUtc = DateTime.now().toUtc().subtract(
          const Duration(minutes: 5),
        );

        expect(
          () => service.schedule(
            id: 101,
            title: 'Past reminder',
            body: 'Should fail',
            scheduledAtUtc: pastUtc,
            timeZoneId: 'UTC',
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('future'),
            ),
          ),
        );
      },
    );

    test(
      'schedule succeeds with exact mode when exact alarms are supported',
      () async {
        final futureUtc = DateTime.now().toUtc().add(const Duration(hours: 2));

        when(
          () => mockPlugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async {});

        final result = await service.schedule(
          id: 200,
          title: 'Meeting',
          body: 'Team sync',
          scheduledAtUtc: futureUtc,
          timeZoneId: 'UTC',
          payload: 'note:123',
        );

        expect(result.isExact, isTrue);
        expect(result.mode, NotificationScheduleMode.exact);
        verify(
          () => mockPlugin.zonedSchedule(
            id: 200,
            title: 'Meeting',
            body: 'Team sync',
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: 'note:123',
          ),
        ).called(1);
      },
    );

    test(
      'schedule falls back to inexactAllowWhileIdle when exact scheduling fails',
      () async {
        final futureUtc = DateTime.now().toUtc().add(const Duration(hours: 2));

        // First call (exact) throws PlatformException (e.g. permission revoked / missing SCHEDULE_EXACT_ALARM)
        // Second call (inexact fallback) succeeds
        var callCount = 0;
        when(
          () => mockPlugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((invocation) async {
          callCount++;
          final mode =
              invocation.namedArguments[#androidScheduleMode]
                  as AndroidScheduleMode;
          if (mode == AndroidScheduleMode.exactAllowWhileIdle &&
              callCount == 1) {
            throw PlatformException(
              code: 'exact_alarms_not_permitted',
              message: 'Exact alarms are not permitted for this application.',
            );
          }
        });

        // Inject mock android plugin
        final mockAndroid = MockAndroidFlutterLocalNotificationsPlugin();
        when(
          () => mockAndroid.canScheduleExactNotifications(),
        ).thenAnswer((_) async => true);
        when(
          () => mockPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >(),
        ).thenReturn(mockAndroid);

        // Trigger schedule; should not crash, but fall back to inexact mode
        final result = await service.schedule(
          id: 201,
          title: 'Fallbacked reminder',
          body: 'Inexact mode',
          scheduledAtUtc: futureUtc,
          timeZoneId: 'UTC',
        );

        // Verify it fell back safely
        expect(result.isExact, isFalse);
        expect(result.mode, NotificationScheduleMode.inexact);
        expect(result.warning, contains('Kesin alarm'));
      },
    );
  });
}
