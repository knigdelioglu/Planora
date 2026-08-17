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
import 'package:not_app/core/sync/sync_models.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/attachments/data/repositories/attachments_repository_impl.dart';
import 'package:not_app/features/conflicts/data/repositories/conflict_repository_impl.dart';
import 'package:not_app/features/kanban/data/repositories/kanban_repository_impl.dart';
import 'package:not_app/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:not_app/features/reminders/data/repositories/reminders_repository_impl.dart';
import 'package:not_app/features/search/data/repositories/search_repository_impl.dart';
import 'package:not_app/features/settings/presentation/screens/sync_queue_screen.dart';
import 'package:not_app/features/settings/presentation/settings_screen.dart';

class MockNotificationService extends Mock implements NotificationService {}

class TestClock implements AppClock {
  DateTime _now = DateTime.utc(2026, 8, 16, 12);
  @override
  DateTime nowUtc() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

void main() {
  group(
    'Kabul Kriteri 1: SyncQueueRepository API Katmanı ve Durum Bazlı Sorgulama',
    () {
      late AppDatabase database;
      late TestClock clock;
      late DriftSyncQueueRepository queue;

      setUp(() {
        database = AppDatabase(NativeDatabase.memory());
        clock = TestClock();
        queue = DriftSyncQueueRepository(database: database, clock: clock);
      });

      tearDown(() async {
        await database.close();
      });

      test(
        'durum bazlı sorgulama, attempt count, hata mesajı ve nextAttemptAt doğru listelenir',
        () async {
          // 1. Enqueue 4 operations with different types
          await queue.enqueue(
            entityType: 'note',
            entityId: 'note-1',
            operationType: SyncOperationType.upsert,
            payload: <String, Object?>{'title': 'Draft Note 1', 'version': 1},
          );
          await queue.enqueue(
            entityType: 'card',
            entityId: 'card-1',
            operationType: SyncOperationType.upsert,
            payload: <String, Object?>{'title': 'Kanban Task 1', 'version': 1},
          );
          await queue.enqueue(
            entityType: 'attachment',
            entityId: 'att-1',
            operationType: SyncOperationType.uploadAttachment,
            payload: <String, Object?>{
              'fileName': 'report.pdf',
              'localPath': '/tmp/doc.pdf',
            },
          );
          await queue.enqueue(
            entityType: 'note',
            entityId: 'note-2',
            operationType: SyncOperationType.delete,
            payload: <String, Object?>{'version': 2},
          );

          final initialOps = await queue.allOperations();
          expect(initialOps.length, 4);

          final opCard1 = initialOps.firstWhere((o) => o.entityId == 'card-1');
          final opAtt1 = initialOps.firstWhere((o) => o.entityId == 'att-1');
          final opNote2 = initialOps.firstWhere((o) => o.entityId == 'note-2');

          // 2. Set statuses
          // opNote1 remains pending
          // opCard1 -> retryWaiting
          await queue.markRetry(opCard1.id, error: 'Network timeout 504');
          // opAtt1 -> failedRecoverable
          await queue.markFailedRecoverable(opAtt1.id, error: 'File corrupted');
          // opNote2 -> blockedConflict
          await queue.markConflict(
            opNote2.id,
            error: 'Remote version conflict',
          );

          // 3. Query all and verify details
          final all = await queue.allOperations();
          expect(all.length, 4);

          final pendingOps = await queue.allOperations(
            status: SyncOperationStatus.pending,
          );
          expect(pendingOps.length, 1);
          expect(pendingOps.first.entityId, 'note-1');
          expect(pendingOps.first.attemptCount, 0);
          expect(pendingOps.first.lastError, isNull);
          expect(pendingOps.first.nextAttemptAt, isNull);

          final retryOps = await queue.allOperations(
            status: SyncOperationStatus.retryWaiting,
          );
          expect(retryOps.length, 1);
          expect(retryOps.first.entityId, 'card-1');
          expect(retryOps.first.attemptCount, 1);
          expect(retryOps.first.lastError, 'Network timeout 504');
          expect(retryOps.first.nextAttemptAt, isNotNull);

          final failedOps = await queue.allOperations(
            status: SyncOperationStatus.failedRecoverable,
          );
          expect(failedOps.length, 1);
          expect(failedOps.first.entityId, 'att-1');
          expect(failedOps.first.lastError, 'File corrupted');

          final conflictOps = await queue.allOperations(
            status: SyncOperationStatus.blockedConflict,
          );
          expect(conflictOps.length, 1);
          expect(conflictOps.first.entityId, 'note-2');
          expect(conflictOps.first.lastError, 'Remote version conflict');

          // 4. Status counts
          final counts = await queue.statusCounts();
          expect(counts[SyncOperationStatus.pending], 1);
          expect(counts[SyncOperationStatus.retryWaiting], 1);
          expect(counts[SyncOperationStatus.failedRecoverable], 1);
          expect(counts[SyncOperationStatus.blockedConflict], 1);
          expect(counts[SyncOperationStatus.completed], 0);
        },
      );

      test(
        'retryOperation, retryAll, deleteOperation ve clearQueue doğru çalışır',
        () async {
          await queue.enqueue(
            entityType: 'note',
            entityId: 'note-1',
            operationType: SyncOperationType.upsert,
            payload: <String, Object?>{'title': 'N1'},
          );
          await queue.enqueue(
            entityType: 'note',
            entityId: 'note-2',
            operationType: SyncOperationType.upsert,
            payload: <String, Object?>{'title': 'N2'},
          );

          final ops = await queue.allOperations();
          final op1 = ops.firstWhere((o) => o.entityId == 'note-1');
          final op2 = ops.firstWhere((o) => o.entityId == 'note-2');

          await queue.markRetry(op1.id, error: 'Err1');
          await queue.markFailedRecoverable(op2.id, error: 'Err2');

          // retry single
          await queue.retryOperation(op1.id);
          final reloaded1 = (await queue.allOperations()).firstWhere(
            (o) => o.id == op1.id,
          );
          expect(reloaded1.status, SyncOperationStatus.pending);
          expect(reloaded1.nextAttemptAt, isNull);

          // retryAll
          await queue.retryAll();
          final reloaded2 = (await queue.allOperations()).firstWhere(
            (o) => o.id == op2.id,
          );
          expect(reloaded2.status, SyncOperationStatus.pending);
          expect(reloaded2.nextAttemptAt, isNull);

          // delete single
          await queue.deleteOperation(op1.id);
          final remaining = await queue.allOperations();
          expect(remaining.length, 1);
          expect(remaining.first.id, op2.id);

          // clear queue
          await queue.clearQueue();
          final emptyList = await queue.allOperations();
          expect(emptyList, isEmpty);
        },
      );

      test(
        'watchOperations ve watchStatusCounts reaktif olarak güncellenir',
        () async {
          final statusCountsStream = queue.watchStatusCounts();
          final operationsStream = queue.watchOperations();

          final List<Map<SyncOperationStatus, int>> countHistory = [];
          final List<List<SyncOperation>> opHistory = [];

          final sub1 = statusCountsStream.listen((c) => countHistory.add(c));
          final sub2 = operationsStream.listen((o) => opHistory.add(o));

          await Future<void>.delayed(const Duration(milliseconds: 20));

          await queue.enqueue(
            entityType: 'note',
            entityId: 'n1',
            operationType: SyncOperationType.upsert,
            payload: {'title': 'N1'},
          );
          await Future<void>.delayed(const Duration(milliseconds: 20));

          final ops = await queue.allOperations();
          await queue.markRetry(ops.first.id, error: 'Network error');
          await Future<void>.delayed(const Duration(milliseconds: 20));

          await queue.deleteOperation(ops.first.id);
          await Future<void>.delayed(const Duration(milliseconds: 20));

          expect(countHistory.length, greaterThanOrEqualTo(3));
          expect(opHistory.length, greaterThanOrEqualTo(3));

          await sub1.cancel();
          await sub2.cancel();
        },
      );
    },
  );

  group(
    'Kabul Kriteri 2, 3 & 4: SyncQueueScreen UI, Kurtarma Aksiyonları ve Reaktivite',
    () {
      late AppDatabase database;
      late TestClock clock;
      late DriftSyncQueueRepository queue;
      late AppServices testServices;
      late MockNotificationService mockNotifications;

      Widget createTestApp(Widget child) {
        return ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(testServices),
            syncQueueRepositoryProvider.overrideWithValue(queue),
            syncCoordinatorProvider.overrideWithValue(
              testServices.syncCoordinator,
            ),
            settingsRepositoryProvider.overrideWithValue(testServices.settings),
            conflictRepositoryProvider.overrideWithValue(
              testServices.conflicts,
            ),
          ],
          child: MaterialApp(home: child),
        );
      }

      setUp(() {
        database = AppDatabase(NativeDatabase.memory());
        clock = TestClock();
        queue = DriftSyncQueueRepository(database: database, clock: clock);
        mockNotifications = MockNotificationService();
        when(() => mockNotifications.permissionState()).thenAnswer(
          (_) async => const NotificationPermissionState(
            notificationsAllowed: true,
            exactAlarmsAllowed: true,
          ),
        );
        when(
          () => mockNotifications.openAppSettings(),
        ).thenAnswer((_) async => true);

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
          queue: queue,
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

      testWidgets('Kuyruk boş olduğunda EmptyState gösterir', (tester) async {
        await tester.pumpWidget(createTestApp(const SyncQueueScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Senkronizasyon Kuyruğu'), findsOneWidget);
        expect(find.text('Kuyruk boş'), findsOneWidget);
        expect(
          find.text('Senkronizasyon bekleyen herhangi bir işlem bulunmuyor.'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });

      testWidgets(
        'Kuyruktaki operasyonları, operasyon tipini, hedef entity adını ve hata ayrıntısını listeler',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 1600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await queue.enqueue(
            entityType: 'note',
            entityId: 'note-uuid-1',
            operationType: SyncOperationType.upsert,
            payload: <String, Object?>{'title': 'Toplantı Notları 2026'},
          );
          await queue.enqueue(
            entityType: 'card',
            entityId: 'card-uuid-2',
            operationType: SyncOperationType.delete,
            payload: <String, Object?>{'title': 'Eski Görev Kartı'},
          );
          await queue.enqueue(
            entityType: 'attachment',
            entityId: 'att-uuid-3',
            operationType: SyncOperationType.uploadAttachment,
            payload: <String, Object?>{'fileName': 'sunum.pdf'},
          );

          final ops = await queue.allOperations();
          final opCard = ops.firstWhere((o) => o.entityId == 'card-uuid-2');
          final opAtt = ops.firstWhere((o) => o.entityId == 'att-uuid-3');

          await queue.markRetry(opCard.id, error: '503 Service Unavailable');
          await queue.markConflict(
            opAtt.id,
            error: 'Cloud version has diverged',
          );

          await tester.pumpWidget(createTestApp(const SyncQueueScreen()));
          await tester.pumpAndSettle();

          // Top overview card
          expect(find.text('Kuyruk Durumu'), findsOneWidget);
          expect(find.text('3 işlem bekliyor'), findsOneWidget);
          expect(find.text('Bekleyen: 1'), findsOneWidget);
          expect(find.text('Yeniden Denenecek: 1'), findsOneWidget);
          expect(find.text('Çakışmada: 1'), findsOneWidget);

          // Target entity display names
          expect(find.text('note: Toplantı Notları 2026'), findsOneWidget);
          expect(find.text('card: Eski Görev Kartı'), findsOneWidget);
          expect(find.text('attachment: sunum.pdf'), findsOneWidget);

          // Operation types
          expect(find.text('Kaydet / Güncelle'), findsOneWidget);
          expect(find.text('Sil'), findsOneWidget);
          expect(find.text('Dosya Yükle'), findsOneWidget);

          // Status badges
          expect(find.text('Bekliyor'), findsOneWidget);
          expect(find.text('Tekrar Denenecek'), findsNWidgets(2));
          expect(find.text('Çakışmada'), findsNWidgets(2));

          // Error details
          expect(
            find.textContaining('Hata: 503 Service Unavailable'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Hata: Cloud version has diverged'),
            findsOneWidget,
          );

          // Deneme sayısı
          expect(find.text('Deneme sayısı: 1'), findsOneWidget);
          expect(find.text('Deneme sayısı: 0'), findsNWidgets(2));

          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );

      testWidgets('Filtreleme sekmeleri (FilterChip) listeyi filtreler', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await queue.enqueue(
          entityType: 'note',
          entityId: 'note-1',
          operationType: SyncOperationType.upsert,
          payload: {'title': 'Note Alpha'},
        );
        await queue.enqueue(
          entityType: 'note',
          entityId: 'note-2',
          operationType: SyncOperationType.upsert,
          payload: {'title': 'Note Beta'},
        );

        final ops = await queue.allOperations();
        await queue.markRetry(
          ops.firstWhere((o) => o.entityId == 'note-2').id,
          error: 'err',
        );

        await tester.pumpWidget(createTestApp(const SyncQueueScreen()));
        await tester.pumpAndSettle();

        expect(find.text('note: Note Alpha'), findsOneWidget);
        expect(find.text('note: Note Beta'), findsOneWidget);

        // Filter by 'Tekrar Denenecek'
        final retryFilterChip = find.widgetWithText(
          FilterChip,
          'Tekrar Denenecek',
        );
        expect(retryFilterChip, findsOneWidget);
        await tester.tap(retryFilterChip);
        await tester.pumpAndSettle();

        expect(find.text('note: Note Beta'), findsOneWidget);
        expect(find.text('note: Note Alpha'), findsNothing);

        // Filter by 'Bekleyenler'
        final pendingFilterChip = find.widgetWithText(
          FilterChip,
          'Bekleyenler',
        );
        await tester.tap(pendingFilterChip);
        await tester.pumpAndSettle();

        expect(find.text('note: Note Alpha'), findsOneWidget);
        expect(find.text('note: Note Beta'), findsNothing);

        // Reset filter to 'Tümü'
        final allFilterChip = find.widgetWithText(FilterChip, 'Tümü');
        await tester.tap(allFilterChip);
        await tester.pumpAndSettle();

        expect(find.text('note: Note Alpha'), findsOneWidget);
        expect(find.text('note: Note Beta'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });

      testWidgets(
        'Şimdi Tekrar Dene ve Tümünü Tekrar Dene aksiyonları çalışır',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 1600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await queue.enqueue(
            entityType: 'note',
            entityId: 'note-1',
            operationType: SyncOperationType.upsert,
            payload: {'title': 'Retry Note 1'},
          );
          await queue.enqueue(
            entityType: 'note',
            entityId: 'note-2',
            operationType: SyncOperationType.upsert,
            payload: {'title': 'Retry Note 2'},
          );

          final ops = await queue.allOperations();
          final op1 = ops.firstWhere((o) => o.entityId == 'note-1');
          final op2 = ops.firstWhere((o) => o.entityId == 'note-2');

          await queue.markRetry(op1.id, error: 'Fail 1');
          await queue.markFailedRecoverable(op2.id, error: 'Fail 2');

          await tester.pumpWidget(createTestApp(const SyncQueueScreen()));
          await tester.pumpAndSettle();

          // Tap single retry button on first card
          final singleRetryBtns = find.text('Şimdi Tekrar Dene');
          expect(singleRetryBtns, findsNWidgets(2));
          await tester.tap(singleRetryBtns.first);
          await tester.pump();
          expect(
            find.text('İşlem yeniden deneme için sıraya alındı.'),
            findsOneWidget,
          );
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();

          // Op1 is now pending
          final reloadedOp1 = (await queue.allOperations()).firstWhere(
            (o) => o.id == op1.id,
          );
          expect(reloadedOp1.status, SyncOperationStatus.pending);
          expect(reloadedOp1.nextAttemptAt, isNull);

          // Tap Tümünü Tekrar Dene button
          final retryAllBtn = find.text('Tümünü Tekrar Dene');
          await tester.tap(retryAllBtn);
          await tester.pump();
          await tester.pumpAndSettle();

          final reloadedOp2 = (await queue.allOperations()).firstWhere(
            (o) => o.id == op2.id,
          );
          expect(reloadedOp2.status, SyncOperationStatus.pending);
          expect(reloadedOp2.nextAttemptAt, isNull);
          expect(
            find.textContaining('Tüm işlemler sıraya alındı'),
            findsOneWidget,
          );

          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );

      testWidgets(
        'Çakışmaya Git butonu ConflictsScreen sayfasına yönlendirir',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 1600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await queue.enqueue(
            entityType: 'note',
            entityId: 'note-conflict-1',
            operationType: SyncOperationType.upsert,
            payload: {'title': 'Conflicted Note'},
          );

          final ops = await queue.allOperations();
          await queue.markConflict(
            ops.first.id,
            error: 'Blocked by version divergence',
          );

          await tester.pumpWidget(createTestApp(const SyncQueueScreen()));
          await tester.pumpAndSettle();

          final conflictBtn = find.text('Çakışmaya Git');
          expect(conflictBtn, findsOneWidget);

          await tester.tap(conflictBtn);
          await tester.pumpAndSettle();

          // Navigated to ConflictsScreen
          expect(find.text('Senkronizasyon çakışmaları'), findsOneWidget);

          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );

      testWidgets(
        'Kuyruktan Silme / Temizleme onay dialogu gösterir ve silme işlemini gerçekleştirir',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 1600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await queue.enqueue(
            entityType: 'note',
            entityId: 'note-delete-1',
            operationType: SyncOperationType.upsert,
            payload: {'title': 'Delete Me'},
          );

          await tester.pumpWidget(createTestApp(const SyncQueueScreen()));
          await tester.pumpAndSettle();

          // 1. Single delete with cancel
          final deleteBtn = find.text('Kuyruktan Temizle');
          expect(deleteBtn, findsOneWidget);
          await tester.tap(deleteBtn);
          await tester.pumpAndSettle();

          expect(find.text('İşlemi kuyruktan kaldır'), findsOneWidget);
          expect(
            find.textContaining('veri kaybına yol açabilir'),
            findsOneWidget,
          );

          // Tap Vazgeç
          await tester.tap(find.text('Vazgeç'));
          await tester.pumpAndSettle();
          expect(await queue.allOperations(), isNotEmpty);

          // 2. Single delete with confirm
          await tester.tap(deleteBtn);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Kuyruktan Sil'));
          await tester.pumpAndSettle();

          expect(await queue.allOperations(), isEmpty);
          expect(find.text('İşlem kuyruktan silindi.'), findsOneWidget);
          expect(find.text('Kuyruk boş'), findsOneWidget);

          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );

      testWidgets(
        'Kuyruktan Temizle/Sıfırla onay penceresiyle tüm kuyruğu temizler',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 1600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await queue.enqueue(
            entityType: 'note',
            entityId: 'n1',
            operationType: SyncOperationType.upsert,
            payload: {'title': 'N1'},
          );
          await queue.enqueue(
            entityType: 'note',
            entityId: 'n2',
            operationType: SyncOperationType.upsert,
            payload: {'title': 'N2'},
          );

          await tester.pumpWidget(createTestApp(const SyncQueueScreen()));
          await tester.pumpAndSettle();

          final clearAllBtn = find.text('Kuyruktan Temizle/Sıfırla');
          expect(clearAllBtn, findsOneWidget);

          await tester.tap(clearAllBtn);
          await tester.pumpAndSettle();

          expect(find.text('Kuyruğu temizle / sıfırla'), findsOneWidget);
          expect(
            find.textContaining(
              'tüm bekleyen ve başarısız senkronizasyon işlemleri silinecektir',
            ),
            findsOneWidget,
          );

          // Cancel
          await tester.tap(find.text('Vazgeç'));
          await tester.pumpAndSettle();
          expect((await queue.allOperations()).length, 2);

          // Confirm
          await tester.tap(clearAllBtn);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Kuyruğu Sıfırla'));
          await tester.pumpAndSettle();

          expect(await queue.allOperations(), isEmpty);
          expect(
            find.text('Senkronizasyon kuyruğu temizlendi.'),
            findsOneWidget,
          );
          expect(find.text('Kuyruk boş'), findsOneWidget);

          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );

      testWidgets(
        'SettingsScreen Senkronizasyon Kuyruğu butonunu gösterir ve tıklandığında ekrana gider',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 1600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await queue.enqueue(
            entityType: 'note',
            entityId: 'n-settings-1',
            operationType: SyncOperationType.upsert,
            payload: {'title': 'Settings Queue Test'},
          );

          await tester.pumpWidget(
            createTestApp(const Scaffold(body: SettingsScreen())),
          );
          await tester.pumpAndSettle();

          expect(find.text('Senkronizasyon'), findsOneWidget);
          expect(
            find.textContaining('Kuyrukta 1 işlem bekliyor'),
            findsOneWidget,
          );

          final queueBtn = find.text('Senkronizasyon Kuyruğu');
          expect(queueBtn, findsOneWidget);

          await tester.ensureVisible(queueBtn);
          await tester.pumpAndSettle();
          await tester.tap(queueBtn);
          await tester.pumpAndSettle();

          expect(find.byType(SyncQueueScreen), findsOneWidget);
          expect(find.text('note: Settings Queue Test'), findsOneWidget);

          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    },
  );
}

class DisabledNetworkInfo implements NetworkInfo {
  const DisabledNetworkInfo();
  @override
  Future<bool> isConnected() async => false;
  @override
  Stream<bool> get onConnectivityChanged => const Stream<bool>.empty();
}
