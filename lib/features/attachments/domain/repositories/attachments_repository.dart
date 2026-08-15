import 'dart:io';

import 'package:not_app/features/attachments/domain/entities/attachment.dart';

abstract interface class AttachmentsRepository {
  Future<Attachment> add({
    required String parentType,
    required String parentId,
    required File source,
  });
  Future<void> remove(String attachmentId);
}
