import 'package:drift/drift.dart';

@TableIndex(name: 'notes_updated_at_idx', columns: {#updatedAt})
@TableIndex(name: 'notes_deleted_at_idx', columns: {#deletedAt})
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get contentJson =>
      text().withDefault(const Constant('{"version":1,"blocks":[]}'))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
