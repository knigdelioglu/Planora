import 'package:drift/drift.dart' hide isNotNull, isNull;
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
import 'package:not_app/core/utils/fractional_indexing_helper.dart';
import 'package:not_app/features/attachments/data/repositories/attachments_repository_impl.dart';
import 'package:not_app/features/conflicts/data/repositories/conflict_repository_impl.dart';
import 'package:not_app/features/kanban/data/repositories/kanban_repository_impl.dart';
import 'package:not_app/features/kanban/presentation/screens/card_detail_screen.dart';
import 'package:not_app/features/kanban/presentation/screens/kanban_board_screen.dart';
import 'package:not_app/features/kanban/presentation/widgets/kanban_card_widget.dart';
import 'package:not_app/features/notes/data/repositories/note_kanban_repository_impl.dart';
import 'package:not_app/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:not_app/features/reminders/data/repositories/reminders_repository_impl.dart';
import 'package:not_app/features/search/data/repositories/search_repository_impl.dart';

class _MockNotificationService extends Mock implements NotificationService {}

class _DisabledNetworkInfo implements NetworkInfo {
  const _DisabledNetworkInfo();

  @override
  Future<bool> isConnected() async => false;

  @override
  Stream<bool> get onConnectivityChanged => Stream<bool>.value(false);
}

