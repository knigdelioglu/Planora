import 'package:drift/drift.dart';

@TableIndex(name: 'reminders_parent_idx', columns: {#parentType, #parentId})
@TableIndex(name: 'reminders_schedule_idx', columns: {#scheduledAtUtc})
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get parentType => text()();
  TextColumn get parentId => text()();
  TextColumn get title => text()();
  TextColumn get body => text().nullable()();
  DateTimeColumn get scheduledAtUtc => dateTime()();
  TextColumn get timeZoneId => text()();
  IntColumn get notificationId => integer()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get schedulingStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get lastReconciledAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
