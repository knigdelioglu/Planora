import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/sync/policy_sync_queue_repository.dart';
import 'package:not_app/core/sync/sync_models.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/attachments/domain/attachment_backup_policy.dart';

class _Clock implements AppClock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 8, 17, 12);
}

void main() {
  test('oversized local attachment never enters cloud sync queue', () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final _Clock clock = _Clock();
    final DriftSyncQueueRepository baseQueue = DriftSyncQueueRepository(
      database: db,
      clock: clock,
    );
    final PolicySyncQueueRepository queue = PolicySyncQueueRepository(
      delegate: baseQueue,
      database: db,
    );
    final DateTime now = clock.nowUtc();

    await db
        .into(db.attachments)
        .insert(
          AttachmentsCompanion.insert(
            id: 'large-attachment',
            parentType: 'note',
            parentId: 'note-1',
            fileName: 'large.pdf',
            localPath: '/local/large.pdf',
            sizeBytes: AttachmentBackupPolicy.maximumCloudBackupBytes + 1,
            transferState: const Value<String>('pendingUpload'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await queue.enqueue(
      entityType: 'attachment',
      entityId: 'large-attachment',
      operationType: SyncOperationType.upsert,
      baseVersion: 0,
      payload: <String, Object?>{
        'id': 'large-attachment',
        'sizeBytes': AttachmentBackupPolicy.maximumCloudBackupBytes + 1,
        'version': 1,
        'updatedAt': now.toIso8601String(),
      },
    );
    await queue.enqueue(
      entityType: 'attachment',
      entityId: 'large-attachment',
      operationType: SyncOperationType.uploadAttachment,
      baseVersion: 1,
      payload: const <String, Object?>{
        'attachmentId': 'large-attachment',
        'localPath': '/local/large.pdf',
        'fileName': 'large.pdf',
      },
    );

    final Attachment row = await (db.select(
      db.attachments,
    )..where((tbl) => tbl.id.equals('large-attachment'))).getSingle();
    expect(row.transferState, 'localOnly');
    expect(await baseQueue.dueOperations(), isEmpty);
  });

  test('attachment at cloud limit is still queued', () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final _Clock clock = _Clock();
    final DriftSyncQueueRepository baseQueue = DriftSyncQueueRepository(
      database: db,
      clock: clock,
    );
    final PolicySyncQueueRepository queue = PolicySyncQueueRepository(
      delegate: baseQueue,
      database: db,
    );
    final DateTime now = clock.nowUtc();

    await db
        .into(db.attachments)
        .insert(
          AttachmentsCompanion.insert(
            id: 'limit-attachment',
            parentType: 'note',
            parentId: 'note-1',
            fileName: 'limit.pdf',
            localPath: '/local/limit.pdf',
            sizeBytes: AttachmentBackupPolicy.maximumCloudBackupBytes,
            transferState: const Value<String>('pendingUpload'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await queue.enqueue(
      entityType: 'attachment',
      entityId: 'limit-attachment',
      operationType: SyncOperationType.upsert,
      baseVersion: 0,
      payload: <String, Object?>{
        'id': 'limit-attachment',
        'sizeBytes': AttachmentBackupPolicy.maximumCloudBackupBytes,
        'version': 1,
        'updatedAt': now.toIso8601String(),
      },
    );

    expect(await baseQueue.dueOperations(), hasLength(1));
  });
}
