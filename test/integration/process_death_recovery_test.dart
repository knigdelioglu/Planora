import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/auth/auth_service.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/logging/app_logger.dart';
import 'package:not_app/core/network/network_info.dart';
import 'package:not_app/core/remote/remote_gateway.dart';
import 'package:not_app/core/remote/remote_models.dart';
import 'package:not_app/core/services/file_storage_service.dart';
import 'package:not_app/core/services/notification_service.dart';
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
import 'package:not_app/features/notes/domain/entities/note_document.dart';
import 'package:not_app/features/reminders/data/repositories/reminders_repository_impl.dart';
import 'package:not_app/features/search/data/repositories/search_repository_impl.dart';
import 'package:path/path.dart' as p;

class _MutableClock implements AppClock {
  _MutableClock([DateTime? initial])
    : current = initial ?? DateTime.utc(2026, 8, 16, 12);

  DateTime current;

  @override
  DateTime nowUtc() => current.toUtc();

  void advance(Duration duration) {
    current = current.add(duration);
  }
}

class _TestNetworkInfo implements NetworkInfo {
  bool online = true;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isConnected() async => online;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void setOnline(bool value) {
    online = value;
    _controller.add(value);
  }

  void dispose() {
    _controller.close();
  }
}

class _TestAuthService implements AuthService {
  _TestAuthService({String? userId})
    : _state = AuthSessionState(
        isConfigured: true,
        isSignedIn: true,
        userId: userId ?? 'user-test-123',
        email: 'test@example.com',
      );

  AuthSessionState _state;
  final StreamController<AuthSessionState> _controller =
      StreamController<AuthSessionState>.broadcast();

  @override
  AuthSessionState get currentState => _state;

  @override
  Stream<AuthSessionState> watchState() => _controller.stream;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signInWithOAuth(OAuthProvider provider) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInWithApple() async {}

  @override
  Future<void> signOut() async {
    _state = const AuthSessionState(isConfigured: true, isSignedIn: false);
    _controller.add(_state);
  }

  void setSignedIn(String userId) {
    _state = AuthSessionState(
      isConfigured: true,
      isSignedIn: true,
      userId: userId,
      email: '$userId@example.com',
    );
    _controller.add(_state);
  }

  void dispose() {
    _controller.close();
  }
}

class _RecordingNotificationService implements NotificationService {
  bool initialized = false;
  bool allowExact = true;
  final Map<int, ScheduledNotificationRecord> scheduled =
      <int, ScheduledNotificationRecord>{};
  final List<int> cancelledIds = <int>[];

  @override
  String get localTimeZoneId => 'UTC';

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<void> refreshTimeZone() async {}

  @override
  Future<NotificationPermissionState> requestPermissions() async {
    return NotificationPermissionState(
      notificationsAllowed: true,
      exactAlarmsAllowed: allowExact,
    );
  }

  @override
  Future<NotificationPermissionState> permissionState() async {
    return NotificationPermissionState(
      notificationsAllowed: true,
      exactAlarmsAllowed: allowExact,
    );
  }

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
    scheduled[id] = ScheduledNotificationRecord(
      id: id,
      title: title,
      body: body,
      scheduledAtUtc: scheduledAtUtc,
      payload: payload,
      isExact: allowExact,
    );
    return NotificationScheduleResult(
      mode: allowExact
          ? NotificationScheduleMode.exact
          : NotificationScheduleMode.inexact,
    );
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
    cancelledIds.add(id);
  }

  @override
  Future<Set<int>> pendingIds() async => scheduled.keys.toSet();
}

class ScheduledNotificationRecord {
  const ScheduledNotificationRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAtUtc,
    required this.isExact,
    this.payload,
  });

  final int id;
  final String title;
  final String body;
  final DateTime scheduledAtUtc;
  final bool isExact;
  final String? payload;
}

class _RecordingRemoteGateway implements RemoteGateway {
  _RecordingRemoteGateway({required this.userId});

  @override
  final String? userId;

  @override
  bool get available => userId != null;

  final Map<String, RemoteEntity> remoteStore = <String, RemoteEntity>{};
  final Map<String, List<int>> uploadedBlobs = <String, List<int>>{};
  int currentRevision = 1;
  final List<String> appliedOperations = <String>[];

