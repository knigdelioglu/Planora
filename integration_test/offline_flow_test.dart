import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/kanban/data/repositories/kanban_repository_impl.dart';
import 'package:not_app/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:not_app/features/notes/domain/entities/note_document.dart';

class _Clock implements AppClock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 8, 15, 12);
}

void main() {
  test('core offline journeys commit locally without a remote service', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final clock = _Clock();
    final queue = DriftSyncQueueRepository(database: db, clock: clock);
    final notes = DriftNotesRepository(database: db, syncQueue: queue, clock: clock);
    final kanban = DriftKanbanRepository(database: db, syncQueue: queue, clock: clock);

    final noteId = await notes.createNote(title: 'Offline');
    await notes.saveDocument(noteId, NoteDocument(version: 1, blocks: const <NoteBlock>[NoteBlock(id: 'p', type: NoteBlockType.paragraph, text: 'Yerel içerik')]));
    final boardId = await kanban.createBoard(title: 'İşler');
    final columnId = await kanban.createColumn(boardId: boardId, title: 'Yapılacak');
    await kanban.createCard(boardId: boardId, columnId: columnId, title: 'Görev');

    expect((await notes.getNote(noteId))?.document.plainText, 'Yerel içerik');
    expect(await db.select(db.cards).get(), hasLength(1));
    expect(await queue.dueOperations(), isNotEmpty);
  });
}
