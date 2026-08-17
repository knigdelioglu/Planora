import 'package:drift/drift.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/sync/sync_models.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/kanban/domain/repositories/kanban_repository.dart';
import 'package:not_app/features/notes/domain/entities/linked_note.dart';
import 'package:not_app/features/notes/domain/repositories/note_kanban_repository.dart';

final class DriftNoteKanbanRepository implements NoteKanbanRepository {
  DriftNoteKanbanRepository({
    required this.database,
    required this.kanban,
    required this.syncQueue,
    required this.clock,
  });

  final AppDatabase database;
  final KanbanRepository kanban;
  final SyncQueueRepository syncQueue;
  final AppClock clock;

  @override
  Future<List<LinkedNoteEntity>> linkedNotesForCard(String cardId) async {
    final rows = await database.customSelect(
      '''
      SELECT l.note_id, l.card_id, n.title
      FROM card_note_links AS l
      INNER JOIN notes AS n ON n.id = l.note_id
      INNER JOIN cards AS c ON c.id = l.card_id
      WHERE l.card_id = ?
        AND l.deleted_at IS NULL
        AND n.deleted_at IS NULL
        AND c.deleted_at IS NULL
      ORDER BY l.updated_at DESC
      ''',
      variables: <Variable<Object>>[Variable<String>(cardId)],
    ).get();
    return rows
        .map(
          (row) => LinkedNoteEntity(
            noteId: row.read<String>('note_id'),
            cardId: row.read<String>('card_id'),
            title: row.read<String>('title'),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<String?> linkedCardIdForNote(String noteId) async {
    final row = await database.customSelect(
      '''
      SELECT l.card_id
      FROM card_note_links AS l
      INNER JOIN cards AS c ON c.id = l.card_id
      WHERE l.note_id = ?
        AND l.deleted_at IS NULL
        AND c.deleted_at IS NULL
      LIMIT 1
      ''',
      variables: <Variable<Object>>[Variable<String>(noteId)],
    ).getSingleOrNull();
    return row?.read<String>('card_id');
  }

  @override
  Future<String> moveNoteToColumn({
    required String noteId,
    required String boardId,
    required String columnId,
    required String title,
  }) async {
    final String cleanTitle = title.trim().isEmpty
        ? 'Başlıksız not'
        : title.trim();
    final String cardId = await kanban.createCard(
      boardId: boardId,
      columnId: columnId,
      title: cleanTitle,
      description: 'Bağlı not',
    );
    await moveNoteToCard(noteId: noteId, cardId: cardId);
    return cardId;
  }

  @override
  Future<void> moveNoteToCard({
    required String noteId,
    required String cardId,
  }) async {
    final Note? note = await (database.select(database.notes)
          ..where((tbl) => tbl.id.equals(noteId) & tbl.deletedAt.isNull()))
        .getSingleOrNull();
    if (note == null) throw StateError('Not bulunamadı.');

    final Card? card = await (database.select(database.cards)
          ..where((tbl) => tbl.id.equals(cardId) & tbl.deletedAt.isNull()))
        .getSingleOrNull();
    if (card == null) throw StateError('Hedef kart bulunamadı.');

    final existing = await database.customSelect(
      '''
      SELECT id, note_id, card_id, created_at, updated_at, version, deleted_at
      FROM card_note_links
      WHERE id = ?
      LIMIT 1
      ''',
      variables: <Variable<Object>>[Variable<String>(noteId)],
    ).getSingleOrNull();

    if (existing != null &&
        existing.read<String>('card_id') == cardId &&
        existing.readNullable<String>('deleted_at') == null) {
      return;
    }

    final DateTime now = clock.nowUtc();
    final int baseVersion = existing?.read<int>('version') ?? 0;
    final int version = baseVersion + 1;
    final String createdAt =
        existing?.read<String>('created_at') ?? now.toIso8601String();
    final String updatedAt = now.toIso8601String();

    await database.transaction(() async {
      await database.customStatement(
        '''
        INSERT INTO card_note_links(
          id, note_id, card_id, created_at, updated_at, version, deleted_at
        ) VALUES (?, ?, ?, ?, ?, ?, NULL)
        ON CONFLICT(id) DO UPDATE SET
          note_id = excluded.note_id,
          card_id = excluded.card_id,
          updated_at = excluded.updated_at,
          version = excluded.version,
          deleted_at = NULL
        ''',
        <Object?>[
          noteId,
          noteId,
          cardId,
          createdAt,
          updatedAt,
          version,
        ],
      );
      await syncQueue.enqueue(
        entityType: 'card_note_link',
        entityId: noteId,
        operationType: SyncOperationType.upsert,
        baseVersion: baseVersion,
        payload: <String, Object?>{
          'id': noteId,
          'noteId': noteId,
          'cardId': cardId,
          'createdAt': createdAt,
          'updatedAt': updatedAt,
          'version': version,
          'deletedAt': null,
        },
      );
    });
  }

  @override
  Future<void> unlinkNote(String noteId) async {
    final existing = await database.customSelect(
      '''
      SELECT id, note_id, card_id, created_at, updated_at, version, deleted_at
      FROM card_note_links
      WHERE id = ?
      LIMIT 1
      ''',
      variables: <Variable<Object>>[Variable<String>(noteId)],
    ).getSingleOrNull();
    if (existing == null ||
        existing.readNullable<String>('deleted_at') != null) {
      return;
    }

    final DateTime now = clock.nowUtc();
    final int baseVersion = existing.read<int>('version');
    final int version = baseVersion + 1;
    final String deletedAt = now.toIso8601String();

    await database.transaction(() async {
      await database.customStatement(
        '''
        UPDATE card_note_links
        SET updated_at = ?, version = ?, deleted_at = ?
        WHERE id = ?
        ''',
        <Object?>[deletedAt, version, deletedAt, noteId],
      );
      await syncQueue.enqueue(
        entityType: 'card_note_link',
        entityId: noteId,
        operationType: SyncOperationType.delete,
        baseVersion: baseVersion,
        payload: <String, Object?>{
          'id': noteId,
          'noteId': noteId,
          'cardId': existing.read<String>('card_id'),
          'createdAt': existing.read<String>('created_at'),
          'updatedAt': deletedAt,
          'version': version,
          'deletedAt': deletedAt,
        },
      );
    });
  }
}
