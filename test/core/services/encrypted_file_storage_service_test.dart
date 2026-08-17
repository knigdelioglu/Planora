import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/security/local_data_key_service.dart';
import 'package:not_app/core/services/encrypted_file_storage_service.dart';
import 'package:not_app/core/services/file_storage_service.dart';
import 'package:path/path.dart' as p;

final class _FixedKeys implements LocalDataKeyService {
  @override
  Future<List<int>> attachmentKey() async => List<int>.filled(32, 7);

  @override
  Future<String> databasePassphrase() async => 'test-database-key';
}

void main() {
  late Directory root;
  late Directory temp;
  late EncryptedFileStorageService storage;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('not-secure-storage-root-');
    temp = await Directory.systemTemp.createTemp('not-secure-storage-temp-');
    storage = EncryptedFileStorageService(
      delegate: SandboxFileStorageService(
        rootDirectoryProvider: () async => root,
        tempDirectoryProvider: () async => temp,
      ),
      keyService: _FixedKeys(),
      tempDirectoryProvider: () async => temp,
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test(
    'persistent attachment bytes are encrypted and materialize losslessly',
    () async {
      const String secret = 'private note attachment payload 123456';
      final File source = File(p.join(temp.path, 'report.txt'));
      await source.writeAsString(secret, flush: true);

      final StoredFile stored = await storage.persist(
        source,
        attachmentId: 'attachment_1',
      );
      final List<int> persistedBytes = await File(
        stored.localPath,
      ).readAsBytes();

      expect(_containsBytes(persistedBytes, utf8.encode(secret)), isFalse);
      expect(utf8.decode(persistedBytes.sublist(0, 8)), 'NOTENC01');
      expect(stored.sizeBytes, utf8.encode(secret).length);

      final File materialized = await storage.materializeForRead(
        stored.localPath,
        fileName: stored.fileName,
      );
      expect(await materialized.readAsString(), secret);
      await storage.deleteMaterialized(materialized);
    },
  );

  test(
    'legacy plaintext attachment is encrypted during reconciliation lookup',
    () async {
      const String secret = 'legacy plaintext must not remain on disk';
      final Directory legacyDirectory = Directory(
        p.join(root.path, 'app_storage', 'attachments', 'legacy_1'),
      );
      await legacyDirectory.create(recursive: true);
      final File legacyFile = File(p.join(legacyDirectory.path, 'legacy.txt'));
      await legacyFile.writeAsString(secret, flush: true);

      expect(await storage.exists(legacyFile.path), isTrue);
      final List<int> bytes = await legacyFile.readAsBytes();
      expect(_containsBytes(bytes, utf8.encode(secret)), isFalse);
      expect(utf8.decode(bytes.sublist(0, 8)), 'NOTENC01');

      final File materialized = await storage.materializeForRead(
        legacyFile.path,
        fileName: 'legacy.txt',
      );
      expect(await materialized.readAsString(), secret);
    },
  );
}

bool _containsBytes(List<int> haystack, List<int> needle) {
  if (needle.isEmpty) return true;
  if (haystack.length < needle.length) return false;
  for (int start = 0; start <= haystack.length - needle.length; start++) {
    bool match = true;
    for (int index = 0; index < needle.length; index++) {
      if (haystack[start + index] != needle[index]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}
