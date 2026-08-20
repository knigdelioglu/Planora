import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/events/entity_change_bus.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
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

  test('saved smart view stores a versioned filter and queues sync', () async {
    final String tagId = await tags.createTag(name: 'Planora');
    final String viewId = await smartViews.createView(
      name: 'Planora işleri',
      filter: ContentFilter(
        allTagIds: <String>[tagId],
        hasAttachment: true,
      ),
    );

    final views = await smartViews.watchViews().first;
    final view = views.singleWhere((item) => item.id == viewId);
    expect(view.filter.version, ContentFilter.currentVersion);
    expect(view.filter.allTagIds, <String>[tagId]);
    expect(await queue.dueOperations(), isNotEmpty);
  });
}
