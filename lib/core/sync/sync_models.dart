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

extension SyncOperationStatusX on SyncOperationStatus {
  String get displayName {
    switch (this) {
      case SyncOperationStatus.pending:
        return 'Bekliyor';
      case SyncOperationStatus.processing:
        return 'İşleniyor';
      case SyncOperationStatus.retryWaiting:
        return 'Tekrar Denenecek';
      case SyncOperationStatus.failedRecoverable:
        return 'Başarısız';
      case SyncOperationStatus.completed:
        return 'Tamamlandı';
      case SyncOperationStatus.blockedConflict:
        return 'Çakışmada';
    }
  }
}

extension SyncOperationTypeX on SyncOperationType {
  String get displayName {
    switch (this) {
      case SyncOperationType.upsert:
        return 'Kaydet / Güncelle';
      case SyncOperationType.delete:
        return 'Sil';
      case SyncOperationType.uploadAttachment:
        return 'Dosya Yükle';
    }
  }
}

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

  String get targetEntityDisplayName {
    final dynamic title =
        payload['title'] ?? payload['name'] ?? payload['fileName'];
    if (title is String && title.trim().isNotEmpty) {
      return '$entityType: ${title.trim()}';
    }
    return '$entityType · $entityId';
  }
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