  @override
  Future<RemoteApplyResult> apply({
    required String entityType,
    required String entityId,
    required int? baseVersion,
    required int version,
    required DateTime updatedAt,
    required DateTime? deletedAt,
    required Map<String, Object?> payload,
  }) async {
    final String key = '$entityType:$entityId';
    appliedOperations.add(key);
    final RemoteEntity? existing = remoteStore[key];
    if (existing != null &&
        baseVersion != null &&
        existing.version != baseVersion) {
      return RemoteApplyConflict(existing);
    }
    final int rev = currentRevision++;
    final RemoteEntity entity = RemoteEntity(
      entityType: entityType,
      entityId: entityId,
      version: version,
      syncRevision: rev,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      payload: Map<String, Object?>.unmodifiable(payload),
    );
    remoteStore[key] = entity;
    return RemoteApplySuccess(rev);
  }

  @override
  Future<List<RemoteEntity>> pull({
    required int afterRevision,
    int limit = 250,
  }) async {
    return remoteStore.values
        .where((e) => e.syncRevision > afterRevision)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<void> uploadAttachment({
    required String remotePath,
    required File file,
  }) async {
    final List<int> bytes = await file.readAsBytes();
    uploadedBlobs[remotePath] = bytes;
  }

  @override
  Future<String> createAttachmentDownloadUrl(String remotePath) async {
    return 'https://example.supabase.co/storage/v1/object/public/attachments/$remotePath';
  }

  @override
  Future<void> deleteAttachment(String remotePath) async {
    uploadedBlobs.remove(remotePath);
  }
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late Directory tempTestDir;
  late File dbFile;
  late _MutableClock clock;
  late _TestNetworkInfo network;
  late _TestAuthService auth;
  late _RecordingRemoteGateway remote;
  late _RecordingNotificationService notifications;
  late SandboxFileStorageService fileStorage;

  setUp(() async {
    tempTestDir = await Directory.systemTemp.createTemp('not_death_test_');
    dbFile = File(p.join(tempTestDir.path, 'test_app.db'));
    clock = _MutableClock();
    network = _TestNetworkInfo();
    auth = _TestAuthService(userId: 'user_death_test');
    remote = _RecordingRemoteGateway(userId: 'user_death_test');
    notifications = _RecordingNotificationService();
    fileStorage = SandboxFileStorageService(
      rootDirectoryProvider: () async => tempTestDir,
      tempDirectoryProvider: () async => tempTestDir,
    );
    await notifications.initialize();
  });

  tearDown(() async {
    network.dispose();
    auth.dispose();
    try {
      if (await tempTestDir.exists()) {
        await tempTestDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  AppDatabase openDb() {
    return AppDatabase(NativeDatabase(dbFile));
  }

  group(
    'AC1 & AC2: Veritabanı Crash & Restart Dayanıklılığı (Zero Corruption & Deadlock Prevention)',
    () {
      test(
        'Uncommitted transaction rolls back cleanly on hard restart without corrupting database',
        () async {
          // 1. Open DB, perform committed note
          final db1 = openDb();
          final queue1 = DriftSyncQueueRepository(database: db1, clock: clock);
          final notes1 = DriftNotesRepository(
            database: db1,
            syncQueue: queue1,
            clock: clock,
          );

          final committedNoteId = await notes1.createNote(title: 'Kalıcı Not');
          await notes1.saveDocument(
            committedNoteId,
            NoteDocument(
              version: 1,
              blocks: const <NoteBlock>[
                NoteBlock(
                  id: 'b1',
                  type: NoteBlockType.paragraph,
                  text: 'Kalıcı veri',
                ),
              ],
            ),
          );

          // 2. Start a transaction that fails / crashes before commit
          try {
            await db1.transaction(() async {
              await db1
                  .into(db1.notes)
                  .insert(
                    NotesCompanion.insert(
                      id: 'uncommitted-note-id',
                      title: const Value<String>('Taslak Kaybolacak'),
                      contentJson: const Value<String>('{}'),
                      createdAt: clock.nowUtc(),
                      updatedAt: clock.nowUtc(),
                    ),
                  );
              // Simulate crash by throwing an exception before transaction completes
              throw StateError('Simulated crash / process termination');
            });
          } catch (_) {}

          // Abruptly close database connection
          await db1.close();

          // 3. Reopen DB from the same on-disk SQLite file (simulating process restart)
          final db2 = openDb();
          addTearDown(db2.close);

          // Verify PRAGMA integrity_check is 'ok'
          final integrity = await db2.integrityCheck();
          expect(integrity, equals(<String>['ok']));

          final quick = await db2.quickCheck();
          expect(quick, equals(<String>['ok']));

          // Verify committed note exists with full content
          final restoredNote = await (db2.select(
            db2.notes,
          )..where((tbl) => tbl.id.equals(committedNoteId))).getSingle();
          expect(restoredNote.title, equals('Kalıcı Not'));

          // Verify uncommitted note does not exist
          final uncommitted =
              await (db2.select(db2.notes)
                    ..where((tbl) => tbl.id.equals('uncommitted-note-id')))
                  .getSingleOrNull();
          expect(uncommitted, isNull);
        },
      );

      test(
        'Committed hierarchical Kanban and search index persist across process restarts with WAL replay',
        () async {
          final db1 = openDb();
          final queue1 = DriftSyncQueueRepository(database: db1, clock: clock);
          final kanban1 = DriftKanbanRepository(
            database: db1,
            syncQueue: queue1,
            clock: clock,
          );
          final search1 = DriftSearchRepository(db1);

          final boardId = await kanban1.createBoard(title: 'Proje Panosu');
          final col1 = await kanban1.createColumn(
            boardId: boardId,
            title: 'Yapılacak',
          );
          await kanban1.createColumn(boardId: boardId, title: 'Bitti');
          final card1 = await kanban1.createCard(
            boardId: boardId,
            columnId: col1,
            title: 'Kritik Görev 1',
          );
          await kanban1.createCard(
            boardId: boardId,
            columnId: col1,
            title: 'Kritik Görev 2',
          );

          // Rebuild search FTS index
          await search1.rebuildIndex();

          // Checkpoint and close
          await db1.checkpoint(truncate: false);
          await db1.close();

          // Reopen in fresh process instance
          final db2 = openDb();
          addTearDown(db2.close);

          expect(await db2.integrityCheck(), equals(<String>['ok']));

          final boards = await db2.select(db2.boards).get();
          expect(boards, hasLength(1));
          expect(boards.first.id, equals(boardId));

          final columns = await (db2.select(
            db2.boardColumns,
          )..where((tbl) => tbl.boardId.equals(boardId))).get();
          expect(columns, hasLength(2));

          final cards = await (db2.select(
            db2.cards,
          )..where((tbl) => tbl.boardId.equals(boardId))).get();
          expect(cards, hasLength(2));

          final search2 = DriftSearchRepository(db2);
          final searchResults = await search2.search('Kritik');
          expect(searchResults, isNotEmpty);
          expect(searchResults.first.entityId, equals(card1));
        },
      );

      test(
        'High-frequency reopenings and concurrent reads avoid deadlocks via busy_timeout',
        () async {
          // Create initial DB
          final dbInitial = openDb();
          final qInitial = DriftSyncQueueRepository(
            database: dbInitial,
            clock: clock,
          );
          final notesInitial = DriftNotesRepository(
            database: dbInitial,
            syncQueue: qInitial,
            clock: clock,
          );
          for (int i = 0; i < 10; i++) {
            await notesInitial.createNote(title: 'Note $i');
          }
          await dbInitial.close();

          // Open multiple instances and perform rapid concurrent queries
          final List<Future<void>> concurrentOperations = <Future<void>>[];
          for (int cycle = 0; cycle < 5; cycle++) {
            concurrentOperations.add(() async {
              final db = openDb();
              try {
                final count = (await db.select(db.notes).get()).length;
                expect(count, equals(10));
                final integrity = await db.integrityCheck();
                expect(integrity, equals(<String>['ok']));
              } finally {
                await db.close();
              }
            }());
          }

          await Future.wait(concurrentOperations);

          // Verify DB is healthy
          final finalDb = openDb();
          addTearDown(finalDb.close);
          expect(await finalDb.integrityCheck(), equals(<String>['ok']));
        },
      );
    },
  );

  group(
    'AC1 & AC2: Sync Kuyruğu ve In-Flight Operasyonların Yeniden Başlatmada Güvenle Devam Etmesi',
    () {
      test(
        'In-flight (processing) queue items resume and push cleanly after simulated app kill',
        () async {
          // 1. Initial process: user creates notes, sync queue gets operations
          final db1 = openDb();
          final queue1 = DriftSyncQueueRepository(database: db1, clock: clock);
          final notes1 = DriftNotesRepository(
            database: db1,
            syncQueue: queue1,
            clock: clock,
          );

          final note1 = await notes1.createNote(title: 'Sync Restart Testi');
          final note2 = await notes1.createNote(title: 'İkinci Not');

          // Simulate that operation 1 was marked 'processing' right when the process died
          final dueOps = await queue1.dueOperations();
          expect(dueOps, hasLength(2));
          await queue1.markProcessing(dueOps.first.id);

          // Verify status in DB before kill
          final rawQueue1 = await db1.select(db1.syncQueue).get();
          expect(rawQueue1.first.status, equals('processing'));

          // Simulate sudden process death
          await db1.close();

          // 2. Restarted process: open DB, initialize sync stack
          final db2 = openDb();
          addTearDown(db2.close);
          final queue2 = DriftSyncQueueRepository(database: db2, clock: clock);
          final localStore2 = LocalEntityStore(database: db2, clock: clock);
          final conflicts2 = DriftConflictRepository(
            database: db2,
            syncQueue: queue2,
            localStore: localStore2,
            clock: clock,
          );
          final engine2 = SyncEngine(
            database: db2,
            queue: queue2,
            remote: remote,
            localStore: localStore2,
            conflicts: conflicts2,
            clock: clock,
            logger: const AppLogger(),
          );
          final coordinator2 = SyncCoordinator(
            networkInfo: network,
            authService: auth,
            engine: engine2,
            queue: queue2,
            database: db2,
            clock: clock,
            reconcileReminders: () async {},
            logger: const AppLogger(),
          );

          // Verify queue still considers the interrupted 'processing' operation as due
          final resumedDueOps = await queue2.dueOperations();
          expect(resumedDueOps, hasLength(2));
          expect(
            resumedDueOps.map((op) => op.entityId),
            containsAll(<String>[note1, note2]),
          );

          // Start sync coordinator on restart
          await coordinator2.start();
          final syncResult = await coordinator2.syncNow();
          expect(syncResult.pushed, equals(2));
          expect(syncResult.conflicts, equals(0));

          // Verify remote received both entities
          expect(
            remote.appliedOperations,
            containsAll(<String>['note:$note1', 'note:$note2']),
          );
          expect(remote.remoteStore['note:$note1'], isNotNull);
          expect(remote.remoteStore['note:$note2'], isNotNull);

          // Verify all queue items are now completed
          final remainingDue = await queue2.dueOperations();
          expect(remainingDue, isEmpty);

          final queueCounts = await queue2.statusCounts();
          expect(queueCounts[SyncOperationStatus.completed], equals(2));
          expect(queueCounts[SyncOperationStatus.pending], equals(0));
          expect(queueCounts[SyncOperationStatus.processing], equals(0));

          await coordinator2.stop();
        },
      );

      test(
        'Interrupted remote cursor in sync_meta is preserved and resumes pull from exact revision',
        () async {
          final db1 = openDb();
          final queue1 = DriftSyncQueueRepository(database: db1, clock: clock);
          final localStore1 = LocalEntityStore(database: db1, clock: clock);
          final conflicts1 = DriftConflictRepository(
            database: db1,
            syncQueue: queue1,
            localStore: localStore1,
            clock: clock,
          );
          final engine1 = SyncEngine(
            database: db1,
            queue: queue1,
            remote: remote,
            localStore: localStore1,
            conflicts: conflicts1,
            clock: clock,
            logger: const AppLogger(),
          );

          // Populate remote with 3 items (revisions 1, 2, 3)
          await remote.apply(
            entityType: 'note',
            entityId: 'remote-note-1',
            baseVersion: null,
            version: 1,
            updatedAt: clock.nowUtc(),
            deletedAt: null,
            payload: <String, Object?>{
              'id': 'remote-note-1',
              'title': 'Uzak Not 1',
              'document': <String, Object?>{
                'version': 1,
                'blocks': <Object?>[],
              },
              'version': 1,
            },
          );
          await remote.apply(
            entityType: 'note',
            entityId: 'remote-note-2',
            baseVersion: null,
            version: 1,
            updatedAt: clock.nowUtc(),
            deletedAt: null,
            payload: <String, Object?>{
              'id': 'remote-note-2',
              'title': 'Uzak Not 2',
              'document': <String, Object?>{
                'version': 1,
                'blocks': <Object?>[],
              },
              'version': 1,
            },
          );

          // Run pull once
          final result1 = await engine1.runOnce();
          expect(result1.pulled, equals(2));

          // Verify cursor is recorded in sync_meta table
          final cursorRow1 = await (db1.select(
            db1.syncMeta,
          )..where((tbl) => tbl.key.equals('remote_cursor'))).getSingle();
          final cursorValue = int.parse(cursorRow1.value);
          expect(cursorValue, isPositive);

          // Close DB abruptly
          await db1.close();

          // Add item 3 on remote (revision 3)
          await remote.apply(
            entityType: 'note',
            entityId: 'remote-note-3',
            baseVersion: null,
            version: 1,
            updatedAt: clock.nowUtc(),
            deletedAt: null,
            payload: <String, Object?>{
              'id': 'remote-note-3',
              'title': 'Uzak Not 3',
              'document': <String, Object?>{
                'version': 1,
                'blocks': <Object?>[],
              },
              'version': 1,
            },
          );

          // Reopen DB
          final db2 = openDb();
          addTearDown(db2.close);
          final queue2 = DriftSyncQueueRepository(database: db2, clock: clock);
          final localStore2 = LocalEntityStore(database: db2, clock: clock);
          final conflicts2 = DriftConflictRepository(
            database: db2,
            syncQueue: queue2,
            localStore: localStore2,
            clock: clock,
          );
          final engine2 = SyncEngine(
            database: db2,
            queue: queue2,
            remote: remote,
            localStore: localStore2,
            conflicts: conflicts2,
            clock: clock,
            logger: const AppLogger(),
          );

          // Pull on restarted engine should only pull the new item (revision 3)
          final result2 = await engine2.runOnce();
          expect(result2.pulled, equals(1));

          final allLocalNotes = await db2.select(db2.notes).get();
          expect(allLocalNotes, hasLength(3));
          expect(
            allLocalNotes.map((n) => n.id),
            containsAll(<String>[
              'remote-note-1',
              'remote-note-2',
              'remote-note-3',
            ]),
          );
        },
      );

      test(
        'Blocked conflict state survives process death and remains resolvable post-restart',
        () async {
          final db1 = openDb();
          final queue1 = DriftSyncQueueRepository(database: db1, clock: clock);
          final localStore1 = LocalEntityStore(database: db1, clock: clock);
          final conflicts1 = DriftConflictRepository(
            database: db1,
            syncQueue: queue1,
            localStore: localStore1,
            clock: clock,
          );
          final notes1 = DriftNotesRepository(
            database: db1,
            syncQueue: queue1,
            clock: clock,
          );

          final noteId = await notes1.createNote(title: 'Çakışma Notu');
          final conflictId = await conflicts1.record(
            entityType: 'note',
            entityId: noteId,
            local: <String, Object?>{'title': 'Yerel Sürüm', 'version': 2},
            remote: RemoteEntity(
              entityType: 'note',
              entityId: noteId,
              version: 3,
              syncRevision: 5,
              updatedAt: clock.nowUtc(),
              payload: <String, Object?>{'title': 'Uzak Sürüm', 'version': 3},
            ),
          );
          await queue1.markConflict(
            (await queue1.dueOperations()).first.id,
            error: 'Remote version mismatch',
          );

          // Verify conflict exists
          final openBefore = await conflicts1.watchOpen().first;
          expect(openBefore, hasLength(1));
          await db1.close();

          // Reopen on restart
          final db2 = openDb();
          addTearDown(db2.close);
          final queue2 = DriftSyncQueueRepository(database: db2, clock: clock);
          final localStore2 = LocalEntityStore(database: db2, clock: clock);
          final conflicts2 = DriftConflictRepository(
            database: db2,
            syncQueue: queue2,
            localStore: localStore2,
            clock: clock,
          );

          final openAfter = await conflicts2.watchOpen().first;
          expect(openAfter, hasLength(1));
          expect(openAfter.first.entityId, equals(noteId));

          // Resolve conflict after restart using local version
          await conflicts2.resolveUsingLocal(conflictId);
          final openResolved = await conflicts2.watchOpen().first;
          expect(openResolved, isEmpty);
        },
      );
    },
  );

  group(
    'AC1 & AC2: Yarım Kalan Attachment Transferleri ve Orphan/Temp Reconciliation',
    () {
      test(
        'Interrupted attachment download leaves .tmp file -> restart reconciliation cleans temp and updates DB',
        () async {
          final db1 = openDb();

          // Create an attachment row in 'downloading' state
          const attachmentId = 'att-interrupted-download';
          await db1
              .into(db1.attachments)
              .insert(
                AttachmentsCompanion.insert(
                  id: attachmentId,
                  parentType: 'note',
                  parentId: 'note-1',
                  fileName: 'document.pdf',
                  localPath: '',
                  mimeType: const Value<String?>('application/pdf'),
                  sizeBytes: 1024,
                  isCache: const Value<bool>(false),
                  transferState: const Value<String>('downloading'),
                  remotePath: const Value<String?>(
                    'user_death_test/att-interrupted-download/document.pdf',
                  ),
                  createdAt: clock.nowUtc(),
                  updatedAt: clock.nowUtc(),
                ),
              );

          // Create leftover .tmp file in downloads temp directory
          final tempDownloadsDir = Directory(
            p.join(tempTestDir.path, 'not_attachment_downloads', attachmentId),
          );
          await tempDownloadsDir.create(recursive: true);
          final tmpFile = File(
            p.join(tempDownloadsDir.path, 'partial_download.tmp'),
          );
          await tmpFile.writeAsString('partial-binary-data');
          expect(await tmpFile.exists(), isTrue);

          // Process dies
          await db1.close();

          // Restart: open DB and run reconcile
          final db2 = openDb();
          addTearDown(db2.close);
          final queue2 = DriftSyncQueueRepository(database: db2, clock: clock);
          final attachmentsRepo2 = DriftAttachmentsRepository(
            database: db2,
            storage: fileStorage,
            syncQueue: queue2,
            clock: clock,
            remote: remote,
            tempDirectoryProvider: () async => tempTestDir,
          );

          final reconResult = await attachmentsRepo2.reconcile();
          expect(reconResult.tempFilesCleaned, isPositive);

          // Verify temp file was cleaned up
          expect(await tmpFile.exists(), isFalse);

          // Verify DB record is in clean remoteOnly state
          final attRow = await (db2.select(
            db2.attachments,
          )..where((tbl) => tbl.id.equals(attachmentId))).getSingle();
          expect(attRow.transferState, equals('remoteOnly'));
          expect(attRow.localPath, isEmpty);
        },
      );

      test(
        'Interrupted attachment upload with local file preserved resumes upload upon restart',
        () async {
          final db1 = openDb();
          final queue1 = DriftSyncQueueRepository(database: db1, clock: clock);
          final attachmentsRepo1 = DriftAttachmentsRepository(
            database: db1,
            storage: fileStorage,
            syncQueue: queue1,
            clock: clock,
            remote: remote,
            tempDirectoryProvider: () async => tempTestDir,
          );

          // Create source file and add to repository
          final sourceFile = File(p.join(tempTestDir.path, 'source_photo.jpg'));
          await sourceFile.writeAsBytes(
            List<int>.generate(256, (i) => i % 256),
          );

          final added = await attachmentsRepo1.addFromFile(
            parentType: 'note',
            parentId: 'note-upload-test',
            source: sourceFile,
          );

          // Verify upload operation is in queue
          final dueOps1 = await queue1.dueOperations();
          expect(
            dueOps1.any(
              (op) => op.operationType == SyncOperationType.uploadAttachment,
            ),
            isTrue,
          );

          // Simulate upload started (processing) then crash
          final uploadOp = dueOps1.firstWhere(
            (op) => op.operationType == SyncOperationType.uploadAttachment,
          );
          await queue1.markProcessing(uploadOp.id);

          await db1.close();

          // Restart process
          final db2 = openDb();
          addTearDown(db2.close);
          final queue2 = DriftSyncQueueRepository(database: db2, clock: clock);
          final localStore2 = LocalEntityStore(database: db2, clock: clock);
          final conflicts2 = DriftConflictRepository(
            database: db2,
            syncQueue: queue2,
            localStore: localStore2,
            clock: clock,
          );
          final attachmentsRepo2 = DriftAttachmentsRepository(
            database: db2,
            storage: fileStorage,
            syncQueue: queue2,
            clock: clock,
            remote: remote,
            tempDirectoryProvider: () async => tempTestDir,
          );
          final engine2 = SyncEngine(
            database: db2,
            queue: queue2,
            remote: remote,
            localStore: localStore2,
            conflicts: conflicts2,
            clock: clock,
            logger: const AppLogger(),
          );

          // Run reconcile first
          await attachmentsRepo2.reconcile();

          // Local file in sandbox must NOT be deleted
          final localRow = await (db2.select(
            db2.attachments,
          )..where((tbl) => tbl.id.equals(added.id))).getSingle();
          expect(localRow.localPath, isNotEmpty);
          expect(await File(localRow.localPath).exists(), isTrue);

          // Run sync engine to complete upload
          final syncResult = await engine2.runOnce();
          expect(syncResult.pushed, isPositive);

          // Verify remote received the blob
          expect(remote.uploadedBlobs, isNotEmpty);
          expect(remote.uploadedBlobs.keys.first, contains(added.id));

          // Verify attachment row is now 'synced' with remotePath set
          final syncedRow = await (db2.select(
            db2.attachments,
          )..where((tbl) => tbl.id.equals(added.id))).getSingle();
          expect(syncedRow.transferState, equals('synced'));
          expect(syncedRow.remotePath, isNotNull);
        },
      );
    },
  );

  group(
    'AC1 & AC2: Hatırlatıcıların Yaşam Döngüsü ve Yeniden Başlatma Senkronizasyonu (Reconciliation)',
    () {
      test(
        'Active future reminders are re-scheduled with OS on reboot, while past/deleted are cancelled',
        () async {
          final db1 = openDb();
          final queue1 = DriftSyncQueueRepository(database: db1, clock: clock);
          final remindersRepo1 = DriftRemindersRepository(
            database: db1,
            notifications: notifications,
            syncQueue: queue1,
            clock: clock,
          );

          final futureDate = clock.nowUtc().add(const Duration(hours: 3));
          final soonDate = clock.nowUtc().add(const Duration(hours: 1));

          // 1. Active future reminder
          final remFuture = await remindersRepo1.create(
            parentType: 'note',
            parentId: 'note-1',
            title: 'Gelecek Hatırlatıcı',
            body: '3 saat sonra',
            scheduledAtUtc: futureDate,
            timeZoneId: 'UTC',
          );

          // 2. Soon reminder (which will become past after clock advance)
          final remSoon = await remindersRepo1.create(
            parentType: 'note',
            parentId: 'note-2',
            title: 'Geçmişe Düşecek',
            body: '1 saat sonra',
            scheduledAtUtc: soonDate,
            timeZoneId: 'UTC',
          );

          // 3. Deleted reminder
          final remDeleted = await remindersRepo1.create(
            parentType: 'note',
            parentId: 'note-3',
            title: 'Silinecek',
            scheduledAtUtc: futureDate.add(const Duration(days: 1)),
            timeZoneId: 'UTC',
          );
          await remindersRepo1.remove(remDeleted.id);

          expect(
            notifications.scheduled.containsKey(remFuture.notificationId),
            isTrue,
          );

          // Advance clock past remSoon (simulating passage of time across shutdown)
          clock.advance(const Duration(hours: 2));

          // Simulate device reboot: OS alarm scheduler loses all scheduled alarms in RAM
          notifications.scheduled.clear();
          expect(notifications.scheduled, isEmpty);
          await db1.close();

          // Restart process
          final db2 = openDb();
          addTearDown(db2.close);
          final queue2 = DriftSyncQueueRepository(database: db2, clock: clock);
          final remindersRepo2 = DriftRemindersRepository(
            database: db2,
            notifications: notifications,
            syncQueue: queue2,
            clock: clock,
          );

          // Run reconciliation on startup
          await remindersRepo2.reconcile();

          // Verify only future active reminder was scheduled with OS
          expect(
            notifications.scheduled.containsKey(remFuture.notificationId),
            isTrue,
          );
          expect(
            notifications.scheduled.containsKey(remSoon.notificationId),
            isFalse,
          );
          expect(
            notifications.scheduled.containsKey(remDeleted.notificationId),
            isFalse,
          );

          final row = await (db2.select(
            db2.reminders,
          )..where((tbl) => tbl.id.equals(remFuture.id))).getSingle();
          expect(row.schedulingStatus, equals('scheduled'));
          expect(row.lastReconciledAt, isNotNull);
        },
      );

      test(
        'Exact alarm denied on restart gracefully falls back to inexact without losing schedule',
        () async {
          final db1 = openDb();
          final queue1 = DriftSyncQueueRepository(database: db1, clock: clock);
          final remindersRepo1 = DriftRemindersRepository(
            database: db1,
            notifications: notifications,
            syncQueue: queue1,
            clock: clock,
          );

          final rem = await remindersRepo1.create(
            parentType: 'note',
            parentId: 'note-fallback-test',
            title: 'İzin Reddi Hatırlatıcısı',
            scheduledAtUtc: clock.nowUtc().add(const Duration(hours: 5)),
            timeZoneId: 'UTC',
          );

          // Simulate OS reboot and user revoking SCHEDULE_EXACT_ALARM permission in Android Settings
          notifications.scheduled.clear();
          notifications.allowExact = false;
          await db1.close();

          final db2 = openDb();
          addTearDown(db2.close);
          final queue2 = DriftSyncQueueRepository(database: db2, clock: clock);
          final remindersRepo2 = DriftRemindersRepository(
            database: db2,
            notifications: notifications,
            syncQueue: queue2,
            clock: clock,
          );

          await remindersRepo2.reconcile();

          // Scheduled as inexact fallback
          final scheduledRec = notifications.scheduled[rem.notificationId];
          expect(scheduledRec, isNotNull);
          expect(scheduledRec!.isExact, isFalse);

          final row = await (db2.select(
            db2.reminders,
          )..where((tbl) => tbl.id.equals(rem.id))).getSingle();
          expect(row.schedulingStatus, equals('inexact'));
        },
      );
    },
  );

  group(
    'AC1 & AC2: Bütünleşik Çoklu Crash-Restart Yaşam Döngüsü (End-to-End Cycle)',
    () {
      test(
        'Continuous multi-restart cycle: create -> crash -> reopen -> mutate -> crash -> sync successfully',
        () async {
          late String testNoteId;
          late String testBoardId;

          // Cycle 1: Create note & board, then abruptly kill
          {
            final db = openDb();
            final queue = DriftSyncQueueRepository(database: db, clock: clock);
            final notes = DriftNotesRepository(
              database: db,
              syncQueue: queue,
              clock: clock,
            );
            final kanban = DriftKanbanRepository(
              database: db,
              syncQueue: queue,
              clock: clock,
            );

            testNoteId = await notes.createNote(title: 'Döngü Notu');
            testBoardId = await kanban.createBoard(title: 'Döngü Panosu');

            expect(await db.integrityCheck(), equals(<String>['ok']));
            await db.close(); // Simulating crash 1
          }

          // Cycle 2: Reopen, update note, add card, then abruptly kill
          {
            final db = openDb();
            final queue = DriftSyncQueueRepository(database: db, clock: clock);
            final notes = DriftNotesRepository(
              database: db,
              syncQueue: queue,
              clock: clock,
            );
            final kanban = DriftKanbanRepository(
              database: db,
              syncQueue: queue,
              clock: clock,
            );

            expect(await db.integrityCheck(), equals(<String>['ok']));

            await notes.saveDocument(
              testNoteId,
              NoteDocument(
                version: 1,
                blocks: const <NoteBlock>[
                  NoteBlock(
                    id: 'c1',
                    type: NoteBlockType.paragraph,
                    text: 'İkinci döngüde yazıldı',
                  ),
                ],
              ),
            );

            final col = await kanban.createColumn(
              boardId: testBoardId,
              title: 'Süreçte',
            );
            await kanban.createCard(
              boardId: testBoardId,
              columnId: col,
              title: 'Görev 2. Döngü',
            );

            await db.close(); // Simulating crash 2
          }

          // Cycle 3: Reopen, bootstrap full stack with SyncCoordinator, perform syncNow
          {
            final db = openDb();
            addTearDown(db.close);

            expect(await db.integrityCheck(), equals(<String>['ok']));

            final queue = DriftSyncQueueRepository(database: db, clock: clock);
            final localStore = LocalEntityStore(database: db, clock: clock);
            final conflicts = DriftConflictRepository(
              database: db,
              syncQueue: queue,
              localStore: localStore,
              clock: clock,
            );
            final notes = DriftNotesRepository(
              database: db,
              syncQueue: queue,
              clock: clock,
            );
            final kanban = DriftKanbanRepository(
              database: db,
              syncQueue: queue,
              clock: clock,
            );
            final reminders = DriftRemindersRepository(
              database: db,
              notifications: notifications,
              syncQueue: queue,
              clock: clock,
            );
            final attachments = DriftAttachmentsRepository(
              database: db,
              storage: fileStorage,
              syncQueue: queue,
              clock: clock,
              remote: remote,
              tempDirectoryProvider: () async => tempTestDir,
            );
            final engine = SyncEngine(
              database: db,
              queue: queue,
              remote: remote,
              localStore: localStore,
              conflicts: conflicts,
              clock: clock,
              logger: const AppLogger(),
            );
            final coordinator = SyncCoordinator(
              networkInfo: network,
              authService: auth,
              engine: engine,
              queue: queue,
              database: db,
              clock: clock,
              reconcileReminders: reminders.reconcile,
              logger: const AppLogger(),
            );

            // Run reconciliation
            await reminders.reconcile();
            await attachments.reconcile();

            // Start coordinator and sync
            await coordinator.start();
            final syncResult = await coordinator.syncNow();
            expect(syncResult.conflicts, equals(0));
            expect(syncResult.pushed, isPositive);

            // Verify full state consistency
            final note = await notes.getNote(testNoteId);
            expect(note, isNotNull);
            expect(note!.title, equals('Döngü Notu'));
            expect(note.document.plainText, equals('İkinci döngüde yazıldı'));

            final snapshot = await kanban.watchBoard(testBoardId).first;
            expect(snapshot, isNotNull);
            expect(snapshot!.columns, hasLength(1));
            expect(
              snapshot.cardsByColumn[snapshot.columns.first.id],
              hasLength(1),
            );
            expect(
              snapshot.cardsByColumn[snapshot.columns.first.id]!.first.title,
              equals('Görev 2. Döngü'),
            );

            // Zero corruption, zero stuck queue operations
            expect(await db.integrityCheck(), equals(<String>['ok']));
            expect(await queue.dueOperations(), isEmpty);

            await coordinator.stop();
          }
        },
      );
    },
  );
}
