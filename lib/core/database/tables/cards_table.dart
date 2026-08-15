import 'package:drift/drift.dart';
import 'package:not_app/core/database/tables/board_columns_table.dart';
import 'package:not_app/core/database/tables/boards_table.dart';

@TableIndex(name: 'cards_column_rank_idx', columns: {#columnId, #rankKey})
@TableIndex(name: 'cards_board_idx', columns: {#boardId})
class Cards extends Table {
  TextColumn get id => text()();
  TextColumn get boardId => text().references(Boards, #id)();
  TextColumn get columnId => text().references(BoardColumns, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();

  /// Kept nullable for schema-v1 migration compatibility. Product ordering
  /// uses [rankKey] exclusively.
  RealColumn get rank => real().nullable()();
  TextColumn get rankKey => text().withDefault(const Constant('hzzzzzzzzzzz'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
