import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/auth/auth_service.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/logging/app_logger.dart';
import 'package:not_app/core/network/network_info.dart';
import 'package:not_app/core/services/notification_service.dart';
import 'package:not_app/core/sync/local_entity_store.dart';
import 'package:not_app/core/sync/sync_coordinator.dart';
import 'package:not_app/core/sync/sync_engine.dart';
import 'package:not_app/core/sync/sync_models.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/conflicts/data/repositories/conflict_repository_impl.dart';
import 'package:not_app/features/kanban/data/repositories/kanban_repository_impl.dart';
import 'package:not_app/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:not_app/features/notes/domain/entities/note_document.dart';
import 'package:not_app/features/reminders/data/repositories/reminders_repository_impl.dart';
import 'package:uuid/uuid.dart';

import '../helpers/postgres_remote_gateway.dart';
import '../helpers/postgres_rls_harness.dart';

final class _MutableClock implements AppClock {
  _MutableClock(this._now);

  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}

final class _FakeNotificationService implements NotificationService {
  final Set<int> _pending = <int>{};

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refreshTimeZone() async {}

  @override
  Future<NotificationPermissionState> requestPermissions() async =>
      const NotificationPermissionState(
        notificationsAllowed: true,
        exactAlarmsAllowed: true,
      );

  @override
  Future<NotificationPermissionState> permissionState() async =>
      const NotificationPermissionState(
        notificationsAllowed: true,
        exactAlarmsAllowed: true,
      );

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<NotificationScheduleResult> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAtUtc,
    required String timeZoneId,
    String? payload,
  }) async {
    _pending.add(id);
    return const NotificationScheduleResult(
      mode: NotificationScheduleMode.exact,
    );
  }

  @override
  Future<void> cancel(int id) async {
    _pending.remove(id);
  }

  @override
  Future<Set<int>> pendingIds() async => Set<int>.from(_pending);

  @override
  String get localTimeZoneId => 'UTC';
}

final class _TestNetworkInfo implements NetworkInfo {
  _TestNetworkInfo({this.connected = true});

  bool connected;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  void notifyChanged() {
    _controller.add(connected);
  }

  @override
  Future<bool> isConnected() async => connected;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;
}

final class _TestAuthService implements AuthService {
  _TestAuthService({required String userId, required String email})
    : _state = AuthSessionState(
        isConfigured: true,
        isSignedIn: true,
        userId: userId,
        email: email,
      );

  AuthSessionState _state;
  final StreamController<AuthSessionState> _controller =
      StreamController<AuthSessionState>.broadcast();

  @override
  AuthSessionState get currentState => _state;

  @override
  Stream<AuthSessionState> watchState() async* {
    yield _state;
    yield* _controller.stream;
  }

  void setSignedIn(bool signedIn, {String? userId, String? email}) {
    _state = AuthSessionState(
      isConfigured: true,
      isSignedIn: signedIn,
      userId: signedIn ? (userId ?? _state.userId) : null,
      email: signedIn ? (email ?? _state.email) : null,
    );
    _controller.add(_state);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    setSignedIn(true, email: email);
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    setSignedIn(true, email: email);
  }

  @override
  Future<void> signInWithOAuth(OAuthProvider provider) async {
    setSignedIn(true, email: 'oauth@example.com');
  }

  @override
  Future<void> signInWithGoogle() => signInWithOAuth(OAuthProvider.google);

  @override
  Future<void> signInWithApple() => signInWithOAuth(OAuthProvider.apple);

  @override
  Future<void> signOut() async {
    setSignedIn(false);
  }
}

final class _E2EClientDevice {
  _E2EClientDevice._({
    required this.name,
    required this.database,
    required this.gateway,
    required this.queue,
    required this.localStore,
    required this.conflicts,
    required this.notes,
    required this.kanban,
    required this.reminders,
    required this.engine,
    required this.network,
    required this.auth,
    required this.coordinator,
    required this.clock,
  });

  final String name;
  final AppDatabase database;
  final PostgresRemoteGateway gateway;
  final DriftSyncQueueRepository queue;
  final LocalEntityStore localStore;
  final DriftConflictRepository conflicts;
  final DriftNotesRepository notes;
  final DriftKanbanRepository kanban;
  final DriftRemindersRepository reminders;
  final SyncEngine engine;
  final _TestNetworkInfo network;
  final _TestAuthService auth;
  final SyncCoordinator coordinator;
  final _MutableClock clock;

