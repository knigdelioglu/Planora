import 'dart:io';

import 'package:not_app/features/attachments/domain/entities/attachment.dart';

abstract interface class AttachmentsRepository {
  Stream<List<AttachmentEntity>> watchForParent(String parentType, String parentId);
  Future<AttachmentEntity> addFromFile({
    required String parentType,
    required String parentId,
    required File source,
  });
  Future<File> ensureLocal(String attachmentId);
  Future<void> remove(String attachmentId);
  Future<int> cacheSizeBytes();
  Future<void> evictCacheUntil(int maximumBytes);
}
