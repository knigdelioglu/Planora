import 'package:drift/drift.dart';
import 'package:not_app/core/database/connection/native.dart';
import 'package:not_app/core/database/tables/attachments_table.dart';
import 'package:not_app/core/database/tables/board_columns_table.dart';
import 'package:not_app/core/database/tables/boards_table.dart';
import 'package:not_app/core/database/tables/cards_table.dart';
import 'package:not_app/core/database/tables/notes_table.dart';
import 'package:not_app/core/database/tables/reminders_table.dart';
import 'package:not_app/core/database/tables/sync_queue_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Boards,
    BoardColumns,
    Cards,
    Notes,
    Attachments,
    Reminders,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  static Future<AppDatabase> open() async => AppDatabase(await openNativeConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async => migrator.createAll(),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