  static _E2EClientDevice create({
    required String name,
    required PostgresRlsHarness harness,
    required String userId,
    required String email,
    required _MutableClock clock,
  }) {
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    final PostgresRemoteGateway gateway = PostgresRemoteGateway(
      harness: harness,
      currentUserId: userId,
    );
    final DriftSyncQueueRepository queue = DriftSyncQueueRepository(
      database: database,
      clock: clock,
    );
    final LocalEntityStore localStore = LocalEntityStore(
      database: database,
      clock: clock,
    );
    final DriftConflictRepository conflicts = DriftConflictRepository(
      database: database,
      syncQueue: queue,
      localStore: localStore,
      clock: clock,
    );
    final DriftNotesRepository notes = DriftNotesRepository(
      database: database,
      syncQueue: queue,
      clock: clock,
    );
    final DriftKanbanRepository kanban = DriftKanbanRepository(
      database: database,
      syncQueue: queue,
      clock: clock,
    );
    final _FakeNotificationService notifications = _FakeNotificationService();
    final DriftRemindersRepository reminders = DriftRemindersRepository(
      database: database,
      notifications: notifications,
      syncQueue: queue,
      clock: clock,
    );
    final SyncEngine engine = SyncEngine(
      database: database,
      queue: queue,
      remote: gateway,
      localStore: localStore,
      conflicts: conflicts,
      clock: clock,
      logger: const AppLogger(enabled: false),
    );
    final _TestNetworkInfo network = _TestNetworkInfo(connected: true);
    final _TestAuthService auth = _TestAuthService(
      userId: userId,
      email: email,
    );
    final SyncCoordinator coordinator = SyncCoordinator(
      networkInfo: network,
      authService: auth,
      engine: engine,
      queue: queue,
      database: database,
      clock: clock,
      reconcileReminders: () async {},
      logger: const AppLogger(enabled: false),
    );

    return _E2EClientDevice._(
      name: name,
      database: database,
      gateway: gateway,
      queue: queue,
      localStore: localStore,
      conflicts: conflicts,
      notes: notes,
      kanban: kanban,
      reminders: reminders,
      engine: engine,
      network: network,
      auth: auth,
      coordinator: coordinator,
      clock: clock,
    );
  }

  void goOffline() {
    gateway.online = false;
    network.connected = false;
    network.notifyChanged();
  }

  void goOnline() {
    gateway.online = true;
    network.connected = true;
    network.notifyChanged();
  }

  Future<void> close() async {
    await coordinator.stop();
    await database.close();
  }
}

