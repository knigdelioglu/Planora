import 'package:drift/drift.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/sync/sync_models.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/features/attachments/domain/attachment_backup_policy.dart';

final class PolicySyncQueueRepository implements SyncQueueRepository {
  PolicySyncQueueRepository({
    required this.delegate,
    required this.database,
    this.backupPolicy = const AttachmentBackupPolicy(),
  });

  final SyncQueueRepository delegate;
  final AppDatabase database;
  final AttachmentBackupPolicy backupPolicy;

  @override
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required SyncOperationType operationType,
    required Map<String, Object?> payload,
    int? baseVersion,
  }) async {
    if (entityType == 'attachment') {
      final Attachment? row = await (database.select(database.attachments)
            ..where((tbl) => tbl.id.equals(entityId)))
          .getSingleOrNull();
      if (row != null && row.remotePath == null) {
        if (operationType == SyncOperationType.delete &&
            row.transferState == 'localOnly') {
          return;
        }
        if (operationType != SyncOperationType.delete &&
            !backupPolicy.allowsSize(row.sizeBytes)) {
          await (database.update(database.attachments)
                ..where((tbl) => tbl.id.equals(entityId)))
              .write(
            const AttachmentsCompanion(
              transferState: Value<String>('localOnly'),
            ),
          );
          return;
        }
      }
    }
    await delegate.enqueue(
      entityType: entityType,
      entityId: entityId,
      operationType: operationType,
      payload: payload,
      baseVersion: baseVersion,
    );
  }

  @override
  Future<List<SyncOperation>> dueOperations({int limit = 50}) async {
    final List<SyncOperation> due = await delegate.dueOperations(limit: limit);
    final List<SyncOperation> allowed = <SyncOperation>[];
    for (final SyncOperation operation in due) {
      if (operation.entityType != 'attachment' ||
          operation.operationType == SyncOperationType.delete) {
        allowed.add(operation);
        continue;
      }
      final Attachment? row = await (database.select(database.attachments)
            ..where((tbl) => tbl.id.equals(operation.entityId)))
          .getSingleOrNull();
      if (row == null ||
          row.deletedAt != null ||
          row.remotePath != null ||
          backupPolicy.allowsSize(row.sizeBytes)) {
        allowed.add(operation);
        continue;
      }
      await (database.update(database.attachments)
            ..where((tbl) => tbl.id.equals(operation.entityId)))
          .write(
        const AttachmentsCompanion(
          transferState: Value<String>('localOnly'),
        ),
      );
      await delegate.markCompleted(operation.id);
    }
    return allowed;
  }

  @override
  Future<List<SyncOperation>> allOperations({
    SyncOperationStatus? status,
    bool includeCompleted = false,
  }) => delegate.allOperations(
    status: status,
    includeCompleted: includeCompleted,
  );

  @override
  Stream<List<SyncOperation>> watchOperations({
    SyncOperationStatus? status,
    bool includeCompleted = false,
  }) => delegate.watchOperations(
    status: status,
    includeCompleted: includeCompleted,
  );

  @override
  Future<Map<SyncOperationStatus, int>> statusCounts() =>
      delegate.statusCounts();

  @override
  Stream<Map<SyncOperationStatus, int>> watchStatusCounts() =>
      delegate.watchStatusCounts();

  @override
  Future<void> retryOperation(String operationId) =>
      delegate.retryOperation(operationId);

  @override
  Future<void> retryAll({SyncOperationStatus? status}) =>
      delegate.retryAll(status: status);

  @override
  Future<void> deleteOperation(String operationId) =>
      delegate.deleteOperation(operationId);

  @override
  Future<void> clearQueue({
    SyncOperationStatus? status,
    bool onlyUncompleted = true,
  }) => delegate.clearQueue(
    status: status,
    onlyUncompleted: onlyUncompleted,
  );

  @override
  Future<void> markProcessing(String operationId) =>
      delegate.markProcessing(operationId);

  @override
  Future<void> markCompleted(String operationId) =>
      delegate.markCompleted(operationId);

  @override
  Future<void> markRetry(String operationId, {required String error}) =>
      delegate.markRetry(operationId, error: error);

  @override
  Future<void> markFailedRecoverable(
    String operationId, {
    required String error,
  }) => delegate.markFailedRecoverable(operationId, error: error);

  @override
  Future<void> markConflict(String operationId, {required String error}) =>
      delegate.markConflict(operationId, error: error);

  @override
  Future<void> resolveBlockedConflicts({
    required String entityType,
    required String entityId,
  }) => delegate.resolveBlockedConflicts(
    entityType: entityType,
    entityId: entityId,
  );

  @override
  Stream<int> watchPendingCount() => delegate.watchPendingCount();
}
