import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

record StoredFile(
  String localPath,
  String fileName,
  int sizeBytes,
);

abstract interface class FileStorageService {
  Future<StoredFile> persist(File source);
  Future<void> delete(String localPath);
}

final class SandboxFileStorageService implements FileStorageService {
  SandboxFileStorageService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  Future<StoredFile> persist(File source) async {
    final root = await getApplicationSupportDirectory();
    final attachmentDir = Directory(
      p.join(root.path, 'app_storage', 'attachments', _uuid.v7()),
    );
    await attachmentDir.create(recursive: true);

    final fileName = p.basename(source.path);
    final destination = File(p.join(attachmentDir.path, fileName));
    final copied = await source.copy(destination.path);
    final size = await copied.length();

    return (copied.path, fileName, size);
  }

  @override
  Future<void> delete(String localPath) async {
    final file = File(localPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
