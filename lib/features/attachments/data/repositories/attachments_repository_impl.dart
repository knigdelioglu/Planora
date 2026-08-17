import 'dart:async';
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
    required this.database,
    required this.storage,
    required this.syncQueue,
    required this.clock,
    required this.remote,
    Dio? dio,
    Uuid? uuid,
    this.tempDirectoryProvider,
  }) : _dio = dio ?? Dio(),
       _uuid = uuid ?? const Uuid();

  final AppDatabase database;
  final FileStorageService storage;
  final SyncQueueRepository syncQueue;
  final AppClock clock;
  final RemoteGateway remote;
  final Dio _dio;
  final Uuid _uuid;
  final Future<Directory> Function()? tempDirectoryProvider;

  AppDatabase get _database => database;
  FileStorageService get _storage => storage;
  SyncQueueRepository get _syncQueue => syncQueue;
  AppClock get _clock => clock;
  RemoteGateway get _remote => remote;
  Future<Directory> Function()? get _tempDirectoryProvider =>
      tempDirectoryProvider;
  final StreamController<AttachmentTransferProgress> _progressController =
      StreamController<AttachmentTransferProgress>.broadcast();
  final Map<String, double> _activeProgress = <String, double>{};
  final Map<String, CancelToken> _activeCancelTokens = <String, CancelToken>{};

  Stream<AttachmentTransferProgress> watchProgress(String attachmentId) =>
      _progressController.stream.where(
        (progress) => progress.attachmentId == attachmentId,
      );

  Stream<Map<String, double>> watchActiveProgress() async* {
    yield Map<String, double>.unmodifiable(_activeProgress);
    yield* _progressController.stream.map(
      (_) => Map<String, double>.unmodifiable(_activeProgress),
    );
  }

  double? getProgress(String attachmentId) => _activeProgress[attachmentId];

  void _reportProgress({
    required String attachmentId,
    required bool isUpload,
    required int bytesTransferred,
    required int totalBytes,
    required double progress,
  }) {
    _activeProgress[attachmentId] = progress;
    _progressController.add(
      AttachmentTransferProgress(
        attachmentId: attachmentId,
        isUpload: isUpload,
        bytesTransferred: bytesTransferred,
        totalBytes: totalBytes,
        progress: progress,
      ),
    );
  }

  void _clearProgress(String attachmentId) {
    _activeProgress.remove(attachmentId);
    _progressController.add(
      AttachmentTransferProgress(
        attachmentId: attachmentId,
        isUpload: false,
        bytesTransferred: 0,
        totalBytes: 0,
        progress: 0.0,
      ),
    );
  }

  void cancelTransfer(String attachmentId) {
    final CancelToken? token = _activeCancelTokens.remove(attachmentId);
    if (token != null && !token.isCancelled) {
      token.cancel('Transfer cancelled by user');
    }
    _clearProgress(attachmentId);
    unawaited(
      (_database.update(
        _database.attachments,
      )..where((tbl) => tbl.id.equals(attachmentId))).write(
        const AttachmentsCompanion(transferState: Value<String>('failed')),
      ),
    );
  }

  Future<void> retryTransfer(
    String attachmentId, {
    CancelToken? cancelToken,
  }) async {
    final Attachment? row = await (_database.select(
      _database.attachments,
    )..where((tbl) => tbl.id.equals(attachmentId))).getSingleOrNull();
    if (row == null || row.deletedAt != null) return;

    if (row.localPath.isNotEmpty && await _storage.exists(row.localPath)) {
      await _database.transaction(() async {
        await (_database.update(
          _database.attachments,
        )..where((tbl) => tbl.id.equals(attachmentId))).write(
          const AttachmentsCompanion(
            transferState: Value<String>('pendingUpload'),
          ),
        );

        final List<SyncQueueData> queued = await (_database.select(
          _database.syncQueue,
        )..where((tbl) => tbl.entityId.equals(attachmentId))).get();

        bool hasUploadOp = false;
        for (final op in queued) {
          if (op.operationType == SyncOperationType.uploadAttachment.name) {
            hasUploadOp = true;
            await (_database.update(
              _database.syncQueue,
            )..where((tbl) => tbl.operationId.equals(op.operationId))).write(
              const SyncQueueCompanion(
                status: Value<String>('pending'),
                nextAttemptAt: Value<DateTime?>(null),
                lastError: Value<String?>(null),
              ),
            );
          }
        }
        if (!hasUploadOp) {
          await _syncQueue.enqueue(
            entityType: 'attachment',
            entityId: attachmentId,
            operationType: SyncOperationType.uploadAttachment,
            baseVersion: row.version,
            payload: <String, Object?>{
              'attachmentId': attachmentId,
              'localPath': row.localPath,
              'fileName': row.fileName,
            },
          );
        }
      });
    } else if (row.remotePath != null && row.remotePath!.isNotEmpty) {
      await ensureLocal(attachmentId, cancelToken: cancelToken);
    }
  }

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
                lastAccessedAt: Value<DateTime?>(now),
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
      try {
        await _storage.deleteOwned(stored.localPath);
      } catch (_) {}
      rethrow;
    }
    final row = await (_database.select(
      _database.attachments,
    )..where((tbl) => tbl.id.equals(id))).getSingle();
    return _map(row);
  }

  @override
  Future<File> ensureLocal(
    String attachmentId, {
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    final Attachment? row = await (_database.select(
      _database.attachments,
    )..where((tbl) => tbl.id.equals(attachmentId))).getSingleOrNull();
    if (row == null || row.deletedAt != null) {
      throw StateError('Attachment does not exist.');
    }
    if (row.localPath.isNotEmpty && await _storage.exists(row.localPath)) {
      await _touch(row.id);
      if (row.transferState != 'synced') {
        await (_database.update(
          _database.attachments,
        )..where((tbl) => tbl.id.equals(row.id))).write(
          const AttachmentsCompanion(transferState: Value<String>('synced')),
        );
      }
      return File(row.localPath);
    }
    if (row.remotePath == null || !_remote.available) {
      throw FileSystemException(
        'Attachment is not available on this device and cloud download is unavailable.',
      );
    }

    final CancelToken token = cancelToken ?? CancelToken();
    _activeCancelTokens[attachmentId] = token;

    final String url = await _remote.createAttachmentDownloadUrl(
      row.remotePath!,
    );
    final Directory tempRoot = _tempDirectoryProvider != null
        ? await _tempDirectoryProvider!()
        : await getTemporaryDirectory();
    final Directory tempDir = Directory(
      p.join(tempRoot.path, 'not_attachment_downloads', row.id),
    );
    await tempDir.create(recursive: true);
    final File temp = File(
      p.join(tempDir.path, '${_uuid.v7()}_${row.fileName}.tmp'),
    );

    try {
      await (_database.update(
        _database.attachments,
      )..where((tbl) => tbl.id.equals(row.id))).write(
        const AttachmentsCompanion(transferState: Value<String>('downloading')),
      );
      _reportProgress(
        attachmentId: row.id,
        isUpload: false,
        bytesTransferred: 0,
        totalBytes: row.sizeBytes,
        progress: 0.0,
      );

      await _dio.download(
        url,
        temp.path,
        cancelToken: token,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          final int effectiveTotal = total > 0 ? total : row.sizeBytes;
          final double ratio = effectiveTotal > 0
              ? (received / effectiveTotal).clamp(0.0, 1.0)
              : 0.0;
          _reportProgress(
            attachmentId: row.id,
            isUpload: false,
            bytesTransferred: received,
            totalBytes: effectiveTotal,
            progress: ratio,
          );
          onProgress?.call(received, total);
        },
      );

      final StoredFile cached = await _storage.persistCache(
        temp,
        attachmentId: row.id,
      );
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
      try {
        if (await tempDir.exists()) {
          final List<FileSystemEntity> entries = await tempDir.list().toList();
          if (entries.isEmpty) await tempDir.delete();
        }
      } catch (_) {}

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
    } on DioException {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}

      await (_database.update(
        _database.attachments,
      )..where((tbl) => tbl.id.equals(row.id))).write(
        const AttachmentsCompanion(
          transferState: Value<String>('failed'),
          localPath: Value<String>(''),
          isCache: Value<bool>(false),
        ),
      );
      rethrow;
    } catch (_) {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}

      await (_database.update(
        _database.attachments,
      )..where((tbl) => tbl.id.equals(row.id))).write(
        const AttachmentsCompanion(
          transferState: Value<String>('failed'),
          localPath: Value<String>(''),
          isCache: Value<bool>(false),
        ),
      );
      rethrow;
    } finally {
      _activeCancelTokens.remove(attachmentId);
      _clearProgress(attachmentId);
    }
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
      try {
        if (row.isCache) {
          await _storage.deleteCache(row.localPath);
        } else {
          await _storage.deleteOwned(row.localPath);
        }
      } catch (_) {}
    }
  }

  @override
  Future<int> cacheSizeBytes() => _storage.cacheSizeBytes();

  @override
  Future<void> evictCacheUntil(int maximumBytes) async {
    if (maximumBytes < 0) {
      throw ArgumentError.value(
        maximumBytes,
        'maximumBytes',
        'Maximum bytes cannot be negative.',
      );
    }
    int currentSize = await _storage.cacheSizeBytes();
    if (maximumBytes > 0 && currentSize <= maximumBytes) {
      return;
    }

    // DB-backed LRU: order cached attachments by lastAccessedAt ASC (nulls first), then createdAt ASC
    final List<Attachment> candidates =
        await (_database.select(_database.attachments)
              ..where(
                (tbl) => tbl.isCache.equals(true) & tbl.deletedAt.isNull(),
              )
              ..orderBy(<OrderingTerm Function($AttachmentsTable)>[
                (tbl) => OrderingTerm(
                  expression: tbl.lastAccessedAt,
                  mode: OrderingMode.asc,
                  nulls: NullsOrder.first,
                ),
                (tbl) => OrderingTerm.asc(tbl.createdAt),
              ]))
            .get();

    for (final Attachment candidate in candidates) {
      if (maximumBytes > 0 && currentSize <= maximumBytes) break;

      int freedBytes = 0;
      if (candidate.localPath.isNotEmpty) {
        try {
          final File file = File(candidate.localPath);
          if (await file.exists()) {
            freedBytes = await file.length();
          }
          await _storage.deleteCache(candidate.localPath);
        } catch (_) {
          // Graceful handling if file is already missing or inaccessible
        }
      }
      currentSize -= (freedBytes > 0 ? freedBytes : candidate.sizeBytes);

      // Consistent DB update: clear localPath, mark isCache false, update transferState
      await (_database.update(
        _database.attachments,
      )..where((tbl) => tbl.id.equals(candidate.id))).write(
        AttachmentsCompanion(
          localPath: const Value<String>(''),
          isCache: const Value<bool>(false),
          transferState: Value<String>(
            candidate.remotePath != null ? 'remoteOnly' : 'pendingUpload',
          ),
        ),
      );
    }

    // If cache on disk still exceeds maximumBytes (e.g. unindexed leftover files in cache dir)
    if (currentSize > maximumBytes) {
      final List<File> remainingFiles = await _storage.listFiles(
        bucket: 'cache',
      );
      for (final File file in remainingFiles) {
        if (currentSize <= maximumBytes) break;
        try {
          final int size = await file.length();
          await _storage.deleteCache(file.path);
          currentSize -= size;
        } catch (_) {}
      }
    }
  }

  Future<AttachmentReconciliationResult> reconcile() async {
    int missingFilesHandled = 0;
    int tombstonesCleaned = 0;
    int orphanedFilesDeleted = 0;
    int tempFilesCleaned = 0;

    // 1. Clean temporary downloads
    try {
      await _storage.cleanTempDownloads();
      tempFilesCleaned++;
    } catch (_) {}

    // 2. Fetch all DB attachment records
    final List<Attachment> rows = await _database
        .select(_database.attachments)
        .get();

    final Set<String> validSandboxFilePaths = <String>{};

    for (final Attachment row in rows) {
      if (row.localPath.trim().isEmpty) {
        if (row.transferState == 'downloading' ||
            row.transferState == 'uploading') {
          await (_database.update(
            _database.attachments,
          )..where((tbl) => tbl.id.equals(row.id))).write(
            AttachmentsCompanion(
              transferState: Value<String>(
                row.remotePath != null ? 'remoteOnly' : 'failed',
              ),
            ),
          );
        }
        continue;
      }

      final String normalizedPath = p.normalize(p.absolute(row.localPath));

      // Path traversal security check: must be strictly inside sandbox
      final bool inSandbox = await _storage.isWithinSandbox(normalizedPath);
      if (!inSandbox) {
        // Unsafe path outside sandbox! Refuse to touch file on disk and sanitize DB record.
        await (_database.update(
          _database.attachments,
        )..where((tbl) => tbl.id.equals(row.id))).write(
          AttachmentsCompanion(
            localPath: const Value<String>(''),
            isCache: const Value<bool>(false),
            transferState: Value<String>(
              row.remotePath != null ? 'remoteOnly' : 'localOnly',
            ),
          ),
        );
        missingFilesHandled++;
        continue;
      }

      // Tombstone record (deletedAt != null)
      if (row.deletedAt != null) {
        if (await _storage.exists(normalizedPath)) {
          try {
            if (row.isCache) {
              await _storage.deleteCache(normalizedPath);
            } else {
              await _storage.deleteOwned(normalizedPath);
            }
            tombstonesCleaned++;
          } catch (_) {}
        }
        await (_database.update(
          _database.attachments,
        )..where((tbl) => tbl.id.equals(row.id))).write(
          const AttachmentsCompanion(
            localPath: Value<String>(''),
            isCache: Value<bool>(false),
          ),
        );
        continue;
      }

      // Active record (deletedAt == null)
      final bool fileExists = await _storage.exists(normalizedPath);
      if (fileExists) {
        validSandboxFilePaths.add(normalizedPath);
      } else {
        // DB record references a file that does not exist on disk
        missingFilesHandled++;
        await (_database.update(
          _database.attachments,
        )..where((tbl) => tbl.id.equals(row.id))).write(
          AttachmentsCompanion(
            localPath: const Value<String>(''),
            isCache: const Value<bool>(false),
            transferState: Value<String>(
              row.remotePath != null ? 'remoteOnly' : 'localOnly',
            ),
          ),
        );
      }
    }

    // 3. Scan managed sandbox for unreferenced / orphaned files
    final List<File> filesOnDisk = await _storage.listFiles();
    for (final File diskFile in filesOnDisk) {
      final String diskPath = p.normalize(p.absolute(diskFile.path));
      if (!validSandboxFilePaths.contains(diskPath)) {
        try {
          await _storage.deleteSandboxFile(diskPath);
          orphanedFilesDeleted++;
        } catch (_) {}
      }
    }

    // 4. Clean empty directories in sandbox
    try {
      await _storage.cleanEmptyDirectories();
    } catch (_) {}

    return AttachmentReconciliationResult(
      missingFilesHandled: missingFilesHandled,
      tombstonesCleaned: tombstonesCleaned,
      orphanedFilesDeleted: orphanedFilesDeleted,
      tempFilesCleaned: tempFilesCleaned,
    );
  }

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

