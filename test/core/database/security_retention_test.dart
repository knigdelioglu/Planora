import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('completed sync operations are scrubbed immediately', () async {
    final DateTime now = DateTime.utc(2026, 8, 17, 12);
    await database
        .into(database.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            operationId: 'op_1',
            entityType: 'note',
            entityId: 'note_1',
            operationType: 'upsert',
            payloadJson: '{"contentJson":"TOP SECRET"}',
            createdAt: now,
          ),
        );

    await (database.update(database.syncQueue)
          ..where((tbl) => tbl.operationId.equals('op_1')))
        .write(const SyncQueueCompanion(status: Value<String>('completed')));

    final SyncQueueData row = await (database.select(
      database.syncQueue,
    )..where((tbl) => tbl.operationId.equals('op_1'))).getSingle();
    expect(row.payloadJson, '{}');
    expect(row.lastError, isNull);
  });

  test('resolved conflict snapshots are scrubbed immediately', () async {
    final DateTime now = DateTime.utc(2026, 8, 17, 12);
    await database
        .into(database.conflicts)
        .insert(
          ConflictsCompanion.insert(
            id: 'conflict_1',
            entityType: 'note',
            entityId: 'note_1',
            localJson: '{"contentJson":"LOCAL SECRET"}',
            remoteJson: '{"contentJson":"REMOTE SECRET"}',
            localUpdatedAt: now,
            remoteUpdatedAt: now,
            createdAt: now,
          ),
        );

    await (database.update(database.conflicts)
          ..where((tbl) => tbl.id.equals('conflict_1')))
        .write(ConflictsCompanion(resolvedAt: Value<DateTime?>(now)));

    final Conflict row = await (database.select(
      database.conflicts,
    )..where((tbl) => tbl.id.equals('conflict_1'))).getSingle();
    expect(row.localJson, '{}');
    expect(row.remoteJson, '{}');
  });
}
