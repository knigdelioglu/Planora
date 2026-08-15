import 'dart:io';

import 'package:drift/drift.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/logging/app_logger.dart';
import 'package:not_app/core/remote/remote_gateway.dart';
import 'package:not_app/core/remote/remote_models.dart';
import 'package:not_app/core/sync/local_entity_store.dart';
import 'package:not_app/core/sync/sync_models.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/conflicts/domain/repositories/conflict_repository.dart';

final class SyncRunResult {
  const SyncRunResult({
    required this.pushed,
    required this.pulled,
    required this.conflicts,
  });
  final int pushed;
  final int pulled;
  final int conflicts;
}

final class SyncEngine {
  SyncEngine({
    required AppDatabase database,
    required SyncQueueRepository queue,
    required RemoteGateway remote,
    required LocalEntityStore localStore,
    required ConflictRepository conflicts,
    required AppClock clock,
    required AppLogger logger,
  }) : _database = database,
       _queue = queue,
       _remote = remote,
       _localStore = localStore,
       _conflicts = conflicts,
       _clock = clock,
       _logger = logger;

  final AppDatabase _database;
  final SyncQueueRepository _queue;
  final RemoteGateway _remote;
  final LocalEntityStore _localStore;
  final ConflictRepository _conflicts;
  final AppClock _clock;
  final AppLogger _logger;
  bool _running = false;

  Future<SyncRunResult> runOnce() async {
    if (_running || !_remote.available) {
      return const SyncRunResult(pushed: 0, pulled: 0, conflicts: 0);
    }
    _running = true;
    int pushed = 0;
    int pulled = 0;
    int conflictCount = 0;
    try {
      final List<SyncOperation> operations = await _queue.dueOperations();
      for (final SyncOperation operation in operations) {
        try {
          await _queue.markProcessing(operation.id);
          final bool conflict = await _push(operation);
          if (conflict) {
            conflictCount++;
          } else {
            pushed++;
            await _queue.markCompleted(operation.id);
          }
        } catch (error, stackTrace) {
          _logger.warning(
            'Sync push failed for ${operation.entityType}/${operation.entityId}',
            error,
            stackTrace,
          );
          await _queue.markRetry(operation.id, error: _safeError(error));
        }
      }

      int cursor = await _readCursor();
      while (true) {
        final List<RemoteEntity> batch = await _remote.pull(
          afterRevision: cursor,
        );
        if (batch.isEmpty) break;
        for (final RemoteEntity remote in batch) {
          final int localVersion = await _localStore.localVersion(
            remote.entityType,
            remote.entityId,
          );
          final bool dirty = await _localStore.hasPendingMutation(
            remote.entityType,
            remote.entityId,
          );
          if (dirty && localVersion > 0 && remote.version != localVersion) {
            final Map<String, Object?>? local = await _localStore.payloadFor(
              remote.entityType,
              remote.entityId,
            );
            if (local != null) {
              await _conflicts.record(
                entityType: remote.entityType,
                entityId: remote.entityId,
                local: local,
                remote: remote,
              );
              conflictCount++;
            }
          } else if (remote.version >= localVersion) {
            await _localStore.applyRemote(remote);
            pulled++;
          }
          if (remote.syncRevision > cursor) cursor = remote.syncRevision;
        }
        await _writeCursor(cursor);
        if (batch.length < 250) break;
      }
      return SyncRunResult(
        pushed: pushed,
        pulled: pulled,
        conflicts: conflictCount,
      );
    } finally {
      _running = false;
    }
  }