extension AttachmentsRepositoryTransferX on AttachmentsRepository {
  void cancelTransfer(String attachmentId) {
    if (this is DriftAttachmentsRepository) {
      (this as DriftAttachmentsRepository).cancelTransfer(attachmentId);
    }
  }

  Future<void> retryTransfer(String attachmentId, {CancelToken? cancelToken}) {
    if (this is DriftAttachmentsRepository) {
      return (this as DriftAttachmentsRepository).retryTransfer(
        attachmentId,
        cancelToken: cancelToken,
      );
    }
    return ensureLocal(attachmentId);
  }

  Stream<AttachmentTransferProgress> watchProgress(String attachmentId) {
    if (this is DriftAttachmentsRepository) {
      return (this as DriftAttachmentsRepository).watchProgress(attachmentId);
    }
    return const Stream<AttachmentTransferProgress>.empty();
  }

  Stream<Map<String, double>> watchActiveProgress() {
    if (this is DriftAttachmentsRepository) {
      return (this as DriftAttachmentsRepository).watchActiveProgress();
    }
    return Stream<Map<String, double>>.value(const <String, double>{});
  }

  double? getProgress(String attachmentId) {
    if (this is DriftAttachmentsRepository) {
      return (this as DriftAttachmentsRepository).getProgress(attachmentId);
    }
    return null;
  }
}
