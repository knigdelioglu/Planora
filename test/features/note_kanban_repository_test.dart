import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/kanban/data/repositories/kanban_repository_impl.dart';
import 'package:not_app/features/notes/data/repositories/note_kanban_repository_impl.dart';
import 'package:not_app/features/notes/data/repositories/notes_repository_impl.dart';

class _Clock implements AppClock {
  DateTime _now = DateTime.utc(2026, 8, 17, 12);

  @override
  DateTime nowUtc() {
    final DateTime value = _now;
    _now = _now.add(const Duration(seconds: 1));
    return value;
  }
}

void main() {
  test('saved note moves between cards without duplicate links', () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final _Clock clock = _Clock();
    final DriftSyncQueueRepository queue = DriftSyncQueueRepository(
      database: db,
      clock: clock,
    );
    final DriftNotesRepository notes = DriftNotesRepository(
      database: db,
      syncQueue: queue,
      clock: clock,
    );
    final DriftKanbanRepository kanban = DriftKanbanRepository(
      database: db,
      syncQueue: queue,
      clock: clock,
    );
    final DriftNoteKanbanRepository links = DriftNoteKanbanRepository(
      database: db,
      kanban: kanban,
      syncQueue: queue,
      clock: clock,
    );

    final String noteId = await notes.createNote(title: 'Taşınacak not');
    final String boardId = await kanban.createBoard(title: 'Pano');
    final String columnId = await kanban.createColumn(
      boardId: boardId,
      title: 'Yapılacak',
    );
    final String firstCard = await kanban.createCard(
      boardId: boardId,
      columnId: columnId,
      title: 'Birinci kart',
    );
    final String secondCard = await kanban.createCard(
      boardId: boardId,
      columnId: columnId,
      title: 'İkinci kart',
    );

    await links.moveNoteToCard(noteId: noteId, cardId: firstCard);
    expect(await links.linkedCardIdForNote(noteId), firstCard);
    expect(await links.linkedNotesForCard(firstCard), hasLength(1));

    await links.moveNoteToCard(noteId: noteId, cardId: secondCard);
    expect(await links.linkedCardIdForNote(noteId), secondCard);
    expect(await links.linkedNotesForCard(firstCard), isEmpty);
    expect(await links.linkedNotesForCard(secondCard), hasLength(1));

    final rows = await db.customSelect(
      'SELECT id, note_id, card_id FROM card_note_links',
    ).get();
    expect(rows, hasLength(1));
    expect(rows.single.read<String>('note_id'), noteId);
    expect(rows.single.read<String>('card_id'), secondCard);

    final operations = await queue.allOperations(includeCompleted: true);
    expect(
      operations.where((operation) => operation.entityType == 'card_note_link'),
      hasLength(2),
    );
  });
}
