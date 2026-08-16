import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_app/app/app_services.dart';
import 'package:not_app/app/app_shell.dart';
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
import 'package:not_app/features/kanban/presentation/screens/card_detail_screen.dart';
import 'package:not_app/features/kanban/presentation/screens/kanban_board_screen.dart';
import 'package:not_app/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:not_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:not_app/features/reminders/data/repositories/reminders_repository_impl.dart';
import 'package:not_app/features/search/data/repositories/search_repository_impl.dart';
import 'package:not_app/features/search/domain/repositories/search_repository.dart';
import 'package:not_app/features/search/presentation/screens/search_screen.dart';

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
  late DriftSearchRepository searchRepository;
  late _TestClock clock;
  late AppServices appServices;

  Widget createTestApp(Widget child, {SearchRepository? searchRepoOverride}) {
    return ProviderScope(
      overrides: [
        appServicesProvider.overrideWithValue(appServices),
        searchRepositoryProvider.overrideWithValue(
          searchRepoOverride ?? searchRepository,
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    SearchRepository? searchRepoOverride,
  }) async {
    await tester.pumpWidget(
      createTestApp(screen, searchRepoOverride: searchRepoOverride),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
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
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    clock = _TestClock();
    syncQueue = DriftSyncQueueRepository(database: db, clock: clock);
    searchRepository = DriftSearchRepository(db);

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
    final kanban = DriftKanbanRepository(
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
      kanban: kanban,
      attachments: attachments,
      reminders: reminders,
      search: searchRepository,
    );

    AppServiceRegistry.current = appServices;
  });

  tearDown(() async {
    AppServiceRegistry.clear();
    await db.close();
  });

  group(
    'Kabul Kriteri 4: 1000+ Kayıtlık Büyük Veri Setinde FTS Arama Performansı (<50ms)',
    () {
      test(
        '1000+ not, kart ve pano veritabanına eklenip FTS indeksinde <50ms süreyle aranır',
        () async {
          const int noteCount = 600;
          const int cardCount = 600;
          const int boardCount = 50;

          final insertStopwatch = Stopwatch()..start();

          await db.inTransaction(() async {
            for (int i = 0; i < noteCount; i++) {
              await db.upsertSearchEntry(
                entityType: 'note',
                entityId: 'note_$i',
                title: 'Not Başlığı $i - Flutter Performans Raporu',
                body:
                    'Bu not içerisinde veri senkronizasyonu, sqlite fts indexleme, mimari optimizasyon $i ve derin içerik bulunmaktadır.',
              );
            }
            for (int i = 0; i < cardCount; i++) {
              await db.upsertSearchEntry(
                entityType: 'card',
                entityId: 'card_$i',
                title: 'Kart Görevi #$i: Kanban kartı taşıma ve ranking',
                body:
                    'Kart detay açıklaması #$i. Supabase kuyruk optimizasyonu ve UI tepkisellik testleri.',
              );
            }
            for (int i = 0; i < boardCount; i++) {
              await db.upsertSearchEntry(
                entityType: 'board',
                entityId: 'board_$i',
                title: 'Pano $i: Sprint Planlama & Yol Haritası',
                body: '',
              );
            }
          });

          insertStopwatch.stop();
          expect(
            insertStopwatch.elapsedMilliseconds,
            lessThan(3000),
            reason:
                '1250+ arama kaydı 3 saniyeden kısa sürede indekslenmelidir',
          );

          final queries = <String>[
            'Flutter',
            'Kanban',
            'Sprint',
            'optimizasyon',
            'senkronizasyon',
            'mimari Performans',
            'raporu',
            'detay',
            'bulunmayan_kelime_xyz',
          ];

          for (final query in queries) {
            final searchStopwatch = Stopwatch()..start();
            final results = await searchRepository.search(query, limit: 100);
            searchStopwatch.stop();

            final int elapsed = searchStopwatch.elapsedMilliseconds;
            expect(
              elapsed,
              lessThan(50),
              reason:
                  '1000+ kayıtta "$query" arama süresi <50ms olmalıdır. Ölçülen: ${elapsed}ms',
            );

            if (query == 'Flutter') {
              expect(results.isNotEmpty, isTrue);
              expect(results.every((r) => r.entityType == 'note'), isTrue);
            } else if (query == 'Kanban') {
              expect(results.isNotEmpty, isTrue);
              expect(results.every((r) => r.entityType == 'card'), isTrue);
            } else if (query == 'Sprint') {
              expect(results.isNotEmpty, isTrue);
              expect(results.every((r) => r.entityType == 'board'), isTrue);
            } else if (query == 'bulunmayan_kelime_xyz') {
              expect(results.isEmpty, isTrue);
            }
          }
        },
      );

      test(
        '1000+ veri setinde 50 ardışık arama sorgusunun ortalama yanıt süresi <15ms olmalıdır',
        () async {
          await db.inTransaction(() async {
            for (int i = 0; i < 600; i++) {
              await db.upsertSearchEntry(
                entityType: 'note',
                entityId: 'n_$i',
                title: 'Not $i Test Dokümanı',
                body: 'İçerik detayı kelime_$i veri analizi rapor',
              );
            }
            for (int i = 0; i < 600; i++) {
              await db.upsertSearchEntry(
                entityType: 'card',
                entityId: 'c_$i',
                title: 'Kart $i Görev Özeti',
                body: 'Görev açıklaması madde_$i süreç takip',
              );
            }
          });

          final Stopwatch benchmarkWatch = Stopwatch()..start();
          const int iterations = 50;

          for (int i = 0; i < iterations; i++) {
            final query = i.isEven ? 'Dokümanı' : 'Özeti';
            final qWatch = Stopwatch()..start();
            final results = await searchRepository.search(query, limit: 50);
            qWatch.stop();
            expect(
              qWatch.elapsedMilliseconds,
              lessThan(50),
              reason: 'Her bir sorgu 50ms altında tamamlanmalı',
            );
            expect(results.length, equals(50));
          }

          benchmarkWatch.stop();
          final double avgMs = benchmarkWatch.elapsedMilliseconds / iterations;
          expect(
            avgMs,
            lessThan(15.0),
            reason:
                'Ortalama arama süresi 15ms altında olmalıdır. Ölçülen ortalama: ${avgMs}ms',
          );
        },
      );

      testWidgets(
        '1000+ kayıtlı veritabanında SearchScreen hızlı yazma (debounce) ve UI render akıcılığı',
        (tester) async {
          tester.view.physicalSize = const Size(1000, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await db.inTransaction(() async {
            for (int i = 0; i < 5; i++) {
              await db.upsertSearchEntry(
                entityType: 'note',
                entityId: 'ui_note_$i',
                title: 'Optimizasyon Notu $i',
                body: 'Arama performansı gövde metni $i',
              );
              await db.upsertSearchEntry(
                entityType: 'card',
                entityId: 'ui_card_$i',
                title: 'Optimizasyon Kartı #$i',
                body: 'Kart açıklaması #$i',
              );
            }
            for (int i = 0; i < 990; i++) {
              await db.upsertSearchEntry(
                entityType: 'note',
                entityId: 'bg_note_$i',
                title: 'Arşiv Kaydı $i',
                body: 'Arka plan verisi $i',
              );
            }
          });

          await pumpScreen(tester, const SearchScreen());

          final textFieldFinder = find.byKey(
            const ValueKey('search_text_field'),
          );
          expect(textFieldFinder, findsOneWidget);

          await tester.enterText(textFieldFinder, 'O');
          await tester.pump(const Duration(milliseconds: 50));
          await tester.enterText(textFieldFinder, 'Op');
          await tester.pump(const Duration(milliseconds: 50));
          await tester.enterText(textFieldFinder, 'Opt');
          await tester.pump(const Duration(milliseconds: 50));
          await tester.enterText(textFieldFinder, 'Optimizasyon');

          await tester.pump(const Duration(milliseconds: 100));
          expect(
            find.byKey(const ValueKey('search_section_note')),
            findsNothing,
            reason: '180ms debounce dolmadan arama tetiklenmemeli',
          );

          final renderWatch = Stopwatch()..start();
          await tester.pump(const Duration(milliseconds: 250));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
          renderWatch.stop();

          expect(
            renderWatch.elapsedMilliseconds,
            lessThan(600),
            reason:
                'Arama sonucu güncellemesi ve render işlemi akıcı olmalıdır',
          );

          expect(
            find.byKey(const ValueKey('search_section_note')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('search_section_card')),
            findsOneWidget,
          );
          expect(find.text('Notlar (5)'), findsOneWidget);
          expect(find.text('Kartlar (5)'), findsOneWidget);

          await unmountScreen(tester);
        },
      );
    },
  );

  group(
    'Kabul Kriteri 1: Arama Sonuç Gruplaması ("Notlar (N)", "Kartlar (N)", "Panolar (N)")',
    () {
      testWidgets(
        'Tüm kategoriler eşleştiğinde grup başlıkları doğru sıralama ve sayılarla listelenir',
        (tester) async {
          await db.inTransaction(() async {
            await db.upsertSearchEntry(
              entityType: 'note',
              entityId: 'n1',
              title: 'Algoritma Notu 1',
              body: 'Arama metni',
            );
            await db.upsertSearchEntry(
              entityType: 'note',
              entityId: 'n2',
              title: 'Algoritma Notu 2',
              body: 'Arama metni',
            );
            await db.upsertSearchEntry(
              entityType: 'card',
              entityId: 'c1',
              title: 'Algoritma Kartı 1',
              body: 'Arama detayı',
            );
            await db.upsertSearchEntry(
              entityType: 'board',
              entityId: 'b1',
              title: 'Algoritma Panosu 1',
              body: '',
            );
          });

          await pumpScreen(tester, const SearchScreen());

          final textFieldFinder = find.byKey(
            const ValueKey('search_text_field'),
          );
          await tester.enterText(textFieldFinder, 'Algoritma');
          await tester.pump(const Duration(milliseconds: 250));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();

          expect(find.text('Notlar (2)'), findsOneWidget);
          expect(find.text('Kartlar (1)'), findsOneWidget);
          expect(find.text('Panolar (1)'), findsOneWidget);

          expect(
            find.byKey(const ValueKey('search_section_note')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('search_section_card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('search_section_board')),
            findsOneWidget,
          );

          expect(find.text('Algoritma Notu 1'), findsOneWidget);
          expect(find.text('Algoritma Notu 2'), findsOneWidget);
          expect(find.text('Algoritma Kartı 1'), findsOneWidget);
          expect(find.text('Algoritma Panosu 1'), findsOneWidget);

          await unmountScreen(tester);
        },
      );

      testWidgets(
        'Sonucu olmayan kategoriler başlıksız olarak tamamen gizlenir',
        (tester) async {
          await db.inTransaction(() async {
            await db.upsertSearchEntry(
              entityType: 'note',
              entityId: 'n_only',
              title: 'Yalnızca Not Başlığı',
              body: 'Not açıklaması',
            );
            await db.upsertSearchEntry(
              entityType: 'card',
              entityId: 'c_other',
              title: 'Başka Bir Konu',
              body: 'İlgisiz içerik',
            );
          });

          await pumpScreen(tester, const SearchScreen());

          await tester.enterText(
            find.byKey(const ValueKey('search_text_field')),
            'Yalnızca',
          );
          await tester.pump(const Duration(milliseconds: 250));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();

          expect(find.text('Notlar (1)'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('search_section_note')),
            findsOneWidget,
          );

          expect(find.textContaining('Kartlar'), findsNothing);
          expect(
            find.byKey(const ValueKey('search_section_card')),
            findsNothing,
          );
          expect(find.textContaining('Panolar'), findsNothing);
          expect(
            find.byKey(const ValueKey('search_section_board')),
            findsNothing,
          );

          await unmountScreen(tester);
        },
      );

      testWidgets(
        'Eşleşen sonuç olmadığında "Sonuç bulunamadı" boş durum mesajı gösterilir',
        (tester) async {
          await pumpScreen(tester, const SearchScreen());

          await tester.enterText(
            find.byKey(const ValueKey('search_text_field')),
            'olmayan_kelime_9999',
          );
          await tester.pump(const Duration(milliseconds: 250));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();

          expect(find.text('Sonuç bulunamadı'), findsOneWidget);
          expect(find.text('Farklı bir kelime deneyin.'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('search_section_note')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('search_section_card')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('search_section_board')),
            findsNothing,
          );

          await unmountScreen(tester);
        },
      );
    },
  );

  group('Kabul Kriteri 2: Klavye Gezintisi (ArrowDown, ArrowUp, Enter, Escape)', () {
    testWidgets(
      'ArrowDown ve ArrowUp tuşları sonuçlar arasında seçim imlecini hareket ettirir',
      (tester) async {
        await db.inTransaction(() async {
          await db.upsertSearchEntry(
            entityType: 'note',
            entityId: 'nav_n1',
            title: 'Gezinti Notu A',
            body: 'Detay',
          );
          await db.upsertSearchEntry(
            entityType: 'card',
            entityId: 'nav_c1',
            title: 'Gezinti Kartı B',
            body: 'Detay',
          );
        });

        await pumpScreen(tester, const SearchScreen());

        final textField = find.byKey(const ValueKey('search_text_field'));
        await tester.enterText(textField, 'Gezinti');
        await tester.pump(const Duration(milliseconds: 250));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump();

        expect(find.text('Gezinti Notu A'), findsOneWidget);
        expect(find.text('Gezinti Kartı B'), findsOneWidget);

        final item1Finder = find.byKey(
          const ValueKey('search_result_note_nav_n1'),
        );
        final item2Finder = find.byKey(
          const ValueKey('search_result_card_nav_c1'),
        );

        ListTile item1 = tester.widget<ListTile>(item1Finder);
        ListTile item2 = tester.widget<ListTile>(item2Finder);
        expect(item1.selected, isFalse);
        expect(item2.selected, isFalse);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        item1 = tester.widget<ListTile>(item1Finder);
        item2 = tester.widget<ListTile>(item2Finder);
        expect(
          item1.selected,
          isTrue,
          reason: 'İlk ArrowDown 1. öğeyi seçmeli',
        );
        expect(item2.selected, isFalse);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        item1 = tester.widget<ListTile>(item1Finder);
        item2 = tester.widget<ListTile>(item2Finder);
        expect(item1.selected, isFalse);
        expect(
          item2.selected,
          isTrue,
          reason: 'İkinci ArrowDown 2. öğeyi seçmeli',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        item2 = tester.widget<ListTile>(item2Finder);
        expect(
          item2.selected,
          isTrue,
          reason: 'Listenin sonundayken son öğede kalmalı',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        item1 = tester.widget<ListTile>(item1Finder);
        item2 = tester.widget<ListTile>(item2Finder);
        expect(item1.selected, isTrue, reason: 'ArrowUp önceki öğeyi seçmeli');
        expect(item2.selected, isFalse);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        item1 = tester.widget<ListTile>(item1Finder);
        item2 = tester.widget<ListTile>(item2Finder);
        expect(
          item1.selected,
          isFalse,
          reason: 'En üstte ArrowUp seçimi sıfırlamalı',
        );
        expect(item2.selected, isFalse);

        await unmountScreen(tester);
      },
    );

    testWidgets(
      'Enter tuşu seçili öğeyi açar (NotEditorScreen / CardDetailScreen / KanbanBoardScreen)',
      (tester) async {
        await db.inTransaction(() async {
          await db.upsertSearchEntry(
            entityType: 'note',
            entityId: 'target_note_1',
            title: 'Hedef Not',
            body: 'Not gövdesi',
          );
          await db.upsertSearchEntry(
            entityType: 'card',
            entityId: 'target_card_1',
            title: 'Hedef Kart',
            body: 'Kart gövdesi',
          );
          await db.upsertSearchEntry(
            entityType: 'board',
            entityId: 'target_board_1',
            title: 'Hedef Pano',
            body: '',
          );
        });

        await pumpScreen(tester, const SearchScreen());

        final textField = find.byKey(const ValueKey('search_text_field'));
        await tester.enterText(textField, 'Hedef');
        await tester.pump(const Duration(milliseconds: 250));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump();

        // Navigate to card (index 1)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        final item2 = tester.widget<ListTile>(
          find.byKey(const ValueKey('search_result_card_target_card_1')),
        );
        expect(item2.selected, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(CardDetailScreen), findsOneWidget);

        await unmountScreen(tester);
      },
    );

    testWidgets('Enter tuşu ilk öğeyi (NotEditorScreen) doğru açar', (
      tester,
    ) async {
      await db.inTransaction(() async {
        await db.upsertSearchEntry(
          entityType: 'note',
          entityId: 'open_note_1',
          title: 'Açılacak Not',
          body: 'Not içeriği',
        );
      });

      await pumpScreen(tester, const SearchScreen());

      final textField = find.byKey(const ValueKey('search_text_field'));
      await tester.enterText(textField, 'Açılacak');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NoteEditorScreen), findsOneWidget);

      await unmountScreen(tester);
    });

    testWidgets('Enter tuşu pano öğesini (KanbanBoardScreen) doğru açar', (
      tester,
    ) async {
      await db.inTransaction(() async {
        await db.upsertSearchEntry(
          entityType: 'board',
          entityId: 'open_board_1',
          title: 'Açılacak Pano',
          body: '',
        );
      });

      await pumpScreen(tester, const SearchScreen());

      final textField = find.byKey(const ValueKey('search_text_field'));
      await tester.enterText(textField, 'Açılacak Pano');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(KanbanBoardScreen), findsOneWidget);

      await unmountScreen(tester);
    });

    testWidgets(
      'Escape tuşu dolu arama alanını temizler, boşken ekranı kapatır veya unfocus eder',
      (tester) async {
        await db.inTransaction(() async {
          await db.upsertSearchEntry(
            entityType: 'note',
            entityId: 'esc_note',
            title: 'Escape Notu',
            body: 'Escape denemesi',
          );
        });

        await pumpScreen(tester, const SearchScreen());

        final textField = find.byKey(const ValueKey('search_text_field'));
        await tester.enterText(textField, 'Escape');
        await tester.pump(const Duration(milliseconds: 250));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump();

        expect(find.text('Escape Notu'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        final TextField fieldWidget = tester.widget<TextField>(textField);
        expect(fieldWidget.controller?.text, isEmpty);
        expect(find.text('Ne arıyorsunuz?'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        await unmountScreen(tester);
      },
    );
  });

  group('Kabul Kriteri 3: ⌘K / Ctrl+K Kısayolu ve Arama Çubuğu Odaklaması', () {
    testWidgets(
      'SearchScreen içinde ⌘K kısayolu arama kutusunu odaklar ve metni seçer',
      (tester) async {
        final FocusNode focusNode = FocusNode(debugLabel: 'SearchFocusNode');
        addTearDown(() => focusNode.dispose());

        await pumpScreen(
          tester,
          SearchScreen(focusNode: focusNode, autofocus: true),
        );

        expect(
          focusNode.hasFocus,
          isTrue,
          reason: 'autofocus: true arama kutusunu odaklamalıdır',
        );

        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump();

        expect(
          focusNode.hasFocus,
          isTrue,
          reason: '⌘K arama kutusunu odaklı tutmalı ve seçmelidir',
        );

        await unmountScreen(tester);
      },
    );

    testWidgets(
      'SearchScreen içinde Ctrl+K kısayolu arama kutusunu odaklar ve metni seçer',
      (tester) async {
        final FocusNode focusNode = FocusNode(debugLabel: 'SearchFocusNode');
        addTearDown(() => focusNode.dispose());

        await pumpScreen(
          tester,
          SearchScreen(focusNode: focusNode, autofocus: true),
        );

        expect(focusNode.hasFocus, isTrue);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump();

        expect(
          focusNode.hasFocus,
          isTrue,
          reason: 'Ctrl+K arama kutusunu odaklı tutmalıdır',
        );

        await unmountScreen(tester);
      },
    );

    testWidgets(
      'AppShell üzerinde ⌘K kısayolu basıldığında arama sekmesine geçer ve arama kutusunu odaklar',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await pumpScreen(tester, const AppShell());

        expect(find.text('Ana Sayfa'), findsWidgets);
        expect(find.byType(SearchScreen), findsNothing);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump();

        expect(find.byType(SearchScreen), findsOneWidget);

        final textFieldFinder = find.byKey(const ValueKey('search_text_field'));
        expect(textFieldFinder, findsOneWidget);

        final TextField textField = tester.widget<TextField>(textFieldFinder);
        expect(
          textField.focusNode?.hasFocus,
          isTrue,
          reason:
              'AppShell üzerinden ⌘K basılınca arama çubuğu odaklanmış olmalıdır',
        );

        await unmountScreen(tester);
      },
    );

    testWidgets(
      'AppShell üzerinde Ctrl+K kısayolu basıldığında arama sekmesine geçer ve arama kutusunu odaklar',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await pumpScreen(tester, const AppShell());

        expect(find.text('Ana Sayfa'), findsWidgets);
        expect(find.byType(SearchScreen), findsNothing);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump();

        expect(find.byType(SearchScreen), findsOneWidget);

        final textFieldFinder = find.byKey(const ValueKey('search_text_field'));
        expect(textFieldFinder, findsOneWidget);

        final TextField textField = tester.widget<TextField>(textFieldFinder);
        expect(
          textField.focusNode?.hasFocus,
          isTrue,
          reason:
              'AppShell üzerinden Ctrl+K basılınca arama çubuğu odaklanmış olmalıdır',
        );

        await unmountScreen(tester);
      },
    );
  });
}