  Future<bool> _push(SyncOperation operation) async {
    if (operation.operationType == SyncOperationType.uploadAttachment) {
      await _uploadAttachment(operation);
      return false;
    }
    final Map<String, Object?> payload = Map<String, Object?>.from(
      operation.payload,
    );
    final int version =
        (payload['version'] as num?)?.toInt() ??
        await _localStore.localVersion(
          operation.entityType,
          operation.entityId,
        );
    final DateTime updatedAt =
        DateTime.tryParse((payload['updatedAt'] ?? '').toString())?.toUtc() ??
        _clock.nowUtc();
    final DateTime? deletedAt = payload['deletedAt'] == null
        ? null
        : DateTime.tryParse(payload['deletedAt'].toString())?.toUtc();
    final RemoteApplyResult result = await _remote.apply(
      entityType: operation.entityType,
      entityId: operation.entityId,
      baseVersion: operation.baseVersion,
      version: version,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      payload: payload,
    );
    if (result is RemoteApplyConflict) {
      final bool alreadyDeleted =
          operation.operationType == SyncOperationType.delete &&
          result.remote.deletedAt != null &&
          result.remote.version >= version;
      if (alreadyDeleted) {
        await _deleteAttachmentBlobIfNeeded(operation);
        return false;
      }
      final Map<String, Object?>? local = await _localStore.payloadFor(
        operation.entityType,
        operation.entityId,
      );
      if (local != null) {
        await _conflicts.record(
          entityType: operation.entityType,
          entityId: operation.entityId,
          local: local,
          remote: result.remote,
        );
      }
      await _queue.markConflict(
        operation.id,
        error: 'Remote version changed while this device was offline.',
      );
      return true;
    }
    await _deleteAttachmentBlobIfNeeded(operation);
    return false;
  }

  Future<void> _deleteAttachmentBlobIfNeeded(SyncOperation operation) async {
    if (operation.entityType != 'attachment' ||
        operation.operationType != SyncOperationType.delete) {
      return;
    }
    final String remotePath = (operation.payload['remotePath'] ?? '')
        .toString()
        .trim();
    if (remotePath.isEmpty) return;
    await _remote.deleteAttachment(remotePath);
  }

  Future<void> _uploadAttachment(SyncOperation operation) async {
    final String localPath = (operation.payload['localPath'] ?? '').toString();
    final String fileName = (operation.payload['fileName'] ?? 'attachment')
        .toString();
    if (localPath.isEmpty) {
      throw StateError('Upload operation has no local file path.');
    }
    final String? uid = _remote.userId;
    if (uid == null) throw StateError('Cloud account is not signed in.');
    final Attachment? beforeUpload = await (_database.select(
      _database.attachments,
    )..where((tbl) => tbl.id.equals(operation.entityId))).getSingleOrNull();
    if (beforeUpload == null || beforeUpload.deletedAt != null) return;
    final String remotePath =
        '$uid/${operation.entityId}/${_safeRemoteName(fileName)}';
    await _remote.uploadAttachment(
      remotePath: remotePath,
      file: File(localPath),
    );
    final Attachment? row = await (_database.select(
      _database.attachments,
    )..where((tbl) => tbl.id.equals(operation.entityId))).getSingleOrNull();
    if (row == null || row.deletedAt != null) {
      await _remote.deleteAttachment(remotePath);
      return;
    }
    final DateTime now = _clock.nowUtc();
    final int nextVersion = row.version + 1;
    await _database.transaction(() async {
      await (_database.update(
        _database.attachments,
      )..where((tbl) => tbl.id.equals(row.id))).write(
        AttachmentsCompanion(
          remotePath: Value<String?>(remotePath),
          transferState: const Value<String>('synced'),
          updatedAt: Value<DateTime>(now),
          version: Value<int>(nextVersion),
        ),
      );
      final Map<String, Object?>? metadata = await _localStore.payloadFor(
        'attachment',
        row.id,
      );
      if (metadata != null) {
        await _queue.enqueue(
          entityType: 'attachment',
          entityId: row.id,
          operationType: SyncOperationType.upsert,
          baseVersion: row.version,
          payload: metadata,
        );
      }
    });
  }

  String _safeRemoteName(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  Future<int> _readCursor() async {
    final SyncMetaData? row = await (_database.select(
      _database.syncMeta,
    )..where((tbl) => tbl.key.equals('remote_cursor'))).getSingleOrNull();
    return int.tryParse(row?.value ?? '0') ?? 0;
  }

  Future<void> _writeCursor(int value) async {
    await _database
        .into(_database.syncMeta)
        .insertOnConflictUpdate(
          SyncMetaCompanion.insert(
            key: 'remote_cursor',
            value: value.toString(),
            updatedAt: _clock.nowUtc(),
          ),
        );
  }

  String _safeError(Object error) {
    final String value = error.toString();
    return value.length <= 500 ? value : value.substring(0, 500);
  }
}
