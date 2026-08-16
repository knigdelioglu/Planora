import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/logging/app_logger.dart';
import 'package:not_app/core/remote/remote_gateway.dart';
import 'package:not_app/core/remote/remote_models.dart';
import 'package:not_app/core/services/file_storage_service.dart';
import 'package:not_app/core/sync/local_entity_store.dart';
import 'package:not_app/core/sync/sync_engine.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/attachments/data/repositories/attachments_repository_impl.dart';
import 'package:not_app/features/attachments/domain/entities/attachment.dart';
import 'package:not_app/features/attachments/presentation/attachments_section.dart';
import 'package:not_app/features/conflicts/domain/entities/sync_conflict.dart';
import 'package:not_app/features/conflicts/domain/repositories/conflict_repository.dart';
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

final class _ResilientFakeRemoteGateway implements RemoteGateway {
  _ResilientFakeRemoteGateway();

  @override
  bool available = true;

  @override
  final String? userId = 'user-resilience-test';

  final Map<String, String> uploadedBlobs = <String, String>{};
  final List<String> uploadAttempts = <String>[];
  bool failNextUpload = false;
  Exception? uploadException;

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
    uploadAttempts.add(remotePath);
    if (failNextUpload) {
      failNextUpload = false;
      throw uploadException ??
          const SocketException('Network unreachable during upload');
    }
    uploadedBlobs[remotePath] = file.path;
  }

  @override
  Future<void> deleteAttachment(String remotePath) async {
    uploadedBlobs.remove(remotePath);
  }

  @override
  Future<String> createAttachmentDownloadUrl(String remotePath) async =>
      'https://example.com/download/$remotePath';
}

final class _FakeConflictRepository implements ConflictRepository {
  @override
  Stream<List<SyncConflictEntity>> watchOpen() =>
      Stream<List<SyncConflictEntity>>.value(const <SyncConflictEntity>[]);

  @override
  Future<String> record({
    required String entityType,
    required String entityId,
    required Map<String, Object?> local,
    required RemoteEntity remote,
  }) async => 'conflict-1';

  @override
  Future<void> resolveUsingLocal(String conflictId) async {}

  @override
  Future<void> resolveUsingRemote(String conflictId) async {}

