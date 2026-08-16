import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

final class StoredFile {
  const StoredFile({
    required this.id,
    required this.localPath,
    required this.fileName,
    required this.sizeBytes,
    required this.checksum,
  });

  final String id;
  final String localPath;
  final String fileName;
  final int sizeBytes;
  final String checksum;
}

abstract interface class FileStorageService {
  Future<StoredFile> persist(File source, {String? attachmentId});
  Future<StoredFile> persistCache(File source, {required String attachmentId});
  Future<void> deleteOwned(String localPath);
  Future<void> deleteCache(String localPath);
  Future<int> cacheSizeBytes();
  Future<void> evictCacheUntil({required int maximumBytes});
  Future<bool> exists(String localPath);
}

final class SandboxFileStorageService implements FileStorageService {
  SandboxFileStorageService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<Directory> _supportRoot() async {
    final Directory support = await getApplicationSupportDirectory();
    final Directory root = Directory(p.join(support.path, 'app_storage'));
    await root.create(recursive: true);
    return root;
  }

  @override
  Future<StoredFile> persist(File source, {String? attachmentId}) async {
    return _persistInto(
      source,
      attachmentId: attachmentId ?? _uuid.v7(),
      cache: false,
    );
  }

  @override
  Future<StoredFile> persistCache(File source, {required String attachmentId}) {
    return _persistInto(source, attachmentId: attachmentId, cache: true);
  }

  Future<StoredFile> _persistInto(
    File source, {
    required String attachmentId,
    required bool cache,
  }) async {
    if (!await source.exists()) {
      throw FileSystemException('Selected file no longer exists.', source.path);
    }
    final Directory root = await _supportRoot();
    final String bucket = cache ? 'cache' : 'attachments';
    final Directory directory = Directory(
      p.join(root.path, bucket, attachmentId),
    );
    await directory.create(recursive: true);
    final String fileName = _safeName(p.basename(source.path));
    final File destination = File(p.join(directory.path, fileName));
    final IOSink sink = destination.openWrite(mode: FileMode.writeOnly);
    try {
      await source.openRead().pipe(sink);
    } catch (_) {
      await sink.close();
      rethrow;
    }
    final int size = await destination.length();
    final Digest digest = await sha256.bind(destination.openRead()).first;
    return StoredFile(
      id: attachmentId,
      localPath: destination.path,
      fileName: fileName,
      sizeBytes: size,
      checksum: digest.toString(),
    );
  }

  String _safeName(String candidate) {
    final String stripped = candidate
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .trim();
    return stripped.isEmpty ? 'attachment' : stripped;
  }

  @override
  Future<void> deleteOwned(String localPath) =>
      _deleteWithin(localPath, 'attachments');

  @override
  Future<void> deleteCache(String localPath) =>
      _deleteWithin(localPath, 'cache');

  Future<void> _deleteWithin(String localPath, String bucket) async {
    final Directory root = await _supportRoot();
    final String allowed = p.normalize(p.absolute(p.join(root.path, bucket)));
    final String target = p.normalize(p.absolute(localPath));
    if (!p.isWithin(allowed, target)) {
      throw FileSystemException(
        'Refusing to delete outside managed sandbox.',
        target,
      );
    }
    final File file = File(target);
    if (await file.exists()) await file.delete();
    final Directory parent = file.parent;
    if (await parent.exists() && p.isWithin(allowed, parent.path)) {
      final List<FileSystemEntity> remaining = await parent.list().toList();
      if (remaining.isEmpty) await parent.delete();
    }
  }

  @override
  Future<bool> exists(String localPath) => File(localPath).exists();

  @override
  Future<int> cacheSizeBytes() async {
    final Directory root = await _supportRoot();
    final Directory cache = Directory(p.join(root.path, 'cache'));
    if (!await cache.exists()) return 0;
    int total = 0;
    await for (final FileSystemEntity entity in cache.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  @override
  Future<void> evictCacheUntil({required int maximumBytes}) async {
    if (maximumBytes < 0) {
      throw ArgumentError.value(maximumBytes, 'maximumBytes');
    }
    final Directory root = await _supportRoot();
    final Directory cache = Directory(p.join(root.path, 'cache'));
    if (!await cache.exists()) return;
    final List<File> files = <File>[];
    await for (final FileSystemEntity entity in cache.list(recursive: true)) {
      if (entity is File) files.add(entity);
    }
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    int total = 0;
    for (final File file in files) {
      total += await file.length();
    }
    for (final File file in files) {
      if (total <= maximumBytes) break;
      final int size = await file.length();
      await file.delete();
      total -= size;
    }
  }
}
