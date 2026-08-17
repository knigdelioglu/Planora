import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart';
import 'package:not_app/core/security/local_data_key_service.dart';
import 'package:not_app/core/services/file_storage_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

final class EncryptedFileStorageService implements FileStorageService {
  EncryptedFileStorageService({
    required FileStorageService delegate,
    required LocalDataKeyService keyService,
    Future<Directory> Function()? tempDirectoryProvider,
    Uuid? uuid,
  }) : _delegate = delegate,
       _keyService = keyService,
       _tempDirectoryProvider = tempDirectoryProvider,
       _uuid = uuid ?? const Uuid();

  static final List<int> _magic = ascii.encode('NOTENC01');
  static const int _macLength = 16;

  final FileStorageService _delegate;
  final LocalDataKeyService _keyService;
  final Future<Directory> Function()? _tempDirectoryProvider;
  final Uuid _uuid;
  final AesGcm _cipher = AesGcm.with256bits();
  Future<SecretKey>? _secretKeyFuture;

  int get _headerLength => _magic.length + _cipher.nonceLength;

  Future<SecretKey> _secretKey() => _secretKeyFuture ??= _keyService
      .attachmentKey()
      .then((bytes) => SecretKey(bytes));

  @override
  Future<StoredFile> persist(File source, {String? attachmentId}) {
    return _persistEncrypted(source, attachmentId: attachmentId, cache: false);
  }

  @override
  Future<StoredFile> persistCache(File source, {required String attachmentId}) {
    return _persistEncrypted(source, attachmentId: attachmentId, cache: true);
  }

  Future<StoredFile> _persistEncrypted(
    File source, {
    required String? attachmentId,
    required bool cache,
  }) async {
    if (!await source.exists()) {
      throw FileSystemException('Selected file no longer exists.', source.path);
    }
    final String safeOriginalName = _safeName(p.basename(source.path));
    final int clearSize = await source.length();
    final Digest clearDigest = await sha256.bind(source.openRead()).first;
    final Directory workspace = await _cryptoWorkspace();
    await workspace.create(recursive: true);
    final File encrypted = File(p.join(workspace.path, '${_uuid.v7()}.notenc'));

    try {
      await _encrypt(source, encrypted);
      final StoredFile stored = cache
          ? await _delegate.persistCache(encrypted, attachmentId: attachmentId!)
          : await _delegate.persist(encrypted, attachmentId: attachmentId);
      return StoredFile(
        id: stored.id,
        localPath: stored.localPath,
        fileName: safeOriginalName,
        sizeBytes: clearSize,
        checksum: clearDigest.toString(),
      );
    } finally {
      if (await encrypted.exists()) {
        try {
          await encrypted.delete();
        } catch (_) {}
      }
    }
  }

