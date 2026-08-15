final class RemoteEntity {
  const RemoteEntity({
    required this.entityType,
    required this.entityId,
    required this.version,
    required this.updatedAt,
    required this.payload,
    required this.syncRevision,
    this.deletedAt,
  });

  final String entityType;
  final String entityId;
  final int version;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final Map<String, Object?> payload;
  final int syncRevision;
}

sealed class RemoteApplyResult {
  const RemoteApplyResult();
}

final class RemoteApplySuccess extends RemoteApplyResult {
  const RemoteApplySuccess(this.revision);
  final int revision;
}

final class RemoteApplyConflict extends RemoteApplyResult {
  const RemoteApplyConflict(this.remote);
  final RemoteEntity remote;
}
