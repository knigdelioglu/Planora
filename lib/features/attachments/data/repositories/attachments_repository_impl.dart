import 'dart:io';

import 'package:not_app/features/attachments/domain/entities/attachment.dart';
import 'package:not_app/features/attachments/domain/repositories/attachments_repository.dart';

/// Orchestrates FileStorageService + Drift transaction + sync queue.
final class AttachmentsRepositoryImpl implements AttachmentsRepository {
  const AttachmentsRepositoryImpl();

  @override
  Future<Attachment> add({
    required String parentType,
    required String parentId,
    required File source,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> remove(String attachmentId) => throw UnimplementedError();
}
