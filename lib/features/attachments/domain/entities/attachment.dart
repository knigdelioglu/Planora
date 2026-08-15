class Attachment {
  const Attachment({
    required this.id,
    required this.parentType,
    required this.parentId,
    required this.fileName,
    required this.localPath,
    required this.sizeBytes,
    this.mimeType,
    this.remotePath,
  });

  final String id;
  final String parentType;
  final String parentId;
  final String fileName;
  final String localPath;
  final String? remotePath;
  final String? mimeType;
  final int sizeBytes;
}