void main() {
  late PostgresRlsHarness harness;
  late String primaryUserId;
  late String primaryUserEmail;
  late String isolatedUserId;
  late String isolatedUserEmail;

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    harness = PostgresRlsHarness();
    await harness.setupSchema(
      migrationFilePath: 'supabase/migrations/0001_initial.sql',
    );
  });

  setUp(() async {
    final String seed1 = const Uuid().v4();
    final String seed2 = const Uuid().v4();
    primaryUserId = seed1;
    primaryUserEmail = 'user_$seed1@example.com';
    isolatedUserId = seed2;
    isolatedUserEmail = 'isolated_$seed2@example.com';

    await harness.createUser(id: primaryUserId, email: primaryUserEmail);
    await harness.createUser(id: isolatedUserId, email: isolatedUserEmail);
  });

  tearDown(() async {
    await harness.asUser(primaryUserId, (session) async {
      await session.deleteEntities();
      await session.deleteStorageObjects();
    });
    await harness.asUser(isolatedUserId, (session) async {
      await session.deleteEntities();
      await session.deleteStorageObjects();
    });
  });

  group(
    'Kabul Kriteri 1 — Cihaz A ve Cihaz B gerçek Supabase backend ile senkronizasyon',
    () {
      test(
        'Cihaz A not oluşturur, push eder; Cihaz B pull edip notu eksiksiz alır; Cihaz C (ayrık hesap) erişemez',
        () async {
          final _MutableClock clock = _MutableClock(
            DateTime.utc(2026, 8, 16, 8, 0, 0),
          );
          final _E2EClientDevice deviceA = _E2EClientDevice.create(
            name: 'Device A',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );
          final _E2EClientDevice deviceB = _E2EClientDevice.create(
            name: 'Device B',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );
          final _E2EClientDevice deviceC = _E2EClientDevice.create(
            name: 'Device C (Isolated)',
            harness: harness,
            userId: isolatedUserId,
            email: isolatedUserEmail,
            clock: clock,
          );

          addTearDown(deviceA.close);
          addTearDown(deviceB.close);
          addTearDown(deviceC.close);

          // Cihaz A not oluşturur
          final String noteId = await deviceA.notes.createNote(
            title: 'E2E Başlangıç Notu',
          );
          await deviceA.notes.saveDocument(
            noteId,
            NoteDocument(
              version: 1,
              blocks: const <NoteBlock>[
                NoteBlock(
                  id: 'b1',
                  type: NoteBlockType.paragraph,
                  text: 'Gerçek Supabase üzerinde çoklu istemci testi.',
                ),
              ],
            ),
          );

          // Cihaz A sunucuya gönderir (push - create ve document save operasyonları)
          final SyncRunResult aPush = await deviceA.engine.runOnce();
          expect(aPush.pushed, 2);
          expect(aPush.conflicts, 0);

          // Gerçek PostgreSQL backend doğrudan doğrulanır
          await harness.asUser(primaryUserId, (session) async {
            final List<Map<String, dynamic>> rows = await session
                .selectEntities(
                  whereClause: "entity_type = 'note' AND entity_id = '$noteId'",
                );
            expect(rows, hasLength(1));
            expect(rows.first['version'], 2);
            final Map<String, dynamic> payload = Map<String, dynamic>.from(
              rows.first['payload'] as Map,
            );
            expect(payload['title'], 'E2E Başlangıç Notu');
          });

          // Cihaz B senkronize edip notu alır (pull)
          final SyncRunResult bPull = await deviceB.engine.runOnce();
          expect(bPull.pulled, 1);
          expect(bPull.conflicts, 0);

          final noteOnB = await deviceB.notes.getNote(noteId);
          expect(noteOnB, isNotNull);
          expect(noteOnB!.title, 'E2E Başlangıç Notu');
          expect(
            noteOnB.document.plainText,
            'Gerçek Supabase üzerinde çoklu istemci testi.',
          );
          expect(noteOnB.version, 2);

          // Ayrık hesap (User C) senkronize ettiğinde RLS gereği notu göremez
          final SyncRunResult cPull = await deviceC.engine.runOnce();
          expect(cPull.pulled, 0);
          final noteOnC = await deviceC.notes.getNote(noteId);
          expect(noteOnC, isNull);
        },
      );

      test(
        'Kanban ve Reminder entitileri de iki cihaz arasında gerçek backend ile senkronize olur',
        () async {
          final _MutableClock clock = _MutableClock(
            DateTime.utc(2026, 8, 16, 9, 0, 0),
          );
          final _E2EClientDevice deviceA = _E2EClientDevice.create(
            name: 'Device A',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );
          final _E2EClientDevice deviceB = _E2EClientDevice.create(
            name: 'Device B',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );

          addTearDown(deviceA.close);
          addTearDown(deviceB.close);

          final String boardId = await deviceA.kanban.createBoard(
            title: 'Sınıf Projesi',
          );
          final String columnId = await deviceA.kanban.createColumn(
            boardId: boardId,
            title: 'Yapılacaklar',
          );
          final String cardId = await deviceA.kanban.createCard(
            boardId: boardId,
            columnId: columnId,
            title: 'Ödevleri Kontrol Et',
          );
          final reminder = await deviceA.reminders.create(
            parentType: 'card',
            parentId: cardId,
            title: 'Ödev Hatırlatıcı',
            body: 'Yarın teslim',
            scheduledAtUtc: DateTime.utc(2026, 8, 17, 10, 0, 0),
            timeZoneId: 'UTC',
          );

          // Cihaz A 4 entitiyi sunucuya push eder
          final SyncRunResult pushRes = await deviceA.engine.runOnce();
          expect(pushRes.pushed, 4);
          expect(pushRes.conflicts, 0);

          // Cihaz B 4 entitiyi pull eder
          final SyncRunResult pullRes = await deviceB.engine.runOnce();
          expect(pullRes.pulled, 4);
          expect(pullRes.conflicts, 0);

          final List<Board> boardsOnB = await deviceB.database
              .select(deviceB.database.boards)
              .get();
          expect(
            boardsOnB.any((b) => b.id == boardId && b.title == 'Sınıf Projesi'),
            isTrue,
          );

          final List<BoardColumn> colsOnB = await deviceB.database
              .select(deviceB.database.boardColumns)
              .get();
          expect(
            colsOnB.any((c) => c.id == columnId && c.title == 'Yapılacaklar'),
            isTrue,
          );

          final List<Card> cardsOnB = await deviceB.database
              .select(deviceB.database.cards)
              .get();
          expect(
            cardsOnB.any(
              (c) => c.id == cardId && c.title == 'Ödevleri Kontrol Et',
            ),
            isTrue,
          );

          final List<Reminder> remindersOnB = await deviceB.database
              .select(deviceB.database.reminders)
              .get();
          expect(
            remindersOnB.any(
              (r) => r.id == reminder.id && r.title == 'Ödev Hatırlatıcı',
            ),
            isTrue,
          );
        },
      );
    },
  );

  group(
    'Kabul Kriteri 2 — Çevrimdışı çakışma, RemoteApplyConflict tespiti ve veri koruma',
    () {
      test(
        'İki istemci çevrimdışıyken aynı notu günceller; Cihaz A önce push yapar; Cihaz B bağlandığında versiyon çakışması tespit edilip yerel kayıt korunur',
        () async {
          final _MutableClock clock = _MutableClock(
            DateTime.utc(2026, 8, 16, 10, 0, 0),
          );
          final _E2EClientDevice deviceA = _E2EClientDevice.create(
            name: 'Device A',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );
          final _E2EClientDevice deviceB = _E2EClientDevice.create(
            name: 'Device B',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );

          addTearDown(deviceA.close);
          addTearDown(deviceB.close);

          // Ortak not oluşturulup iki cihaza da senkronize edilir (v1)
          final String noteId = await deviceA.notes.createNote(
            title: 'Ortak Not Başlığı v1',
          );
          await deviceA.engine.runOnce();
          await deviceB.engine.runOnce();
          expect(
            (await deviceB.notes.getNote(noteId))?.title,
            'Ortak Not Başlığı v1',
          );

          // Her iki istemci çevrimdışı olur
          deviceA.goOffline();
          deviceB.goOffline();

          clock.advance(const Duration(minutes: 2));
          await deviceA.notes.updateTitle(
            noteId,
            'Cihaz A Çevrimdışı Değişikliği',
          );

          clock.advance(const Duration(minutes: 2));
          await deviceB.notes.updateTitle(
            noteId,
            'Cihaz B Çevrimdışı Değişikliği',
          );

          // Cihaz A önce bağlanıp push yapar -> versiyon 2 olur
          deviceA.goOnline();
          final SyncRunResult aPush = await deviceA.engine.runOnce();
          expect(aPush.pushed, 1);
          expect(aPush.conflicts, 0);

          // Gerçek PostgreSQL'de versiyon 2 doğrulanır
          await harness.asUser(primaryUserId, (session) async {
            final List<Map<String, dynamic>> rows = await session
                .selectEntities(
                  whereClause: "entity_type = 'note' AND entity_id = '$noteId'",
                );
            expect(rows.first['version'], 2);
            final Map<String, dynamic> payload = Map<String, dynamic>.from(
              rows.first['payload'] as Map,
            );
            expect(payload['title'], 'Cihaz A Çevrimdışı Değişikliği');
          });

          // Cihaz B bağlanıp senkronize olur -> RemoteApplyConflict tespit edilir
          deviceB.goOnline();
          final SyncRunResult bSync = await deviceB.engine.runOnce();
          expect(bSync.conflicts, 1);
          expect(bSync.pushed, 0);

          // Cihaz B yerel kaydını KORUR ve sunucudaki Cihaz A başlığıyla ezilmez
          final noteOnB = await deviceB.notes.getNote(noteId);
          expect(
            noteOnB?.title,
            'Cihaz B Çevrimdışı Değişikliği',
            reason:
                'Pull veya push çakışması çözülmemiş yerel kirli sürümü ezmemelidir.',
          );

          // Cihaz B yerel veritabanında 1 adet açık çakışma kaydı oluşur
          final List<Conflict> openConflicts = await (deviceB.database.select(
            deviceB.database.conflicts,
          )..where((tbl) => tbl.resolvedAt.isNull())).get();
          expect(openConflicts, hasLength(1));
          expect(openConflicts.first.entityId, noteId);
          expect(openConflicts.first.entityType, 'note');

          // Cihaz B senkronizasyon kuyruğunda operasyon 'blockedConflict' olarak işaretlenir
          final List<SyncQueueData> blockedItems =
              await (deviceB.database.select(deviceB.database.syncQueue)..where(
                    (tbl) =>
                        tbl.entityType.equals('note') &
                        tbl.entityId.equals(noteId) &
                        tbl.status.equals(
                          SyncOperationStatus.blockedConflict.name,
                        ),
                  ))
                  .get();
          expect(blockedItems, hasLength(1));
        },
      );
    },
  );

  group(
    'Kabul Kriteri 3 — Çakışma çözümleme ve tam durum yakınsaması (convergence)',
    () {
      test(
        '3a: Cihaz B çakışmayı yerel (local) seçimle çözer -> her iki cihaz ve sunucu v3 durumuna yakınsar',
        () async {
          final _MutableClock clock = _MutableClock(
            DateTime.utc(2026, 8, 16, 11, 0, 0),
          );
          final _E2EClientDevice deviceA = _E2EClientDevice.create(
            name: 'Device A',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );
          final _E2EClientDevice deviceB = _E2EClientDevice.create(
            name: 'Device B',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );

          addTearDown(deviceA.close);
          addTearDown(deviceB.close);

          final String noteId = await deviceA.notes.createNote(
            title: 'Convergence Test Note',
          );
          await deviceA.engine.runOnce();
          await deviceB.engine.runOnce();

          // Çakışma üretilir
          deviceA.goOffline();
          deviceB.goOffline();
          await deviceA.notes.updateTitle(
            noteId,
            'Device A Title (Overridden Later)',
          );
          await deviceB.notes.updateTitle(noteId, 'Device B Winner Title');

          deviceA.goOnline();
          await deviceA.engine.runOnce(); // Server now at v2

          deviceB.goOnline();
          final SyncRunResult conflictRun = await deviceB.engine.runOnce();
          expect(conflictRun.conflicts, 1);

          final Conflict openConflict = (await (deviceB.database.select(
            deviceB.database.conflicts,
          )..where((tbl) => tbl.resolvedAt.isNull())).get()).single;

          // Cihaz B çakışmayı yerel (local) seçimle çözer
          clock.advance(const Duration(minutes: 1));
          await deviceB.conflicts.resolveUsingLocal(openConflict.id);

          // Cihaz B'deki not sürümü v3 olmalı ve kuyruktaki blokaj kalkmalıdır
          final noteAfterRes = await deviceB.notes.getNote(noteId);
          expect(noteAfterRes?.title, 'Device B Winner Title');
          expect(noteAfterRes?.version, 3);

          final List<SyncQueueData> blockedAfterRes =
              await (deviceB.database.select(deviceB.database.syncQueue)..where(
                    (tbl) =>
                        tbl.entityType.equals('note') &
                        tbl.entityId.equals(noteId) &
                        tbl.status.equals(
                          SyncOperationStatus.blockedConflict.name,
                        ),
                  ))
                  .get();
          expect(blockedAfterRes, isEmpty);

          // Cihaz B senkronize olur -> v3 sunucuya push edilir
          final SyncRunResult bPushResolved = await deviceB.engine.runOnce();
          expect(bPushResolved.pushed, 1);
          expect(bPushResolved.conflicts, 0);

          // Cihaz A senkronize olur -> v3'ü sunucudan çeker
          final SyncRunResult aPullResolved = await deviceA.engine.runOnce();
          expect(aPullResolved.pulled, 1);

          // Durum Yakınsaması (Convergence) Doğrulaması:
          expect(
            (await deviceA.notes.getNote(noteId))?.title,
            'Device B Winner Title',
          );
          expect((await deviceA.notes.getNote(noteId))?.version, 3);
          expect(
            (await deviceB.notes.getNote(noteId))?.title,
            'Device B Winner Title',
          );
          expect((await deviceB.notes.getNote(noteId))?.version, 3);

          // Gerçek PostgreSQL'de v3 doğrulanır
          await harness.asUser(primaryUserId, (session) async {
            final List<Map<String, dynamic>> rows = await session
                .selectEntities(
                  whereClause: "entity_type = 'note' AND entity_id = '$noteId'",
                );
            expect(rows.first['version'], 3);
            final Map<String, dynamic> payload = Map<String, dynamic>.from(
              rows.first['payload'] as Map,
            );
            expect(payload['title'], 'Device B Winner Title');
          });

          // Açık çakışma ve bloklanmış kuyruk kaydı kalmadığı doğrulanır
          expect(
            await (deviceA.database.select(
              deviceA.database.conflicts,
            )..where((tbl) => tbl.resolvedAt.isNull())).get(),
            isEmpty,
          );
          expect(
            await (deviceB.database.select(
              deviceB.database.conflicts,
            )..where((tbl) => tbl.resolvedAt.isNull())).get(),
            isEmpty,
          );
          expect(
            await (deviceA.database.select(
              deviceA.database.syncQueue,
            )..where((tbl) => tbl.status.isNotIn(<String>['completed']))).get(),
            isEmpty,
          );
          expect(
            await (deviceB.database.select(
              deviceB.database.syncQueue,
            )..where((tbl) => tbl.status.isNotIn(<String>['completed']))).get(),
            isEmpty,
          );
        },
      );

      test(
        '3b: Cihaz B çakışmayı uzak (remote) seçimle çözer -> her iki cihaz Cihaz A sürümüne eşitlenir',
        () async {
          final _MutableClock clock = _MutableClock(
            DateTime.utc(2026, 8, 16, 12, 0, 0),
          );
          final _E2EClientDevice deviceA = _E2EClientDevice.create(
            name: 'Device A',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );
          final _E2EClientDevice deviceB = _E2EClientDevice.create(
            name: 'Device B',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );

          addTearDown(deviceA.close);
          addTearDown(deviceB.close);

          final String noteId = await deviceA.notes.createNote(
            title: 'Base Title',
          );
          await deviceA.engine.runOnce();
          await deviceB.engine.runOnce();

          // Çakışma oluşturulur
          deviceA.goOffline();
          deviceB.goOffline();
          await deviceA.notes.updateTitle(
            noteId,
            'Authoritative Device A Title',
          );
          await deviceB.notes.updateTitle(noteId, 'Discarded Device B Title');

          deviceA.goOnline();
          await deviceA.engine
              .runOnce(); // Server at v2 (Authoritative Device A Title)

          deviceB.goOnline();
          await deviceB.engine.runOnce(); // Conflict recorded on B

          final Conflict openConflict = (await (deviceB.database.select(
            deviceB.database.conflicts,
          )..where((tbl) => tbl.resolvedAt.isNull())).get()).single;

          // Cihaz B çakışmayı uzak (remote) seçimle çözer
          clock.advance(const Duration(minutes: 1));
          await deviceB.conflicts.resolveUsingRemote(openConflict.id);

          // Cihaz B Cihaz A'nın sürümünü benimser
          final noteOnB = await deviceB.notes.getNote(noteId);
          expect(noteOnB?.title, 'Authoritative Device A Title');
          expect(noteOnB?.version, 2);

          // Her iki cihaz senkronize edilir
          await deviceB.engine.runOnce();
          await deviceA.engine.runOnce();

          // Convergence
          expect(
            (await deviceA.notes.getNote(noteId))?.title,
            'Authoritative Device A Title',
          );
          expect(
            (await deviceB.notes.getNote(noteId))?.title,
            'Authoritative Device A Title',
          );

          expect(
            await (deviceB.database.select(
              deviceB.database.conflicts,
            )..where((tbl) => tbl.resolvedAt.isNull())).get(),
            isEmpty,
          );
          expect(
            await (deviceB.database.select(
              deviceB.database.syncQueue,
            )..where((tbl) => tbl.status.isNotIn(<String>['completed']))).get(),
            isEmpty,
          );
        },
      );

      test(
        '3c: Cihaz B çakışmayı kopya olarak sakla (resolveAsCopy) ile çözer -> her iki not da korunur ve sunucuya aktarılır',
        () async {
          final _MutableClock clock = _MutableClock(
            DateTime.utc(2026, 8, 16, 13, 0, 0),
          );
          final _E2EClientDevice deviceA = _E2EClientDevice.create(
            name: 'Device A',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );
          final _E2EClientDevice deviceB = _E2EClientDevice.create(
            name: 'Device B',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );

          addTearDown(deviceA.close);
          addTearDown(deviceB.close);

          final String noteId = await deviceA.notes.createNote(
            title: 'Orijinal Başlık',
          );
          await deviceA.engine.runOnce();
          await deviceB.engine.runOnce();

          deviceA.goOffline();
          deviceB.goOffline();
          await deviceA.notes.updateTitle(noteId, 'Cihaz A Değişikliği');
          await deviceB.notes.updateTitle(noteId, 'Cihaz B Değişikliği');

          deviceA.goOnline();
          await deviceA.engine.runOnce();

          deviceB.goOnline();
          await deviceB.engine.runOnce();

          final Conflict openConflict = (await (deviceB.database.select(
            deviceB.database.conflicts,
          )..where((tbl) => tbl.resolvedAt.isNull())).get()).single;

          // Cihaz B çakışmayı kopya olarak çözer
          await deviceB.conflicts.resolveAsCopy(openConflict.id);

          // Cihaz B'de hem orijinal not (Cihaz A sürümünde) hem de çakışma kopyası olmalıdır
          final List<Note> notesOnB = await deviceB.database
              .select(deviceB.database.notes)
              .get();
          expect(notesOnB, hasLength(2));
          expect(notesOnB.any((n) => n.title == 'Cihaz A Değişikliği'), isTrue);
          expect(
            notesOnB.any((n) => n.title.contains('Çakışma kopyası')),
            isTrue,
          );

          // Her iki cihaz senkronize olur
          await deviceB.engine.runOnce();
          await deviceA.engine.runOnce();

          final List<Note> notesOnA = await deviceA.database
              .select(deviceA.database.notes)
              .get();
          expect(notesOnA, hasLength(2));
          expect(
            notesOnA.any(
              (n) => n.id == noteId && n.title == 'Cihaz A Değişikliği',
            ),
            isTrue,
          );
          expect(notesOnA.any((n) => n.id != noteId), isTrue);
        },
      );
    },
  );

  group(
    'Kabul Kriteri 4 — Delete vs Update çakışma senaryoları (veri kaybı olmadan)',
    () {
      test(
        '4.1: Cihaz A silerken Cihaz B çevrimdışı günceller; Cihaz B çakışmayı tespit edip yerel seçimle notu kurtarır (sıfır veri kaybı)',
        () async {
          final _MutableClock clock = _MutableClock(
            DateTime.utc(2026, 8, 16, 14, 0, 0),
          );
          final _E2EClientDevice deviceA = _E2EClientDevice.create(
            name: 'Device A',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );
          final _E2EClientDevice deviceB = _E2EClientDevice.create(
            name: 'Device B',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );

          addTearDown(deviceA.close);
          addTearDown(deviceB.close);

          // Not v1 olarak iki cihaza da senkronize edilir
          final String noteId = await deviceA.notes.createNote(
            title: 'Silinecek/Güncellenecek Not',
          );
          await deviceA.engine.runOnce();
          await deviceB.engine.runOnce();

          deviceA.goOffline();
          deviceB.goOffline();

          // Cihaz A notu çöpe atar (soft delete)
          clock.advance(const Duration(minutes: 1));
          await deviceA.notes.trash(noteId);

          // Cihaz B çevrimdışıyken notun başlığını günceller
          clock.advance(const Duration(minutes: 1));
          await deviceB.notes.updateTitle(
            noteId,
            'Cihaz B Tarafından Kurtarılan Not',
          );

          // Cihaz A bağlanıp silme işlemini sunucuya iletir (v2, deleted_at dolu)
          deviceA.goOnline();
          final SyncRunResult aPush = await deviceA.engine.runOnce();
          expect(aPush.pushed, 1);

          // Gerçek PostgreSQL'de deleted_at kontrol edilir
          await harness.asUser(primaryUserId, (session) async {
            final List<Map<String, dynamic>> rows = await session
                .selectEntities(
                  whereClause: "entity_type = 'note' AND entity_id = '$noteId'",
                );
            expect(rows.first['deleted_at'], isNotNull);
            expect(rows.first['version'], 2);
          });

          // Cihaz B bağlanıp push denediğinde RemoteApplyConflict alır
          deviceB.goOnline();
          final SyncRunResult bSync = await deviceB.engine.runOnce();
          expect(bSync.conflicts, 1);

          // Cihaz B'nin güncel içeriği korunur
          final noteOnB = await deviceB.notes.getNote(noteId);
          expect(noteOnB?.title, 'Cihaz B Tarafından Kurtarılan Not');
          expect(noteOnB?.deletedAt, isNull);

          final Conflict conflict = (await (deviceB.database.select(
            deviceB.database.conflicts,
          )..where((tbl) => tbl.resolvedAt.isNull())).get()).single;

          // Cihaz B yerel sürümü seçerek notu kurtarır (resurrect)
          clock.advance(const Duration(minutes: 1));
          await deviceB.conflicts.resolveUsingLocal(conflict.id);

          // Cihaz B v3 olarak notu sunucuya push eder
          final SyncRunResult bPush = await deviceB.engine.runOnce();
          expect(bPush.pushed, 1);
          expect(bPush.conflicts, 0);

          // Cihaz A senkronize olup notu tekrar geri kazanır (resurrected)
          final SyncRunResult aPull = await deviceA.engine.runOnce();
          expect(aPull.pulled, 1);

          final noteOnA = await deviceA.notes.getNote(noteId);
          expect(noteOnA, isNotNull);
          expect(noteOnA!.title, 'Cihaz B Tarafından Kurtarılan Not');
          expect(noteOnA.deletedAt, isNull);
          expect(noteOnA.version, 3);

          // Gerçek PostgreSQL'de deleted_at temizlenmiş ve v3 olmuş olmalıdır
          await harness.asUser(primaryUserId, (session) async {
            final List<Map<String, dynamic>> rows = await session
                .selectEntities(
                  whereClause: "entity_type = 'note' AND entity_id = '$noteId'",
                );
            expect(rows.first['deleted_at'], isNull);
            expect(rows.first['version'], 3);
            final Map<String, dynamic> payload = Map<String, dynamic>.from(
              rows.first['payload'] as Map,
            );
            expect(payload['title'], 'Cihaz B Tarafından Kurtarılan Not');
          });
        },
      );

      test(
        '4.2: Cihaz A güncellerken Cihaz B çevrimdışı siler; çakışma sonrası uzak seçimle Cihaz A içeriği korunur',
        () async {
          final _MutableClock clock = _MutableClock(
            DateTime.utc(2026, 8, 16, 15, 0, 0),
          );
          final _E2EClientDevice deviceA = _E2EClientDevice.create(
            name: 'Device A',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );
          final _E2EClientDevice deviceB = _E2EClientDevice.create(
            name: 'Device B',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );

          addTearDown(deviceA.close);
          addTearDown(deviceB.close);

          final String noteId = await deviceA.notes.createNote(
            title: 'Önemli Not',
          );
          await deviceA.engine.runOnce();
          await deviceB.engine.runOnce();

          deviceA.goOffline();
          deviceB.goOffline();

          // Cihaz A önemli bir güncelleme yapar
          await deviceA.notes.updateTitle(
            noteId,
            'Kritik Önemli Not Güncellemesi',
          );

          // Cihaz B notu çöpe atar (soft delete)
          await deviceB.notes.trash(noteId);

          // Cihaz A önce push yapar -> v2
          deviceA.goOnline();
          await deviceA.engine.runOnce();

          // Cihaz B bağlanıp silme push'u denediğinde çakışma oluşur
          deviceB.goOnline();
          final SyncRunResult bSync = await deviceB.engine.runOnce();
          expect(bSync.conflicts, 1);

          final Conflict conflict = (await (deviceB.database.select(
            deviceB.database.conflicts,
          )..where((tbl) => tbl.resolvedAt.isNull())).get()).single;

          // Cihaz B uzak içeriğin (Cihaz A'nın önemli güncellemesinin) korunmasını seçer
          await deviceB.conflicts.resolveUsingRemote(conflict.id);

          await deviceB.engine.runOnce();
          await deviceA.engine.runOnce();

          expect(
            (await deviceA.notes.getNote(noteId))?.title,
            'Kritik Önemli Not Güncellemesi',
          );
          expect((await deviceA.notes.getNote(noteId))?.deletedAt, isNull);
          expect(
            (await deviceB.notes.getNote(noteId))?.title,
            'Kritik Önemli Not Güncellemesi',
          );
          expect((await deviceB.notes.getNote(noteId))?.deletedAt, isNull);
        },
      );
    },
  );

  group(
    'SyncCoordinator ve Dayanıklılık (Resilience / Idempotency) Entegrasyonu',
    () {
      test(
        'SyncCoordinator ile ağ durumu ve syncNow akışı gerçek PostgreSQL üzerinde tam döngü çalışır',
        () async {
          final _MutableClock clock = _MutableClock(
            DateTime.utc(2026, 8, 16, 16, 0, 0),
          );
          final _E2EClientDevice deviceA = _E2EClientDevice.create(
            name: 'Device A',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );
          final _E2EClientDevice deviceB = _E2EClientDevice.create(
            name: 'Device B',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );

          addTearDown(deviceA.close);
          addTearDown(deviceB.close);

          final String noteId = await deviceA.notes.createNote(
            title: 'Coordinator Note',
          );
          final SyncRunResult resA = await deviceA.coordinator.syncNow();
          expect(resA.pushed, 1);
          expect(
            deviceA.coordinator.currentHealth.lastSuccessfulSyncAt,
            isNotNull,
          );
          expect(deviceA.coordinator.currentHealth.lastError, isNull);

          await deviceB.coordinator.syncNow();
          expect(
            (await deviceB.notes.getNote(noteId))?.title,
            'Coordinator Note',
          );
          expect(
            deviceB.coordinator.currentHealth.lastSuccessfulSyncAt,
            isNotNull,
          );
          expect(deviceB.coordinator.currentHealth.lastError, isNull);
        },
      );

      test(
        'Sunucu onay kaybı sonrası retry işlemi idempotent çalışır (kayıt çoğalması veya çakışma olmadan)',
        () async {
          final _MutableClock clock = _MutableClock(
            DateTime.utc(2026, 8, 16, 17, 0, 0),
          );
          final _E2EClientDevice client = _E2EClientDevice.create(
            name: 'Retry Client',
            harness: harness,
            userId: primaryUserId,
            email: primaryUserEmail,
            clock: clock,
          );
          addTearDown(client.close);

          // Gateway commit sonrası hata simüle edecek şekilde ayarlanır
          client.gateway.failAfterNextApply = true;

          final String noteId = await client.notes.createNote(
            title: 'Idempotent Retry Note',
          );
          final SyncRunResult firstRun = await client.engine.runOnce();
          expect(firstRun.pushed, 0);

          // Kuyrukta retryWaiting kaydı olmalı
          final List<SyncQueueData> retryWaitingItems =
              await (client.database.select(client.database.syncQueue)..where(
                    (tbl) => tbl.status.equals(
                      SyncOperationStatus.retryWaiting.name,
                    ),
                  ))
                  .get();
          expect(retryWaitingItems, hasLength(1));

          // Zaman ilerler ve retry çalışır
          clock.advance(const Duration(hours: 1));
          final SyncRunResult retryRun = await client.engine.runOnce();
          expect(retryRun.pushed, 1);
          expect(retryRun.conflicts, 0);

          // Kuyrukta kalan bekleyen işlem ve açık çakışma olmamalı
          expect(
            await (client.database.select(
              client.database.syncQueue,
            )..where((tbl) => tbl.status.isNotIn(<String>['completed']))).get(),
            isEmpty,
          );
          expect(
            await (client.database.select(
              client.database.conflicts,
            )..where((tbl) => tbl.resolvedAt.isNull())).get(),
            isEmpty,
          );

          // Gerçek PostgreSQL'de tam 1 adet kayıt olmalı
          await harness.asUser(primaryUserId, (session) async {
            final List<Map<String, dynamic>> rows = await session
                .selectEntities(
                  whereClause: "entity_type = 'note' AND entity_id = '$noteId'",
                );
            expect(rows, hasLength(1));
            expect(rows.first['version'], 1);
          });
        },
      );
    },
  );
}