class _TestClock implements AppClock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 8, 16, 12);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DriftSyncQueueRepository syncQueue;
  late DriftKanbanRepository repository;
  late _TestClock clock;
  late AppServices appServices;

  Widget createTestApp(Widget child) {
    return ProviderScope(
      overrides: [
        appServicesProvider.overrideWithValue(appServices),
        kanbanRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(home: child),
    );
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(createTestApp(screen));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();
  }

  Future<void> unmountScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> settleRepositoryWrite(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    clock = _TestClock();
    syncQueue = DriftSyncQueueRepository(database: db, clock: clock);
    repository = DriftKanbanRepository(
      database: db,
      syncQueue: syncQueue,
      clock: clock,
    );

    final mockNotifications = _MockNotificationService();
    when(() => mockNotifications.permissionState()).thenAnswer(
      (_) async => const NotificationPermissionState(
        notificationsAllowed: true,
        exactAlarmsAllowed: true,
      ),
    );

    final localStore = LocalEntityStore(database: db, clock: clock);
    final conflicts = DriftConflictRepository(
      database: db,
      syncQueue: syncQueue,
      localStore: localStore,
      clock: clock,
    );
    final engine = SyncEngine(
      database: db,
      queue: syncQueue,
      remote: const DisabledRemoteGateway(),
      localStore: localStore,
      conflicts: conflicts,
      clock: clock,
      logger: const AppLogger(),
    );
    final settings = DriftAppSettingsRepository(db, clock);
    final reminders = DriftRemindersRepository(
      database: db,
      notifications: mockNotifications,
      syncQueue: syncQueue,
      clock: clock,
    );
    final coordinator = SyncCoordinator(
      networkInfo: const _DisabledNetworkInfo(),
      authService: const DisabledAuthService(),
      engine: engine,
      queue: syncQueue,
      database: db,
      clock: clock,
      reconcileReminders: reminders.reconcile,
      logger: const AppLogger(),
    );
    final attachments = DriftAttachmentsRepository(
      database: db,
      storage: SandboxFileStorageService(),
      syncQueue: syncQueue,
      clock: clock,
      remote: const DisabledRemoteGateway(),
    );
    final notes = DriftNotesRepository(
      database: db,
      syncQueue: syncQueue,
      clock: clock,
    );

    appServices = AppServices(
      config: const AppConfig(
        environment: 'test',
        supabaseUrl: '',
        supabasePublishableKey: '',
      ),
      database: db,
      clock: clock,
      logger: const AppLogger(),
      networkInfo: const _DisabledNetworkInfo(),
      fileStorage: SandboxFileStorageService(),
      filePicker: PlatformFilePickerService(),
      notifications: mockNotifications,
      auth: const DisabledAuthService(),
      remote: const DisabledRemoteGateway(),
      syncQueue: syncQueue,
      localEntityStore: localStore,
      conflicts: conflicts,
      syncEngine: engine,
      syncCoordinator: coordinator,
      settings: settings,
      notes: notes,
      kanban: repository,
      noteKanban: DriftNoteKanbanRepository(
        database: db,
        kanban: repository,
        syncQueue: syncQueue,
        clock: clock,
      ),
      attachments: attachments,
      reminders: reminders,
      search: DriftSearchRepository(db),
    );

    AppServiceRegistry.current = appServices;
  });

  tearDown(() async {
    AppServiceRegistry.clear();
    await db.close();
  });

  group('500+ kart ve fractional-index performansı', () {
    test('525 kart sıralaması kesin artan rankKey üretir', () async {
      final String boardId = await repository.createBoard(title: 'Büyük Pano');
      final List<String> columnIds = <String>[];
      const int columnCount = 5;
      const int cardsPerColumn = 105;

      for (int i = 0; i < columnCount; i++) {
        columnIds.add(
          await repository.createColumn(
            boardId: boardId,
            title: 'Kolon ${i + 1}',
          ),
        );
      }

      final stopwatch = Stopwatch()..start();
      final DateTime now = clock.nowUtc();
      await db.batch((batch) {
        for (int c = 0; c < columnCount; c++) {
          final List<String> rankKeys = FractionalIndexing.rebalance(
            cardsPerColumn,
          );
          for (int k = 0; k < cardsPerColumn; k++) {
            batch.insert(
              db.cards,
              CardsCompanion.insert(
                id: 'card_${c}_$k',
                boardId: boardId,
                columnId: columnIds[c],
                title: 'Kart C${c + 1} - #$k',
                description: Value<String?>('Detay metni $k'),
                rankKey: Value<String>(rankKeys[k]),
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        }
      });
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      final allCards =
          await (db.select(db.cards)..where(
                (table) =>
                    table.boardId.equals(boardId) & table.deletedAt.isNull(),
              ))
              .get();
      expect(allCards.length, 525);

      for (final String columnId in columnIds) {
        final cards =
            await (db.select(db.cards)
                  ..where(
                    (table) =>
                        table.columnId.equals(columnId) &
                        table.deletedAt.isNull(),
                  )
                  ..orderBy([(table) => OrderingTerm.asc(table.rankKey)]))
                .get();
        expect(cards.length, cardsPerColumn);
        for (int i = 0; i < cards.length - 1; i++) {
          expect(cards[i].rankKey.compareTo(cards[i + 1].rankKey), lessThan(0));
        }
      }
    });

    testWidgets('500 kartlı pano lazy render kullanır', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final String boardId = await repository.createBoard(
        title: 'Performans Panosu',
      );
      final List<String> columnIds = <String>[];
      for (int i = 0; i < 5; i++) {
        columnIds.add(
          await repository.createColumn(
            boardId: boardId,
            title: 'Kolon ${i + 1}',
          ),
        );
      }

      final DateTime now = clock.nowUtc();
      await db.batch((batch) {
        for (int c = 0; c < 5; c++) {
          final List<String> rankKeys = FractionalIndexing.rebalance(100);
          for (int k = 0; k < 100; k++) {
            batch.insert(
              db.cards,
              CardsCompanion.insert(
                id: 'perf_card_${c}_$k',
                boardId: boardId,
                columnId: columnIds[c],
                title: 'Kart C${c + 1} #$k',
                rankKey: Value<String>(rankKeys[k]),
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        }
      });

      final Stopwatch watch = Stopwatch()..start();
      await pumpScreen(tester, KanbanBoardScreen(boardId: boardId));
      watch.stop();

      expect(watch.elapsedMilliseconds, lessThan(15000));
      expect(find.textContaining('Kolon 1'), findsWidgets);
      expect(find.byType(KanbanCardWidget).evaluate().length, lessThan(80));
      await unmountScreen(tester);
    });

    test('yoğun kolonlar arası taşıma rankKey sırasını korur', () async {
      final String boardId = await repository.createBoard(
        title: 'Ranking Benchmark',
      );
      final String col1 = await repository.createColumn(
        boardId: boardId,
        title: 'C1',
      );
      final String col2 = await repository.createColumn(
        boardId: boardId,
        title: 'C2',
      );
      const int initialCards = 250;
      final DateTime now = clock.nowUtc();
      final List<String> rankKeys1 = FractionalIndexing.rebalance(initialCards);
      final List<String> rankKeys2 = FractionalIndexing.rebalance(initialCards);

      await db.batch((batch) {
        for (int i = 0; i < initialCards; i++) {
          batch.insert(
            db.cards,
            CardsCompanion.insert(
              id: 'rank_c1_$i',
              boardId: boardId,
              columnId: col1,
              title: 'C1 Card $i',
              rankKey: Value<String>(rankKeys1[i]),
              createdAt: now,
              updatedAt: now,
            ),
          );
          batch.insert(
            db.cards,
            CardsCompanion.insert(
              id: 'rank_c2_$i',
              boardId: boardId,
              columnId: col2,
              title: 'C2 Card $i',
              rankKey: Value<String>(rankKeys2[i]),
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      });

      final Stopwatch watch = Stopwatch()..start();
      for (int i = 0; i < 25; i++) {
        await repository.moveCard(
          cardId: 'rank_c1_$i',
          destinationColumnId: col2,
          destinationIndex: 0,
        );
        await repository.moveCard(
          cardId: 'rank_c2_$i',
          destinationColumnId: col1,
          destinationIndex: initialCards,
        );
      }
      watch.stop();
      expect(watch.elapsedMilliseconds / 50.0, lessThan(10.0));

      for (final String columnId in <String>[col1, col2]) {
        final cards =
            await (db.select(db.cards)
                  ..where(
                    (table) =>
                        table.columnId.equals(columnId) &
                        table.deletedAt.isNull(),
                  )
                  ..orderBy([(table) => OrderingTerm.asc(table.rankKey)]))
                .get();
        for (int i = 0; i < cards.length - 1; i++) {
          expect(cards[i].rankKey.compareTo(cards[i + 1].rankKey), lessThan(0));
        }
      }
    });
  });

  group('Kanban drag ve erişilebilir taşıma', () {
    testWidgets('kenar auto-scroll drop sonrasında durur', (tester) async {
      tester.view.physicalSize = const Size(600, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final String boardId = await repository.createBoard(
        title: 'Auto Scroll Board',
      );
      final List<String> columns = <String>[];
      for (int i = 0; i < 5; i++) {
        columns.add(
          await repository.createColumn(
            boardId: boardId,
            title: 'Kolon ${i + 1}',
          ),
        );
      }
      await repository.createCard(
        boardId: boardId,
        columnId: columns.first,
        title: 'Sürüklenecek Kart',
      );

      await pumpScreen(tester, KanbanBoardScreen(boardId: boardId));
      final scrollableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.right,
      );
      final ScrollableState scrollable = tester.state(scrollableFinder);
      expect(scrollable.position.pixels, 0.0);

      final cardFinder = find.text('Sürüklenecek Kart');
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(cardFinder),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await gesture.moveTo(const Offset(580, 300));
      await tester.pump(const Duration(milliseconds: 150));
      expect(scrollable.position.pixels, greaterThan(0.0));

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));
      final double offsetAfterDrop = scrollable.position.pixels;
      await tester.pump(const Duration(milliseconds: 300));
      expect(scrollable.position.pixels, offsetAfterDrop);
      await unmountScreen(tester);
    });

    testWidgets('kart menüsü drag dışı taşıma alternatifi sağlar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final String boardId = await repository.createBoard(
        title: 'Erişilebilirlik Panosu',
      );
      final String col1 = await repository.createColumn(
        boardId: boardId,
        title: 'Yapılacak',
      );
      final String col2 = await repository.createColumn(
        boardId: boardId,
        title: 'Devam Eden',
      );
      final String cardId = await repository.createCard(
        boardId: boardId,
        columnId: col1,
        title: 'Taşınacak Kart',
      );

      await pumpScreen(tester, KanbanBoardScreen(boardId: boardId));
      final menu = find.byKey(ValueKey('card_menu_$cardId'));
      expect(menu, findsOneWidget);
      await tester.tap(menu);
      await tester.pumpAndSettle();

      final prevItem = tester.widget<PopupMenuItem<String>>(
        find.byKey(const ValueKey('menu_move_prev')),
      );
      expect(prevItem.enabled, isFalse);
      expect(find.text('Sonraki kolona taşı'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('menu_move_next')));
      await settleRepositoryWrite(tester);
      final card = await (db.select(
        db.cards,
      )..where((table) => table.id.equals(cardId))).getSingle();
      expect(card.columnId, col2);
      await unmountScreen(tester);
    });
  });

  group('Kart detay Quiet Workspace sözleşmesi', () {
    testWidgets('kolon seçici kartı taşır ve başlık/açıklama autosave olur', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final String boardId = await repository.createBoard(
        title: 'Detay Test Panosu',
      );
      final String colA = await repository.createColumn(
        boardId: boardId,
        title: 'A Kolonu',
      );
      final String colB = await repository.createColumn(
        boardId: boardId,
        title: 'B Kolonu',
      );
      final String cardId = await repository.createCard(
        boardId: boardId,
        columnId: colA,
        title: 'Test Kartı',
        description: 'İlk açıklama',
      );

      await pumpScreen(tester, CardDetailScreen(cardId: cardId));

      expect(find.text('Kaydet'), findsNothing);
      expect(find.text('Kolon'), findsOneWidget);
      expect(find.text('Ekler'), findsOneWidget);
      expect(find.text('Hatırlatıcılar'), findsOneWidget);

      final columnField = find.byType(DropdownButtonFormField<String>);
      expect(columnField, findsOneWidget);
      await tester.tap(columnField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('B Kolonu').last);
      await settleRepositoryWrite(tester);

      var card = await (db.select(
        db.cards,
      )..where((table) => table.id.equals(cardId))).getSingle();
      expect(card.columnId, colB);

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), 'Yeni Kart Başlığı');
      await tester.enterText(fields.at(1), 'Autosave açıklaması');
      await tester.pump(const Duration(milliseconds: 600));
      await settleRepositoryWrite(tester);

      card = await (db.select(
        db.cards,
      )..where((table) => table.id.equals(cardId))).getSingle();
      expect(card.title, 'Yeni Kart Başlığı');
      expect(card.description, 'Autosave açıklaması');
      await unmountScreen(tester);
    });

    testWidgets('expanded panoda kart detayı sağ panelde açılır', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final String boardId = await repository.createBoard(
        title: 'Side Pane Panosu',
      );
      final String columnId = await repository.createColumn(
        boardId: boardId,
        title: 'Kolon',
      );
      await repository.createCard(
        boardId: boardId,
        columnId: columnId,
        title: 'Panel Kartı',
      );

      await pumpScreen(tester, KanbanBoardScreen(boardId: boardId));
      await tester.tap(find.text('Panel Kartı'));
      await settleRepositoryWrite(tester);
      await settleRepositoryWrite(tester);

      expect(find.byType(CardDetailPane), findsOneWidget);
      expect(find.text('Kart ayrıntısı'), findsOneWidget);
      expect(find.text('Panel Kartı'), findsWidgets);
      await unmountScreen(tester);
    });
  });
}
