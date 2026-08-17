final class AttachmentTransferProgress {
  const AttachmentTransferProgress({
    required this.attachmentId,
    required this.isUpload,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.progress,
  });

  final String attachmentId;
  final bool isUpload;
  final int bytesTransferred;
  final int totalBytes;
  final double progress;

  int get percentage => (progress * 100).clamp(0, 100).toInt();
}

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
  bool get isUploading => transferState == 'uploading';
  bool get isDownloading => transferState == 'downloading';
  bool get isPending =>
      transferState == 'pending' ||
      transferState == 'pendingUpload' ||
      transferState == 'pendingDownload';
  bool get isFailed =>
      transferState == 'failed' ||
      transferState == 'error' ||
      transferState == 'cancelled';
  bool get isRetryPending =>
      transferState == 'retryPending' || transferState == 'retryWaiting';
  bool get isSynced =>
      transferState == 'synced' || transferState == 'completed';
  bool get isLocalOnly => transferState == 'localOnly';
  bool get isRemoteOnly => transferState == 'remoteOnly';
  bool get isTransferring => isUploading || isDownloading;
  bool get canRetry =>
      isFailed ||
      isRetryPending ||
      (remotePath != null && localPath.isEmpty && !isDownloading);

  String transferStatusLabel([double? progress]) {
    if (isUploading) {
      return progress != null && progress > 0
          ? 'Yükleniyor (%${(progress * 100).clamp(0, 100).toInt()})'
          : 'Yükleniyor';
    }
    if (isDownloading) {
      return progress != null && progress > 0
          ? 'İndiriliyor (%${(progress * 100).clamp(0, 100).toInt()})'
          : 'İndiriliyor';
    }
    if (isPending) return 'Bekliyor';
    if (isFailed) return 'Başarısız';
    if (isRetryPending) return 'Tekrar denenecek';
    if (isSynced) return 'Tamamlandı';
    if (isLocalOnly) return 'Cihazda · Buluta yedeklenmiyor';
    if (isRemoteOnly) return 'Bulutta';
    return transferState;
  }
}
