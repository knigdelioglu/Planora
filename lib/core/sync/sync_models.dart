import 'dart:convert';

enum SyncOperationStatus {
  pending,
  processing,
  retryWaiting,
  failedRecoverable,
  completed,
  blockedConflict,
}

enum SyncOperationType { upsert, delete, uploadAttachment }

final class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.payload,
    required this.baseVersion,
    required this.createdAt,
    required this.attemptCount,
    required this.nextAttemptAt,
    required this.status,
    required this.lastError,
  });

  final String id;
  final String entityType;
  final String entityId;
  final SyncOperationType operationType;
  final Map<String, Object?> payload;
  final int? baseVersion;
  final DateTime createdAt;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final SyncOperationStatus status;
  final String? lastError;

  String get payloadJson => jsonEncode(payload);
}

final class SyncConflictRecord {
  const SyncConflictRecord({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.local,
    required this.remote,
    required this.localUpdatedAt,
    required this.remoteUpdatedAt,
    required this.createdAt,
  });

  final String id;
  final String entityType;
  final String entityId;
  final Map<String, Object?> local;
  final Map<String, Object?> remote;
  final DateTime localUpdatedAt;
  final DateTime remoteUpdatedAt;
  final DateTime createdAt;
}
