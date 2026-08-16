import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_app/app/app_services.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/core/auth/auth_service.dart';
import 'package:not_app/core/config/app_config.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/logging/app_logger.dart';
import 'package:not_app/core/network/network_info.dart';
import 'package:not_app/core/remote/remote_gateway.dart';
import 'package:not_app/core/services/file_picker_service.dart';
import 'package:not_app/core/services/file_storage_service.dart';
import 'package:not_app/core/services/notification_service.dart';
import 'package:not_app/core/settings/app_settings_repository.dart';
import 'package:not_app/core/sync/local_entity_store.dart';
import 'package:not_app/core/sync/sync_coordinator.dart';
import 'package:not_app/core/sync/sync_engine.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/attachments/data/repositories/attachments_repository_impl.dart';
import 'package:not_app/features/conflicts/data/repositories/conflict_repository_impl.dart';
import 'package:not_app/features/kanban/data/repositories/kanban_repository_impl.dart';
import 'package:not_app/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:not_app/features/reminders/data/repositories/reminders_repository_impl.dart';
import 'package:not_app/features/reminders/domain/entities/reminder.dart';
import 'package:not_app/features/reminders/presentation/screens/reminders_screen.dart';
import 'package:not_app/features/search/data/repositories/search_repository_impl.dart';
import 'package:not_app/features/settings/presentation/settings_screen.dart';
import 'package:timezone/data/latest.dart' as tzdata;

class MockNotificationService extends Mock implements NotificationService {}

