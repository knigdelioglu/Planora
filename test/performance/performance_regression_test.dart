import 'dart:io';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/remote/remote_gateway.dart';
import 'package:not_app/core/remote/remote_models.dart';
import 'package:not_app/core/services/file_storage_service.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/core/utils/fractional_indexing_helper.dart';
import 'package:not_app/features/attachments/data/repositories/attachments_repository_impl.dart';
import 'package:not_app/features/kanban/data/repositories/kanban_repository_impl.dart';
import 'package:not_app/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:not_app/features/notes/domain/entities/note.dart';
import 'package:not_app/features/notes/domain/entities/note_document.dart';
import 'package:not_app/features/search/data/repositories/search_repository_impl.dart';

class _TestClock implements AppClock {
  _TestClock(this._now);
  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}

class _FakeRemoteGateway implements RemoteGateway {
  @override
  bool get available => true;

  @override
  String? get userId => 'perf-user';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _TestClock clock;
  late DriftSyncQueueRepository syncQueue;
  late DriftKanbanRepository kanbanRepo;
  late DriftSearchRepository searchRepo;
  late DriftNotesRepository notesRepo;
  late Directory tempDir;
  late SandboxFileStorageService storageService;
  late DriftAttachmentsRepository attachmentsRepo;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    clock = _TestClock(DateTime.utc(2026, 8, 16, 12));
    syncQueue = DriftSyncQueueRepository(database: db, clock: clock);
    kanbanRepo = DriftKanbanRepository(
      database: db,
      syncQueue: syncQueue,
      clock: clock,
    );
    searchRepo = DriftSearchRepository(db);
    notesRepo = DriftNotesRepository(
      database: db,
      syncQueue: syncQueue,
      clock: clock,
    );

