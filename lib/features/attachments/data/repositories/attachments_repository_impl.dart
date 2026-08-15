import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:mime/mime.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/remote/remote_gateway.dart';
import 'package:not_app/core/services/file_storage_service.dart';
import 'package:not_app/core/sync/sync_models.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/attachments/domain/entities/attachment.dart';
import 'package:not_app/features/attachments/domain/repositories/attachments_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

final class DriftAttachmentsRepository implements AttachmentsRepository {
  DriftAttachmentsRepository({
    required AppDatabase database,
    required FileStorageService storage,
    required SyncQueueRepository syncQueue,
    required AppClock clock,
    required RemoteGateway remote,
    Dio? dio,
    Uuid? uuid,
  }) : _database = database,
       _storage = storage,
       _syncQueue = syncQueue,
       _clock = clock,
       _remote = remote,
       _dio = dio ?? Dio(),
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final FileStorageService _storage;
  final SyncQueueRepository _syncQueue;
  final AppClock _clock;
  final RemoteGateway _remote;
  final Dio _dio;
  final Uuid _uuid;

  @override
  Stream<List<AttachmentEntity>> watchForParent(
    String parentType,
    String parentId,
  ) {
    final query = _database.select(_database.attachments)
      ..where(
        (tbl) =>
            tbl.parentType.equals(parentType) &
            tbl.parentId.equals(parentId) &
            tbl.deletedAt.isNull(),
      )
      ..orderBy(<OrderingTerm Function($AttachmentsTable)>[
        (tbl) => OrderingTerm.asc(tbl.createdAt),
      ]);
    return query.watch().map((rows) => rows.map(_map).toList(growable: false));
  }

