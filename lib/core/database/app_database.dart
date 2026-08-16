import 'package:drift/drift.dart';
import 'package:not_app/core/database/connection/native.dart';
import 'package:not_app/core/database/tables/app_settings_table.dart';
import 'package:not_app/core/database/tables/attachments_table.dart';
import 'package:not_app/core/database/tables/board_columns_table.dart';
import 'package:not_app/core/database/tables/boards_table.dart';
import 'package:not_app/core/database/tables/cards_table.dart';
import 'package:not_app/core/database/tables/conflicts_table.dart';
import 'package:not_app/core/database/tables/notes_table.dart';
import 'package:not_app/core/database/tables/reminders_table.dart';
import 'package:not_app/core/database/tables/sync_meta_table.dart';
import 'package:not_app/core/database/tables/sync_queue_table.dart';
import 'package:not_app/core/utils/fractional_indexing_helper.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: <Type>[
    Boards,
    BoardColumns,
    Cards,
    Notes,
    Attachments,
    Reminders,
    SyncQueue,
    AppSettings,
    Conflicts,
    SyncMeta,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  static Future<AppDatabase> open() async =>
      AppDatabase(await openNativeConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      await migrator.createAll();
      await _createSearchFts();
    },
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 2) {
        await migrator.addColumn(notes, notes.isFavorite);
        await migrator.addColumn(notes, notes.lastOpenedAt);
        await migrator.addColumn(boards, boards.colorHex);
        await migrator.addColumn(boardColumns, boardColumns.colorHex);
        await migrator.addColumn(boardColumns, boardColumns.rankKey);
        await migrator.addColumn(cards, cards.rankKey);
        await migrator.addColumn(attachments, attachments.isCache);
        await migrator.addColumn(attachments, attachments.lastAccessedAt);
        await migrator.addColumn(attachments, attachments.transferState);
        await migrator.addColumn(reminders, reminders.body);
        await migrator.addColumn(reminders, reminders.schedulingStatus);
        await migrator.addColumn(reminders, reminders.lastReconciledAt);
        await migrator.createTable(appSettings);
        await migrator.createTable(conflicts);
        await migrator.createTable(syncMeta);
        await _migrateLegacyRanks();
        await _createSearchFts();
      }
      if (from == 2) {
        await migrator.addColumn(conflicts, conflicts.resolution);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA busy_timeout = 5000');
      await _createSearchFts();
      await _createProductIndexes();
    },
  );

  Future<void> _createSearchFts() async {
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS search_fts USING fts5(
        entity_type UNINDEXED,
        entity_id UNINDEXED,
        title,
        body,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');
  }

  Future<void> _createProductIndexes() async {
    const List<String> statements = <String>[
      'CREATE INDEX IF NOT EXISTS boards_updated_at_idx ON boards (updated_at)',
      'CREATE INDEX IF NOT EXISTS board_columns_board_rank_idx ON board_columns (board_id, rank_key)',
      'CREATE INDEX IF NOT EXISTS cards_column_rank_idx ON cards (column_id, rank_key)',
      'CREATE INDEX IF NOT EXISTS cards_board_idx ON cards (board_id)',
      'CREATE INDEX IF NOT EXISTS notes_updated_at_idx ON notes (updated_at)',
      'CREATE INDEX IF NOT EXISTS notes_deleted_at_idx ON notes (deleted_at)',
      'CREATE INDEX IF NOT EXISTS attachments_parent_idx ON attachments (parent_type, parent_id)',
      'CREATE INDEX IF NOT EXISTS attachments_accessed_idx ON attachments (last_accessed_at)',
      'CREATE INDEX IF NOT EXISTS reminders_parent_idx ON reminders (parent_type, parent_id)',
      'CREATE INDEX IF NOT EXISTS reminders_schedule_idx ON reminders (scheduled_at_utc)',
      'CREATE INDEX IF NOT EXISTS sync_queue_due_idx ON sync_queue (status, next_attempt_at, created_at)',
      'CREATE INDEX IF NOT EXISTS conflicts_status_idx ON conflicts (status, created_at)',
    ];
    for (final String statement in statements) {
      await customStatement(statement);
    }
  }

  Future<void> _migrateLegacyRanks() async {
    final List<BoardColumn> columns = await select(boardColumns).get();
    final Map<String, List<BoardColumn>> byBoard =
        <String, List<BoardColumn>>{};
    for (final BoardColumn column in columns) {
      (byBoard[column.boardId] ??= <BoardColumn>[]).add(column);
    }
    for (final List<BoardColumn> group in byBoard.values) {
      group.sort(
        (BoardColumn a, BoardColumn b) => (a.rank ?? 0).compareTo(b.rank ?? 0),
      );
      final List<String> ranks = FractionalIndexing.rebalance(group.length);
      for (int index = 0; index < group.length; index++) {
        await (update(boardColumns)
              ..where((tbl) => tbl.id.equals(group[index].id)))
            .write(BoardColumnsCompanion(rankKey: Value<String>(ranks[index])));
      }
    }

    final List<Card> existingCards = await select(cards).get();
    final Map<String, List<Card>> byColumn = <String, List<Card>>{};
    for (final Card card in existingCards) {
      (byColumn[card.columnId] ??= <Card>[]).add(card);
    }
    for (final List<Card> group in byColumn.values) {
      group.sort((Card a, Card b) => (a.rank ?? 0).compareTo(b.rank ?? 0));
      final List<String> ranks = FractionalIndexing.rebalance(group.length);
      for (int index = 0; index < group.length; index++) {
        await (update(cards)..where((tbl) => tbl.id.equals(group[index].id)))
            .write(CardsCompanion(rankKey: Value<String>(ranks[index])));
      }
    }
  }

  Future<T> inTransaction<T>(Future<T> Function() action) =>
      transaction(action);

  Future<void> upsertSearchEntry({
    required String entityType,
    required String entityId,
    required String title,
    required String body,
  }) async {
    await customStatement(
      'DELETE FROM search_fts WHERE entity_type = ? AND entity_id = ?',
      <Object?>[entityType, entityId],
    );
    await customStatement(
      'INSERT INTO search_fts(entity_type, entity_id, title, body) VALUES (?, ?, ?, ?)',
      <Object?>[entityType, entityId, title, body],
    );
  }

  Future<void> deleteSearchEntry(String entityType, String entityId) {
    return customStatement(
      'DELETE FROM search_fts WHERE entity_type = ? AND entity_id = ?',
      <Object?>[entityType, entityId],
    );
  }
}
