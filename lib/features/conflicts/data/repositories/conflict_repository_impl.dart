import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/remote/remote_models.dart';
import 'package:not_app/core/sync/local_entity_store.dart';
import 'package:not_app/core/sync/sync_models.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/conflicts/domain/entities/sync_conflict.dart';
import 'package:not_app/features/conflicts/domain/repositories/conflict_repository.dart';
import 'package:uuid/uuid.dart';

final class DriftConflictRepository implements ConflictRepository {
  DriftConflictRepository({
    required AppDatabase database,
    required SyncQueueRepository syncQueue,
    required LocalEntityStore localStore,
    required AppClock clock,
    Uuid? uuid,
  }) : _database = database,
       _syncQueue = syncQueue,
       _localStore = localStore,
       _clock = clock,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final SyncQueueRepository _syncQueue;
  final LocalEntityStore _localStore;
  final AppClock _clock;
  final Uuid _uuid;

  @override
  Stream<List<SyncConflictEntity>> watchOpen() {
    final query = _database.select(_database.conflicts)
      ..where((tbl) => tbl.resolvedAt.isNull())
      ..orderBy(<OrderingTerm Function($ConflictsTable)>[
        (tbl) => OrderingTerm.desc(tbl.createdAt),
      ]);
    return query.watch().map((rows) => rows.map(_map).toList(growable: false));
  }

  @override
  Future<String> record({
    required String entityType,
    required String entityId,
    required Map<String, Object?> local,
    required RemoteEntity remote,
  }) async {
    final String id = _uuid.v7();
    await _database
        .into(_database.conflicts)
        .insert(
          ConflictsCompanion.insert(
            id: id,
            entityType: entityType,
            entityId: entityId,
            localJson: jsonEncode(local),
            localUpdatedAt:
                DateTime.tryParse(
                  (local['updatedAt'] ?? '').toString(),
                )?.toUtc() ??
                _clock.nowUtc(),
            remoteUpdatedAt: remote.updatedAt,
            remoteJson: jsonEncode(<String, Object?>{
              ...remote.payload,
              'version': remote.version,
              'updatedAt': remote.updatedAt.toIso8601String(),
              'deletedAt': remote.deletedAt?.toIso8601String(),
              'syncRevision': remote.syncRevision,
            }),
            createdAt: _clock.nowUtc(),
          ),
        );
    return id;
  }

  @override
  Future<void> resolveUsingLocal(String conflictId) async {
    final Conflict row = await _load(conflictId);
    final Map<String, Object?> local = _decode(row.localJson);
    final Map<String, Object?> remote = _decode(row.remoteJson);
    final int remoteVersion = (remote['version'] as num?)?.toInt() ?? 0;
    final int localVersion =
        (local['version'] as num?)?.toInt() ?? remoteVersion + 1;
    await _syncQueue.enqueue(
      entityType: row.entityType,
      entityId: row.entityId,
      operationType: SyncOperationType.upsert,
      baseVersion: remoteVersion,
      payload: <String, Object?>{
        ...local,
        'version': localVersion <= remoteVersion
            ? remoteVersion + 1
            : localVersion,
      },
    );
    await _resolve(row.id, 'local');
  }

  @override
  Future<void> resolveUsingRemote(String conflictId) async {
    final Conflict row = await _load(conflictId);
    final Map<String, Object?> remote = _decode(row.remoteJson);
    final DateTime updatedAt =
        DateTime.tryParse((remote['updatedAt'] ?? '').toString())?.toUtc() ??
        _clock.nowUtc();
    final DateTime? deletedAt = remote['deletedAt'] == null
        ? null
        : DateTime.tryParse(remote['deletedAt'].toString())?.toUtc();
    final int version = (remote['version'] as num?)?.toInt() ?? 1;
    final int revision = (remote['syncRevision'] as num?)?.toInt() ?? 0;
    final Map<String, Object?> payload = Map<String, Object?>.from(remote)
      ..remove('version')
      ..remove('updatedAt')
      ..remove('deletedAt')
      ..remove('syncRevision');
    await _localStore.applyRemote(
      RemoteEntity(
        entityType: row.entityType,
        entityId: row.entityId,
        version: version,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
        payload: payload,
        syncRevision: revision,
      ),
    );
    await _resolve(row.id, 'remote');
  }

  @override
  Future<void> resolveAsCopy(String conflictId) async {
    final Conflict row = await _load(conflictId);
    final Map<String, Object?> local = _decode(row.localJson);
    if (row.entityType != 'note' && row.entityType != 'card') {
      throw StateError(
        'Only note and card conflicts can be preserved as a copy.',
      );
    }
    final String copyId = _uuid.v7();
    final DateTime now = _clock.nowUtc();
    if (row.entityType == 'note') {
      await _database
          .into(_database.notes)
          .insert(
            NotesCompanion.insert(
              id: copyId,
              title: Value<String>(
                '${local['title'] ?? 'Not'} (Çakışma kopyası)',
              ),
              contentJson: Value<String>(
                (local['contentJson'] ?? '{"version":1,"blocks":[]}')
                    .toString(),
              ),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      final String? boardId = local['boardId'] as String?;
      final String? columnId = local['columnId'] as String?;
      if (boardId == null || columnId == null)
        throw StateError('Card conflict data is incomplete.');
      await _database
          .into(_database.cards)
          .insert(
            CardsCompanion.insert(
              id: copyId,
              boardId: boardId,
              columnId: columnId,
              title: '${local['title'] ?? 'Kart'} (Çakışma kopyası)',
              description: Value<String?>(local['description'] as String?),
              rankKey: Value<String>(
                (local['rankKey'] ?? 'hzzzzzzzzzzz').toString(),
              ),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    await _syncQueue.enqueue(
      entityType: row.entityType,
      entityId: copyId,
      operationType: SyncOperationType.upsert,
      baseVersion: 0,
      payload: <String, Object?>{
        ...local,
        'id': copyId,
        'version': 1,
        'updatedAt': now.toIso8601String(),
      },
    );
    await resolveUsingRemote(conflictId);
    await _resolve(row.id, 'copy');
  }

  Future<Conflict> _load(String id) async {
    final Conflict? row = await (_database.select(
      _database.conflicts,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (row == null || row.resolvedAt != null)
      throw StateError('Conflict is not open.');
    return row;
  }

  Future<void> _resolve(String id, String resolution) {
    return (_database.update(
      _database.conflicts,
    )..where((tbl) => tbl.id.equals(id))).write(
      ConflictsCompanion(
        resolvedAt: Value<DateTime?>(_clock.nowUtc()),
        resolution: Value<String?>(resolution),
      ),
    );
  }

  Map<String, Object?> _decode(String raw) {
    final Object? value = jsonDecode(raw);
    return value is Map
        ? Map<String, Object?>.from(value)
        : <String, Object?>{};
  }

  SyncConflictEntity _map(Conflict row) => SyncConflictEntity(
    id: row.id,
    entityType: row.entityType,
    entityId: row.entityId,
    localJson: row.localJson,
    remoteJson: row.remoteJson,
    createdAt: row.createdAt,
    resolvedAt: row.resolvedAt,
    resolution: row.resolution,
  );
}
