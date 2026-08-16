import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('schema v1 fixture migrates to v3 without data loss', () async {
    final _FixtureDatabase fixture = await _FixtureDatabase.create('schema_v1.sql');
    addTearDown(fixture.dispose);

    final sqlite.Database raw = sqlite.sqlite3.open(fixture.file.path);
    try {
      raw.execute(
        "INSERT INTO boards(id, title, created_at, updated_at) "
        "VALUES ('board-1', 'Legacy board', 1000, 1000)",
      );
      raw.execute(
        "INSERT INTO board_columns(id, board_id, title, rank, created_at, updated_at) "
        "VALUES ('column-late', 'board-1', 'Late', 20, 1000, 1000)",
      );
      raw.execute(
        "INSERT INTO board_columns(id, board_id, title, rank, created_at, updated_at) "
        "VALUES ('column-early', 'board-1', 'Early', 10, 1000, 1000)",
      );
      raw.execute(
        "INSERT INTO cards(id, board_id, column_id, title, rank, created_at, updated_at) "
        "VALUES ('card-late', 'board-1', 'column-early', 'Late card', 20, 1000, 1000)",
      );
      raw.execute(
        "INSERT INTO cards(id, board_id, column_id, title, rank, created_at, updated_at) "
        "VALUES ('card-early', 'board-1', 'column-early', 'Early card', 10, 1000, 1000)",
      );
      raw.execute(
        "INSERT INTO notes(id, title, content_json, created_at, updated_at) "
        "VALUES ('note-1', 'Legacy note', '{\"version\":1,\"blocks\":[]}', 1000, 1000)",
      );
    } finally {
      raw.dispose();
    }

    AppDatabase db = AppDatabase(NativeDatabase(fixture.file));
    expect(await _userVersion(db), 3);

    final notes = await db.select(db.notes).get();
    expect(notes, hasLength(1));
    expect(notes.single.id, 'note-1');
    expect(notes.single.title, 'Legacy note');
    expect(notes.single.isFavorite, isFalse);
    expect(notes.single.lastOpenedAt, isNull);

    final columns = await db.select(db.boardColumns).get();
    columns.sort((a, b) => a.rankKey.compareTo(b.rankKey));
    expect(columns.map((column) => column.id), <String>['column-early', 'column-late']);
    expect(columns.every((column) => column.rankKey.isNotEmpty), isTrue);

    final cards = await db.select(db.cards).get();
    cards.sort((a, b) => a.rankKey.compareTo(b.rankKey));
    expect(cards.map((card) => card.id), <String>['card-early', 'card-late']);
    expect(cards.every((card) => card.rankKey.isNotEmpty), isTrue);

    final conflictColumns = await _columnNames(db, 'conflicts');
    expect(conflictColumns, contains('resolution'));
    expect(await _tableExists(db, 'app_settings'), isTrue);
    expect(await _tableExists(db, 'sync_meta'), isTrue);
    expect(await _tableExists(db, 'search_fts'), isTrue);
    expect(
      await _indexNames(db),
      containsAll(<String>[
        'boards_updated_at_idx',
        'board_columns_board_rank_idx',
        'cards_column_rank_idx',
        'cards_board_idx',
        'notes_updated_at_idx',
        'notes_deleted_at_idx',
        'attachments_parent_idx',
        'attachments_accessed_idx',
        'reminders_parent_idx',
        'reminders_schedule_idx',
        'sync_queue_due_idx',
        'conflicts_status_idx',
      ]),
    );

    await db.close();

    db = AppDatabase(NativeDatabase(fixture.file));
    expect(await _userVersion(db), 3);
    expect((await db.select(db.notes).get()).single.title, 'Legacy note');
    await db.close();
  });

  test('schema v2 fixture migrates conflict rows to v3', () async {
    final _FixtureDatabase fixture = await _FixtureDatabase.create('schema_v2.sql');
    addTearDown(fixture.dispose);

    final sqlite.Database raw = sqlite.sqlite3.open(fixture.file.path);
    try {
      raw.execute(
        "INSERT INTO conflicts("
        "id, entity_type, entity_id, local_json, remote_json, "
        "local_updated_at, remote_updated_at, status, created_at"
        ") VALUES ("
        "'conflict-1', 'note', 'note-1', '{\"title\":\"local\"}', "
        "'{\"title\":\"remote\"}', 1000, 2000, 'open', 3000"
        ")",
      );
    } finally {
      raw.dispose();
    }

    final AppDatabase db = AppDatabase(NativeDatabase(fixture.file));
    addTearDown(db.close);

    expect(await _userVersion(db), 3);
    expect(await _columnNames(db, 'conflicts'), contains('resolution'));

    final conflicts = await db.select(db.conflicts).get();
    expect(conflicts, hasLength(1));
    expect(conflicts.single.id, 'conflict-1');
    expect(conflicts.single.entityId, 'note-1');
    expect(conflicts.single.localJson, '{"title":"local"}');
    expect(conflicts.single.remoteJson, '{"title":"remote"}');
    expect(conflicts.single.resolution, isNull);
  });
}

Future<int> _userVersion(AppDatabase db) async {
  final row = await db.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
}

Future<Set<String>> _columnNames(AppDatabase db, String tableName) async {
  final rows = await db.customSelect('PRAGMA table_info($tableName)').get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<Set<String>> _indexNames(AppDatabase db) async {
  final rows = await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type = 'index' AND name NOT LIKE 'sqlite_autoindex%'",
  ).get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<bool> _tableExists(AppDatabase db, String tableName) async {
  final row = await db.customSelect(
    'SELECT COUNT(*) AS count FROM sqlite_master WHERE name = ?',
    variables: <Variable<Object>>[Variable<String>(tableName)],
  ).getSingle();
  return row.read<int>('count') == 1;
}

final class _FixtureDatabase {
  _FixtureDatabase(this.directory, this.file);

  final Directory directory;
  final File file;

  static Future<_FixtureDatabase> create(String fixtureName) async {
    final Directory directory = await Directory.systemTemp.createTemp('not_migration_');
    final File file = File('${directory.path}/fixture.sqlite');
    final sqlite.Database raw = sqlite.sqlite3.open(file.path);
    try {
      final String fixtureSql = await File(
        'test/fixtures/database/$fixtureName',
      ).readAsString();
      for (final String statement in fixtureSql.split(';')) {
        final String sql = statement.trim();
        if (sql.isNotEmpty) {
          raw.execute(sql);
        }
      }
    } finally {
      raw.dispose();
    }
    return _FixtureDatabase(directory, file);
  }

  Future<void> dispose() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
