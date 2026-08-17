import 'package:drift/drift.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/sync/sync_models.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/features/attachments/domain/attachment_backup_policy.dart';

final class PolicySyncQueueRepository implements SyncQueueRepository {
  PolicySyncQueueRepository({
    required SyncQueueRepository delegate,
    required AppDatabase database,
    AttachmentBackupPolicy backupPolicy = const AttachmentBackupPolicy(),
  }) : _delegate = delegate,
       _database = database,
       _backupPolicy = backupPolicy;

  final SyncQueueRepository _delegate;
  final AppDatabase _database;
  final AttachmentBackupPolicy _backupPolicy;

  @override
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required SyncOperationType operationType,
    required Map<String, Object?> payload,
    int? baseVersion,
  }) async {
    if (entityType == 'attachment') {
      final Attachment? row = await (_database.select(_database.attachments)
            ..where((tbl) => tbl.id.equals(entityId)))
          .getSingleOrNull();
      if (row != null && row.remotePath == null) {
        if (operationType == SyncOperationType.delete &&
            row.transferState == 'localOnly') {
          return;
        }
        if (operationType != SyncOperationType.delete &&
            !_backupPolicy.allowsSize(row.sizeBytes)) {
          await (_database.update(_database.attachments)
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
    await _delegate.enqueue(
      entityType: entityType,
      entityId: entityId,
      operationType: operationType,
      payload: payload,
      baseVersion: baseVersion,
    );
  }

  @override
  Future<List<SyncOperation>> dueOperations({int limit = 50}) async {
    final List<SyncOperation> due = await _delegate.dueOperations(limit: limit);
    final List<SyncOperation> allowed = <SyncOperation>[];
    for (final SyncOperation operation in due) {
      if (operation.entityType != 'attachment' ||
          operation.operationType == SyncOperationType.delete) {
        allowed.add(operation);
        continue;
      }
      final Attachment? row = await (_database.select(_database.attachments)
            ..where((tbl) => tbl.id.equals(operation.entityId)))
          .getSingleOrNull();
      if (row == null ||
          row.deletedAt != null ||
          row.remotePath != null ||
          _backupPolicy.allowsSize(row.sizeBytes)) {
        allowed.add(operation);
        continue;
      }
      await (_database.update(_database.attachments)
            ..where((tbl) => tbl.id.equals(operation.entityId)))
          .write(
        const AttachmentsCompanion(
          transferState: Value<String>('localOnly'),
        ),
      );
      await _delegate.markCompleted(operation.id);
    }
    return allowed;
  }

  @override
  Future<List<SyncOperation>> allOperations({
    SyncOperationStatus? status,
    bool includeCompleted = false,
  }) => _delegate.allOperations(
    status: status,
    includeCompleted: includeCompleted,
  );

  @override
  Stream<List<SyncOperation>> watchOperations({
    SyncOperationStatus? status,
    bool includeCompleted = false,
  }) => _delegate.watchOperations(
    status: status,
    includeCompleted: includeCompleted,
  );

  @override
  Future<Map<SyncOperationStatus, int>> statusCounts() =>
      _delegate.statusCounts();

  @override
  Stream<Map<SyncOperationStatus, int>> watchStatusCounts() =>
      _delegate.watchStatusCounts();

  @override
  Future<void> retryOperation(String operationId) =>
      _delegate.retryOperation(operationId);

  @override
  Future<void> retryAll({SyncOperationStatus? status}) =>
      _delegate.retryAll(status: status);

  @override
  Future<void> deleteOperation(String operationId) =>
      _delegate.deleteOperation(operationId);

  @override
  Future<void> clearQueue({
    SyncOperationStatus? status,
    bool onlyUncompleted = true,
  }) => _delegate.clearQueue(
    status: status,
    onlyUncompleted: onlyUncompleted,
  );

  @override
  Future<void> markProcessing(String operationId) =>
      _delegate.markProcessing(operationId);

  @override
  Future<void> markCompleted(String operationId) =>
      _delegate.markCompleted(operationId);

  @override
  Future<void> markRetry(String operationId, {required String error}) =>
      _delegate.markRetry(operationId, error: error);

  @override
  Future<void> markFailedRecoverable(
    String operationId, {
    required String error,
  }) => _delegate.markFailedRecoverable(operationId, error: error);

  @override
  Future<void> markConflict(String operationId, {required String error}) =>
      _delegate.markConflict(operationId, error: error);

  @override
  Future<void> resolveBlockedConflicts({
    required String entityType,
    required String entityId,
  }) => _delegate.resolveBlockedConflicts(
    entityType: entityType,
    entityId: entityId,
  );

  @override
  Stream<int> watchPendingCount() => _delegate.watchPendingCount();
}
