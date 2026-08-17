import 'dart:io';

import 'package:mime/mime.dart';

final class AttachmentBackupDecision {
  const AttachmentBackupDecision({
    required this.allowed,
    required this.sizeBytes,
    required this.mimeType,
    required this.maximumBytes,
  });

  final bool allowed;
  final int sizeBytes;
  final String? mimeType;
  final int maximumBytes;

  bool get localOnly => !allowed;
}

final class AttachmentBackupPolicy {
  const AttachmentBackupPolicy();

  static const int maximumCloudBackupBytes = 10 * 1024 * 1024;

  bool allowsSize(int sizeBytes) => sizeBytes <= maximumCloudBackupBytes;

  Future<AttachmentBackupDecision> evaluate(File file) async {
    final int sizeBytes = await file.length();
    return AttachmentBackupDecision(
      allowed: allowsSize(sizeBytes),
      sizeBytes: sizeBytes,
      mimeType: lookupMimeType(file.path),
      maximumBytes: maximumCloudBackupBytes,
    );
  }

  String localOnlyMessage(String fileName, int sizeBytes) {
    return '$fileName (${formatBytes(sizeBytes)}) buluta yedeklenmeyecek. '
        'Dosya yalnızca bu cihazda saklanacak ve diğer cihazlarda otomatik görünmeyecek.';
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final double kib = bytes / 1024;
    if (kib < 1024) return '${kib.toStringAsFixed(kib >= 100 ? 0 : 1)} KB';
    final double mib = kib / 1024;
    return '${mib.toStringAsFixed(mib >= 100 ? 0 : 1)} MB';
  }
}
