import 'dart:convert';
import 'dart:io';

final class DbResult {
  const DbResult({
    required this.isSuccess,
    this.rowsAffected = 0,
    this.errorMessage,
    this.data,
  });

  factory DbResult.success({int rowsAffected = 0, dynamic data}) =>
      DbResult(isSuccess: true, rowsAffected: rowsAffected, data: data);

  factory DbResult.failure(String errorMessage) =>
      DbResult(isSuccess: false, errorMessage: errorMessage);

  final bool isSuccess;
  final int rowsAffected;
  final String? errorMessage;
  final dynamic data;

  bool get isRlsViolation =>
      errorMessage != null &&
      (errorMessage!.contains('row-level security policy') ||
          errorMessage!.contains('permission denied') ||
          errorMessage!.contains('violates row-level security'));

  @override
  String toString() => isSuccess
      ? 'DbResult.success(rows: $rowsAffected, data: $data)'
      : 'DbResult.failure($errorMessage)';
}

final class ApplyRpcResult {
  const ApplyRpcResult({
    required this.isSuccess,
    this.status,
    this.revision,
    this.remoteConflict,
    this.errorMessage,
  });

  factory ApplyRpcResult.ok(int revision) =>
      ApplyRpcResult(isSuccess: true, status: 'ok', revision: revision);

  factory ApplyRpcResult.conflict(Map<String, dynamic> remote) =>
      ApplyRpcResult(
        isSuccess: true,
        status: 'conflict',
        remoteConflict: remote,
      );

  factory ApplyRpcResult.failure(String errorMessage) =>
      ApplyRpcResult(isSuccess: false, errorMessage: errorMessage);

  final bool isSuccess;
  final String? status;
  final int? revision;
  final Map<String, dynamic>? remoteConflict;
  final String? errorMessage;

  bool get isAuthRequired =>
      errorMessage != null &&
      (errorMessage!.contains('authentication required') ||
          errorMessage!.contains('permission denied'));

  @override
  String toString() => isSuccess
      ? 'ApplyRpcResult.$status(revision: $revision, conflict: $remoteConflict)'
      : 'ApplyRpcResult.failure($errorMessage)';
}

abstract interface class PostgresSessionContext {
  Future<int> countEntities({String? whereClause});
  Future<List<Map<String, dynamic>>> selectEntities({String? whereClause});
  Future<DbResult> insertEntity({
    required String userId,
    required String entityType,
    required String entityId,
    required int version,
    required DateTime updatedAt,
    DateTime? deletedAt,
    Map<String, dynamic> payload = const <String, dynamic>{},
  });
  Future<DbResult> updateEntities({
    required String setClause,
    String? whereClause,
  });
  Future<DbResult> deleteEntities({String? whereClause});
  Future<ApplyRpcResult> applyEntityChange({
    required String entityType,
    required String entityId,
    int? baseVersion,
    required int version,
    required DateTime updatedAt,
    DateTime? deletedAt,
    Map<String, dynamic> payload = const <String, dynamic>{},
  });
  Future<int> countStorageObjects({String? whereClause});
  Future<List<Map<String, dynamic>>> selectStorageObjects({
    String? whereClause,
  });
  Future<DbResult> insertStorageObject({
    required String bucketId,
    required String name,
    required String owner,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  });
  Future<DbResult> updateStorageObjects({
    required String setClause,
    String? whereClause,
  });
  Future<DbResult> deleteStorageObjects({String? whereClause});
}

final class _UserSessionContext implements PostgresSessionContext {
  _UserSessionContext(this._harness, this.userId);

  final PostgresRlsHarness _harness;
  final String userId;

  String get _sessionPrefix =>
      '''
SET ROLE authenticated;
SET request.jwt.claim.sub = '$userId';
SET request.jwt.claim.role = 'authenticated';
''';

  @override
  Future<int> countEntities({String? whereClause}) async {
    final String where = whereClause != null && whereClause.isNotEmpty
        ? ' WHERE $whereClause'
        : '';
    return _harness._queryScalarInt('''
$_sessionPrefix
SELECT count(*) FROM public.entities$where;
''');
  }

