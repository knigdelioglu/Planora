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

  void set(DateTime time) {
    _now = time;
  }
}

final class _FakeRemoteGateway implements RemoteGateway {
  _FakeRemoteGateway();

  @override
  final bool available = true;

  @override
  final String? userId = 'test-user';

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
  }) async {}

  @override
  Future<void> deleteAttachment(String remotePath) async {}

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
    tempBaseDir = Directory.systemTemp.createTempSync('not_lru_test_');
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
    'LRU eviction order is strictly determined by DB lastAccessedAt (not file mtime)',
    () async {
      final t0 = DateTime.utc(2026, 8, 16, 10, 0);
      final t1 = DateTime.utc(2026, 8, 16, 11, 0);
      final t2 = DateTime.utc(2026, 8, 16, 12, 0);

      // Create 3 cache files on disk (100 bytes each)
      final fileA = File(p.join(tempBaseDir.path, 'fileA.bin'))
        ..writeAsBytesSync(List.filled(100, 1));
      final fileB = File(p.join(tempBaseDir.path, 'fileB.bin'))
        ..writeAsBytesSync(List.filled(100, 2));
      final fileC = File(p.join(tempBaseDir.path, 'fileC.bin'))
        ..writeAsBytesSync(List.filled(100, 3));

      final storedA = await storage.persistCache(fileA, attachmentId: 'att-A');
      final storedB = await storage.persistCache(fileB, attachmentId: 'att-B');
      final storedC = await storage.persistCache(fileC, attachmentId: 'att-C');

      // Insert into DB with distinct lastAccessedAt:
      // A -> lastAccessedAt: t2 (Most recently used, even though created first)
      // B -> lastAccessedAt: t0 (Least recently used / oldest access)
      // C -> lastAccessedAt: t1 (Middle access)
      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: 'att-A',
              parentType: 'note',
              parentId: 'note-1',
              fileName: storedA.fileName,
              localPath: storedA.localPath,
              remotePath: const Value('remote/att-A.bin'),
              sizeBytes: 100,
              isCache: const Value(true),
              lastAccessedAt: Value(t2),
              transferState: const Value('synced'),
              createdAt: t0,
              updatedAt: t0,
            ),
          );

      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: 'att-B',
              parentType: 'note',
              parentId: 'note-1',
              fileName: storedB.fileName,
              localPath: storedB.localPath,
              remotePath: const Value('remote/att-B.bin'),
              sizeBytes: 100,
              isCache: const Value(true),
              lastAccessedAt: Value(t0), // Oldest accessed!
              transferState: const Value('synced'),
              createdAt: t0,
              updatedAt: t0,
            ),
          );

      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: 'att-C',
              parentType: 'note',
              parentId: 'note-1',
              fileName: storedC.fileName,
              localPath: storedC.localPath,
              remotePath: const Value('remote/att-C.bin'),
              sizeBytes: 100,
              isCache: const Value(true),
              lastAccessedAt: Value(t1),
              transferState: const Value('synced'),
              createdAt: t0,
              updatedAt: t0,
            ),
          );

      expect(await repository.cacheSizeBytes(), 300);

      // Evict down to 200 bytes -> exactly 1 item should be evicted: att-B (oldest lastAccessedAt)
      await repository.evictCacheUntil(200);

      expect(File(storedB.localPath).existsSync(), isFalse);
      expect(File(storedA.localPath).existsSync(), isTrue);
      expect(File(storedC.localPath).existsSync(), isTrue);

      final rowB = await (db.select(
        db.attachments,
      )..where((tbl) => tbl.id.equals('att-B'))).getSingle();
      expect(rowB.localPath, isEmpty);
      expect(rowB.isCache, isFalse);
      expect(rowB.transferState, 'remoteOnly');

      final rowA = await (db.select(
        db.attachments,
      )..where((tbl) => tbl.id.equals('att-A'))).getSingle();
      expect(rowA.localPath, isNotEmpty);
      expect(rowA.isCache, isTrue);

      // Evict down to 100 bytes -> next oldest is att-C
      await repository.evictCacheUntil(100);

      expect(File(storedC.localPath).existsSync(), isFalse);
      expect(File(storedA.localPath).existsSync(), isTrue);

      final rowC = await (db.select(
        db.attachments,
      )..where((tbl) => tbl.id.equals('att-C'))).getSingle();
      expect(rowC.localPath, isEmpty);
      expect(rowC.isCache, isFalse);
      expect(rowC.transferState, 'remoteOnly');
    },
  );

  test('eviction treats null lastAccessedAt as oldest', () async {
    final t1 = DateTime.utc(2026, 8, 16, 12, 0);

    final fileNull = File(p.join(tempBaseDir.path, 'null_access.bin'))
      ..writeAsBytesSync(List.filled(100, 1));
    final fileRecent = File(p.join(tempBaseDir.path, 'recent_access.bin'))
      ..writeAsBytesSync(List.filled(100, 2));

    final storedNull = await storage.persistCache(
      fileNull,
      attachmentId: 'att-null',
    );
    final storedRecent = await storage.persistCache(
      fileRecent,
      attachmentId: 'att-recent',
    );

    await db
        .into(db.attachments)
        .insert(
          AttachmentsCompanion.insert(
            id: 'att-null',
            parentType: 'note',
            parentId: 'note-1',
            fileName: storedNull.fileName,
            localPath: storedNull.localPath,
            remotePath: const Value('remote/null.bin'),
            sizeBytes: 100,
            isCache: const Value(true),
            lastAccessedAt: const Value(
              null,
            ), // Never accessed after initial pull
            transferState: const Value('synced'),
            createdAt: t1,
            updatedAt: t1,
          ),
        );

    await db
        .into(db.attachments)
        .insert(
          AttachmentsCompanion.insert(
            id: 'att-recent',
            parentType: 'note',
            parentId: 'note-1',
            fileName: storedRecent.fileName,
            localPath: storedRecent.localPath,
            remotePath: const Value('remote/recent.bin'),
            sizeBytes: 100,
            isCache: const Value(true),
            lastAccessedAt: Value(t1),
            transferState: const Value('synced'),
            createdAt: t1,
            updatedAt: t1,
          ),
        );

    await repository.evictCacheUntil(100);

    expect(File(storedNull.localPath).existsSync(), isFalse);
    expect(File(storedRecent.localPath).existsSync(), isTrue);
  });

  test(
    'owned attachments (isCache == false) are never evicted by cache eviction',
    () async {
      final now = clock.nowUtc();
      final ownedFile = File(p.join(tempBaseDir.path, 'owned.png'))
        ..writeAsBytesSync(List.filled(200, 9));
      final storedOwned = await storage.persist(
        ownedFile,
        attachmentId: 'att-owned',
      );

      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: 'att-owned',
              parentType: 'note',
              parentId: 'note-1',
              fileName: storedOwned.fileName,
              localPath: storedOwned.localPath,
              remotePath: const Value('remote/owned.png'),
              sizeBytes: 200,
              isCache: const Value(false), // Owned, not cache!
              lastAccessedAt: Value(
                DateTime.utc(2020, 1, 1),
              ), // Very old access
              transferState: const Value('synced'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Evict cache to 0 bytes
      await repository.evictCacheUntil(0);

      // Owned file must NOT be evicted!
      expect(File(storedOwned.localPath).existsSync(), isTrue);
      final row = await (db.select(
        db.attachments,
      )..where((tbl) => tbl.id.equals('att-owned'))).getSingle();
      expect(row.localPath, storedOwned.localPath);
      expect(row.isCache, isFalse);
    },
  );

  test(
    'graceful eviction when physical cache file was already removed from disk',
    () async {
      final now = clock.nowUtc();
      final fakePath = p.join(
        tempBaseDir.path,
        'app_storage',
        'cache',
        'att-missing',
        'gone.bin',
      );

      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: 'att-missing',
              parentType: 'note',
              parentId: 'note-1',
              fileName: 'gone.bin',
              localPath: fakePath,
              remotePath: const Value('remote/gone.bin'),
              sizeBytes: 500,
              isCache: const Value(true),
              lastAccessedAt: Value(now),
              transferState: const Value('synced'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Should not throw even though file does not exist on disk
      await repository.evictCacheUntil(0);

      final row = await (db.select(
        db.attachments,
      )..where((tbl) => tbl.id.equals('att-missing'))).getSingle();
      expect(row.localPath, isEmpty);
      expect(row.isCache, isFalse);
      expect(row.transferState, 'remoteOnly');
    },
  );

  test('ensureLocal updates lastAccessedAt on existing local file', () async {
    final t0 = DateTime.utc(2026, 8, 16, 10, 0);
    final t1 = DateTime.utc(2026, 8, 16, 15, 0);

    final sampleFile = File(p.join(tempBaseDir.path, 'test_touch.txt'))
      ..writeAsStringSync('touch me');
    final stored = await storage.persist(sampleFile, attachmentId: 'att-touch');

    await db
        .into(db.attachments)
        .insert(
          AttachmentsCompanion.insert(
            id: 'att-touch',
            parentType: 'note',
            parentId: 'note-1',
            fileName: stored.fileName,
            localPath: stored.localPath,
            sizeBytes: stored.sizeBytes,
            isCache: const Value(false),
            lastAccessedAt: Value(t0),
            transferState: const Value('synced'),
            createdAt: t0,
            updatedAt: t0,
          ),
        );

    clock.set(t1);

    final file = await repository.ensureLocal('att-touch');
    expect(file.path, stored.localPath);

    final row = await (db.select(
      db.attachments,
    )..where((tbl) => tbl.id.equals('att-touch'))).getSingle();
    expect(row.lastAccessedAt?.toUtc(), t1);
  });
}
