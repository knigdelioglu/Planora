import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class LocalDataKeyService {
  Future<String> databasePassphrase();
  Future<List<int>> attachmentKey();
}

final class SecureLocalDataKeyService implements LocalDataKeyService {
  SecureLocalDataKeyService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              resetOnError: false,
              storageNamespace: 'not_local_data_keys',
            ),
          );

  static const String _databaseKeyName = 'not.database.passphrase.v1';
  static const String _attachmentKeyName = 'not.attachments.key.v1';
  static const int _keyLength = 32;

  final FlutterSecureStorage _storage;
  List<int>? _databaseKeyCache;
  List<int>? _attachmentKeyCache;

  @override
  Future<String> databasePassphrase() async {
    final List<int> bytes = _databaseKeyCache ??= await _loadOrCreate(
      _databaseKeyName,
    );
    return base64UrlEncode(bytes);
  }

  @override
  Future<List<int>> attachmentKey() async {
    final List<int> bytes = _attachmentKeyCache ??= await _loadOrCreate(
      _attachmentKeyName,
    );
    return List<int>.unmodifiable(bytes);
  }

  Future<List<int>> _loadOrCreate(String key) async {
    final String? raw = await _storage.read(key: key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<int> decoded = base64Url.decode(raw);
        if (decoded.length != _keyLength) {
          throw const FormatException('Unexpected local key length.');
        }
        return List<int>.unmodifiable(decoded);
      } on FormatException catch (error) {
        throw StateError(
          'Secure local-data key is corrupt. Refusing to replace it because '
          'that would make existing encrypted data unreadable: $error',
        );
      }
    }

    final Random random = Random.secure();
    final List<int> generated = List<int>.generate(
      _keyLength,
      (_) => random.nextInt(256),
      growable: false,
    );
    await _storage.write(key: key, value: base64UrlEncode(generated));
    return List<int>.unmodifiable(generated);
  }
}
