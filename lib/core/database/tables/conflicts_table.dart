import 'package:drift/drift.dart';

@TableIndex(name: 'conflicts_status_idx', columns: {#status, #createdAt})
class Conflicts extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get localJson => text()();
  TextColumn get remoteJson => text()();
  DateTimeColumn get localUpdatedAt => dateTime()();
  DateTimeColumn get remoteUpdatedAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  TextColumn get resolution => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
