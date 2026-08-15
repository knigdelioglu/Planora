import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:not_app/features/notes/domain/entities/note_document.dart';

class _Clock implements AppClock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 8, 15, 12);
}

void main() {
  test('note survives repository read and queues local mutations', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final clock = _Clock();
    final queue = DriftSyncQueueRepository(database: db, clock: clock);
    final repo = DriftNotesRepository(
      database: db,
      syncQueue: queue,
      clock: clock,
    );
    final id = await repo.createNote(title: 'Test');
    await repo.saveDocument(
      id,
      NoteDocument(
        version: 1,
        blocks: const <NoteBlock>[
          NoteBlock(id: 'x', type: NoteBlockType.paragraph, text: 'Merhaba'),
        ],
      ),
    );
    final note = await repo.getNote(id);
    expect(note?.title, 'Test');
    expect(note?.document.plainText, 'Merhaba');
    expect(await queue.dueOperations(), isNotEmpty);
  });
}
