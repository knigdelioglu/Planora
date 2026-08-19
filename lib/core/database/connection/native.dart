import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:not_app/core/security/local_data_key_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

Future<QueryExecutor> openNativeConnection({
  LocalDataKeyService? keyService,
}) async {
  final LocalDataKeyService keys = keyService ?? SecureLocalDataKeyService();
  final String passphrase = await keys.databasePassphrase();
  final String escapedKey = _escapeSql(passphrase);
  final Directory directory = await getApplicationSupportDirectory();
  final Directory dbDirectory = Directory(p.join(directory.path, 'database'));
  await dbDirectory.create(recursive: true);

  final File legacyFile = File(p.join(dbDirectory.path, 'not.sqlite'));
  final File encryptedFile = File(
    p.join(dbDirectory.path, 'not.secure.sqlite'),
  );
  final String sqliteTempDirectory = (await getTemporaryDirectory()).path;

  return NativeDatabase.createInBackground(
    encryptedFile,
    isolateSetup: () async {
      sqlite3.tempDirectory = sqliteTempDirectory;
      final bool legacyExists = await legacyFile.exists();
      final bool encryptedExists = await encryptedFile.exists();
      if (legacyExists && !encryptedExists) {
        await _migratePlaintextDatabase(
          legacyFile: legacyFile,
          encryptedFile: encryptedFile,
          escapedKey: escapedKey,
        );
      } else if (legacyExists && encryptedExists) {
        _verifyEncryptedDatabase(encryptedFile, escapedKey);
        await _deleteLegacyDatabaseFiles(legacyFile);
      }
    },
    setup: (Database rawDb) {
      if (rawDb.select('PRAGMA cipher;').isEmpty) {
        throw StateError(
          'Encrypted SQLite support is unavailable. Refusing to open local data '
          'without database encryption.',
        );
      }
      rawDb.execute("PRAGMA key = '$escapedKey';");
    },
  );
}

Future<void> _migratePlaintextDatabase({
  required File legacyFile,
  required File encryptedFile,
  required String escapedKey,
}) async {
  final File temporary = File('${encryptedFile.path}.tmp');
  if (await temporary.exists()) {
    await temporary.delete();
  }

  final Database plaintext = sqlite3.open(legacyFile.path);
  try {
    plaintext.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    plaintext.execute("VACUUM INTO '${_escapeSql(temporary.path)}';");
  } finally {
    plaintext.close();
  }

  final Database encrypted = sqlite3.open(temporary.path);
  try {
    if (encrypted.select('PRAGMA cipher;').isEmpty) {
      throw StateError('SQLite encryption provider is not available.');
    }
    encrypted.execute("PRAGMA rekey = '$escapedKey';");
  } finally {
    encrypted.close();
  }

  _verifyEncryptedDatabase(temporary, escapedKey);
  await temporary.rename(encryptedFile.path);
  _verifyEncryptedDatabase(encryptedFile, escapedKey);
  await _deleteLegacyDatabaseFiles(legacyFile);
}

void _verifyEncryptedDatabase(File file, String escapedKey) {
  final Database verification = sqlite3.open(file.path);
  try {
    if (verification.select('PRAGMA cipher;').isEmpty) {
      throw StateError('SQLite encryption provider is not available.');
    }
    verification.execute("PRAGMA key = '$escapedKey';");
    final ResultSet check = verification.select('PRAGMA quick_check;');
    if (check.rows.isEmpty || check.rows.first.first.toString() != 'ok') {
      throw StateError('Encrypted database integrity check failed.');
    }
  } finally {
    verification.close();
  }
}

Future<void> _deleteLegacyDatabaseFiles(File legacyFile) async {
  await _deleteIfExists(legacyFile);
  await _deleteIfExists(File('${legacyFile.path}-wal'));
  await _deleteIfExists(File('${legacyFile.path}-shm'));
}

Future<void> _deleteIfExists(File file) async {
  if (await file.exists()) {
    await file.delete();
  }
}

String _escapeSql(String value) => value.replaceAll("'", "''");
