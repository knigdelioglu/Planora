import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('foreign keys and schema can persist a board column and card', () async {
    final DateTime now = DateTime.utc(2026, 8, 15);
    await db
        .into(db.boards)
        .insert(
          BoardsCompanion.insert(
            id: 'b',
            title: 'Board',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.boardColumns)
        .insert(
          BoardColumnsCompanion.insert(
            id: 'c',
            boardId: 'b',
            title: 'Todo',
            rankKey: const Value('hzzzzzzzzzzz'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            id: 'k',
            boardId: 'b',
            columnId: 'c',
            title: 'Card',
            rankKey: const Value('hzzzzzzzzzzz'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    expect(await db.select(db.cards).get(), hasLength(1));
  });

  test('fts entry can be inserted and queried', () async {
    await db.upsertSearchEntry(
      entityType: 'note',
      entityId: 'n',
      title: 'Deneme',
      body: 'çevrimdışı not',
    );
    final rows = await db
        .customSelect(
          "SELECT entity_id FROM search_fts WHERE search_fts MATCH 'çevrimdışı'",
        )
        .get();
    expect(rows.single.read<String>('entity_id'), 'n');
  });
}