  @override
  Future<AttachmentEntity> addFromFile({
    required String parentType,
    required String parentId,
    required File source,
  }) async {
    if (parentType != 'note' && parentType != 'card') {
      throw ArgumentError.value(
        parentType,
        'parentType',
        'Only note and card attachments are supported.',
      );
    }
    final String id = _uuid.v7();
    final StoredFile stored = await _storage.persist(source, attachmentId: id);
    final DateTime now = _clock.nowUtc();
    final String? mimeType = lookupMimeType(stored.fileName);
    try {
      await _database.transaction(() async {
        await _database
            .into(_database.attachments)
            .insert(
              AttachmentsCompanion.insert(
                id: id,
                parentType: parentType,
                parentId: parentId,
                fileName: stored.fileName,
                localPath: stored.localPath,
                mimeType: Value<String?>(mimeType),
                sizeBytes: stored.sizeBytes,
                checksum: Value<String?>(stored.checksum),
                isCache: const Value<bool>(false),
                transferState: const Value<String>('pendingUpload'),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _syncQueue.enqueue(
          entityType: 'attachment',
          entityId: id,
          operationType: SyncOperationType.upsert,
          baseVersion: 0,
          payload: <String, Object?>{
            'id': id,
            'parentType': parentType,
            'parentId': parentId,
            'fileName': stored.fileName,
            'remotePath': null,
            'mimeType': mimeType,
            'sizeBytes': stored.sizeBytes,
            'checksum': stored.checksum,
            'version': 1,
            'updatedAt': now.toIso8601String(),
            'deletedAt': null,
          },
        );
        await _syncQueue.enqueue(
          entityType: 'attachment',
          entityId: id,
          operationType: SyncOperationType.uploadAttachment,
          baseVersion: 1,
          payload: <String, Object?>{
            'attachmentId': id,
            'localPath': stored.localPath,
            'fileName': stored.fileName,
          },
        );
      });
    } catch (_) {
      await _storage.deleteOwned(stored.localPath);
      rethrow;
    }
    final row = await (_database.select(
      _database.attachments,
    )..where((tbl) => tbl.id.equals(id))).getSingle();
    return _map(row);
  }

  @override
  Future<File> ensureLocal(String attachmentId) async {
    final Attachment? row = await (_database.select(
      _database.attachments,
    )..where((tbl) => tbl.id.equals(attachmentId))).getSingleOrNull();
    if (row == null || row.deletedAt != null)
      throw StateError('Attachment does not exist.');
    if (row.localPath.isNotEmpty && await _storage.exists(row.localPath)) {
      await _touch(row.id);
      return File(row.localPath);
    }
    if (row.remotePath == null || !_remote.available) {
      throw FileSystemException(
        'Attachment is not available on this device and cloud download is unavailable.',
      );
    }

    final String url = await _remote.createAttachmentDownloadUrl(
      row.remotePath!,
    );
    final Directory tempRoot = await getTemporaryDirectory();
    final Directory tempDir = Directory(
      p.join(tempRoot.path, 'not_attachment_downloads', row.id),
    );
    await tempDir.create(recursive: true);
    final File temp = File(p.join(tempDir.path, row.fileName));
    await _dio.download(url, temp.path, deleteOnError: true);
    final StoredFile cached = await _storage.persistCache(
      temp,
      attachmentId: row.id,
    );
    if (await temp.exists()) await temp.delete();
    final DateTime now = _clock.nowUtc();
    await (_database.update(
      _database.attachments,
    )..where((tbl) => tbl.id.equals(row.id))).write(
      AttachmentsCompanion(
        localPath: Value<String>(cached.localPath),
        isCache: const Value<bool>(true),
        checksum: Value<String?>(cached.checksum),
        sizeBytes: Value<int>(cached.sizeBytes),
        lastAccessedAt: Value<DateTime?>(now),
        transferState: const Value<String>('synced'),
      ),
    );
    return File(cached.localPath);
  }

  Future<void> _touch(String id) async {
    await (_database.update(
      _database.attachments,
    )..where((tbl) => tbl.id.equals(id))).write(
      AttachmentsCompanion(lastAccessedAt: Value<DateTime?>(_clock.nowUtc())),
    );
  }

  @override
  Future<void> remove(String attachmentId) async {
    final Attachment? row = await (_database.select(
      _database.attachments,
    )..where((tbl) => tbl.id.equals(attachmentId))).getSingleOrNull();
    if (row == null || row.deletedAt != null) return;
    final DateTime now = _clock.nowUtc();
    await _database.transaction(() async {
      await (_database.update(
        _database.attachments,
      )..where((tbl) => tbl.id.equals(attachmentId))).write(
        AttachmentsCompanion(
          deletedAt: Value<DateTime?>(now),
          updatedAt: Value<DateTime>(now),
          version: Value<int>(row.version + 1),
        ),
      );
      await _syncQueue.enqueue(
        entityType: 'attachment',
        entityId: attachmentId,
        operationType: SyncOperationType.delete,
        baseVersion: row.version,
        payload: <String, Object?>{
          'id': attachmentId,
          'version': row.version + 1,
          'updatedAt': now.toIso8601String(),
          'deletedAt': now.toIso8601String(),
          'remotePath': row.remotePath,
        },
      );
    });
    if (row.localPath.isNotEmpty) {
      if (row.isCache) {
        await _storage.deleteCache(row.localPath);
      } else {
        await _storage.deleteOwned(row.localPath);
      }
    }
  }

  @override
  Future<int> cacheSizeBytes() => _storage.cacheSizeBytes();

  @override
  Future<void> evictCacheUntil(int maximumBytes) =>
      _storage.evictCacheUntil(maximumBytes: maximumBytes);

  AttachmentEntity _map(Attachment row) => AttachmentEntity(
    id: row.id,
    parentType: row.parentType,
    parentId: row.parentId,
    fileName: row.fileName,
    localPath: row.localPath,
    remotePath: row.remotePath,
    mimeType: row.mimeType,
    sizeBytes: row.sizeBytes,
    checksum: row.checksum,
    isCache: row.isCache,
    lastAccessedAt: row.lastAccessedAt,
    transferState: row.transferState,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    version: row.version,
    deletedAt: row.deletedAt,
  );
}
