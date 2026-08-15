import 'package:drift/drift.dart';

@TableIndex(name: 'attachments_parent_idx', columns: {#parentType, #parentId})
@TableIndex(name: 'attachments_accessed_idx', columns: {#lastAccessedAt})
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get parentType => text()();
  TextColumn get parentId => text()();
  TextColumn get fileName => text()();
  TextColumn get localPath => text()();
  TextColumn get remotePath => text().nullable()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get sizeBytes => integer()();
  TextColumn get checksum => text().nullable()();
  BoolColumn get isCache => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastAccessedAt => dateTime().nullable()();
  TextColumn get transferState =>
      text().withDefault(const Constant('localOnly'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
