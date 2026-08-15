import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/kanban/data/repositories/kanban_repository_impl.dart';

class _Clock implements AppClock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 8, 15, 12);
}

void main() {
  test('cards reorder and move between columns without list reindex dependency', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final clock = _Clock();
    final queue = DriftSyncQueueRepository(database: db, clock: clock);
    final repo = DriftKanbanRepository(database: db, syncQueue: queue, clock: clock);
    final board = await repo.createBoard(title: 'Board');
    final left = await repo.createColumn(boardId: board, title: 'Todo');
    final right = await repo.createColumn(boardId: board, title: 'Done');
    final card = await repo.createCard(boardId: board, columnId: left, title: 'Task');
    await repo.moveCard(cardId: card, destinationColumnId: right, destinationIndex: 0);
    final row = await (db.select(db.cards)..where((tbl) => tbl.id.equals(card))).getSingle();
    expect(row.columnId, right);
    expect(row.rankKey, hasLength(12));
  });
}
