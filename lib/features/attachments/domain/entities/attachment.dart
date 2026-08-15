final class AttachmentEntity {
  const AttachmentEntity({
    required this.id,
    required this.parentType,
    required this.parentId,
    required this.fileName,
    required this.localPath,
    required this.sizeBytes,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.isCache,
    required this.transferState,
    this.remotePath,
    this.mimeType,
    this.checksum,
    this.lastAccessedAt,
    this.deletedAt,
  });

  final String id;
  final String parentType;
  final String parentId;
  final String fileName;
  final String localPath;
  final String? remotePath;
  final String? mimeType;
  final int sizeBytes;
  final String? checksum;
  final bool isCache;
  final DateTime? lastAccessedAt;
  final String transferState;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get hasLocalCopy => localPath.isNotEmpty;
}
