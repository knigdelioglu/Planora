final class SyncConflictEntity {
  const SyncConflictEntity({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.localJson,
    required this.remoteJson,
    required this.createdAt,
    this.resolvedAt,
    this.resolution,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String localJson;
  final String remoteJson;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolution;
}
