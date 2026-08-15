import 'package:drift/drift.dart';

@TableIndex(name: 'boards_updated_at_idx', columns: {#updatedAt})
class Boards extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get colorHex => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