  Future<File> materializeForRead(
    String localPath, {
    required String fileName,
  }) async {
    if (!await _delegate.isWithinSandbox(localPath)) {
      throw FileSystemException(
        'Refusing to read an attachment outside the managed sandbox.',
        localPath,
      );
    }
    final File encrypted = File(p.normalize(p.absolute(localPath)));
    if (!await encrypted.exists()) {
      throw FileSystemException('Attachment is missing.', localPath);
    }
    await _ensureEncryptedAtRest(encrypted);

    final Directory root = await _materializedRoot();
    final Directory directory = Directory(p.join(root.path, _uuid.v7()));
    await directory.create(recursive: true);
    final File clear = File(p.join(directory.path, _safeName(fileName)));
    try {
      await _decrypt(encrypted, clear);
      return clear;
    } catch (_) {
      try {
        await directory.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> deleteMaterialized(File file) async {
    final Directory root = await _materializedRoot();
    final String target = p.normalize(p.absolute(file.path));
    final String allowed = p.normalize(p.absolute(root.path));
    if (!p.isWithin(allowed, target)) return;
    try {
      if (await file.exists()) await file.delete();
      final Directory parent = file.parent;
      if (await parent.exists()) await parent.delete(recursive: true);
    } catch (_) {}
  }

  @override
  Future<bool> exists(String localPath) async {
    if (!await _delegate.exists(localPath)) return false;
    final File file = File(p.normalize(p.absolute(localPath)));
    await _ensureEncryptedAtRest(file);
    return true;
  }

  Future<void> _ensureEncryptedAtRest(File file) async {
    if (await _isEncrypted(file)) return;
    final File replacement = File('${file.path}.${_uuid.v7()}.encrypting');
    try {
      await _encrypt(file, replacement);
      try {
        await replacement.rename(file.path);
      } on FileSystemException {
        await file.delete();
        await replacement.rename(file.path);
      }
    } finally {
      if (await replacement.exists()) {
        try {
          await replacement.delete();
        } catch (_) {}
      }
    }
  }

  Future<bool> _isEncrypted(File file) async {
    if (!await file.exists() ||
        await file.length() < _headerLength + _macLength) {
      return false;
    }
    final RandomAccessFile handle = await file.open();
    try {
      final List<int> prefix = await handle.read(_magic.length);
      return _bytesEqual(prefix, _magic);
    } finally {
      await handle.close();
    }
  }

  Future<void> _encrypt(File source, File destination) async {
    final SecretKey key = await _secretKey();
    final List<int> nonce = _cipher.newNonce();
    Mac? mac;
    final IOSink sink = destination.openWrite(mode: FileMode.writeOnly);
    try {
      sink.add(_magic);
      sink.add(nonce);
      await sink.addStream(
        _cipher.encryptStream(
          source.openRead(),
          secretKey: key,
          nonce: nonce,
          onMac: (Mac value) => mac = value,
        ),
      );
      final Mac? completedMac = mac;
      if (completedMac == null) {
        throw StateError(
          'Attachment encryption did not produce an authentication tag.',
        );
      }
      sink.add(completedMac.bytes);
      await sink.flush();
      await sink.close();
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      if (await destination.exists()) {
        try {
          await destination.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> _decrypt(File source, File destination) async {
    final int length = await source.length();
    if (length < _headerLength + _macLength) {
      throw const FormatException('Encrypted attachment is truncated.');
    }
    final RandomAccessFile handle = await source.open();
    late final List<int> header;
    late final List<int> macBytes;
    try {
      header = await handle.read(_headerLength);
      await handle.setPosition(length - _macLength);
      macBytes = await handle.read(_macLength);
    } finally {
      await handle.close();
    }
    if (header.length != _headerLength ||
        !_bytesEqual(header.sublist(0, _magic.length), _magic) ||
        macBytes.length != _macLength) {
      throw const FormatException('Encrypted attachment header is invalid.');
    }

    final List<int> nonce = header.sublist(_magic.length);
    final SecretKey key = await _secretKey();
    final IOSink sink = destination.openWrite(mode: FileMode.writeOnly);
    try {
      await sink.addStream(
        _cipher.decryptStream(
          source.openRead(_headerLength, length - _macLength),
          secretKey: key,
          nonce: nonce,
          mac: Mac(macBytes),
        ),
      );
      await sink.flush();
      await sink.close();
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      if (await destination.exists()) {
        try {
          await destination.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<Directory> _tempRoot() => _tempDirectoryProvider != null
      ? _tempDirectoryProvider!()
      : getTemporaryDirectory();

  Future<Directory> _cryptoWorkspace() async {
    final Directory root = await _tempRoot();
    return Directory(p.join(root.path, 'not_attachment_crypto'));
  }

  Future<Directory> _materializedRoot() async {
    final Directory root = await _tempRoot();
    return Directory(p.join(root.path, 'not_attachment_materialized'));
  }

  String _safeName(String candidate) {
    final String basename = p.basename(candidate);
    final String stripped = basename
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .trim();
    final String normalized = stripped.isEmpty ? 'attachment' : stripped;
    return normalized.length <= 180 ? normalized : normalized.substring(0, 180);
  }

  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int difference = 0;
    for (int index = 0; index < a.length; index++) {
      difference |= a[index] ^ b[index];
    }
    return difference == 0;
  }

  @override
  Future<void> cleanTempDownloads() async {
    await _delegate.cleanTempDownloads();
    for (final Directory directory in <Directory>[
      await _cryptoWorkspace(),
      await _materializedRoot(),
    ]) {
      if (await directory.exists()) {
        try {
          await directory.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> deleteOwned(String localPath) =>
      _delegate.deleteOwned(localPath);

  @override
  Future<void> deleteCache(String localPath) =>
      _delegate.deleteCache(localPath);

  @override
  Future<void> deleteSandboxFile(String localPath) =>
      _delegate.deleteSandboxFile(localPath);

  @override
  Future<int> cacheSizeBytes() => _delegate.cacheSizeBytes();

  @override
  Future<void> evictCacheUntil({required int maximumBytes}) =>
      _delegate.evictCacheUntil(maximumBytes: maximumBytes);

  @override
  Future<bool> isWithinSandbox(String localPath, {String? bucket}) =>
      _delegate.isWithinSandbox(localPath, bucket: bucket);

  @override
  Future<List<File>> listFiles({String? bucket}) =>
      _delegate.listFiles(bucket: bucket);

  @override
  Future<void> cleanEmptyDirectories({String? bucket}) =>
      _delegate.cleanEmptyDirectories(bucket: bucket);
}
