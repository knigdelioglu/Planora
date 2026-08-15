import 'package:drift/drift.dart';

class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get parentType => text()();
  TextColumn get parentId => text()();
  TextColumn get title => text()();
  DateTimeColumn get scheduledAtUtc => dateTime()();
  TextColumn get timeZoneId => text()();
  IntColumn get notificationId => integer()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