  @override
  Future<void> resolveAsCopy(String conflictId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBaseDir;
  late AppDatabase db;
  late _TestClock clock;
  late SandboxFileStorageService storage;
  late DriftSyncQueueRepository queue;
  late _ResilientFakeRemoteGateway remote;
  late LocalEntityStore localStore;
  late _FakeConflictRepository conflicts;
  late AppLogger logger;
  late SyncEngine syncEngine;
  late DriftAttachmentsRepository repository;

  setUp(() async {
    tempBaseDir = Directory.systemTemp.createTempSync('not_transfer_test_');
    db = AppDatabase(NativeDatabase.memory());
    clock = _TestClock(DateTime.utc(2026, 8, 16, 12));
    storage = SandboxFileStorageService(
      rootDirectoryProvider: () async => tempBaseDir,
      tempDirectoryProvider: () async => tempBaseDir,
    );
    queue = DriftSyncQueueRepository(database: db, clock: clock);
    remote = _ResilientFakeRemoteGateway();
    localStore = LocalEntityStore(database: db, clock: clock);
    conflicts = _FakeConflictRepository();
    logger = const AppLogger();
    syncEngine = SyncEngine(
      database: db,
      queue: queue,
      remote: remote,
      localStore: localStore,
      conflicts: conflicts,
      clock: clock,
      logger: logger,
    );
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

  group('Kabul Kriteri 1: Upload Kesinti & Idempotency', () {
    test(
      'upload fails on network error, marks retryWaiting, retries to exact same remotePath without duplicate objects',
      () async {
        final sampleFile = File(p.join(tempBaseDir.path, 'doc.pdf'))
          ..writeAsStringSync('pdf content 123');
        final entity = await repository.addFromFile(
          parentType: 'note',
          parentId: 'note-100',
          source: sampleFile,
        );

        expect(entity.transferState, 'pendingUpload');

        // Simulate network failure during upload
        remote.failNextUpload = true;
        remote.uploadException = const SocketException(
          'Connection reset by peer',
        );

        await syncEngine.runOnce();

        // Verify attachment row is set to retryWaiting and syncQueue has retry
        final failedRow = await (db.select(
          db.attachments,
        )..where((tbl) => tbl.id.equals(entity.id))).getSingle();
        expect(failedRow.transferState, 'retryWaiting');
        expect(failedRow.remotePath, isNull);

        final pendingOps = await queue.dueOperations();
        expect(pendingOps, isEmpty); // not due yet because of backoff

        // Now advance clock and retry
        clock.advance(const Duration(minutes: 5));
        final dueOps = await queue.dueOperations();
        expect(dueOps, isNotEmpty);

        final run2 = await syncEngine.runOnce();
        expect(run2.pushed, greaterThan(0));

        final syncedRow = await (db.select(
          db.attachments,
        )..where((tbl) => tbl.id.equals(entity.id))).getSingle();
        expect(syncedRow.transferState, 'synced');
        expect(
          syncedRow.remotePath,
          'user-resilience-test/${entity.id}/doc.pdf',
        );

        // Verify deterministic path: both upload attempts used the EXACT same path
        expect(remote.uploadAttempts.length, 2);
        expect(
          remote.uploadAttempts[0],
          'user-resilience-test/${entity.id}/doc.pdf',
        );
        expect(
          remote.uploadAttempts[1],
          'user-resilience-test/${entity.id}/doc.pdf',
        );
        expect(remote.uploadedBlobs.keys.length, 1);
        expect(
          remote.uploadedBlobs.keys.first,
          'user-resilience-test/${entity.id}/doc.pdf',
        );
      },
    );

    test(
      'lost ACK recovery: when remote blob exists but local retry occurs, metadata transaction stays consistent',
      () async {
        final sampleFile = File(p.join(tempBaseDir.path, 'image.png'))
          ..writeAsBytesSync(<int>[137, 80, 78, 71, 13, 10, 26, 10]);
        final entity = await repository.addFromFile(
          parentType: 'card',
          parentId: 'card-200',
          source: sampleFile,
        );

        // Pre-populate remote blob as if upload reached server but ACK was dropped
        final expectedRemotePath =
            'user-resilience-test/${entity.id}/image.png';
        remote.uploadedBlobs[expectedRemotePath] = sampleFile.path;

        await syncEngine.runOnce();

        final syncedRow = await (db.select(
          db.attachments,
        )..where((tbl) => tbl.id.equals(entity.id))).getSingle();
        expect(syncedRow.transferState, 'synced');
        expect(syncedRow.remotePath, expectedRemotePath);
        expect(remote.uploadedBlobs.length, 1);
      },
    );
  });

  group('Kabul Kriteri 2: Download Kesinti & Temizlik Güvenliği', () {
    test(
      'download network failure cleans up partial temp files and keeps DB localPath clean without storing broken path',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://mock.local'));
        dio.httpClientAdapter = _FailingHttpClientAdapter(
          failWith: const SocketException('Connection terminated midway'),
        );

        final customRepo = DriftAttachmentsRepository(
          database: db,
          storage: storage,
          syncQueue: queue,
          clock: clock,
          remote: remote,
          dio: dio,
          tempDirectoryProvider: () async => tempBaseDir,
        );

        final now = clock.nowUtc();
        const attId = 'att-broken-dl-1';
        await db
            .into(db.attachments)
            .insert(
              AttachmentsCompanion.insert(
                id: attId,
                parentType: 'note',
                parentId: 'note-1',
                fileName: 'large_video.mp4',
                localPath: '',
                remotePath: const Value(
                  'user-resilience-test/att-broken-dl-1/large_video.mp4',
                ),
                sizeBytes: 10485760,
                isCache: const Value(false),
                transferState: const Value('remoteOnly'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        await expectLater(
          customRepo.ensureLocal(attId),
          throwsA(isA<DioException>()),
        );

        // Verify DB record has not stored broken path
        final row = await (db.select(
          db.attachments,
        )..where((tbl) => tbl.id.equals(attId))).getSingle();
        expect(row.localPath, isEmpty);
        expect(row.isCache, isFalse);
        expect(row.transferState, 'failed');

        // Verify no leftover partial files in temp directory
        final tempDownloadsDir = Directory(
          p.join(tempBaseDir.path, 'not_attachment_downloads'),
        );
        if (tempDownloadsDir.existsSync()) {
          final tempFiles = tempDownloadsDir
              .listSync(recursive: true)
              .whereType<File>()
              .toList();
          expect(tempFiles, isEmpty);
        }
      },
    );
  });

  group('Kabul Kriteri 3: Transfer Durumları ve Progress UX', () {
    test('AttachmentEntity getters and localized status labels', () {
      final now = DateTime.utc(2026, 8, 16);
      AttachmentEntity createWithState(String state) => AttachmentEntity(
        id: 'att-1',
        parentType: 'note',
        parentId: 'n1',
        fileName: 'test.png',
        localPath: state == 'synced' || state == 'localOnly'
            ? '/path/test.png'
            : '',
        remotePath: state != 'localOnly' ? 'user/n1/test.png' : null,
        sizeBytes: 102400,
        createdAt: now,
        updatedAt: now,
        version: 1,
        isCache: false,
        transferState: state,
      );

      final uploading = createWithState('uploading');
      expect(uploading.isUploading, isTrue);
      expect(uploading.isTransferring, isTrue);
      expect(uploading.transferStatusLabel(0.45), 'Yükleniyor (%45)');
      expect(uploading.transferStatusLabel(null), 'Yükleniyor');

      final downloading = createWithState('downloading');
      expect(downloading.isDownloading, isTrue);
      expect(downloading.isTransferring, isTrue);
      expect(downloading.transferStatusLabel(0.80), 'İndiriliyor (%80)');

      final pending = createWithState('pendingUpload');
      expect(pending.isPending, isTrue);
      expect(pending.transferStatusLabel(), 'Bekliyor');

      final failed = createWithState('failed');
      expect(failed.isFailed, isTrue);
      expect(failed.canRetry, isTrue);
      expect(failed.transferStatusLabel(), 'Başarısız');

      final retryWaiting = createWithState('retryWaiting');
      expect(retryWaiting.isRetryPending, isTrue);
      expect(retryWaiting.canRetry, isTrue);
      expect(retryWaiting.transferStatusLabel(), 'Tekrar denenecek');

      final synced = createWithState('synced');
      expect(synced.isSynced, isTrue);
      expect(synced.transferStatusLabel(), 'Tamamlandı');
    });

    test('DriftAttachmentsRepository streams live transfer progress', () async {
      final dio = Dio();
      dio.httpClientAdapter = _ChunkedProgressHttpClientAdapter(
        totalBytes: 1000,
        chunkBytes: 250,
      );

      final customRepo = DriftAttachmentsRepository(
        database: db,
        storage: storage,
        syncQueue: queue,
        clock: clock,
        remote: remote,
        dio: dio,
        tempDirectoryProvider: () async => tempBaseDir,
      );

      final List<AttachmentTransferProgress> progressEvents =
          <AttachmentTransferProgress>[];
      final subscription = customRepo
          .watchProgress('att-stream-1')
          .listen(progressEvents.add);

      final now = clock.nowUtc();
      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: 'att-stream-1',
              parentType: 'note',
              parentId: 'note-1',
              fileName: 'stream_test.dat',
              localPath: '',
              remotePath: const Value('user/att-stream-1/stream_test.dat'),
              sizeBytes: 1000,
              isCache: const Value(false),
              transferState: const Value('remoteOnly'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final file = await customRepo.ensureLocal('att-stream-1');
      expect(await file.exists(), isTrue);

      await subscription.cancel();
      expect(progressEvents, isNotEmpty);
      expect(progressEvents.any((e) => e.progress == 1.0), isTrue);
    });
  });

  group('Kabul Kriteri 4: CancelToken ile Güvenli İptal', () {
    test(
      'CancelToken safely cancels in-flight download, cleans temp files, and updates DB without blocking',
      () async {
        final cancelToken = CancelToken();
        final dio = Dio();
        dio.httpClientAdapter = _DelayedCancelableHttpClientAdapter(
          delay: const Duration(milliseconds: 200),
        );

        final customRepo = DriftAttachmentsRepository(
          database: db,
          storage: storage,
          syncQueue: queue,
          clock: clock,
          remote: remote,
          dio: dio,
          tempDirectoryProvider: () async => tempBaseDir,
        );

        final now = clock.nowUtc();
        const attId = 'att-cancel-test-1';
        await db
            .into(db.attachments)
            .insert(
              AttachmentsCompanion.insert(
                id: attId,
                parentType: 'note',
                parentId: 'note-1',
                fileName: 'cancel_me.mp4',
                localPath: '',
                remotePath: const Value('user/att-cancel-test-1/cancel_me.mp4'),
                sizeBytes: 50000,
                isCache: const Value(false),
                transferState: const Value('remoteOnly'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        final Future<File> downloadFuture = customRepo.ensureLocal(
          attId,
          cancelToken: cancelToken,
        );

        // Cancel mid-flight
        await Future<void>.delayed(const Duration(milliseconds: 30));
        cancelToken.cancel('User cancelled download');

        await expectLater(
          downloadFuture,
          throwsA(
            predicate((e) => e is DioException && CancelToken.isCancel(e)),
          ),
        );

        final row = await (db.select(
          db.attachments,
        )..where((tbl) => tbl.id.equals(attId))).getSingle();
        expect(row.localPath, isEmpty);
        expect(row.transferState, 'failed');

        // Verify temp dir cleanup
        final tempDownloadsDir = Directory(
          p.join(tempBaseDir.path, 'not_attachment_downloads', attId),
        );
        expect(tempDownloadsDir.existsSync(), isFalse);
      },
    );

    test(
      'cancelTransfer() method cancels active transfer and updates DB state immediately',
      () async {
        final dio = Dio();
        dio.httpClientAdapter = _DelayedCancelableHttpClientAdapter(
          delay: const Duration(milliseconds: 300),
        );

        final customRepo = DriftAttachmentsRepository(
          database: db,
          storage: storage,
          syncQueue: queue,
          clock: clock,
          remote: remote,
          dio: dio,
          tempDirectoryProvider: () async => tempBaseDir,
        );

        final now = clock.nowUtc();
        const attId = 'att-cancel-method-test';
        await db
            .into(db.attachments)
            .insert(
              AttachmentsCompanion.insert(
                id: attId,
                parentType: 'card',
                parentId: 'card-1',
                fileName: 'method_cancel.zip',
                localPath: '',
                remotePath: const Value(
                  'user/att-cancel-method-test/method_cancel.zip',
                ),
                sizeBytes: 80000,
                isCache: const Value(false),
                transferState: const Value('remoteOnly'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        final Future<File> downloadFuture = customRepo.ensureLocal(attId);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        customRepo.cancelTransfer(attId);

        await expectLater(
          downloadFuture,
          throwsA(
            predicate((e) => e is DioException && CancelToken.isCancel(e)),
          ),
        );

        final row = await (db.select(
          db.attachments,
        )..where((tbl) => tbl.id.equals(attId))).getSingle();
        expect(row.transferState, 'failed');
      },
    );
  });

  group('Kabul Kriteri 5: Tek Tıkla "Tekrar Dene" Aksiyonu', () {
    test(
      'retryTransfer() for failed upload resets syncQueue to pending and allows successful upload',
      () async {
        final sampleFile = File(p.join(tempBaseDir.path, 'retry_doc.txt'))
          ..writeAsStringSync('retry content');
        final entity = await repository.addFromFile(
          parentType: 'note',
          parentId: 'note-retry',
          source: sampleFile,
        );

        // Simulate failure on initial upload
        remote.failNextUpload = true;
        await syncEngine.runOnce();

        final failedRow = await (db.select(
          db.attachments,
        )..where((tbl) => tbl.id.equals(entity.id))).getSingle();
        expect(failedRow.transferState, 'retryWaiting');

        // User triggers single-click retry action
        await repository.retryTransfer(entity.id);

        final pendingRow = await (db.select(
          db.attachments,
        )..where((tbl) => tbl.id.equals(entity.id))).getSingle();
        expect(pendingRow.transferState, 'pendingUpload');

        // SyncEngine runs and succeeds
        final run = await syncEngine.runOnce();
        expect(run.pushed, 1);

        final syncedRow = await (db.select(
          db.attachments,
        )..where((tbl) => tbl.id.equals(entity.id))).getSingle();
        expect(syncedRow.transferState, 'synced');
        expect(syncedRow.remotePath, isNotNull);
      },
    );

    test(
      'retryTransfer() for failed download restarts download and completes successfully',
      () async {
        final now = clock.nowUtc();
        const attId = 'att-retry-dl-1';
        await db
            .into(db.attachments)
            .insert(
              AttachmentsCompanion.insert(
                id: attId,
                parentType: 'note',
                parentId: 'note-1',
                fileName: 'retry_download.txt',
                localPath: '',
                remotePath: const Value(
                  'user/att-retry-dl-1/retry_download.txt',
                ),
                sizeBytes: 50,
                isCache: const Value(false),
                transferState: const Value('failed'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        final dio = Dio();
        dio.httpClientAdapter = _ChunkedProgressHttpClientAdapter(
          totalBytes: 50,
          chunkBytes: 50,
        );

        final customRepo = DriftAttachmentsRepository(
          database: db,
          storage: storage,
          syncQueue: queue,
          clock: clock,
          remote: remote,
          dio: dio,
          tempDirectoryProvider: () async => tempBaseDir,
        );

        await customRepo.retryTransfer(attId);

        final row = await (db.select(
          db.attachments,
        )..where((tbl) => tbl.id.equals(attId))).getSingle();
        expect(row.transferState, 'synced');
        expect(row.localPath, isNotEmpty);
        expect(File(row.localPath).existsSync(), isTrue);
      },
    );
  });

  group('Widget UX Testleri: AttachmentsSection & Actions', () {
    testWidgets(
      'AttachmentsSection displays states and triggers retry and cancel actions',
      (tester) async {
        final now = clock.nowUtc();

        // Insert 3 attachments with different states: 1 transferring, 1 failed, 1 synced
        await db
            .into(db.attachments)
            .insert(
              AttachmentsCompanion.insert(
                id: 'att-ui-1',
                parentType: 'card',
                parentId: 'card-ui-test',
                fileName: 'uploading_image.png',
                localPath: '/tmp/uploading_image.png',
                mimeType: const Value('image/png'),
                sizeBytes: 204800,
                isCache: const Value(false),
                transferState: const Value('uploading'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.attachments)
            .insert(
              AttachmentsCompanion.insert(
                id: 'att-ui-2',
                parentType: 'card',
                parentId: 'card-ui-test',
                fileName: 'failed_file.pdf',
                localPath: '',
                remotePath: const Value('user/card-ui-test/failed_file.pdf'),
                mimeType: const Value('application/pdf'),
                sizeBytes: 512000,
                isCache: const Value(false),
                transferState: const Value('failed'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.attachments)
            .insert(
              AttachmentsCompanion.insert(
                id: 'att-ui-3',
                parentType: 'card',
                parentId: 'card-ui-test',
                fileName: 'completed_doc.docx',
                localPath: '/tmp/completed_doc.docx',
                sizeBytes: 102400,
                isCache: const Value(false),
                transferState: const Value('synced'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              attachmentsRepositoryProvider.overrideWithValue(repository),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: AttachmentsSection(
                  parentType: 'card',
                  parentId: 'card-ui-test',
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Verify filenames rendered
        expect(find.text('uploading_image.png'), findsOneWidget);
        expect(find.text('failed_file.pdf'), findsOneWidget);
        expect(find.text('completed_doc.docx'), findsOneWidget);

        // Verify status subtitles rendered
        expect(find.textContaining('Yükleniyor'), findsOneWidget);
        expect(find.textContaining('Başarısız'), findsOneWidget);
        expect(find.textContaining('Tamamlandı'), findsOneWidget);

        // Verify transfer progress indicator rendered for uploading item
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        // Verify Cancel action button exists for uploading item
        expect(find.byTooltip('İptal et'), findsOneWidget);

        // Verify "Tekrar dene" action button exists for failed item
        expect(find.byTooltip('Tekrar dene'), findsOneWidget);

        // Tap "Tekrar dene" button
        await tester.tap(find.byTooltip('Tekrar dene'));
        await tester.pump();

        // Tap "İptal et" button
        await tester.tap(find.byTooltip('İptal et'));
        await tester.pump();

        // Clean unmount of widget tree and settle internal timers
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });
}

// Helpers for Mock Dio Adapters
final class _FailingHttpClientAdapter implements HttpClientAdapter {
  _FailingHttpClientAdapter({required this.failWith});
  final Exception failWith;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      error: failWith,
      type: DioExceptionType.connectionError,
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _DelayedCancelableHttpClientAdapter implements HttpClientAdapter {
  _DelayedCancelableHttpClientAdapter({required this.delay});
  final Duration delay;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final completer = Completer<ResponseBody>();
    unawaited(
      cancelFuture?.then((_) {
            if (!completer.isCompleted) {
              completer.completeError(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.cancel,
                  error: 'Operation cancelled',
                ),
              );
            }
          }) ??
          Future<void>.value(),
    );

    unawaited(
      Future<void>.delayed(delay).then((_) {
        if (!completer.isCompleted) {
          completer.complete(
            ResponseBody.fromBytes(
              <int>[1, 2, 3, 4, 5],
              200,
              headers: <String, List<String>>{
                Headers.contentLengthHeader: <String>['5'],
              },
            ),
          );
        }
      }),
    );

    return completer.future;
  }

  @override
  void close({bool force = false}) {}
}

final class _ChunkedProgressHttpClientAdapter implements HttpClientAdapter {
  _ChunkedProgressHttpClientAdapter({
    required this.totalBytes,
    required this.chunkBytes,
  });

  final int totalBytes;
  final int chunkBytes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final streamController = StreamController<Uint8List>();

    unawaited(() async {
      int sent = 0;
      while (sent < totalBytes) {
        final int currentChunk = (totalBytes - sent).clamp(1, chunkBytes);
        streamController.add(
          Uint8List.fromList(List<int>.filled(currentChunk, 65)),
        );
        sent += currentChunk;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await streamController.close();
    }());

    return ResponseBody(
      streamController.stream,
      200,
      headers: <String, List<String>>{
        Headers.contentLengthHeader: <String>[totalBytes.toString()],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
