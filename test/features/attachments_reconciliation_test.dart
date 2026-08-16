import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/remote/remote_gateway.dart';
import 'package:not_app/core/remote/remote_models.dart';
import 'package:not_app/core/services/file_storage_service.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/attachments/data/repositories/attachments_repository_impl.dart';
import 'package:path/path.dart' as p;

final class _TestClock implements AppClock {
  _TestClock(this._now);

  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}

final class _FakeRemoteGateway implements RemoteGateway {
  _FakeRemoteGateway();

  @override
  final bool available = true;

  @override
  final String? userId = 'test-user';

  final Map<String, String> uploads = <String, String>{};

  @override
  Future<RemoteApplyResult> apply({
    required String entityType,
    required String entityId,
    required int? baseVersion,
    required int version,
    required DateTime updatedAt,
    required DateTime? deletedAt,
    required Map<String, Object?> payload,
  }) async => const RemoteApplySuccess(1);

  @override
  Future<List<RemoteEntity>> pull({
    required int afterRevision,
    int limit = 250,
  }) async => const <RemoteEntity>[];

  @override
  Future<void> uploadAttachment({
    required String remotePath,
    required File file,
  }) async {
    uploads[remotePath] = file.path;
  }

  @override
  Future<void> deleteAttachment(String remotePath) async {
    uploads.remove(remotePath);
  }

  @override
  Future<String> createAttachmentDownloadUrl(String remotePath) async =>
      'https://example.com/attachments/$remotePath';
}

