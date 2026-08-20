import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/events/entity_change_bus.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/kanban/data/repositories/kanban_repository_impl.dart';
import 'package:not_app/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:not_app/features/notes/domain/entities/note_document.dart';
import 'package:not_app/features/smart_views/data/repositories/smart_views_repository_impl.dart';
import 'package:not_app/features/smart_views/domain/entities/content_filter.dart';
import 'package:not_app/features/tags/data/repositories/tags_repository_impl.dart';
import 'package:not_app/features/tags/domain/entities/tag.dart';

class _Clock implements AppClock {
  DateTime value = DateTime.utc(2026, 8, 20, 6);

  @override
  DateTime nowUtc() => value;
}

void main() {
  late AppDatabase db;
  late EntityChangeBus changes;
  late _Clock clock;
  late DriftSyncQueueRepository queue;
  late DriftTagsRepository tags;
  late DriftSmartViewsRepository smartViews;
  late DriftNotesRepository notes;
  late DriftKanbanRepository kanban;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    changes = EntityChangeBus();
    clock = _Clock();
    queue = DriftSyncQueueRepository(database: db, clock: clock);
    tags = DriftTagsRepository(
      database: db,
      syncQueue: queue,
      clock: clock,
      changes: changes,
    );
    smartViews = DriftSmartViewsRepository(
      database: db,
      syncQueue: queue,
      clock: clock,
      changes: changes,
    );
    notes = DriftNotesRepository(
      database: db,
      syncQueue: queue,
      clock: clock,
    );
    kanban = DriftKanbanRepository(
      database: db,
      syncQueue: queue,
      clock: clock,
    );
  });

  tearDown(() async {
    await changes.dispose();
    await db.close();
  });

  test('same normalized tag converges to the same identity', () async {
    final String first = await tags.createTag(name: '#Okul');
    final String second = await tags.createTag(name: ' okul ');

    expect(second, first);
    final list = await tags.watchTags().first;
    expect(list, hasLength(1));
    expect(list.single.normalizedName, 'okul');
  });

  test('tag assignment survives unassign and deterministic restore', () async {
    final String noteId = await notes.createNote(title: 'Ders');
    final String tagId = await tags.createTag(name: 'Okul');

    await tags.assign(
      tagId: tagId,
      targetType: TagTargetType.note,
      targetId: noteId,
    );
    expect(
      await tags.tagsForTarget(
        targetType: TagTargetType.note,
        targetId: noteId,
      ),
      hasLength(1),
    );

    await tags.unassign(
      tagId: tagId,
      targetType: TagTargetType.note,
      targetId: noteId,
    );
    expect(
      await tags.tagsForTarget(
        targetType: TagTargetType.note,
        targetId: noteId,
      ),
      isEmpty,
    );

    await tags.assign(
      tagId: tagId,
      targetType: TagTargetType.note,
      targetId: noteId,
    );
    expect(
      await tags.tagsForTarget(
        targetType: TagTargetType.note,
        targetId: noteId,
      ),
      hasLength(1),
    );
  });

  test('deleting a tag removes it from targets without deleting content', () async {
    final String noteId = await notes.createNote(title: 'Kalacak not');
    final String tagId = await tags.createTag(name: 'Geçici');
    await tags.assign(
      tagId: tagId,
      targetType: TagTargetType.note,
      targetId: noteId,
    );

    await tags.deleteTag(tagId);

    expect(await notes.getNote(noteId), isNotNull);
    expect(
      await tags.tagsForTarget(
        targetType: TagTargetType.note,
        targetId: noteId,
      ),
      isEmpty,
    );
  });

  test('smart view combines text, tag and metadata filters', () async {
    final String noteId = await notes.createNote(title: 'Sınav hazırlığı');
    await notes.saveDocument(
      noteId,
      NoteDocument(
        version: NoteDocument.currentVersion,
        blocks: const <NoteBlock>[
          NoteBlock(
            id: 'block-1',
            type: NoteBlockType.paragraph,
            text: 'Edebiyat sorularını gözden geçir',
          ),
        ],
      ),
    );
    await notes.setFavorite(noteId, true);
    final String tagId = await tags.createTag(name: 'Okul');
    await tags.assign(
      tagId: tagId,
      targetType: TagTargetType.note,
      targetId: noteId,
    );

    final results = await smartViews.query(
      ContentFilter(
        scope: ContentScope.notes,
        textQuery: 'edebiyat',
        allTagIds: <String>[tagId],
        favorite: true,
        hasTags: true,
        updatedWithinDays: 7,
      ),
    );

    expect(results.map((item) => item.entityId), contains(noteId));
  });

  test('ALL tag filter requires every selected tag', () async {
    final String both = await notes.createNote(title: 'İki etiket');
    final String one = await notes.createNote(title: 'Tek etiket');
    final String okul = await tags.createTag(name: 'Okul');
    final String onemli = await tags.createTag(name: 'Önemli');

    for (final String noteId in <String>[both, one]) {
      await tags.assign(
        tagId: okul,
        targetType: TagTargetType.note,
        targetId: noteId,
      );
    }
    await tags.assign(
      tagId: onemli,
      targetType: TagTargetType.note,
      targetId: both,
    );

    final results = await smartViews.query(
      ContentFilter(
        scope: ContentScope.notes,
        allTagIds: <String>[okul, onemli],
      ),
    );

    expect(results.map((item) => item.entityId), contains(both));
    expect(results.map((item) => item.entityId), isNot(contains(one)));
  });

  test('ANY tag filter accepts at least one selected tag', () async {
    final String okulNote = await notes.createNote(title: 'Okul');
    final String kisiselNote = await notes.createNote(title: 'Kişisel');
    final String diger = await notes.createNote(title: 'Diğer');
    final String okul = await tags.createTag(name: 'Okul');
    final String kisisel = await tags.createTag(name: 'Kişisel');
    await tags.assign(
      tagId: okul,
      targetType: TagTargetType.note,
      targetId: okulNote,
    );
    await tags.assign(
      tagId: kisisel,
      targetType: TagTargetType.note,
      targetId: kisiselNote,
    );

    final results = await smartViews.query(
      ContentFilter(
        scope: ContentScope.notes,
        anyTagIds: <String>[okul, kisisel],
      ),
    );
    final ids = results.map((item) => item.entityId).toSet();
    expect(ids, containsAll(<String>[okulNote, kisiselNote]));
    expect(ids, isNot(contains(diger)));
  });

  test('NOT tag filter excludes matching content', () async {
    final String included = await notes.createNote(title: 'Dahil');
    final String excluded = await notes.createNote(title: 'Hariç');
    final String bekliyor = await tags.createTag(name: 'Bekliyor');
    await tags.assign(
      tagId: bekliyor,
      targetType: TagTargetType.note,
      targetId: excluded,
    );

    final results = await smartViews.query(
      ContentFilter(
        scope: ContentScope.notes,
        noneTagIds: <String>[bekliyor],
      ),
    );
    final ids = results.map((item) => item.entityId).toSet();
    expect(ids, contains(included));
    expect(ids, isNot(contains(excluded)));
  });

  test('built-in untagged semantics excludes tagged content', () async {
    final String tagged = await notes.createNote(title: 'Etiketli');
    final String untagged = await notes.createNote(title: 'Etiketsiz');
    final String tagId = await tags.createTag(name: 'Önemli');
    await tags.assign(
      tagId: tagId,
      targetType: TagTargetType.note,
      targetId: tagged,
    );

    final results = await smartViews.query(
      const ContentFilter(scope: ContentScope.notes, hasTags: false),
    );

    expect(results.map((item) => item.entityId), contains(untagged));
    expect(results.map((item) => item.entityId), isNot(contains(tagged)));
  });

  test('board and column filters limit card results', () async {
    final String boardA = await kanban.createBoard(title: 'A');
    final String boardB = await kanban.createBoard(title: 'B');
    final String columnA1 = await kanban.createColumn(
      boardId: boardA,
      title: 'A1',
    );
    final String columnA2 = await kanban.createColumn(
      boardId: boardA,
      title: 'A2',
    );
    final String columnB = await kanban.createColumn(
      boardId: boardB,
      title: 'B1',
    );
    final String cardA1 = await kanban.createCard(
      boardId: boardA,
      columnId: columnA1,
      title: 'A1 kartı',
    );
    await kanban.createCard(
      boardId: boardA,
      columnId: columnA2,
      title: 'A2 kartı',
    );
    await kanban.createCard(
      boardId: boardB,
      columnId: columnB,
      title: 'B kartı',
    );

    final results = await smartViews.query(
      ContentFilter(
        scope: ContentScope.cards,
        boardId: boardA,
        columnId: columnA1,
      ),
    );

    expect(results.map((item) => item.entityId), <String>[cardA1]);
  });

  test('saved smart view stores a versioned filter and queues sync', () async {
    final String tagId = await tags.createTag(name: 'Planora');
    final String viewId = await smartViews.createView(
      name: 'Planora işleri',
      filter: ContentFilter(
        anyTagIds: <String>[tagId],
        hasAttachment: true,
      ),
    );

    final views = await smartViews.watchViews().first;
    final view = views.singleWhere((item) => item.id == viewId);
    expect(view.filter.version, ContentFilter.currentVersion);
    expect(view.filter.anyTagIds, <String>[tagId]);
    expect(await queue.dueOperations(), isNotEmpty);
  });
}
