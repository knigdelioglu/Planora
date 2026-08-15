import 'package:drift/drift.dart';
import 'package:not_app/core/database/tables/board_columns_table.dart';
import 'package:not_app/core/database/tables/boards_table.dart';

class Cards extends Table {
  TextColumn get id => text()();
  TextColumn get boardId => text().references(Boards, #id)();
  TextColumn get columnId => text().references(BoardColumns, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  RealColumn get rank => real()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
