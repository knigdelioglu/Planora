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

  setUp(() {
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

  group('Kabul Kriteri 3: 500+ Kart ve Çoklu Kolon Performans Doğrulaması', () {
    test(
      '500+ kartlık veri seti oluşturma ve fractional index sıralama doğrulaması',
      () async {
        final String boardId = await repository.createBoard(
          title: 'Büyük Pano',
        );
        final List<String> columnIds = <String>[];
        const int columnCount = 5;
        const int cardsPerColumn = 105; // 5 * 105 = 525 cards
        const int totalCards = columnCount * cardsPerColumn;

        for (int i = 0; i < columnCount; i++) {
          final String colId = await repository.createColumn(
            boardId: boardId,
            title: 'Kolon ${i + 1}',
          );
          columnIds.add(colId);
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
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(2000),
          reason: '500+ kart veritabanına 2 saniyenin altında eklenmeli',
        );

        final allCards =
            await (db.select(db.cards)..where(
                  (tbl) => tbl.boardId.equals(boardId) & tbl.deletedAt.isNull(),
                ))
                .get();
        expect(allCards.length, totalCards);

        for (final colId in columnIds) {
          final colCards =
              await (db.select(db.cards)
                    ..where(
                      (tbl) =>
                          tbl.columnId.equals(colId) & tbl.deletedAt.isNull(),
                    )
                    ..orderBy([(tbl) => OrderingTerm.asc(tbl.rankKey)]))
                  .get();
          expect(colCards.length, cardsPerColumn);
          for (int i = 0; i < colCards.length - 1; i++) {
            expect(
              colCards[i].rankKey.compareTo(colCards[i + 1].rankKey),
              lessThan(0),
              reason: 'rankKey her zaman kesin artan sırada olmalıdır',
            );
          }
        }
      },
    );

    testWidgets('500+ kart içeren panonun açılışı ve lazy render doğrulaması', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final String boardId = await repository.createBoard(
        title: 'Performans Panosu',
      );
      final List<String> columnIds = <String>[];
      const int columnCount = 5;
      const int cardsPerColumn = 100; // 500 cards

      for (int i = 0; i < columnCount; i++) {
        final String colId = await repository.createColumn(
          boardId: boardId,
          title: 'Kolon ${i + 1}',
        );
        columnIds.add(colId);
      }

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
                id: 'perf_card_${c}_$k',
                boardId: boardId,
                columnId: columnIds[c],
                title: 'Kart C${c + 1} #$k',
                description: Value<String?>('Açıklama $k'),
                rankKey: Value<String>(rankKeys[k]),
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        }
      });

      final Stopwatch renderStopwatch = Stopwatch()..start();

      await pumpScreen(tester, KanbanBoardScreen(boardId: boardId));
      renderStopwatch.stop();

      expect(
        renderStopwatch.elapsedMilliseconds,
        lessThan(3000),
        reason: '500+ kartlı pano makul sürede tam açılmalı',
      );

      expect(find.textContaining('Kolon 1'), findsWidgets);
      expect(find.textContaining('Kolon 2'), findsWidgets);
      expect(find.textContaining('Kolon 3'), findsWidgets);

      final renderedCards = find.byType(KanbanCardWidget);
      expect(
        renderedCards.evaluate().length,
        lessThan(80),
        reason:
            'ListView.builder sadece görünür kartları instantiate etmelidir (lazy rendering)',
      );

      await unmountScreen(tester);
    });

    testWidgets('500+ kartlı panoda yatay ve dikey scroll akıcılığı', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final String boardId = await repository.createBoard(
        title: 'Scroll Test Panosu',
      );
      final List<String> columnIds = <String>[];
      const int columnCount = 6;
      const int cardsPerColumn = 90; // 540 cards

      for (int i = 0; i < columnCount; i++) {
        final String colId = await repository.createColumn(
          boardId: boardId,
          title: 'Sütun ${i + 1}',
        );
        columnIds.add(colId);
      }

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
                id: 'scroll_card_${c}_$k',
                boardId: boardId,
                columnId: columnIds[c],
                title: 'Kart S${c + 1} #$k',
                rankKey: Value<String>(rankKeys[k]),
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        }
      });

      await pumpScreen(tester, KanbanBoardScreen(boardId: boardId));

      final verticalList = find.byType(ListView).at(1);
      final vScrollStopwatch = Stopwatch()..start();

      await tester.drag(verticalList, const Offset(0, -300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      vScrollStopwatch.stop();
      expect(
        vScrollStopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason: 'Dikey scroll frame pacing akıcı olmalıdır',
      );

      final horizontalList = find.byType(ListView).first;
      final scrollStopwatch = Stopwatch()..start();

      await tester.drag(horizontalList, const Offset(-300, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      scrollStopwatch.stop();
      expect(
        scrollStopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason: 'Yatay scroll frame pacing akıcı olmalıdır',
      );

      await unmountScreen(tester);
    });

    test(
      '500+ kartlı veri setinde yoğun fractional index hesaplama performansı',
      () async {
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
        final List<String> rankKeys1 = FractionalIndexing.rebalance(
          initialCards,
        );
        final List<String> rankKeys2 = FractionalIndexing.rebalance(
          initialCards,
        );

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

        final Stopwatch moveStopwatch = Stopwatch()..start();

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

        moveStopwatch.stop();
        final double avgMsPerMove = moveStopwatch.elapsedMilliseconds / 50.0;
        expect(
          avgMsPerMove,
          lessThan(10.0),
          reason:
              'Kart başına fractional index ve persistence süresi 10ms altında olmalıdır',
        );

        final c1Cards =
            await (db.select(db.cards)
                  ..where(
                    (tbl) => tbl.columnId.equals(col1) & tbl.deletedAt.isNull(),
                  )
                  ..orderBy([(tbl) => OrderingTerm.asc(tbl.rankKey)]))
                .get();
        for (int i = 0; i < c1Cards.length - 1; i++) {
          expect(
            c1Cards[i].rankKey.compareTo(c1Cards[i + 1].rankKey),
            lessThan(0),
          );
        }

        final c2Cards =
            await (db.select(db.cards)
                  ..where(
                    (tbl) => tbl.columnId.equals(col2) & tbl.deletedAt.isNull(),
                  )
                  ..orderBy([(tbl) => OrderingTerm.asc(tbl.rankKey)]))
                .get();
        for (int i = 0; i < c2Cards.length - 1; i++) {
          expect(
            c2Cards[i].rankKey.compareTo(c2Cards[i + 1].rankKey),
            lessThan(0),
          );
        }
      },
    );
  });

  group(
    'Kabul Kriteri 1: Otomatik Kenar Kaydırma (Auto-scroll) ve Runaway Önleme',
    () {
      testWidgets(
        'Kart kenara (48px) yaklaştığında yatay auto-scroll tetiklenir ve bırakıldığında durur',
        (tester) async {
          tester.view.physicalSize = const Size(600, 600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final String boardId = await repository.createBoard(
            title: 'Auto Scroll Board',
          );
          final List<String> colIds = <String>[];
          for (int i = 0; i < 5; i++) {
            colIds.add(
              await repository.createColumn(
                boardId: boardId,
                title: 'Kolon ${i + 1}',
              ),
            );
          }

          await repository.createCard(
            boardId: boardId,
            columnId: colIds[0],
            title: 'Sürüklenecek Kart',
          );

          await pumpScreen(tester, KanbanBoardScreen(boardId: boardId));

          final scrollableFinder = find.byType(Scrollable).first;
          final ScrollableState initialScrollable = tester.state(
            scrollableFinder,
          );
          expect(initialScrollable.position.pixels, 0.0);

          final cardFinder = find.text('Sürüklenecek Kart');
          expect(cardFinder, findsOneWidget);

          final TestGesture gesture = await tester.startGesture(
            tester.getCenter(cardFinder),
          );
          await tester.pump(const Duration(milliseconds: 600));

          await gesture.moveTo(const Offset(580, 300));
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pump(const Duration(milliseconds: 100));

          final ScrollableState scrollingScrollable = tester.state(
            scrollableFinder,
          );
          expect(
            scrollingScrollable.position.pixels,
            greaterThan(0.0),
            reason: 'Sağ kenar 48px eşiğinde yatay liste sağa kaydırılmalıdır',
          );

          await gesture.up();
          await tester.pump(const Duration(milliseconds: 50));

          final ScrollableState droppedScrollable = tester.state(
            scrollableFinder,
          );
          final double offsetAfterDrop = droppedScrollable.position.pixels;

          await tester.pump(const Duration(milliseconds: 300));
          final double offsetAfterWait = droppedScrollable.position.pixels;
          expect(
            offsetAfterWait,
            equals(offsetAfterDrop),
            reason:
                'Kart bırakıldığında auto-scroll timer anında iptal edilmeli, runaway oluşmamalıdır',
          );

          expect(find.text('Sürüklenecek Kart'), findsOneWidget);

          await unmountScreen(tester);
        },
      );

      testWidgets('Merkezde sürükleme yapılırken auto-scroll tetiklenmez', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final String boardId = await repository.createBoard(
          title: 'Center Drag Board',
        );
        final col1 = await repository.createColumn(
          boardId: boardId,
          title: 'K1',
        );
        await repository.createColumn(boardId: boardId, title: 'K2');
        await repository.createCard(
          boardId: boardId,
          columnId: col1,
          title: 'Orta Kart',
        );

        await pumpScreen(tester, KanbanBoardScreen(boardId: boardId));

        final scrollableFinder = find.byType(Scrollable).first;
        final ScrollableState scrollable = tester.state(scrollableFinder);
        expect(scrollable.position.pixels, 0.0);

        final cardFinder = find.text('Orta Kart');
        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(cardFinder),
        );
        await tester.pump(const Duration(milliseconds: 600));

        await gesture.moveTo(const Offset(400, 300));
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          scrollable.position.pixels,
          0.0,
          reason:
              'Kenar eşiği (48px) dışındayken auto-scroll tetiklenmemelidir',
        );

        await gesture.up();
        await tester.pump(const Duration(milliseconds: 50));

        await unmountScreen(tester);
      });
    },
  );

  group(
    'Kabul Kriteri 2: Kart Menüsünde ve Detay Ekranında Erişilebilir Alternatif Taşıma',
    () {
      testWidgets(
        'Pano kart menüsündeki alternatif taşıma butonları kartı doğru konumlara taşır',
        (tester) async {
          tester.view.physicalSize = const Size(1000, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

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
          await repository.createColumn(boardId: boardId, title: 'Tamamlandı');

          final String card1 = await repository.createCard(
            boardId: boardId,
            columnId: col1,
            title: 'Kart 1',
          );
          await repository.createCard(
            boardId: boardId,
            columnId: col1,
            title: 'Kart 2',
          );
          final String card3 = await repository.createCard(
            boardId: boardId,
            columnId: col1,
            title: 'Kart 3',
          );

          await pumpScreen(tester, KanbanBoardScreen(boardId: boardId));

          final card1Menu = find.byKey(ValueKey('card_menu_$card1'));
          expect(card1Menu, findsOneWidget);
          await tester.tap(card1Menu);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));

          expect(find.text('Önceki kolona taşı'), findsOneWidget);
          expect(find.text('Sonraki kolona taşı'), findsOneWidget);
          expect(find.text('Kolonun en üstüne taşı'), findsOneWidget);
          expect(find.text('Kolonun en altına taşı'), findsOneWidget);

          final prevItem = tester.widget<PopupMenuItem<String>>(
            find.byKey(const ValueKey('menu_move_prev')),
          );
          expect(prevItem.enabled, isFalse);

          await tester.tap(find.byKey(const ValueKey('menu_move_next')));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          final card1Row = await (db.select(
            db.cards,
          )..where((tbl) => tbl.id.equals(card1))).getSingle();
          expect(card1Row.columnId, col2);

          final card3Menu = find.byKey(ValueKey('card_menu_$card3'));
          await tester.tap(card3Menu);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));

          await tester.tap(find.byKey(const ValueKey('menu_move_top')));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          final col1CardsAfterTop =
              await (db.select(db.cards)
                    ..where(
                      (tbl) =>
                          tbl.columnId.equals(col1) & tbl.deletedAt.isNull(),
                    )
                    ..orderBy([(tbl) => OrderingTerm.asc(tbl.rankKey)]))
                  .get();
          expect(col1CardsAfterTop.first.id, card3);

          final card3MenuAgain = find.byKey(ValueKey('card_menu_$card3'));
          await tester.tap(card3MenuAgain);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));

          await tester.tap(find.byKey(const ValueKey('menu_move_bottom')));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          final col1CardsAfterBottom =
              await (db.select(db.cards)
                    ..where(
                      (tbl) =>
                          tbl.columnId.equals(col1) & tbl.deletedAt.isNull(),
                    )
                    ..orderBy([(tbl) => OrderingTerm.asc(tbl.rankKey)]))
                  .get();
          expect(col1CardsAfterBottom.last.id, card3);

          await unmountScreen(tester);
        },
      );

      testWidgets(
        'Kart detay ekranındaki erişilebilir taşıma butonları ve menüsü eksiksiz çalışır',
        (tester) async {
          tester.view.physicalSize = const Size(1000, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

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

          final String cardA1 = await repository.createCard(
            boardId: boardId,
            columnId: colA,
            title: 'Test Kartı',
          );
          await repository.createCard(
            boardId: boardId,
            columnId: colA,
            title: 'İkinci Kart',
          );

          await pumpScreen(tester, CardDetailScreen(cardId: cardA1));

          expect(
            find.byKey(const ValueKey('detail_btn_move_prev')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('detail_btn_move_next')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('detail_btn_move_top')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('detail_btn_move_bottom')),
            findsOneWidget,
          );

          expect(find.text('Önceki kolona taşı'), findsWidgets);
          expect(find.text('Sonraki kolona taşı'), findsWidgets);
          expect(find.text('Kolonun en üstüne taşı'), findsWidgets);
          expect(find.text('Kolonun en altına taşı'), findsWidgets);

          final prevButton = tester.widget<OutlinedButton>(
            find.byKey(const ValueKey('detail_btn_move_prev')),
          );
          expect(prevButton.onPressed, isNull);

          await tester.tap(find.byKey(const ValueKey('detail_btn_move_next')));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          final cardRow = await (db.select(
            db.cards,
          )..where((tbl) => tbl.id.equals(cardA1))).getSingle();
          expect(cardRow.columnId, colB);

          expect(find.text('Kolon: B Kolonu'), findsOneWidget);

          final nextButton = tester.widget<OutlinedButton>(
            find.byKey(const ValueKey('detail_btn_move_next')),
          );
          expect(nextButton.onPressed, isNull);

          final prevButtonNow = tester.widget<OutlinedButton>(
            find.byKey(const ValueKey('detail_btn_move_prev')),
          );
          expect(prevButtonNow.onPressed, isNotNull);

          await tester.tap(find.byKey(const ValueKey('detail_btn_move_prev')));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          final cardRowBack = await (db.select(
            db.cards,
          )..where((tbl) => tbl.id.equals(cardA1))).getSingle();
          expect(cardRowBack.columnId, colA);
          expect(find.text('Kolon: A Kolonu'), findsOneWidget);

          final overflowMenu = find.byKey(
            const ValueKey('card_detail_overflow_menu'),
          );
          expect(overflowMenu, findsOneWidget);
          await tester.tap(overflowMenu);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));

          expect(
            find.byKey(const ValueKey('detail_menu_move_prev')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('detail_menu_move_next')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('detail_menu_move_top')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('detail_menu_move_bottom')),
            findsOneWidget,
          );

          await unmountScreen(tester);
        },
      );
    },
  );
}