class TestClock implements AppClock {
  DateTime _now = DateTime.utc(2026, 8, 16, 12);
  @override
  DateTime nowUtc() => _now;
  void advance(Duration d) => _now = _now.add(d);
  void setTime(DateTime time) => _now = time.toUtc();
}

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
  });

  group('Kabul Kriteri 1 & 2: Reminders Reconciliation & Exact Fallback', () {
    late AppDatabase database;
    late TestClock clock;
    late DriftSyncQueueRepository syncQueue;
    late MockNotificationService mockNotifications;
    late DriftRemindersRepository repository;
    final Set<int> scheduledInOS = <int>{};
    final Set<int> cancelledInOS = <int>{};
    bool allowExact = true;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      clock = TestClock();
      syncQueue = DriftSyncQueueRepository(database: database, clock: clock);
      mockNotifications = MockNotificationService();
      scheduledInOS.clear();
      cancelledInOS.clear();
      allowExact = true;

      when(() => mockNotifications.localTimeZoneId).thenReturn('UTC');
      when(() => mockNotifications.refreshTimeZone()).thenAnswer((_) async {});
      when(() => mockNotifications.permissionState()).thenAnswer(
        (_) async => NotificationPermissionState(
          notificationsAllowed: true,
          exactAlarmsAllowed: allowExact,
        ),
      );
      when(
        () => mockNotifications.pendingIds(),
      ).thenAnswer((_) async => Set<int>.from(scheduledInOS));
      when(() => mockNotifications.cancel(any())).thenAnswer((inv) async {
        final id = inv.positionalArguments[0] as int;
        scheduledInOS.remove(id);
        cancelledInOS.add(id);
      });
      when(
        () => mockNotifications.schedule(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledAtUtc: any(named: 'scheduledAtUtc'),
          timeZoneId: any(named: 'timeZoneId'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((inv) async {
        final id = inv.namedArguments[#id] as int;
        scheduledInOS.add(id);
        if (allowExact) {
          return const NotificationScheduleResult(
            mode: NotificationScheduleMode.exact,
          );
        } else {
          return const NotificationScheduleResult(
            mode: NotificationScheduleMode.inexact,
            warning: 'Exact alarm fallback',
          );
        }
      });

      repository = DriftRemindersRepository(
        database: database,
        notifications: mockNotifications,
        syncQueue: syncQueue,
        clock: clock,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'reconcile schedules active future reminders to OS with exact mode',
      () async {
        final ReminderEntity r1 = await repository.create(
          parentType: 'note',
          parentId: 'note-1',
          title: 'Meeting 1',
          scheduledAtUtc: clock.nowUtc().add(const Duration(hours: 2)),
          timeZoneId: 'UTC',
        );

        expect(r1.schedulingStatus, 'scheduled');
        expect(scheduledInOS, contains(r1.notificationId));

        // Clear OS state to simulate app restart/reboot where alarms were cleared
        scheduledInOS.clear();
        expect(scheduledInOS, isEmpty);

        // Reconcile
        await repository.reconcile();

        expect(scheduledInOS, contains(r1.notificationId));
        final row = await (database.select(
          database.reminders,
        )..where((tbl) => tbl.id.equals(r1.id))).getSingle();
        expect(row.schedulingStatus, 'scheduled');
        expect(row.lastReconciledAt, isNotNull);
      },
    );

    test(
      'reconcile uses inexact fallback when exact alarm permission is missing without crash',
      () async {
        allowExact = false;

        final ReminderEntity r1 = await repository.create(
          parentType: 'note',
          parentId: 'note-1',
          title: 'Inexact Reminder',
          scheduledAtUtc: clock.nowUtc().add(const Duration(hours: 3)),
          timeZoneId: 'UTC',
        );

        // Inexact fallback was recorded in DB
        expect(r1.schedulingStatus, 'inexact');
        expect(scheduledInOS, contains(r1.notificationId));

        // Reset OS and reconcile
        scheduledInOS.clear();
        await repository.reconcile();

        expect(scheduledInOS, contains(r1.notificationId));
        final row = await (database.select(
          database.reminders,
        )..where((tbl) => tbl.id.equals(r1.id))).getSingle();
        expect(row.schedulingStatus, 'inexact');
      },
    );

    test('reconcile cancels deleted and disabled reminders from OS', () async {
      final ReminderEntity r1 = await repository.create(
        parentType: 'note',
        parentId: 'note-1',
        title: 'Active Reminder',
        scheduledAtUtc: clock.nowUtc().add(const Duration(hours: 1)),
        timeZoneId: 'UTC',
      );
      final ReminderEntity r2 = await repository.create(
        parentType: 'card',
        parentId: 'card-1',
        title: 'To Disable',
        scheduledAtUtc: clock.nowUtc().add(const Duration(hours: 2)),
        timeZoneId: 'UTC',
      );
      final ReminderEntity r3 = await repository.create(
        parentType: 'note',
        parentId: 'note-2',
        title: 'To Delete',
        scheduledAtUtc: clock.nowUtc().add(const Duration(hours: 3)),
        timeZoneId: 'UTC',
      );

      expect(scheduledInOS, {
        r1.notificationId,
        r2.notificationId,
        r3.notificationId,
      });

      // Disable r2
      await repository.update(
        id: r2.id,
        title: r2.title,
        scheduledAtUtc: r2.scheduledAtUtc,
        timeZoneId: r2.timeZoneId,
        enabled: false,
      );

      // Delete r3
      await repository.remove(r3.id);

      // Reconcile
      await repository.reconcile();

      expect(scheduledInOS, contains(r1.notificationId));
      expect(scheduledInOS, isNot(contains(r2.notificationId)));
      expect(scheduledInOS, isNot(contains(r3.notificationId)));
      expect(cancelledInOS, contains(r2.notificationId));
      expect(cancelledInOS, contains(r3.notificationId));
    });

    test(
      'reconcile does NOT re-trigger past reminders and cancels them from OS',
      () async {
        final ReminderEntity r1 = await repository.create(
          parentType: 'note',
          parentId: 'note-1',
          title: 'Will become past',
          scheduledAtUtc: clock.nowUtc().add(const Duration(minutes: 30)),
          timeZoneId: 'UTC',
        );

        expect(scheduledInOS, contains(r1.notificationId));

        // Advance clock past the reminder time
        clock.advance(const Duration(hours: 2));

        // Reconcile
        await repository.reconcile();

        // Past reminder must be cancelled and not re-scheduled
        expect(cancelledInOS, contains(r1.notificationId));
        expect(scheduledInOS, isNot(contains(r1.notificationId)));
      },
    );

    test(
      'reconcile cancels orphaned OS notifications that do not exist in DB',
      () async {
        // Simulate an orphaned OS notification with ID 99999
        scheduledInOS.add(99999);

        final ReminderEntity r1 = await repository.create(
          parentType: 'note',
          parentId: 'note-1',
          title: 'Valid Active',
          scheduledAtUtc: clock.nowUtc().add(const Duration(hours: 1)),
          timeZoneId: 'UTC',
        );

        expect(scheduledInOS, contains(99999));
        expect(scheduledInOS, contains(r1.notificationId));

        await repository.reconcile();

        expect(cancelledInOS, contains(99999));
        expect(scheduledInOS, isNot(contains(99999)));
        expect(scheduledInOS, contains(r1.notificationId));
      },
    );
  });

  group('Kabul Kriteri 3 & 4: Settings & Reminders Screen Permission UX', () {
    late AppDatabase database;
    late TestClock clock;
    late MockNotificationService mockNotifications;
    late AppServices testServices;

    Widget createTestApp(Widget child) {
      return ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(testServices),
          settingsRepositoryProvider.overrideWithValue(testServices.settings),
          remindersRepositoryProvider.overrideWithValue(testServices.reminders),
          notificationServiceProvider.overrideWithValue(
            testServices.notifications,
          ),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );
    }

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      clock = TestClock();
      mockNotifications = MockNotificationService();
      when(() => mockNotifications.localTimeZoneId).thenReturn('UTC');
      when(() => mockNotifications.refreshTimeZone()).thenAnswer((_) async {});
      when(
        () => mockNotifications.pendingIds(),
      ).thenAnswer((_) async => <int>{});
      when(
        () => mockNotifications.openAppSettings(),
      ).thenAnswer((_) async => true);

      final queue = DriftSyncQueueRepository(database: database, clock: clock);
      final localStore = LocalEntityStore(database: database, clock: clock);
      final conflicts = DriftConflictRepository(
        database: database,
        syncQueue: queue,
        localStore: localStore,
        clock: clock,
      );
      final engine = SyncEngine(
        database: database,
        queue: queue,
        remote: const DisabledRemoteGateway(),
        localStore: localStore,
        conflicts: conflicts,
        clock: clock,
        logger: const AppLogger(),
      );
      final settings = DriftAppSettingsRepository(database, clock);
      final reminders = DriftRemindersRepository(
        database: database,
        notifications: mockNotifications,
        syncQueue: queue,
        clock: clock,
      );

      final coordinator = SyncCoordinator(
        networkInfo: const DisabledNetworkInfo(),
        authService: const DisabledAuthService(),
        engine: engine,
        database: database,
        clock: clock,
        reconcileReminders: reminders.reconcile,
        logger: const AppLogger(),
      );

      testServices = AppServices(
        config: const AppConfig(
          environment: 'test',
          supabaseUrl: '',
          supabasePublishableKey: '',
        ),
        database: database,
        clock: clock,
        logger: const AppLogger(),
        networkInfo: const DisabledNetworkInfo(),
        fileStorage: SandboxFileStorageService(),
        filePicker: PlatformFilePickerService(),
        notifications: mockNotifications,
        auth: const DisabledAuthService(),
        remote: const DisabledRemoteGateway(),
        syncQueue: queue,
        localEntityStore: localStore,
        conflicts: conflicts,
        syncEngine: engine,
        syncCoordinator: coordinator,
        settings: settings,
        notes: DriftNotesRepository(
          database: database,
          syncQueue: queue,
          clock: clock,
        ),
        kanban: DriftKanbanRepository(
          database: database,
          syncQueue: queue,
          clock: clock,
        ),
        attachments: DriftAttachmentsRepository(
          database: database,
          storage: SandboxFileStorageService(),
          syncQueue: queue,
          clock: clock,
          remote: const DisabledRemoteGateway(),
        ),
        reminders: reminders,
        search: DriftSearchRepository(database),
      );
    });

    tearDown(() async {
      await database.close();
    });

    testWidgets(
      'SettingsScreen displays notification & exact alarm states and openAppSettings button',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        when(() => mockNotifications.permissionState()).thenAnswer(
          (_) async => const NotificationPermissionState(
            notificationsAllowed: true,
            exactAlarmsAllowed: false,
          ),
        );

        await tester.pumpWidget(createTestApp(const SettingsScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Bildirimler ve İzinler'), findsOneWidget);
        expect(find.text('Bildirim İzni'), findsOneWidget);
        expect(find.text('Kesin Alarm İzni (Exact Alarm)'), findsOneWidget);
        expect(
          find.textContaining('Kapalı — yaklaşık zaman garantisi'),
          findsOneWidget,
        );

        final openBtn = find.text('Sistem ayarlarını aç');
        expect(openBtn, findsOneWidget);

        await tester.ensureVisible(openBtn);
        await tester.pumpAndSettle();
        await tester.tap(openBtn);
        await tester.pumpAndSettle();
        verify(() => mockNotifications.openAppSettings()).called(1);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'SettingsScreen shows alert and recovery banner when notifications are denied',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        when(() => mockNotifications.permissionState()).thenAnswer(
          (_) async => const NotificationPermissionState(
            notificationsAllowed: false,
            exactAlarmsAllowed: false,
          ),
        );

        await tester.pumpWidget(createTestApp(const SettingsScreen()));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Bildirim izni kalıcı olarak reddedilmiş olabilir',
          ),
          findsOneWidget,
        );
        expect(find.text('Sistem ayarlarını aç'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'RemindersScreen displays warning banner and recovery button when permissions are missing',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        when(() => mockNotifications.permissionState()).thenAnswer(
          (_) async => const NotificationPermissionState(
            notificationsAllowed: false,
            exactAlarmsAllowed: false,
          ),
        );

        await tester.pumpWidget(createTestApp(const RemindersScreen()));
        await tester.pumpAndSettle();

        expect(find.textContaining('Bildirim izni kapalı'), findsOneWidget);
        final openBtn = find.text('Ayarları Aç');
        expect(openBtn, findsOneWidget);
        expect(find.text('İzin İste'), findsOneWidget);

        await tester.ensureVisible(openBtn);
        await tester.pumpAndSettle();
        await tester.tap(openBtn);
        await tester.pumpAndSettle();
        verify(() => mockNotifications.openAppSettings()).called(1);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });
}

class DisabledNetworkInfo implements NetworkInfo {
  const DisabledNetworkInfo();
  @override
  Future<bool> isConnected() async => false;
  @override
  Stream<bool> get onConnectivityChanged => const Stream<bool>.empty();
}
