import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/logging/app_logger.dart';
import 'package:not_app/core/remote/remote_gateway.dart';
import 'package:not_app/core/remote/remote_models.dart';
import 'package:not_app/core/sync/local_entity_store.dart';
import 'package:not_app/core/sync/sync_engine.dart';
import 'package:not_app/core/sync/sync_models.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/conflicts/data/repositories/conflict_repository_impl.dart';
import 'package:not_app/features/notes/data/repositories/notes_repository_impl.dart';

final class _MutableClock implements AppClock {
  _MutableClock(this._now);

  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}

final class _MemoryRemoteGateway implements RemoteGateway {
  final Map<String, RemoteEntity> _entities = <String, RemoteEntity>{};
  int _revision = 0;
  bool online = true;
  bool failAfterNextApply = false;
  bool reversePullOrder = false;

  @override
  bool get available => online;

  @override
  String? get userId => 'test-user';

  String _key(String entityType, String entityId) => '$entityType:$entityId';

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
    if (!online) throw StateError('remote unavailable');
    final String key = _key(entityType, entityId);
    final RemoteEntity? current = _entities[key];
    if (current != null &&
        baseVersion != null &&
        current.version != baseVersion) {
      return RemoteApplyConflict(current);
    }
    _revision++;
    final RemoteEntity next = RemoteEntity(
      entityType: entityType,
      entityId: entityId,
      version: version,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      payload: Map<String, Object?>.from(payload),
      syncRevision: _revision,
    );
    _entities[key] = next;
    if (failAfterNextApply) {
      failAfterNextApply = false;
      throw StateError('remote response lost after commit');
    }
    return RemoteApplySuccess(_revision);
  }

  @override
  Future<List<RemoteEntity>> pull({
    required int afterRevision,
    int limit = 250,
  }) async {
    if (!online) throw StateError('remote unavailable');
    final List<RemoteEntity> rows =
        _entities.values
            .where((entity) => entity.syncRevision > afterRevision)
            .toList()
          ..sort(
            (RemoteEntity a, RemoteEntity b) =>
                a.syncRevision.compareTo(b.syncRevision),
          );
    if (reversePullOrder) {
      rows.setAll(0, rows.reversed.toList(growable: false));
    }
    return rows.take(limit).toList(growable: false);
  }

  @override
  Future<void> uploadAttachment({
    required String remotePath,
    required File file,
  }) async {
    if (!online) throw StateError('remote unavailable');
  }

  @override
  Future<String> createAttachmentDownloadUrl(String remotePath) async {
    if (!online) throw StateError('remote unavailable');
    return 'memory://$remotePath';
  }

  @override
  Future<void> deleteAttachment(String remotePath) async {
    if (!online) throw StateError('remote unavailable');
  }
}

final class _ClientHarness {
  _ClientHarness._({
    required this.database,
    required this.conflicts,
    required this.notes,
    required this.engine,
  });

  final AppDatabase database;
  final DriftConflictRepository conflicts;
  final DriftNotesRepository notes;
  final SyncEngine engine;

  static _ClientHarness create({
    required RemoteGateway remote,
    required AppClock clock,
  }) {
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
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
    final SyncEngine engine = SyncEngine(
      database: database,
      queue: queue,
      remote: remote,
      localStore: localStore,
      conflicts: conflicts,
      clock: clock,
      logger: const AppLogger(enabled: false),
    );
    return _ClientHarness._(
      database: database,
      conflicts: conflicts,
      notes: notes,
      engine: engine,
    );
  }

  Future<void> close() => database.close();
}

