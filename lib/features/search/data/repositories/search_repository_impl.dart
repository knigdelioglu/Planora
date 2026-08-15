import 'dart:convert';

import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/features/notes/domain/entities/note_document.dart';
import 'package:not_app/features/search/domain/entities/search_result.dart';
import 'package:not_app/features/search/domain/repositories/search_repository.dart';

final class DriftSearchRepository implements SearchRepository {
  DriftSearchRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<SearchResultEntity>> search(String query, {int limit = 60}) async {
    final String normalized = query.trim();
    if (normalized.isEmpty) return const <SearchResultEntity>[];
    final List<String> tokens = normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .map((token) => '"${token.replaceAll('"', '""')}"*')
        .toList(growable: false);
    final String expression = tokens.join(' AND ');
    final rows = await _database.customSelect(
      '''
      SELECT entity_type, entity_id, title,
             snippet(search_fts, 3, '', '', ' … ', 18) AS preview
      FROM search_fts
      WHERE search_fts MATCH ?
      ORDER BY bm25(search_fts)
      LIMIT ?
      ''',
      variables: <Variable<Object>>[
        Variable<String>(expression),
        Variable<int>(limit.clamp(1, 200)),
      ],
      readsFrom: <ResultSetImplementation>{},
    ).get();
    return rows
        .map(
          (row) => SearchResultEntity(
            entityType: row.read<String>('entity_type'),
            entityId: row.read<String>('entity_id'),
            title: row.read<String>('title'),
            preview: row.read<String>('preview'),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> rebuildIndex() async {
    await _database.customStatement('DELETE FROM search_fts');
    final notes = await (_database.select(_database.notes)..where((tbl) => tbl.deletedAt.isNull())).get();
    for (final note in notes) {
      String body = '';
      try {
        final Object? decoded = jsonDecode(note.contentJson);
        if (decoded is Map) body = NoteDocument.fromJson(Map<String, Object?>.from(decoded)).plainText;
      } catch (_) {
        body = '';
      }
      await _database.upsertSearchEntry(entityType: 'note', entityId: note.id, title: note.title, body: body);
    }
    final cards = await (_database.select(_database.cards)..where((tbl) => tbl.deletedAt.isNull())).get();
    for (final card in cards) {
      await _database.upsertSearchEntry(
        entityType: 'card',
        entityId: card.id,
        title: card.title,
        body: card.description ?? '',
      );
    }
    final boards = await (_database.select(_database.boards)..where((tbl) => tbl.deletedAt.isNull())).get();
    for (final board in boards) {
      await _database.upsertSearchEntry(entityType: 'board', entityId: board.id, title: board.title, body: '');
    }
  }
}