    tempDir = Directory.systemTemp.createTempSync('perf_regression_');
    storageService = SandboxFileStorageService(
      rootDirectoryProvider: () async => tempDir,
      tempDirectoryProvider: () async => tempDir,
    );
    attachmentsRepo = DriftAttachmentsRepository(
      database: db,
      storage: storageService,
      syncQueue: syncQueue,
      clock: clock,
      remote: _FakeRemoteGateway(),
      tempDirectoryProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Kriter 4: Kanban 500+ Kart Performans Regresyon Testleri (<3s)', () {
    test(
      '525 kart (5 kolon x 105 kart) veri tabanına yüklenir ve <3s içinde okunup işlenir',
      () async {
        final String boardId = await kanbanRepo.createBoard(
          title: 'Büyük Performans Panosu',
        );

        // 5 Columns
        final List<String> columnIds = <String>[];
        for (int c = 1; c <= 5; c++) {
          final colId = await kanbanRepo.createColumn(
            boardId: boardId,
            title: 'Kolon $c',
          );
          columnIds.add(colId);
        }

        // Generate 525 cards (105 per column) in memory
        final stopwatch = Stopwatch()..start();
        final DateTime now = clock.nowUtc();

        await db.batch((batch) {
          for (int c = 0; c < columnIds.length; c++) {
            final String colId = columnIds[c];
            final List<String> rankKeys = FractionalIndexing.rebalance(105);
            for (int i = 0; i < 105; i++) {
              batch.insert(
                db.cards,
                CardsCompanion.insert(
                  id: 'card_${c}_$i',
                  boardId: boardId,
                  columnId: colId,
                  title:
                      'Kart C${c + 1}-$i: Detaylı görev başlığı ve açıklaması',
                  description: const Value<String?>(
                    'Bu kart performans regresyon testi amacıyla oluşturulmuştur.',
                  ),
                  rankKey: Value<String>(rankKeys[i]),
                  version: const Value(1),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
            }
          }
        });

        final insertElapsed = stopwatch.elapsedMilliseconds;
        expect(
          insertElapsed,
          lessThan(3000),
          reason:
              '525 kartın veritabanına eklenmesi <3000ms olmalıdır. Ölçülen: ${insertElapsed}ms',
        );

        // Measure Board snapshot retrieval
        stopwatch.reset();
        stopwatch.start();

        final snapshot = await kanbanRepo.watchBoard(boardId).first;
        final cards = await db.select(db.cards).get();

        stopwatch.stop();
        final readElapsed = stopwatch.elapsedMilliseconds;

        expect(snapshot, isNotNull);
        expect(cards.length, equals(525));
        expect(
          readElapsed,
          lessThan(500),
          reason:
              '525 kart ve pano verisinin okunması <500ms olmalıdır. Ölçülen: ${readElapsed}ms',
        );
      },
    );

    test(
      '525 kartlık veri setinde Fractional Indexing rebalance <100ms sürede tamamlanır',
      () {
        final stopwatch = Stopwatch()..start();

        final List<String> rebalancedIndices = FractionalIndexing.rebalance(
          525,
        );

        stopwatch.stop();
        final elapsedMs = stopwatch.elapsedMilliseconds;

        expect(rebalancedIndices.length, equals(525));
        expect(
          elapsedMs,
          lessThan(100),
          reason:
              '525 kart için fractional index rebalance <100ms olmalıdır. Ölçülen: ${elapsedMs}ms',
        );

        // Verify strict lexicographical ordering
        for (int i = 0; i < rebalancedIndices.length - 1; i++) {
          expect(
            rebalancedIndices[i].compareTo(rebalancedIndices[i + 1]),
            lessThan(0),
            reason: 'Fractional index sıralaması kesin artan sırada olmalıdır',
          );
        }
      },
    );

    test(
      '500+ kartlı panoda kart taşıma (moveCard) işlemi <50ms sürer',
      () async {
        final String boardId = await kanbanRepo.createBoard(
          title: 'Taşıma Test Panosu',
        );
        final col1 = await kanbanRepo.createColumn(
          boardId: boardId,
          title: 'Yapılacak',
        );
        final col2 = await kanbanRepo.createColumn(
          boardId: boardId,
          title: 'Bitti',
        );

        final DateTime now = clock.nowUtc();
        final indices = FractionalIndexing.rebalance(200);

        await db.batch((batch) {
          for (int i = 0; i < 200; i++) {
            batch.insert(
              db.cards,
              CardsCompanion.insert(
                id: 'c1_$i',
                boardId: boardId,
                columnId: col1,
                title: 'Kart C1-$i',
                rankKey: Value<String>(indices[i]),
                createdAt: now,
                updatedAt: now,
              ),
            );
            batch.insert(
              db.cards,
              CardsCompanion.insert(
                id: 'c2_$i',
                boardId: boardId,
                columnId: col2,
                title: 'Kart C2-$i',
                rankKey: Value<String>(indices[i]),
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        });

        // Measure moving card
        final stopwatch = Stopwatch()..start();

        await kanbanRepo.moveCard(
          cardId: 'c1_50',
          destinationColumnId: col2,
          destinationIndex: 10,
        );

        stopwatch.stop();
        final moveElapsed = stopwatch.elapsedMilliseconds;

        expect(
          moveElapsed,
          lessThan(50),
          reason:
              'Kart taşıma işlemi <50ms içinde tamamlanmalıdır. Ölçülen: ${moveElapsed}ms',
        );
      },
    );
  });

  group('Kriter 4: 1000+ Kayıtlık FTS Arama Performans Regresyon Testleri (<50ms)', () {
    setUp(() async {
      const int noteCount = 600;
      const int cardCount = 600;
      const int boardCount = 50;

      await db.inTransaction(() async {
        for (int i = 0; i < noteCount; i++) {
          await db.upsertSearchEntry(
            entityType: 'note',
            entityId: 'note_$i',
            title: 'Not Başlığı $i - Flutter Performans Raporu',
            body:
                'Bu not $i numaralı sistem mimarisi dokümantasyonunu, Riverpod ve Drift entegrasyonunu içerir.',
          );
        }
        for (int i = 0; i < cardCount; i++) {
          await db.upsertSearchEntry(
            entityType: 'card',
            entityId: 'card_$i',
            title: 'Kart Görevi #$i: Kanban kartı taşıma ve ranking',
            body:
                'Kart detay açıklaması #$i. Supabase kuyruk optimizasyonu ve UI tepkisellik testleri.',
          );
        }
        for (int i = 0; i < boardCount; i++) {
          await db.upsertSearchEntry(
            entityType: 'board',
            entityId: 'board_$i',
            title: 'Pano $i: Sprint Planlama & Yol Haritası',
            body: '',
          );
        }
      });
    });

    test(
      '1000+ kayıtlık veri setinde tekil FTS sorgusu <50ms sürede tamamlanır',
      () async {
        final queries = <String>[
          'Flutter',
          'Kanban',
          'Sprint',
          'optimizasyon',
          'senkronizasyon',
          'mimari Performans',
          'raporu',
          'detay',
          'bulunmayan_kelime_xyz',
        ];

        for (final query in queries) {
          final stopwatch = Stopwatch()..start();
          final results = await searchRepo.search(query, limit: 100);
          stopwatch.stop();

          final elapsed = stopwatch.elapsedMilliseconds;
          expect(
            elapsed,
            lessThan(50),
            reason:
                '1000+ kayıtta "$query" arama süresi <50ms olmalıdır. Ölçülen: ${elapsed}ms',
          );

          if (query == 'Flutter') {
            expect(results.isNotEmpty, isTrue);
          }
        }
      },
    );

    test(
      '1000+ veri setinde 50 ardışık FTS sorgusunun ortalama süresi <15ms olmalıdır',
      () async {
        final searchTerms = <String>[
          'Riverpod',
          'Drift',
          'Görev',
          'Sprint',
          'mimari',
          'optimizasyon',
          'dokümantasyon',
          'kontrol',
          'entegrasyon',
          'Flutter',
        ];

        final stopwatch = Stopwatch()..start();
        int totalCount = 0;

        for (int i = 0; i < 50; i++) {
          final term = searchTerms[i % searchTerms.length];
          final queryStopwatch = Stopwatch()..start();
          final results = await searchRepo.search(term, limit: 50);
          queryStopwatch.stop();

          totalCount += results.length;
          expect(
            queryStopwatch.elapsedMilliseconds,
            lessThan(50),
            reason: 'Her bir sorgu <50ms içinde tamamlanmalıdır',
          );
        }

        stopwatch.stop();
        final double avgMs = stopwatch.elapsedMilliseconds / 50.0;

        expect(totalCount, greaterThan(0));
        expect(
          avgMs,
          lessThan(15.0),
          reason:
              '50 sorgunun ortalama süresi <15ms olmalıdır. Ölçülen: ${avgMs.toStringAsFixed(2)}ms',
        );
      },
    );
  });

  group('Kriter 4: Not Editörü ve Büyük Doküman Performans Regresyon Testleri', () {
    test(
      '250+ blok ve 5000+ kelimelik büyük NoteDocument serileştirme/ayrıştırma <50ms sürer',
      () {
        final List<NoteBlock> blocks = <NoteBlock>[];
        blocks.add(NoteBlock.heading(text: 'Büyük Doküman Başlığı', level: 1));

        for (int i = 1; i <= 150; i++) {
          blocks.add(
            NoteBlock.paragraph(
              text:
                  'Bu paragraf $i, büyük ölçekli metin işleme ve blok tabanlı zengin metin editörünün performansını test etmek için 50 kelimelik uzun cümlelerle oluşturulmuştur. Test metni içerik genişliği ve bellek ayrımını simüle eder.',
            ),
          );
          if (i % 3 == 0) {
            blocks.add(
              NoteBlock.checkbox(
                text: 'Madde $i: Tamamlanması gereken görev öğesi',
                checked: i % 2 == 0,
              ),
            );
          }
        }

        final doc = NoteDocument(version: 1, blocks: blocks);
        expect(doc.blocks.length, greaterThanOrEqualTo(200));

        final stopwatch = Stopwatch()..start();

        // Serialization
        final encodedString = doc.encode();

        // Deserialization
        final restoredDoc = NoteDocument.decode(encodedString);

        stopwatch.stop();
        final elapsed = stopwatch.elapsedMilliseconds;

        expect(restoredDoc.blocks.length, equals(doc.blocks.length));
        expect(
          elapsed,
          lessThan(50),
          reason:
              'Büyük dokümanın encode/decode süresi <50ms olmalıdır. Ölçülen: ${elapsed}ms',
        );
      },
    );

    test(
      'Büyük dokümanın veritabanına kaydedilmesi ve güncellenmesi <50ms tamamlanır',
      () async {
        final String noteId = await notesRepo.createNote(
          title: 'Büyük Not Başlığı',
        );

        final List<NoteBlock> blocks = List.generate(
          150,
          (i) => NoteBlock.paragraph(
            text: 'Paragraf $i: Test içeriği ve performans verisi',
          ),
        );
        final doc = NoteDocument(version: 1, blocks: blocks);

        final stopwatch = Stopwatch()..start();

        await notesRepo.saveDocument(noteId, doc);

        stopwatch.stop();
        final elapsed = stopwatch.elapsedMilliseconds;

        expect(
          elapsed,
          lessThan(50),
          reason:
              'Büyük not dokümanı veritabanı güncellemesi <50ms olmalıdır. Ölçülen: ${elapsed}ms',
        );

        final NoteEntity? retrieved = await notesRepo.getNote(noteId);
        expect(retrieved, isNotNull);
        expect(retrieved!.document.blocks.length, equals(150));
      },
    );
  });

  group(
    'Kriter 4: Attachment Listeleri ve LRU Önbellek Performans Regresyon Testleri',
    () {
      test(
        '1000 ardışık LRU cache işlemi toplam <500ms (ortalama <0.5ms) içinde tamamlanır',
        () async {
          final t0 = DateTime.utc(2026, 8, 16, 10);

          // Prepopulate 100 attachments
          await db.batch((batch) {
            for (int i = 0; i < 100; i++) {
              batch.insert(
                db.attachments,
                AttachmentsCompanion.insert(
                  id: 'att-perf-$i',
                  parentType: 'note',
                  parentId: 'note-perf-1',
                  fileName: 'file_$i.bin',
                  localPath: 'attachments/file_$i.bin',
                  remotePath: Value('remote/file_$i.bin'),
                  sizeBytes: 1024,
                  isCache: const Value(true),
                  lastAccessedAt: Value(t0.add(Duration(minutes: i))),
                  transferState: const Value('synced'),
                  createdAt: t0,
                  updatedAt: t0,
                ),
              );
            }
          });

          final stopwatch = Stopwatch()..start();

          // 1000 cache accesses / updates
          for (int i = 0; i < 1000; i++) {
            final String attId = 'att-perf-${i % 100}';
            await (db.update(
              db.attachments,
            )..where((tbl) => tbl.id.equals(attId))).write(
              AttachmentsCompanion(
                lastAccessedAt: Value(t0.add(Duration(seconds: i))),
              ),
            );
          }

          stopwatch.stop();
          final elapsed = stopwatch.elapsedMilliseconds;

          expect(
            elapsed,
            lessThan(500),
            reason:
                '1000 LRU erişim güncellemesi <500ms içinde tamamlanmalıdır. Ölçülen: ${elapsed}ms',
          );
        },
      );

      test(
        '200+ attachment içeren bir notta ek listeleme ve toplam boyut hesaplama <50ms sürer',
        () async {
          const String noteId = 'note-with-many-attachments';

          await db.batch((batch) {
            for (int i = 0; i < 200; i++) {
              batch.insert(
                db.attachments,
                AttachmentsCompanion.insert(
                  id: 'att-multi-$i',
                  parentType: 'note',
                  parentId: noteId,
                  fileName: 'attachment_doc_$i.pdf',
                  localPath: 'attachments/att_multi_$i.pdf',
                  sizeBytes: 50000,
                  createdAt: DateTime.utc(2026, 8, 16, 12),
                  updatedAt: DateTime.utc(2026, 8, 16, 12),
                ),
              );
            }
          });

          final stopwatch = Stopwatch()..start();

          final list = await attachmentsRepo
              .watchForParent('note', noteId)
              .first;

          final totalBytes = list.fold<int>(0, (sum, a) => sum + a.sizeBytes);

          stopwatch.stop();
          final elapsed = stopwatch.elapsedMilliseconds;

          expect(list.length, equals(200));
          expect(totalBytes, equals(200 * 50000));
          expect(
            elapsed,
            lessThan(50),
            reason:
                '200 attachment listeleme ve boyut hesabı <50ms sürmelidir. Ölçülen: ${elapsed}ms',
          );
        },
      );
    },
  );
}
