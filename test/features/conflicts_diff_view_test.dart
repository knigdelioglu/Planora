import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/core/remote/remote_models.dart';
import 'package:not_app/features/conflicts/domain/entities/sync_conflict.dart';
import 'package:not_app/features/conflicts/domain/repositories/conflict_repository.dart';
import 'package:not_app/features/conflicts/presentation/screens/conflicts_screen.dart';
import 'package:not_app/features/conflicts/presentation/widgets/conflict_diff_view.dart';

class FakeConflictRepository implements ConflictRepository {
  FakeConflictRepository({List<SyncConflictEntity>? initial})
    : _conflicts = initial ?? <SyncConflictEntity>[] {
    _streamController = StreamController<List<SyncConflictEntity>>.broadcast();
  }

  final List<SyncConflictEntity> _conflicts;
  late final StreamController<List<SyncConflictEntity>> _streamController;

  final List<String> resolvedLocalIds = <String>[];
  final List<String> resolvedRemoteIds = <String>[];
  final List<String> resolvedCopyIds = <String>[];

  void _emit() {
    if (!_streamController.isClosed) {
      _streamController.add(List<SyncConflictEntity>.unmodifiable(_conflicts));
    }
  }

  void addConflict(SyncConflictEntity conflict) {
    _conflicts.add(conflict);
    _emit();
  }

