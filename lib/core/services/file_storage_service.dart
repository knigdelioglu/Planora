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

final class AttachmentReconciliationResult {
  const AttachmentReconciliationResult({
    this.missingFilesHandled = 0,
    this.tombstonesCleaned = 0,
    this.orphanedFilesDeleted = 0,
    this.tempFilesCleaned = 0,
  });

  final int missingFilesHandled;
  final int tombstonesCleaned;
  final int orphanedFilesDeleted;
  final int tempFilesCleaned;

  int get totalActions =>
      missingFilesHandled +
      tombstonesCleaned +
      orphanedFilesDeleted +
      tempFilesCleaned;
}

abstract interface class FileStorageService {
  Future<StoredFile> persist(File source, {String? attachmentId});
  Future<StoredFile> persistCache(File source, {required String attachmentId});
  Future<void> deleteOwned(String localPath);
  Future<void> deleteCache(String localPath);
  Future<void> deleteSandboxFile(String localPath);
  Future<int> cacheSizeBytes();
  Future<void> evictCacheUntil({required int maximumBytes});
  Future<bool> exists(String localPath);
  Future<bool> isWithinSandbox(String localPath, {String? bucket});
  Future<List<File>> listFiles({String? bucket});
  Future<void> cleanTempDownloads();
  Future<void> cleanEmptyDirectories({String? bucket});
}

final class SandboxFileStorageService implements FileStorageService {
  SandboxFileStorageService({
    this.rootDirectoryProvider,
    this.tempDirectoryProvider,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final Future<Directory> Function()? rootDirectoryProvider;
  final Future<Directory> Function()? tempDirectoryProvider;
  final Uuid _uuid;

  Future<Directory> Function()? get _rootDirectoryProvider =>
      rootDirectoryProvider;
  Future<Directory> Function()? get _tempDirectoryProvider =>
      tempDirectoryProvider;

  Future<Directory> _supportRoot() async {
    final Directory base = _rootDirectoryProvider != null
        ? await _rootDirectoryProvider!()
        : await getApplicationSupportDirectory();
    final Directory root = Directory(p.join(base.path, 'app_storage'));
    await root.create(recursive: true);
    return root;
  }

  Future<Directory> _tempRoot() async {
    final Directory base = _tempDirectoryProvider != null
        ? await _tempDirectoryProvider!()
        : await getTemporaryDirectory();
    final Directory temp = Directory(
      p.join(base.path, 'not_attachment_downloads'),
    );
    return temp;
  }

  @override
  Future<bool> isWithinSandbox(String localPath, {String? bucket}) async {
    if (localPath.trim().isEmpty) return false;
    final Directory root = await _supportRoot();
    final String target = p.normalize(p.absolute(localPath));
    if (bucket != null) {
      final String allowed = p.normalize(p.absolute(p.join(root.path, bucket)));
      return p.isWithin(allowed, target);
    }
    final String allowedOwned = p.normalize(
      p.absolute(p.join(root.path, 'attachments')),
    );
    final String allowedCache = p.normalize(
      p.absolute(p.join(root.path, 'cache')),
    );
    return p.isWithin(allowedOwned, target) || p.isWithin(allowedCache, target);
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

  @override
  Future<void> deleteSandboxFile(String localPath) =>
      _deleteWithin(localPath, null);

  Future<void> _deleteWithin(String localPath, String? bucket) async {
    if (localPath.trim().isEmpty) return;
    final bool within = await isWithinSandbox(localPath, bucket: bucket);
    if (!within) {
      throw FileSystemException(
        'Refusing to delete outside managed sandbox.',
        localPath,
      );
    }
    final String target = p.normalize(p.absolute(localPath));
    final File file = File(target);
    if (await file.exists()) {
      await file.delete();
    }
    final Directory root = await _supportRoot();
    final String allowedOwned = p.normalize(
      p.absolute(p.join(root.path, 'attachments')),
    );
    final String allowedCache = p.normalize(
      p.absolute(p.join(root.path, 'cache')),
    );
    Directory parent = file.parent;
    while (p.isWithin(allowedOwned, parent.path) ||
        p.isWithin(allowedCache, parent.path)) {
      if (await parent.exists()) {
        final List<FileSystemEntity> remaining = await parent.list().toList();
        if (remaining.isEmpty) {
          await parent.delete();
          parent = parent.parent;
        } else {
          break;
        }
      } else {
        break;
      }
    }
  }

  @override
  Future<bool> exists(String localPath) async {
    if (localPath.trim().isEmpty) return false;
    final bool within = await isWithinSandbox(localPath);
    if (!within) return false;
    return File(p.normalize(p.absolute(localPath))).exists();
  }

  @override
  Future<List<File>> listFiles({String? bucket}) async {
    final Directory root = await _supportRoot();
    final List<File> result = <File>[];
    if (bucket != null) {
      final Directory dir = Directory(p.join(root.path, bucket));
      if (await dir.exists()) {
        await for (final FileSystemEntity entity in dir.list(recursive: true)) {
          if (entity is File) result.add(entity);
        }
      }
    } else {
      for (final String b in const <String>['attachments', 'cache']) {
        final Directory dir = Directory(p.join(root.path, b));
        if (await dir.exists()) {
          await for (final FileSystemEntity entity in dir.list(
            recursive: true,
          )) {
            if (entity is File) result.add(entity);
          }
        }
      }
    }
    return result;
  }

  @override
  Future<void> cleanTempDownloads() async {
    final Directory temp = await _tempRoot();
    if (await temp.exists()) {
      try {
        await temp.delete(recursive: true);
      } catch (_) {}
    }
  }

  @override
  Future<void> cleanEmptyDirectories({String? bucket}) async {
    final Directory root = await _supportRoot();
    final List<String> buckets = bucket != null
        ? <String>[bucket]
        : const <String>['attachments', 'cache'];
    for (final String b in buckets) {
      final Directory dir = Directory(p.join(root.path, b));
      if (!await dir.exists()) continue;
      await _cleanEmptyDirsRecursive(dir);
    }
  }

  Future<bool> _cleanEmptyDirsRecursive(Directory dir) async {
    if (!await dir.exists()) return true;
    bool isEmpty = true;
    final List<FileSystemEntity> entities = await dir.list().toList();
    for (final FileSystemEntity entity in entities) {
      if (entity is Directory) {
        final bool subEmpty = await _cleanEmptyDirsRecursive(entity);
        if (!subEmpty) isEmpty = false;
      } else {
        isEmpty = false;
      }
    }
    if (isEmpty) {
      try {
        await dir.delete();
      } catch (_) {}
    }
    return isEmpty;
  }

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
      try {
        await file.delete();
      } catch (_) {}
      total -= size;
    }
  }
}