void main() {
  test(
    'two clients converge after an offline edit conflict is resolved',
    () async {
      final _MutableClock clock = _MutableClock(DateTime.utc(2026, 8, 16, 8));
      final _MemoryRemoteGateway remote = _MemoryRemoteGateway();
      final _ClientHarness deviceA = _ClientHarness.create(
        remote: remote,
        clock: clock,
      );
      final _ClientHarness deviceB = _ClientHarness.create(
        remote: remote,
        clock: clock,
      );
      addTearDown(deviceA.close);
      addTearDown(deviceB.close);

      final String noteId = await deviceA.notes.createNote(title: 'Original');
      final SyncRunResult initialPush = await deviceA.engine.runOnce();
      expect(initialPush.pushed, 1);

      final SyncRunResult initialPull = await deviceB.engine.runOnce();
      expect(initialPull.pulled, 1);
      expect((await deviceB.notes.getNote(noteId))?.title, 'Original');

      clock.advance(const Duration(minutes: 1));
      await deviceA.notes.updateTitle(noteId, 'Device A');
      clock.advance(const Duration(minutes: 1));
      await deviceB.notes.updateTitle(noteId, 'Device B');

      final SyncRunResult deviceAUpdate = await deviceA.engine.runOnce();
      expect(deviceAUpdate.pushed, 1);

      final SyncRunResult conflictingRun = await deviceB.engine.runOnce();
      expect(conflictingRun.conflicts, 1);
      expect(
        (await deviceB.notes.getNote(noteId))?.title,
        'Device B',
        reason: 'A pull must not overwrite an unresolved dirty local version.',
      );

      final List<Conflict> openConflicts = await (deviceB.database.select(
        deviceB.database.conflicts,
      )..where((tbl) => tbl.resolvedAt.isNull())).get();
      expect(openConflicts, hasLength(1));

      final List<SyncQueueData> blockedBeforeResolution =
          await (deviceB.database.select(deviceB.database.syncQueue)..where(
                (tbl) =>
                    tbl.entityType.equals('note') &
                    tbl.entityId.equals(noteId) &
                    tbl.status.equals(SyncOperationStatus.blockedConflict.name),
              ))
              .get();
      expect(blockedBeforeResolution, hasLength(1));

      clock.advance(const Duration(minutes: 1));
      await deviceB.conflicts.resolveUsingLocal(openConflicts.single.id);

      final noteAfterResolution = await deviceB.notes.getNote(noteId);
      expect(noteAfterResolution?.title, 'Device B');
      expect(noteAfterResolution?.version, 3);

      final List<SyncQueueData> blockedAfterResolution =
          await (deviceB.database.select(deviceB.database.syncQueue)..where(
                (tbl) =>
                    tbl.entityType.equals('note') &
                    tbl.entityId.equals(noteId) &
                    tbl.status.equals(SyncOperationStatus.blockedConflict.name),
              ))
              .get();
      expect(blockedAfterResolution, isEmpty);

      final SyncRunResult resolvedPush = await deviceB.engine.runOnce();
      expect(resolvedPush.pushed, 1);
      expect(resolvedPush.conflicts, 0);

      final SyncRunResult convergencePull = await deviceA.engine.runOnce();
      expect(convergencePull.pulled, 1);
      expect((await deviceA.notes.getNote(noteId))?.title, 'Device B');
      expect((await deviceA.notes.getNote(noteId))?.version, 3);
      expect((await deviceB.notes.getNote(noteId))?.title, 'Device B');
      expect((await deviceB.notes.getNote(noteId))?.version, 3);

      final List<Conflict> remainingConflicts = await (deviceB.database.select(
        deviceB.database.conflicts,
      )..where((tbl) => tbl.resolvedAt.isNull())).get();
      expect(remainingConflicts, isEmpty);

      final List<SyncQueueData> remainingPending =
          await (deviceB.database.select(deviceB.database.syncQueue)..where(
                (tbl) => tbl.status.isNotIn(<String>[
                  SyncOperationStatus.completed.name,
                ]),
              ))
              .get();
      expect(remainingPending, isEmpty);
    },
  );

  test('retry after a lost remote acknowledgement is idempotent', () async {
    final _MutableClock clock = _MutableClock(DateTime.utc(2026, 8, 16, 9));
    final _MemoryRemoteGateway remote = _MemoryRemoteGateway()
      ..failAfterNextApply = true;
    final _ClientHarness client = _ClientHarness.create(
      remote: remote,
      clock: clock,
    );
    addTearDown(client.close);

    await client.notes.createNote(title: 'Retry safe');
    final SyncRunResult firstRun = await client.engine.runOnce();
    expect(firstRun.pushed, 0);
    expect(firstRun.conflicts, 0);

    final List<SyncQueueData> waiting =
        await (client.database.select(client.database.syncQueue)..where(
              (tbl) => tbl.status.equals(SyncOperationStatus.retryWaiting.name),
            ))
            .get();
    expect(waiting, hasLength(1));

    clock.advance(const Duration(hours: 1));
    final SyncRunResult retryRun = await client.engine.runOnce();
    expect(retryRun.pushed, 1);
    expect(retryRun.conflicts, 0);

    final List<SyncQueueData> remainingPending =
        await (client.database.select(client.database.syncQueue)..where(
              (tbl) => tbl.status.isNotIn(<String>[
                SyncOperationStatus.completed.name,
              ]),
            ))
            .get();
    expect(remainingPending, isEmpty);

    final List<Conflict> openConflicts = await (client.database.select(
      client.database.conflicts,
    )..where((tbl) => tbl.resolvedAt.isNull())).get();
    expect(openConflicts, isEmpty);
  });

  test('pull applies board hierarchy before cards', () async {
    final _MutableClock clock = _MutableClock(DateTime.utc(2026, 8, 16, 10));
    final _MemoryRemoteGateway remote = _MemoryRemoteGateway();
    final _ClientHarness deviceA = _ClientHarness.create(
      remote: remote,
      clock: clock,
    );
    final _ClientHarness deviceB = _ClientHarness.create(
      remote: remote,
      clock: clock,
    );
    addTearDown(deviceA.close);
    addTearDown(deviceB.close);

    const String boardId = 'board-sync-order';
    const String columnId = 'column-sync-order';
    const String cardId = 'card-sync-order';
    final DateTime now = clock.nowUtc();
    await deviceA.database
        .into(deviceA.database.boards)
        .insert(
          BoardsCompanion.insert(
            id: boardId,
            title: 'Board',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await deviceA.database
        .into(deviceA.database.boardColumns)
        .insert(
          BoardColumnsCompanion.insert(
            id: columnId,
            boardId: boardId,
            title: 'Column',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await deviceA.database
        .into(deviceA.database.cards)
        .insert(
          CardsCompanion.insert(
            id: cardId,
            boardId: boardId,
            columnId: columnId,
            title: 'Card',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final DriftSyncQueueRepository queue = DriftSyncQueueRepository(
      database: deviceA.database,
      clock: clock,
    );
    await queue.enqueue(
      entityType: 'board',
      entityId: boardId,
      operationType: SyncOperationType.upsert,
      payload: <String, Object?>{
        'title': 'Board',
        'colorHex': null,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'version': 1,
        'deletedAt': null,
      },
    );
    await queue.enqueue(
      entityType: 'column',
      entityId: columnId,
      operationType: SyncOperationType.upsert,
      payload: <String, Object?>{
        'board_id': boardId,
        'title': 'Column',
        'colorHex': null,
        'rank_key': 'hzzzzzzzzzzz',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'version': 1,
        'deletedAt': null,
      },
    );
    await queue.enqueue(
      entityType: 'card',
      entityId: cardId,
      operationType: SyncOperationType.upsert,
      payload: <String, Object?>{
        'board_id': boardId,
        'column_id': columnId,
        'title': 'Card',
        'description': null,
        'rank_key': 'hzzzzzzzzzzz',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'version': 1,
        'deletedAt': null,
      },
    );

    expect((await deviceA.engine.runOnce()).pushed, 3);
    remote.reversePullOrder = true;
    expect((await deviceB.engine.runOnce()).pulled, 3);
    final Card? syncedCard = await (deviceB.database.select(
      deviceB.database.cards,
    )..where((tbl) => tbl.id.equals(cardId))).getSingleOrNull();
    expect(syncedCard, isA<Card>());
  });
}