  @override
  Stream<List<SyncConflictEntity>> watchOpen() {
    return Stream<List<SyncConflictEntity>>.multi((controller) {
      controller.add(List<SyncConflictEntity>.unmodifiable(_conflicts));
      final sub = _streamController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<String> record({
    required String entityType,
    required String entityId,
    required Map<String, Object?> local,
    required RemoteEntity remote,
  }) async {
    return 'new-id';
  }

  @override
  Future<void> resolveUsingLocal(String conflictId) async {
    resolvedLocalIds.add(conflictId);
    _conflicts.removeWhere((c) => c.id == conflictId);
    _emit();
  }

  @override
  Future<void> resolveUsingRemote(String conflictId) async {
    resolvedRemoteIds.add(conflictId);
    _conflicts.removeWhere((c) => c.id == conflictId);
    _emit();
  }

  @override
  Future<void> resolveAsCopy(String conflictId) async {
    resolvedCopyIds.add(conflictId);
    _conflicts.removeWhere((c) => c.id == conflictId);
    _emit();
  }

  void dispose() {
    _streamController.close();
  }
}

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

void main() {
  group(
    'Kabul Kriteri 1: UUID yerine varlığın gerçek başlığı/adı başlıkta vurgulanır',
    () {
      testWidgets(
        'Not çakışmasında UUID yerine gerçek not başlığı vurgulanır',
        (tester) async {
          final noteConflict = SyncConflictEntity(
            id: 'conf-1',
            entityType: 'note',
            entityId: '01950c77-adf0-7000-8000-000000000001',
            localJson: jsonEncode(<String, Object?>{
              'id': '01950c77-adf0-7000-8000-000000000001',
              'title': 'Haftalık Proje Planı',
              'contentJson': '{"version":1,"blocks":[]}',
              'updatedAt': '2026-08-16T15:00:00.000Z',
              'version': 2,
            }),
            remoteJson: jsonEncode(<String, Object?>{
              'id': '01950c77-adf0-7000-8000-000000000001',
              'title': 'Haftalık Plan (Uzak)',
              'contentJson': '{"version":1,"blocks":[]}',
              'updatedAt': '2026-08-16T14:30:00.000Z',
              'version': 2,
            }),
            createdAt: DateTime.utc(2026, 8, 16, 15, 5),
          );

          await tester.pumpWidget(
            _wrapWithTheme(
              ConflictDiffView(
                conflict: noteConflict,
                onResolveLocal: () {},
                onResolveRemote: () {},
                onResolveCopy: () {},
              ),
            ),
          );

          // Header displays real title prominently
          expect(find.text('Haftalık Proje Planı'), findsWidgets);
          // Entity type badge is visible
          expect(find.text('Not'), findsOneWidget);
          // Short entity ID is shown as secondary context
          expect(find.text('#01950c77'), findsOneWidget);
        },
      );

      testWidgets('Kart çakışmasında UUID yerine kart başlığı vurgulanır', (
        tester,
      ) async {
        final cardConflict = SyncConflictEntity(
          id: 'conf-2',
          entityType: 'card',
          entityId: '01950c88-bbbb-7000-8000-000000000002',
          localJson: jsonEncode(<String, Object?>{
            'id': '01950c88-bbbb-7000-8000-000000000002',
            'boardId': 'board-1',
            'columnId': 'col-1',
            'title': 'Sprint 11 Görevi',
            'description': 'Arayüz tasarımı yapılacak',
            'rankKey': 'hzzza',
            'updatedAt': '2026-08-16T16:00:00.000Z',
            'version': 3,
          }),
          remoteJson: jsonEncode(<String, Object?>{
            'id': '01950c88-bbbb-7000-8000-000000000002',
            'boardId': 'board-1',
            'columnId': 'col-2',
            'title': 'Sprint 11 Görevi (Sunucu)',
            'description': 'Arayüz ve testler yapılacak',
            'rankKey': 'hzzzb',
            'updatedAt': '2026-08-16T15:45:00.000Z',
            'version': 3,
          }),
          createdAt: DateTime.utc(2026, 8, 16, 16, 5),
        );

        await tester.pumpWidget(
          _wrapWithTheme(
            ConflictDiffView(
              conflict: cardConflict,
              onResolveLocal: () {},
              onResolveRemote: () {},
              onResolveCopy: () {},
            ),
          ),
        );

        expect(find.text('Sprint 11 Görevi'), findsWidgets);
        expect(find.text('Kart'), findsOneWidget);
      });

      testWidgets(
        'Başlık içermeyen varlıklarda uygun fallback başlık gösterilir',
        (tester) async {
          final untitledConflict = SyncConflictEntity(
            id: 'conf-3',
            entityType: 'note',
            entityId: '01950c99-cccc-7000-8000-000000000003',
            localJson: jsonEncode(<String, Object?>{
              'id': '01950c99-cccc-7000-8000-000000000003',
              'title': '',
              'contentJson': '{"version":1,"blocks":[]}',
            }),
            remoteJson: jsonEncode(<String, Object?>{
              'id': '01950c99-cccc-7000-8000-000000000003',
              'title': '',
              'contentJson': '{"version":1,"blocks":[]}',
            }),
            createdAt: DateTime.utc(2026, 8, 16, 17, 0),
          );

          await tester.pumpWidget(
            _wrapWithTheme(
              ConflictDiffView(
                conflict: untitledConflict,
                onResolveLocal: () {},
                onResolveRemote: () {},
              ),
            ),
          );

          expect(find.text('Başlıksız Not'), findsOneWidget);
        },
      );
    },
  );

  group(
    'Kabul Kriteri 2: Not çakışmalarında başlık, içerik/blok farkları ve son düzenleme zaman damgaları',
    () {
      testWidgets('Not başlık farkı ve zaman damgaları görsel olarak sunulur', (
        tester,
      ) async {
        final noteConflict = SyncConflictEntity(
          id: 'conf-note-diff',
          entityType: 'note',
          entityId: 'note-100',
          localJson: jsonEncode(<String, Object?>{
            'title': 'Yerel Not Başlığı',
            'contentJson': jsonEncode(<String, Object?>{
              'version': 1,
              'blocks': <Map<String, Object?>>[
                {
                  'id': 'b1',
                  'type': 'heading',
                  'text': 'Giriş Başlığı',
                  'level': 1,
                },
                {
                  'id': 'b2',
                  'type': 'paragraph',
                  'text': 'Yerel paragraf detayı.',
                },
              ],
            }),
            'updatedAt': '2026-08-16T17:30:00.000Z',
            'version': 2,
          }),
          remoteJson: jsonEncode(<String, Object?>{
            'title': 'Uzak Not Başlığı',
            'contentJson': jsonEncode(<String, Object?>{
              'version': 1,
              'blocks': <Map<String, Object?>>[
                {
                  'id': 'b1',
                  'type': 'heading',
                  'text': 'Giriş Başlığı',
                  'level': 1,
                },
                {
                  'id': 'b2',
                  'type': 'paragraph',
                  'text': 'Uzak sunucu paragrafı.',
                },
                {
                  'id': 'b3',
                  'type': 'checkbox',
                  'text': 'Uzakta eklenen görev',
                  'checked': true,
                },
              ],
            }),
            'updatedAt': '2026-08-16T16:45:00.000Z',
            'version': 2,
          }),
          createdAt: DateTime.utc(2026, 8, 16, 17, 35),
        );

        await tester.pumpWidget(
          _wrapWithTheme(
            ConflictDiffView(
              conflict: noteConflict,
              onResolveLocal: () {},
              onResolveRemote: () {},
              onResolveCopy: () {},
            ),
          ),
        );

        // Check Title diff section
        expect(find.text('Not Başlığı'), findsOneWidget);
        expect(find.text('Yerel Not Başlığı'), findsWidgets);
        expect(find.text('Uzak Not Başlığı'), findsOneWidget);

        // Check Timestamps section
        expect(find.text('Bu Cihaz (Yerel)'), findsOneWidget);
        expect(find.text('Sunucu (Uzak)'), findsOneWidget);
        // Newer badge is shown for local
        expect(find.text('Daha yeni'), findsOneWidget);

        // Check Content / Blocks diff section
        expect(find.text('Not İçeriği ve Bloklar'), findsOneWidget);
        expect(find.text('Yerel: 2 blok · Uzak: 3 blok'), findsOneWidget);
        expect(find.text('Yerel paragraf detayı.'), findsOneWidget);
        expect(find.text('Uzak sunucu paragrafı.'), findsOneWidget);
        expect(find.text('Uzakta eklenen görev'), findsOneWidget);
      });

      testWidgets('Not favori durumu farkı varsa belirtilir', (tester) async {
        final favConflict = SyncConflictEntity(
          id: 'conf-fav',
          entityType: 'note',
          entityId: 'note-fav-1',
          localJson: jsonEncode(<String, Object?>{
            'title': 'Favori Not',
            'contentJson': '{"version":1,"blocks":[]}',
            'isFavorite': true,
            'updatedAt': '2026-08-16T12:00:00.000Z',
          }),
          remoteJson: jsonEncode(<String, Object?>{
            'title': 'Favori Not',
            'contentJson': '{"version":1,"blocks":[]}',
            'isFavorite': false,
            'updatedAt': '2026-08-16T12:00:00.000Z',
          }),
          createdAt: DateTime.utc(2026, 8, 16, 12, 1),
        );

        await tester.pumpWidget(
          _wrapWithTheme(
            ConflictDiffView(
              conflict: favConflict,
              onResolveLocal: () {},
              onResolveRemote: () {},
            ),
          ),
        );

        expect(find.text('Favori Durumu'), findsOneWidget);
        expect(find.text('Favorilerde'), findsOneWidget);
        expect(find.text('Favori değil'), findsOneWidget);
      });
    },
  );

  group(
    'Kabul Kriteri 3: Kart çakışmalarında başlık, açıklama, kolon, sıra ve hatırlatıcı karşılaştırması',
    () {
      testWidgets(
        'Kart çakışmasında tüm alanlar (başlık, açıklama, kolon, sıra, hatırlatıcı) görsel olarak karşılaştırılır',
        (tester) async {
          final cardConflict = SyncConflictEntity(
            id: 'conf-card-all',
            entityType: 'card',
            entityId: 'card-200',
            localJson: jsonEncode(<String, Object?>{
              'boardId': 'board-1',
              'columnId': 'col-todo',
              'title': 'Yerel Kart Başlığı',
              'description': 'Yerel açıklama metni',
              'rankKey': 'hzzza',
              'dueAt': '2026-08-20T10:00:00.000Z',
              'updatedAt': '2026-08-16T14:00:00.000Z',
              'version': 2,
            }),
            remoteJson: jsonEncode(<String, Object?>{
              'boardId': 'board-1',
              'columnId': 'col-done',
              'title': 'Uzak Kart Başlığı',
              'description': 'Uzak sunucu açıklama metni',
              'rankKey': 'hzzzb',
              'dueAt': null,
              'updatedAt': '2026-08-16T15:00:00.000Z',
              'version': 2,
            }),
            createdAt: DateTime.utc(2026, 8, 16, 15, 5),
          );

          await tester.pumpWidget(
            _wrapWithTheme(
              ConflictDiffView(
                conflict: cardConflict,
                onResolveLocal: () {},
                onResolveRemote: () {},
                onResolveCopy: () {},
              ),
            ),
          );

          // Title diff
          expect(find.text('Kart Başlığı'), findsOneWidget);
          expect(find.text('Yerel Kart Başlığı'), findsWidgets);
          expect(find.text('Uzak Kart Başlığı'), findsOneWidget);

          // Description diff
          expect(find.text('Açıklama'), findsOneWidget);
          expect(find.text('Yerel açıklama metni'), findsOneWidget);
          expect(find.text('Uzak sunucu açıklama metni'), findsOneWidget);

          // Column and Rank diff
          expect(find.text('Kolon ve Sıralama Durumu'), findsOneWidget);
          expect(find.text('Kolon: col-todo'), findsOneWidget);
          expect(find.text('Kolon: col-done'), findsOneWidget);
          expect(find.text('Sıra Anahtarı: hzzza'), findsOneWidget);
          expect(find.text('Sıra Anahtarı: hzzzb'), findsOneWidget);

          // Reminder diff
          expect(find.text('Hatırlatıcı Durumu'), findsOneWidget);
          expect(find.text('2026-08-20T10:00:00.000Z'), findsOneWidget);
          expect(find.text('Hatırlatıcı yok'), findsOneWidget);
        },
      );
    },
  );

  group(
    'Kabul Kriteri 4: Ham JSON görünümü "Teknik Detaylar" akordeonu altında tutulur',
    () {
      testWidgets(
        'Teknik Detaylar akordeonu varsayılan olarak kapalıdır ve tıklandığında ham JSON görünür',
        (tester) async {
          final conflict = SyncConflictEntity(
            id: 'conf-tech-1',
            entityType: 'note',
            entityId: 'note-tech-id',
            localJson: jsonEncode(<String, Object?>{
              'title': 'Test Notu',
              'customField': 'local_secret_value',
            }),
            remoteJson: jsonEncode(<String, Object?>{
              'title': 'Test Notu',
              'customField': 'remote_secret_value',
            }),
            createdAt: DateTime.utc(2026, 8, 16, 12, 0),
          );

          await tester.pumpWidget(
            _wrapWithTheme(
              ConflictDiffView(
                conflict: conflict,
                onResolveLocal: () {},
                onResolveRemote: () {},
              ),
            ),
          );

          // Accordion header is visible
          expect(find.text('Teknik Detaylar (JSON)'), findsOneWidget);
          expect(
            find.text('Geliştiriciler için ham JSON ve sistem kimlikleri'),
            findsOneWidget,
          );

          // Raw JSON content is initially NOT visible (collapsed)
          expect(find.text('local_secret_value'), findsNothing);

          // Scroll and tap to expand
          final expansionTile = find.byKey(
            const Key('technical_details_conf-tech-1'),
          );
          await tester.ensureVisible(expansionTile);
          await tester.tap(expansionTile);
          await tester.pumpAndSettle();

          // Now raw JSON details are visible
          expect(find.text('Çakışma ID:'), findsOneWidget);
          expect(find.text('conf-tech-1'), findsOneWidget);
          expect(find.text('Varlık ID:'), findsOneWidget);
          expect(find.text('note-tech-id'), findsOneWidget);
          expect(find.textContaining('local_secret_value'), findsOneWidget);
          expect(find.textContaining('remote_secret_value'), findsOneWidget);
          expect(find.text('Kopyala'), findsWidgets);
        },
      );
    },
  );

  group(
    'Kabul Kriteri 5: Net aksiyon butonları ("Bu cihazdaki sürümü koru", "Uzak sürümü kabul et", "Kopya olarak iki sürümü de sakla")',
    () {
      testWidgets(
        'Not ve Kart varlıklarında 3 aksiyon da mevcuttur ve tıklandığında ilgili callback tetiklenir',
        (tester) async {
          bool localResolved = false;
          bool remoteResolved = false;
          bool copyResolved = false;

          final noteConflict = SyncConflictEntity(
            id: 'conf-actions',
            entityType: 'note',
            entityId: 'note-act',
            localJson: '{"title":"Yerel"}',
            remoteJson: '{"title":"Uzak"}',
            createdAt: DateTime.utc(2026, 8, 16, 12, 0),
          );

          await tester.pumpWidget(
            _wrapWithTheme(
              ConflictDiffView(
                conflict: noteConflict,
                onResolveLocal: () => localResolved = true,
                onResolveRemote: () => remoteResolved = true,
                onResolveCopy: () => copyResolved = true,
              ),
            ),
          );

          // Check all 3 action button labels
          final btnLocal = find.widgetWithText(
            FilledButton,
            'Bu cihazdaki sürümü koru',
          );
          final btnRemote = find.widgetWithText(
            OutlinedButton,
            'Uzak sürümü kabul et',
          );
          final btnCopy = find.widgetWithText(
            OutlinedButton,
            'Kopya olarak iki sürümü de sakla',
          );

          expect(btnLocal, findsOneWidget);
          expect(btnRemote, findsOneWidget);
          expect(btnCopy, findsOneWidget);

          // Scroll and tap local button
          await tester.ensureVisible(btnLocal);
          await tester.tap(btnLocal);
          expect(localResolved, isTrue);

          // Scroll and tap remote button
          await tester.ensureVisible(btnRemote);
          await tester.tap(btnRemote);
          expect(remoteResolved, isTrue);

          // Scroll and tap copy button
          await tester.ensureVisible(btnCopy);
          await tester.tap(btnCopy);
          expect(copyResolved, isTrue);
        },
      );

      testWidgets(
        'Kopya desteği olmayan varlıklarda kopya butonu gösterilmez',
        (tester) async {
          final attachmentConflict = SyncConflictEntity(
            id: 'conf-att',
            entityType: 'attachment',
            entityId: 'att-1',
            localJson: '{"fileName":"file.png"}',
            remoteJson: '{"fileName":"file_remote.png"}',
            createdAt: DateTime.utc(2026, 8, 16, 12, 0),
          );

          await tester.pumpWidget(
            _wrapWithTheme(
              ConflictDiffView(
                conflict: attachmentConflict,
                onResolveLocal: () {},
                onResolveRemote: () {},
                onResolveCopy: null,
              ),
            ),
          );

          expect(find.text('Bu cihazdaki sürümü koru'), findsOneWidget);
          expect(find.text('Uzak sürümü kabul et'), findsOneWidget);
          expect(find.text('Kopya olarak iki sürümü de sakla'), findsNothing);
        },
      );
    },
  );

  group('ConflictsScreen UI & Yaşam Döngüsü', () {
    testWidgets('Çakışma olmadığında boş durum (EmptyState) gösterir', (
      tester,
    ) async {
      final fakeRepo = FakeConflictRepository(initial: <SyncConflictEntity>[]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [conflictRepositoryProvider.overrideWithValue(fakeRepo)],
          child: const MaterialApp(home: ConflictsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Senkronizasyon çakışmaları'), findsOneWidget);
      expect(find.text('Çakışma yok'), findsOneWidget);
      expect(
        find.text('Cihazlar arasındaki tüm değişiklikler uyumlu ve güncel.'),
        findsOneWidget,
      );

      fakeRepo.dispose();
    });

    testWidgets(
      'Çakışmalar listelenir, aksiyon tıklandığında repo çağrılır ve SnackBar gösterilir',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final conflict = SyncConflictEntity(
          id: 'conf-screen-1',
          entityType: 'note',
          entityId: 'note-screen-1',
          localJson: jsonEncode(<String, Object?>{
            'title': 'Bütçe Planı',
            'contentJson': '{"version":1,"blocks":[]}',
            'updatedAt': '2026-08-16T18:00:00.000Z',
          }),
          remoteJson: jsonEncode(<String, Object?>{
            'title': 'Bütçe Planı v2',
            'contentJson': '{"version":1,"blocks":[]}',
            'updatedAt': '2026-08-16T17:30:00.000Z',
          }),
          createdAt: DateTime.utc(2026, 8, 16, 18, 5),
        );

        final fakeRepo = FakeConflictRepository(initial: [conflict]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [conflictRepositoryProvider.overrideWithValue(fakeRepo)],
            child: const MaterialApp(home: ConflictsScreen()),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Verify conflict card is displayed
        expect(find.text('Bütçe Planı'), findsWidgets);
        final resolveLocalBtn = find.text('Bu cihazdaki sürümü koru');
        expect(resolveLocalBtn, findsOneWidget);

        // Tap "Bu cihazdaki sürümü koru"
        await tester.tap(resolveLocalBtn);
        await tester.pump();

        expect(fakeRepo.resolvedLocalIds, contains('conf-screen-1'));
        // Verify SnackBar feedback
        expect(
          find.text('Bütçe Planı için bu cihazdaki sürüm korundu.'),
          findsOneWidget,
        );

        // Advance timer for SnackBar
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();

        // List becomes empty
        expect(find.text('Çakışma yok'), findsOneWidget);

        fakeRepo.dispose();
      },
    );
  });
}