  @override
  Future<List<Map<String, dynamic>>> selectEntities({
    String? whereClause,
  }) async {
    final String where = whereClause != null && whereClause.isNotEmpty
        ? ' WHERE $whereClause'
        : '';
    return _harness._queryJsonList('''
$_sessionPrefix
SELECT coalesce(json_agg(row_to_json(t)), '[]'::json) FROM (
  SELECT user_id, entity_type, entity_id, version, updated_at, deleted_at, payload, sync_revision
  FROM public.entities$where
  ORDER BY sync_revision ASC
) t;
''');
  }

  @override
  Future<DbResult> insertEntity({
    required String userId,
    required String entityType,
    required String entityId,
    required int version,
    required DateTime updatedAt,
    DateTime? deletedAt,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    final String deletedStr = deletedAt == null
        ? 'NULL'
        : "'${deletedAt.toUtc().toIso8601String()}'";
    final String payloadJson = jsonEncode(payload).replaceAll("'", "''");
    return _harness._executeMutation('''
$_sessionPrefix
INSERT INTO public.entities(user_id, entity_type, entity_id, version, updated_at, deleted_at, payload)
VALUES (
  '$userId',
  '$entityType',
  '$entityId',
  $version,
  '${updatedAt.toUtc().toIso8601String()}',
  $deletedStr,
  '$payloadJson'::jsonb
);
''');
  }

  @override
  Future<DbResult> updateEntities({
    required String setClause,
    String? whereClause,
  }) async {
    final String where = whereClause != null && whereClause.isNotEmpty
        ? ' WHERE $whereClause'
        : '';
    return _harness._executeMutation('''
$_sessionPrefix
UPDATE public.entities SET $setClause$where;
''');
  }

  @override
  Future<DbResult> deleteEntities({String? whereClause}) async {
    final String where = whereClause != null && whereClause.isNotEmpty
        ? ' WHERE $whereClause'
        : '';
    return _harness._executeMutation('''
$_sessionPrefix
DELETE FROM public.entities$where;
''');
  }

  @override
  Future<ApplyRpcResult> applyEntityChange({
    required String entityType,
    required String entityId,
    int? baseVersion,
    required int version,
    required DateTime updatedAt,
    DateTime? deletedAt,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    final String baseVerStr = baseVersion == null ? 'NULL' : '$baseVersion';
    final String deletedStr = deletedAt == null
        ? 'NULL'
        : "'${deletedAt.toUtc().toIso8601String()}'";
    final String payloadJson = jsonEncode(payload).replaceAll("'", "''");

    final DbResult res = await _harness._executeRaw('''
$_sessionPrefix
SELECT public.apply_entity_change(
  '$entityType',
  '$entityId',
  $baseVerStr,
  $version,
  '${updatedAt.toUtc().toIso8601String()}',
  $deletedStr,
  '$payloadJson'::jsonb
);
''');
    if (!res.isSuccess) {
      return ApplyRpcResult.failure(res.errorMessage ?? 'Unknown error');
    }
    try {
      final String raw = (res.data as String).trim();
      final List<String> lines = raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && l != 'SET')
          .toList();
      final String lastLine = lines.isNotEmpty ? lines.last : '';
      final dynamic decoded = jsonDecode(lastLine);
      if (decoded is Map<String, dynamic>) {
        if (decoded['status'] == 'ok') {
          final dynamic rev = decoded['revision'];
          return ApplyRpcResult.ok(rev is num ? rev.toInt() : 0);
        } else if (decoded['status'] == 'conflict') {
          return ApplyRpcResult.conflict(
            Map<String, dynamic>.from(decoded['remote'] as Map),
          );
        }
      }
      return ApplyRpcResult.failure('Unexpected response: $lastLine');
    } catch (e) {
      return ApplyRpcResult.failure('JSON parse error: $e');
    }
  }

  @override
  Future<int> countStorageObjects({String? whereClause}) async {
    final String where = whereClause != null && whereClause.isNotEmpty
        ? ' WHERE $whereClause'
        : '';
    return _harness._queryScalarInt('''
$_sessionPrefix
SELECT count(*) FROM storage.objects$where;
''');
  }

  @override
  Future<List<Map<String, dynamic>>> selectStorageObjects({
    String? whereClause,
  }) async {
    final String where = whereClause != null && whereClause.isNotEmpty
        ? ' WHERE $whereClause'
        : '';
    return _harness._queryJsonList('''
$_sessionPrefix
SELECT coalesce(json_agg(row_to_json(t)), '[]'::json) FROM (
  SELECT id, bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata
  FROM storage.objects$where
  ORDER BY name ASC
) t;
''');
  }

  @override
  Future<DbResult> insertStorageObject({
    required String bucketId,
    required String name,
    required String owner,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final String metadataJson = jsonEncode(metadata).replaceAll("'", "''");
    return _harness._executeMutation('''
$_sessionPrefix
INSERT INTO storage.objects(bucket_id, name, owner, metadata)
VALUES (
  '$bucketId',
  '$name',
  '$owner',
  '$metadataJson'::jsonb
);
''');
  }

  @override
  Future<DbResult> updateStorageObjects({
    required String setClause,
    String? whereClause,
  }) async {
    final String where = whereClause != null && whereClause.isNotEmpty
        ? ' WHERE $whereClause'
        : '';
    return _harness._executeMutation('''
$_sessionPrefix
UPDATE storage.objects SET $setClause$where;
''');
  }

  @override
  Future<DbResult> deleteStorageObjects({String? whereClause}) async {
    final String where = whereClause != null && whereClause.isNotEmpty
        ? ' WHERE $whereClause'
        : '';
    return _harness._executeMutation('''
$_sessionPrefix
DELETE FROM storage.objects$where;
''');
  }
}

final class _AnonSessionContext implements PostgresSessionContext {
  _AnonSessionContext(this._harness);

  final PostgresRlsHarness _harness;

  String get _sessionPrefix => '''
SET ROLE anon;
RESET request.jwt.claim.sub;
SET request.jwt.claim.role = 'anon';
''';

  @override
  Future<int> countEntities({String? whereClause}) async {
    final String where = whereClause != null && whereClause.isNotEmpty
        ? ' WHERE $whereClause'
        : '';
    return _harness._queryScalarInt('''
$_sessionPrefix
SELECT count(*) FROM public.entities$where;
''');
  }

  @override
  Future<List<Map<String, dynamic>>> selectEntities({
    String? whereClause,
  }) async {
    final String where = whereClause != null && whereClause.isNotEmpty
        ? ' WHERE $whereClause'
        : '';
    return _harness._queryJsonList('''
$_sessionPrefix
SELECT coalesce(json_agg(row_to_json(t)), '[]'::json) FROM (
  SELECT user_id, entity_type, entity_id, version, updated_at, deleted_at, payload, sync_revision
  FROM public.entities$where
  ORDER BY sync_revision ASC
) t;
''');
  }

  @override
  Future<DbResult> insertEntity({
    required String userId,
    required String entityType,
    required String entityId,
    required int version,
    required DateTime updatedAt,
    DateTime? deletedAt,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    final String deletedStr = deletedAt == null
        ? 'NULL'
        : "'${deletedAt.toUtc().toIso8601String()}'";
    final String payloadJson = jsonEncode(payload).replaceAll("'", "''");
    return _harness._executeMutation('''
$_sessionPrefix
INSERT INTO public.entities(user_id, entity_type, entity_id, version, updated_at, deleted_at, payload)
VALUES (
  '$userId',
  '$entityType',
  '$entityId',
  $version,
  '${updatedAt.toUtc().toIso8601String()}',
  $deletedStr,
  '$payloadJson'::jsonb
);
''');
  }

  @override
  Future<DbResult> updateEntities({
    required String setClause,
    String? whereClause,
  }) async {
    final String where = whereClause != null && whereClause.isNotEmpty
        ? ' WHERE $whereClause'
        : '';
    return _harness._executeMutation('''
$_sessionPrefix
UPDATE public.entities SET $setClause$where;
''');
  }

  @override
  Future<DbResult> deleteEntities({String? whereClause}) async {
    final String where = whereClause != null && whereClause.isNotEmpty
        ? ' WHERE $whereClause'
        : '';
    return _harness._executeMutation('''
$_sessionPrefix
DELETE FROM public.entities$where;
''');
  }

  @override
  Future<ApplyRpcResult> applyEntityChange({
    required String entityType,
    required String entityId,
    int? baseVersion,
    required int version,
    required DateTime updatedAt,
    DateTime? deletedAt,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    final String baseVerStr = baseVersion == null ? 'NULL' : '$baseVersion';
    final String deletedStr = deletedAt == null
        ? 'NULL'
        : "'${deletedAt.toUtc().toIso8601String()}'";
    final String payloadJson = jsonEncode(payload).replaceAll("'", "''");

    final DbResult res = await _harness._executeRaw('''
$_sessionPrefix
SELECT public.apply_entity_change(
  '$entityType',
  '$entityId',
  $baseVerStr,
  $version,
  '${updatedAt.toUtc().toIso8601String()}',
  $deletedStr,
  '$payloadJson'::jsonb
);
''');
    if (!res.isSuccess) {
      return ApplyRpcResult.failure(res.errorMessage ?? 'Unknown error');
    }
    return ApplyRpcResult.failure(
      'RPC should have been rejected for unauthenticated',
    );
  }

  @override
  Future<int> countStorageObjects({String? whereClause}) async {
    final String where = whereClause != null && whereClause.isNotEmpty
        ? ' WHERE $whereClause'
        : '';
    return _harness._queryScalarInt('''
$_sessionPrefix
SELECT count(*) FROM storage.objects$where;
''');
  }

  @override
  Future<List<Map<String, dynamic>>> selectStorageObjects({
    String? whereClause,
  }) async {
    final String where = whereClause != null && whereClause.isNotEmpty
        ? ' WHERE $whereClause'
        : '';
    return _harness._queryJsonList('''
$_sessionPrefix
SELECT coalesce(json_agg(row_to_json(t)), '[]'::json) FROM (
  SELECT id, bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata
  FROM storage.objects$where
  ORDER BY name ASC
) t;
''');
  }

  @override
  Future<DbResult> insertStorageObject({
    required String bucketId,
    required String name,
    required String owner,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final String metadataJson = jsonEncode(metadata).replaceAll("'", "''");
    return _harness._executeMutation('''
$_sessionPrefix
INSERT INTO storage.objects(bucket_id, name, owner, metadata)
VALUES (
  '$bucketId',
  '$name',
  '$owner',
  '$metadataJson'::jsonb
);
''');
  }

  @override
  Future<DbResult> updateStorageObjects({
    required String setClause,
    String? whereClause,
  }) async {
    final String where = whereClause != null && whereClause.isNotEmpty
        ? ' WHERE $whereClause'
        : '';
    return _harness._executeMutation('''
$_sessionPrefix
UPDATE storage.objects SET $setClause$where;
''');
  }

  @override
  Future<DbResult> deleteStorageObjects({String? whereClause}) async {
    final String where = whereClause != null && whereClause.isNotEmpty
        ? ' WHERE $whereClause'
        : '';
    return _harness._executeMutation('''
$_sessionPrefix
DELETE FROM storage.objects$where;
''');
  }
}

final class PostgresRlsHarness {
  PostgresRlsHarness({
    String? psqlPath,
    String? database,
    String? host,
    int? port,
    String? username,
  }) : psqlPath = psqlPath ?? _detectPsql(),
       database =
           database ??
           Platform.environment['PGDATABASE'] ??
           Platform.environment['SUPABASE_DB_NAME'] ??
           'postgres',
       host =
           host ??
           Platform.environment['PGHOST'] ??
           Platform.environment['SUPABASE_DB_HOST'] ??
           'localhost',
       port =
           port ??
           int.tryParse(Platform.environment['PGPORT'] ?? '') ??
           int.tryParse(Platform.environment['SUPABASE_DB_PORT'] ?? '') ??
           5432,
       username =
           username ??
           Platform.environment['PGUSER'] ??
           Platform.environment['SUPABASE_DB_USER'] ??
           Platform.environment['USER'] ??
           'postgres';

  final String psqlPath;
  final String database;
  final String host;
  final int port;
  final String username;

  static String _detectPsql() {
    final String? envPath = Platform.environment['PSQL_PATH'];
    if (envPath != null && File(envPath).existsSync()) {
      return envPath;
    }

    final List<String> candidatePaths = <String>[
      '/opt/homebrew/opt/postgresql@16/bin/psql',
      '/opt/homebrew/opt/postgresql@17/bin/psql',
      '/opt/homebrew/opt/postgresql/bin/psql',
      '/opt/homebrew/bin/psql',
      '/usr/local/bin/psql',
      '/usr/bin/psql',
    ];

    for (final String path in candidatePaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    final ProcessResult res = Process.runSync('which', <String>['psql']);
    if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
      return res.stdout.toString().trim();
    }

    throw StateError(
      'psql binary not found. Please install PostgreSQL or set PSQL_PATH environment variable.',
    );
  }

  Future<void> setupSchema({required String migrationFilePath}) async {
    final File migrationFile = File(migrationFilePath);
    if (!migrationFile.existsSync()) {
      throw FileSystemException('Migration file not found', migrationFilePath);
    }
    final String migrationSql = await migrationFile.readAsString();

    const String setupMockSql = '''
-- 1. Create auth mock schema
CREATE SCHEMA IF NOT EXISTS auth;
CREATE TABLE IF NOT EXISTS auth.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE,
  created_at timestamptz DEFAULT now()
);

DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
END
\$\$;

CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid AS \$\$
  SELECT coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
  )::uuid;
\$\$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION auth.role() RETURNS text AS \$\$
  SELECT coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'
  )::text;
\$\$ LANGUAGE sql STABLE;

-- 2. Create storage mock schema
CREATE SCHEMA IF NOT EXISTS storage;
CREATE TABLE IF NOT EXISTS storage.buckets (
  id text PRIMARY KEY,
  name text NOT NULL,
  public boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS storage.objects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_id text REFERENCES storage.buckets(id),
  name text NOT NULL,
  owner uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  last_accessed_at timestamptz DEFAULT now(),
  metadata jsonb DEFAULT '{}'::jsonb
);

CREATE OR REPLACE FUNCTION storage.foldername(name text)
RETURNS text[]
LANGUAGE plpgsql
AS \$\$
DECLARE
  _parts text[];
BEGIN
  SELECT string_to_array(name, '/') INTO _parts;
  RETURN _parts[1:array_length(_parts,1)-1];
END
\$\$;

-- 3. Base Grants
GRANT USAGE ON SCHEMA public, auth, storage TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public, storage TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public, storage TO anon, authenticated;
GRANT ALL ON ALL ROUTINES IN SCHEMA public, auth, storage TO anon, authenticated;
''';

    final DbResult setupRes = await _executeRaw(setupMockSql);
    if (!setupRes.isSuccess) {
      throw StateError(
        'Failed to setup mock Supabase schema: ${setupRes.errorMessage}',
      );
    }

    final DbResult migrationRes = await _executeRaw(migrationSql);
    if (!migrationRes.isSuccess) {
      throw StateError(
        'Failed to apply migration SQL: ${migrationRes.errorMessage}',
      );
    }

    const String refreshGrantsSql = '''
GRANT USAGE ON SCHEMA public, auth, storage TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public, storage TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public, storage TO anon, authenticated;
GRANT ALL ON ALL ROUTINES IN SCHEMA public, auth, storage TO anon, authenticated;
''';
    final DbResult grantRes = await _executeRaw(refreshGrantsSql);
    if (!grantRes.isSuccess) {
      throw StateError('Failed to refresh grants: ${grantRes.errorMessage}');
    }
  }

  Future<void> resetData() async {
    const String sql = '''
TRUNCATE TABLE public.entities, storage.objects, auth.users CASCADE;
''';
    final DbResult res = await _executeRaw(sql);
    if (!res.isSuccess) {
      throw StateError('Failed to reset test data: ${res.errorMessage}');
    }
  }

  Future<void> createUser({required String id, required String email}) async {
    final String sql =
        '''
INSERT INTO auth.users (id, email) VALUES ('$id', '$email')
ON CONFLICT (id) DO NOTHING;
''';
    final DbResult res = await _executeRaw(sql);
    if (!res.isSuccess) {
      throw StateError('Failed to create user $id: ${res.errorMessage}');
    }
  }

  Future<void> insertEntityAsSuperuser({
    required String userId,
    required String entityType,
    required String entityId,
    required int version,
    required DateTime updatedAt,
    DateTime? deletedAt,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    final String deletedStr = deletedAt == null
        ? 'NULL'
        : "'${deletedAt.toUtc().toIso8601String()}'";
    final String payloadJson = jsonEncode(payload).replaceAll("'", "''");
    final String sql =
        '''
INSERT INTO public.entities(user_id, entity_type, entity_id, version, updated_at, deleted_at, payload)
VALUES (
  '$userId',
  '$entityType',
  '$entityId',
  $version,
  '${updatedAt.toUtc().toIso8601String()}',
  $deletedStr,
  '$payloadJson'::jsonb
)
ON CONFLICT (user_id, entity_type, entity_id) DO UPDATE SET
  version = excluded.version,
  updated_at = excluded.updated_at,
  deleted_at = excluded.deleted_at,
  payload = excluded.payload;
''';
    final DbResult res = await _executeRaw(sql);
    if (!res.isSuccess) {
      throw StateError(
        'Failed to insert entity as superuser: ${res.errorMessage}',
      );
    }
  }

  Future<void> insertStorageObjectAsSuperuser({
    required String bucketId,
    required String name,
    required String owner,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final String metadataJson = jsonEncode(metadata).replaceAll("'", "''");
    final String sql =
        '''
INSERT INTO storage.objects(bucket_id, name, owner, metadata)
VALUES (
  '$bucketId',
  '$name',
  '$owner',
  '$metadataJson'::jsonb
);
''';
    final DbResult res = await _executeRaw(sql);
    if (!res.isSuccess) {
      throw StateError(
        'Failed to insert storage object as superuser: ${res.errorMessage}',
      );
    }
  }

  Future<T> asUser<T>(
    String userId,
    Future<T> Function(PostgresSessionContext session) action,
  ) async {
    final _UserSessionContext ctx = _UserSessionContext(this, userId);
    return action(ctx);
  }

  Future<T> asAnonymous<T>(
    Future<T> Function(PostgresSessionContext session) action,
  ) async {
    final _AnonSessionContext ctx = _AnonSessionContext(this);
    return action(ctx);
  }

  Future<int> _queryScalarInt(String sql) async {
    final DbResult res = await _executeRaw(sql);
    if (!res.isSuccess) {
      throw StateError('Query failed: ${res.errorMessage}');
    }
    final String raw = (res.data as String).trim();
    final List<String> lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l != 'SET')
        .toList();
    final String lastLine = lines.isNotEmpty ? lines.last : '';
    final int? value = int.tryParse(lastLine);
    if (value == null) {
      throw FormatException(
        'Expected integer scalar, got "$raw" (last line: "$lastLine")',
      );
    }
    return value;
  }

  Future<List<Map<String, dynamic>>> _queryJsonList(String sql) async {
    final DbResult res = await _executeRaw(sql);
    if (!res.isSuccess) {
      throw StateError('JSON query failed: ${res.errorMessage}');
    }
    final String raw = (res.data as String).trim();
    final List<String> lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l != 'SET')
        .toList();
    final String lastLine = lines.isNotEmpty ? lines.last : '';
    if (lastLine.isEmpty || lastLine == '[]')
      return const <Map<String, dynamic>>[];
    try {
      final dynamic decoded = jsonDecode(lastLine);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return const <Map<String, dynamic>>[];
    } catch (e) {
      throw FormatException(
        'Failed to parse JSON response: $raw (last: "$lastLine"), error: $e',
      );
    }
  }

  Future<DbResult> _executeMutation(String sql) async {
    final DbResult res = await _executeRaw(sql);
    if (!res.isSuccess) {
      return res;
    }
    final String output = (res.data as String).trim();
    int rows = 0;
    final RegExp mutationRegex = RegExp(
      r'(?:INSERT \d+ |UPDATE |DELETE )(\d+)',
    );
    final Iterable<Match> matches = mutationRegex.allMatches(output);
    if (matches.isNotEmpty) {
      rows = int.parse(matches.last.group(1)!);
    }
    return DbResult.success(rowsAffected: rows, data: output);
  }

  Future<DbResult> _executeRaw(String sql) async {
    final List<String> args = <String>[
      '-X',
      '-t',
      '-A',
      '-d',
      database,
      '-v',
      'ON_ERROR_STOP=1',
    ];

    if (host.isNotEmpty) {
      args.addAll(<String>['-h', host]);
    }
    if (port > 0) {
      args.addAll(<String>['-p', port.toString()]);
    }
    if (username.isNotEmpty) {
      args.addAll(<String>['-U', username]);
    }
    args.addAll(<String>['-c', sql]);

    final Map<String, String> env = <String, String>{
      'LC_ALL': 'C',
      ...Platform.environment,
    };

    final ProcessResult result = await Process.run(
      psqlPath,
      args,
      environment: env,
    );

    if (result.exitCode != 0) {
      final String stderrStr = result.stderr.toString().trim();
      final String stdoutStr = result.stdout.toString().trim();
      final String message = stderrStr.isNotEmpty ? stderrStr : stdoutStr;
      return DbResult.failure(message);
    }

    return DbResult.success(data: result.stdout.toString());
  }
}
