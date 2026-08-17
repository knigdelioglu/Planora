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
import 'package:not_app/app/widgets/content/app_content.dart';
import 'package:not_app/app/widgets/overlays/global_search_palette.dart';
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
      overrides: <Override>[
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

  Finder fullSearchField() => find.descendant(
    of: find.byKey(const ValueKey('search_text_field')),
    matching: find.byType(TextField),
  );

  Finder paletteSearchField() => find.descendant(
    of: find.byType(GlobalSearchPalette),
    matching: find.byType(TextField),
  );

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

  group('FTS performansı', () {
    test('1250+ kayıt <50ms hedefiyle aranır', () async {
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
      expect(insertStopwatch.elapsedMilliseconds, lessThan(3000));

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
        final stopwatch = Stopwatch()..start();
        final results = await searchRepository.search(query, limit: 100);
        stopwatch.stop();
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(50),
          reason: '1000+ kayıtta "$query" araması <50ms hedefini korumalıdır.',
        );
        if (query == 'Flutter') {
          expect(
            results.every((result) => result.entityType == 'note'),
            isTrue,
          );
        } else if (query == 'Kanban') {
          expect(
            results.every((result) => result.entityType == 'card'),
            isTrue,
          );
        } else if (query == 'Sprint') {
          expect(
            results.every((result) => result.entityType == 'board'),
            isTrue,
          );
        } else if (query == 'bulunmayan_kelime_xyz') {
          expect(results, isEmpty);
        }
      }
    });

    test('50 ardışık sorgunun ortalama yanıtı <15ms kalır', () async {
      await db.inTransaction(() async {
        for (int i = 0; i < 600; i++) {
          await db.upsertSearchEntry(
            entityType: 'note',
            entityId: 'n_$i',
            title: 'Not $i Test Dokümanı',
            body: 'İçerik detayı kelime_$i veri analizi rapor',
          );
          await db.upsertSearchEntry(
            entityType: 'card',
            entityId: 'c_$i',
            title: 'Kart $i Görev Özeti',
            body: 'Görev açıklaması madde_$i süreç takip',
          );
        }
      });

      final benchmark = Stopwatch()..start();
      const int iterations = 50;
      for (int i = 0; i < iterations; i++) {
        final query = i.isEven ? 'Dokümanı' : 'Özeti';
        final single = Stopwatch()..start();
        final results = await searchRepository.search(query, limit: 50);
        single.stop();
        expect(single.elapsedMilliseconds, lessThan(50));
        expect(results.length, 50);
      }
      benchmark.stop();
      expect(benchmark.elapsedMilliseconds / iterations, lessThan(15.0));
    });
  });

  group('Tam sayfa arama UX sözleşmesi', () {
    testWidgets('180ms debounce ve grup başlıkları korunur', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

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
      final input = fullSearchField();
      expect(input, findsOneWidget);

      await tester.enterText(input, 'O');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(input, 'Op');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(input, 'Opt');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(input, 'Optimizasyon');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('search_section_note')), findsNothing);

      final renderWatch = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      renderWatch.stop();

      expect(renderWatch.elapsedMilliseconds, lessThan(600));
      expect(find.text('Notlar (5)'), findsOneWidget);
      expect(find.text('Kartlar (5)'), findsOneWidget);
      expect(find.byKey(const ValueKey('search_section_note')), findsOneWidget);
      expect(find.byKey(const ValueKey('search_section_card')), findsOneWidget);

      await unmountScreen(tester);
    });

    testWidgets('kategori grupları doğru sıralanır ve boş gruplar gizlenir', (
      tester,
    ) async {
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
      await tester.enterText(fullSearchField(), 'Algoritma');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();

      expect(find.text('Notlar (2)'), findsOneWidget);
      expect(find.text('Kartlar (1)'), findsOneWidget);
      expect(find.text('Panolar (1)'), findsOneWidget);
      expect(find.byKey(const ValueKey('search_section_note')), findsOneWidget);
      expect(find.byKey(const ValueKey('search_section_card')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('search_section_board')),
        findsOneWidget,
      );

      await tester.enterText(fullSearchField(), 'Algoritma Notu');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();
      expect(find.textContaining('Kartlar ('), findsNothing);
      expect(find.textContaining('Panolar ('), findsNothing);

      await unmountScreen(tester);
    });

    testWidgets('sonuç yok durumunu açıkça gösterir', (tester) async {
      await pumpScreen(tester, const SearchScreen());
      await tester.enterText(fullSearchField(), 'olmayan_kelime_9999');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();

      expect(find.text('Sonuç bulunamadı'), findsOneWidget);
      expect(find.text('Farklı bir kelime deneyin.'), findsOneWidget);
      await unmountScreen(tester);
    });

    testWidgets('ArrowDown/ArrowUp seçim stateini AppListRow üzerinde taşır', (
      tester,
    ) async {
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
      await tester.enterText(fullSearchField(), 'Gezinti');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();

      final first = find.byKey(const ValueKey('search_result_note_nav_n1'));
      final second = find.byKey(const ValueKey('search_result_card_nav_c1'));
      expect(tester.widget<AppListRow>(first).selected, isFalse);
      expect(tester.widget<AppListRow>(second).selected, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(tester.widget<AppListRow>(first).selected, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(tester.widget<AppListRow>(first).selected, isFalse);
      expect(tester.widget<AppListRow>(second).selected, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(tester.widget<AppListRow>(second).selected, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(tester.widget<AppListRow>(first).selected, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(tester.widget<AppListRow>(first).selected, isFalse);
      expect(tester.widget<AppListRow>(second).selected, isFalse);

      await unmountScreen(tester);
    });

    testWidgets('Enter seçili kartı, ilk sonucu ve pano sonucunu açar', (
      tester,
    ) async {
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
      await tester.enterText(fullSearchField(), 'Hedef');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        tester
            .widget<AppListRow>(
              find.byKey(const ValueKey('search_result_card_target_card_1')),
            )
            .selected,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CardDetailScreen), findsOneWidget);

      await unmountScreen(tester);
    });

    testWidgets('Escape önce sorguyu temizler sonra odaktan çıkar', (
      tester,
    ) async {
      await db.upsertSearchEntry(
        entityType: 'note',
        entityId: 'esc_note',
        title: 'Escape Notu',
        body: 'Escape denemesi',
      );
      await pumpScreen(tester, const SearchScreen());
      await tester.enterText(fullSearchField(), 'Escape');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();

      expect(find.text('Escape Notu'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(
        tester.widget<TextField>(fullSearchField()).controller?.text,
        isEmpty,
      );
      expect(find.text('Ne arıyorsunuz?'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await unmountScreen(tester);
    });
  });

  group('⌘K / Ctrl+K sözleşmesi', () {
    testWidgets('SearchScreen içinde kısayollar alanı odakta tutar', (
      tester,
    ) async {
      final FocusNode focusNode = FocusNode(debugLabel: 'SearchFocusNode');
      addTearDown(focusNode.dispose);
      await pumpScreen(
        tester,
        SearchScreen(focusNode: focusNode, autofocus: true),
      );
      expect(focusNode.hasFocus, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);
      await unmountScreen(tester);
    });

    Future<void> assertShellShortcut(
      WidgetTester tester,
      LogicalKeyboardKey modifier,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpScreen(tester, const AppShell());
      expect(find.byType(GlobalSearchPalette), findsNothing);

      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(modifier);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.byType(GlobalSearchPalette), findsOneWidget);
      final input = paletteSearchField();
      expect(input, findsOneWidget);
      expect(tester.widget<TextField>(input).focusNode?.hasFocus, isTrue);
      await unmountScreen(tester);
    }

    testWidgets('AppShell ⌘K ile floating command palette açar', (
      tester,
    ) async {
      await assertShellShortcut(tester, LogicalKeyboardKey.metaLeft);
    });

    testWidgets('AppShell Ctrl+K ile floating command palette açar', (
      tester,
    ) async {
      await assertShellShortcut(tester, LogicalKeyboardKey.controlLeft);
    });
  });
}