void main() {
  late Directory tempBaseDir;
  late AppDatabase db;
  late _TestClock clock;
  late SandboxFileStorageService storage;
  late DriftSyncQueueRepository queue;
  late _FakeRemoteGateway remote;
  late DriftAttachmentsRepository repository;

  setUp(() async {
    tempBaseDir = Directory.systemTemp.createTempSync(
      'not_reconciliation_test_',
    );
    db = AppDatabase(NativeDatabase.memory());
    clock = _TestClock(DateTime.utc(2026, 8, 16, 12));
    storage = SandboxFileStorageService(
      rootDirectoryProvider: () async => tempBaseDir,
      tempDirectoryProvider: () async => tempBaseDir,
    );
    queue = DriftSyncQueueRepository(database: db, clock: clock);
    remote = _FakeRemoteGateway();
    repository = DriftAttachmentsRepository(
      database: db,
      storage: storage,
      syncQueue: queue,
      clock: clock,
      remote: remote,
      tempDirectoryProvider: () async => tempBaseDir,
    );
  });

  tearDown(() async {
    await db.close();
    if (tempBaseDir.existsSync()) {
      tempBaseDir.deleteSync(recursive: true);
    }
  });

  test(
    'reconciliation updates active DB records whose files are missing on disk',
    () async {
      final now = clock.nowUtc();
      final fakePath = p.join(
        tempBaseDir.path,
        'app_storage',
        'attachments',
        'att-missing-1',
        'missing.png',
      );

      // Record with remotePath
      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: 'att-missing-1',
              parentType: 'note',
              parentId: 'note-1',
              fileName: 'missing.png',
              localPath: fakePath,
              remotePath: const Value('user/att-missing-1/missing.png'),
              sizeBytes: 1024,
              isCache: const Value(false),
              transferState: const Value('synced'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Record without remotePath
      final fakePath2 = p.join(
        tempBaseDir.path,
        'app_storage',
        'attachments',
        'att-missing-2',
        'local_only.pdf',
      );
      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: 'att-missing-2',
              parentType: 'card',
              parentId: 'card-1',
              fileName: 'local_only.pdf',
              localPath: fakePath2,
              sizeBytes: 2048,
              isCache: const Value(false),
              transferState: const Value('pendingUpload'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final result = await repository.reconcile();

      expect(result.missingFilesHandled, 2);

      final row1 = await (db.select(
        db.attachments,
      )..where((tbl) => tbl.id.equals('att-missing-1'))).getSingle();
      expect(row1.localPath, isEmpty);
      expect(row1.isCache, isFalse);
      expect(row1.transferState, 'remoteOnly');

      final row2 = await (db.select(
        db.attachments,
      )..where((tbl) => tbl.id.equals('att-missing-2'))).getSingle();
      expect(row2.localPath, isEmpty);
      expect(row2.isCache, isFalse);
      expect(row2.transferState, 'localOnly');
    },
  );

  test(
    'reconciliation removes physical files for tombstoned DB records and clears DB path',
    () async {
      final sampleFile = File(p.join(tempBaseDir.path, 'sample.txt'))
        ..writeAsStringSync('tombstone content');
      final stored = await storage.persist(
        sampleFile,
        attachmentId: 'att-tombstone',
      );
      expect(File(stored.localPath).existsSync(), isTrue);

      final now = clock.nowUtc();
      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: 'att-tombstone',
              parentType: 'note',
              parentId: 'note-1',
              fileName: stored.fileName,
              localPath: stored.localPath,
              sizeBytes: stored.sizeBytes,
              isCache: const Value(false),
              transferState: const Value('synced'),
              createdAt: now,
              updatedAt: now,
              deletedAt: Value(now),
            ),
          );

      final result = await repository.reconcile();

      expect(result.tombstonesCleaned, 1);
      expect(File(stored.localPath).existsSync(), isFalse);

      final row = await (db.select(
        db.attachments,
      )..where((tbl) => tbl.id.equals('att-tombstone'))).getSingle();
      expect(row.localPath, isEmpty);
    },
  );

  test(
    'reconciliation detects and deletes orphaned files in attachments and cache directories',
    () async {
      // Legitimate active file in DB
      final validFile = File(p.join(tempBaseDir.path, 'valid.txt'))
        ..writeAsStringSync('valid active attachment');
      final validStored = await storage.persist(
        validFile,
        attachmentId: 'att-valid',
      );
      final now = clock.nowUtc();
      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: 'att-valid',
              parentType: 'note',
              parentId: 'note-1',
              fileName: validStored.fileName,
              localPath: validStored.localPath,
              sizeBytes: validStored.sizeBytes,
              isCache: const Value(false),
              transferState: const Value('synced'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Orphaned file in attachments bucket
      final orphanOwnedDir = Directory(
        p.join(tempBaseDir.path, 'app_storage', 'attachments', 'orphan-owned'),
      )..createSync(recursive: true);
      final orphanOwnedFile = File(p.join(orphanOwnedDir.path, 'untracked.bin'))
        ..writeAsBytesSync(<int>[1, 2, 3, 4, 5]);

      // Orphaned file in cache bucket
      final orphanCacheDir = Directory(
        p.join(tempBaseDir.path, 'app_storage', 'cache', 'orphan-cache'),
      )..createSync(recursive: true);
      final orphanCacheFile = File(
        p.join(orphanCacheDir.path, 'stale_cache.dat'),
      )..writeAsBytesSync(<int>[6, 7, 8, 9]);

      expect(orphanOwnedFile.existsSync(), isTrue);
      expect(orphanCacheFile.existsSync(), isTrue);
      expect(File(validStored.localPath).existsSync(), isTrue);

      final result = await repository.reconcile();

      expect(result.orphanedFilesDeleted, 2);
      expect(orphanOwnedFile.existsSync(), isFalse);
      expect(orphanCacheFile.existsSync(), isFalse);
      expect(orphanOwnedDir.existsSync(), isFalse);
      expect(orphanCacheDir.existsSync(), isFalse);
      expect(File(validStored.localPath).existsSync(), isTrue);
    },
  );

  test('reconciliation cleans up incomplete temporary downloads', () async {
    final tempDownloadsDir = Directory(
      p.join(tempBaseDir.path, 'not_attachment_downloads', 'dl-part-1'),
    )..createSync(recursive: true);
    final tempPartialFile = File(p.join(tempDownloadsDir.path, 'partial.tmp'))
      ..writeAsStringSync('half downloaded data');

    expect(tempPartialFile.existsSync(), isTrue);

    final result = await repository.reconcile();

    expect(result.tempFilesCleaned, 1);
    expect(tempPartialFile.existsSync(), isFalse);
  });

  test(
    'path traversal protection: reconciliation and storage refuse to touch files outside sandbox',
    () async {
      final outsideDir = Directory(p.join(tempBaseDir.path, 'outside_system'))
        ..createSync(recursive: true);
      final sensitiveFile = File(
        p.join(outsideDir.path, 'sensitive_passwords.txt'),
      )..writeAsStringSync('super_secret_data');

      expect(sensitiveFile.existsSync(), isTrue);

      // Try path traversal with relative ../..
      final traversalPath = p.join(
        tempBaseDir.path,
        'app_storage',
        'attachments',
        '..',
        '..',
        'outside_system',
        'sensitive_passwords.txt',
      );

      final now = clock.nowUtc();
      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: 'att-malicious',
              parentType: 'note',
              parentId: 'note-1',
              fileName: 'sensitive_passwords.txt',
              localPath: traversalPath,
              sizeBytes: 123,
              isCache: const Value(false),
              transferState: const Value('synced'),
              createdAt: now,
              updatedAt: now,
              deletedAt: Value(now), // Tombstoned to try to trigger deletion
            ),
          );

      await repository.reconcile();

      // Sensitive file outside sandbox MUST remain intact!
      expect(sensitiveFile.existsSync(), isTrue);
      expect(sensitiveFile.readAsStringSync(), 'super_secret_data');

      // DB record should have its illegal localPath cleared
      final row = await (db.select(
        db.attachments,
      )..where((tbl) => tbl.id.equals('att-malicious'))).getSingle();
      expect(row.localPath, isEmpty);

      // Calling deleteOwned on an external path directly must throw FileSystemException
      expect(
        () => storage.deleteOwned(sensitiveFile.path),
        throwsA(isA<FileSystemException>()),
      );
      expect(sensitiveFile.existsSync(), isTrue);
    },
  );
}
