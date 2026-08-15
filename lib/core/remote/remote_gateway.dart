import 'dart:io';

import 'package:not_app/core/remote/remote_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class RemoteGateway {
  bool get available;
  String? get userId;
  Future<RemoteApplyResult> apply({
    required String entityType,
    required String entityId,
    required int? baseVersion,
    required int version,
    required DateTime updatedAt,
    required DateTime? deletedAt,
    required Map<String, Object?> payload,
  });
  Future<List<RemoteEntity>> pull({
    required int afterRevision,
    int limit = 250,
  });
  Future<void> uploadAttachment({
    required String remotePath,
    required File file,
  });
  Future<String> createAttachmentDownloadUrl(String remotePath);
}

final class DisabledRemoteGateway implements RemoteGateway {
  const DisabledRemoteGateway();

  @override
  bool get available => false;
  @override
  String? get userId => null;

  Never _disabled() =>
      throw StateError('Cloud sync is not configured or signed in.');

  @override
  Future<RemoteApplyResult> apply({
    required String entityType,
    required String entityId,
    required int? baseVersion,
    required int version,
    required DateTime updatedAt,
    required DateTime? deletedAt,
    required Map<String, Object?> payload,
  }) async => _disabled();

  @override
  Future<List<RemoteEntity>> pull({
    required int afterRevision,
    int limit = 250,
  }) async => _disabled();

  @override
  Future<void> uploadAttachment({
    required String remotePath,
    required File file,
  }) async => _disabled();

  @override
  Future<String> createAttachmentDownloadUrl(String remotePath) async =>
      _disabled();
}

final class SupabaseRemoteGateway implements RemoteGateway {
  SupabaseRemoteGateway(this._client);

  final SupabaseClient _client;

  @override
  bool get available => _client.auth.currentSession != null;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Future<RemoteApplyResult> apply({
    required String entityType,
    required String entityId,
    required int? baseVersion,
    required int version,
    required DateTime updatedAt,
    required DateTime? deletedAt,
    required Map<String, Object?> payload,
  }) async {
    if (!available) throw StateError('Cloud account is not signed in.');
    final Object? raw = await _client.rpc(
      'apply_entity_change',
      params: <String, Object?>{
        'p_entity_type': entityType,
        'p_entity_id': entityId,
        'p_base_version': baseVersion,
        'p_version': version,
        'p_updated_at': updatedAt.toUtc().toIso8601String(),
        'p_deleted_at': deletedAt?.toUtc().toIso8601String(),
        'p_payload': payload,
      },
    );
    if (raw is! Map) throw StateError('Invalid sync response.');
    final Map<String, Object?> data = Map<String, Object?>.from(raw);
    if (data['status'] == 'conflict') {
      final Object? remoteRaw = data['remote'];
      if (remoteRaw is! Map)
        throw StateError('Conflict response is missing remote entity.');
      return RemoteApplyConflict(
        _mapEntity(Map<String, Object?>.from(remoteRaw)),
      );
    }
    final Object? revision = data['revision'];
    return RemoteApplySuccess(revision is num ? revision.toInt() : 0);
  }

  @override
  Future<List<RemoteEntity>> pull({
    required int afterRevision,
    int limit = 250,
  }) async {
    if (!available) return const <RemoteEntity>[];
    final List<Map<String, dynamic>> rows = await _client
        .from('entities')
        .select(
          'entity_type,entity_id,version,updated_at,deleted_at,payload,sync_revision',
        )
        .gt('sync_revision', afterRevision)
        .order('sync_revision')
        .limit(limit);
    return rows
        .map((row) => _mapEntity(Map<String, Object?>.from(row)))
        .toList(growable: false);
  }

  RemoteEntity _mapEntity(Map<String, Object?> row) {
    final Object? payload = row['payload'];
    return RemoteEntity(
      entityType: row['entity_type']! as String,
      entityId: row['entity_id']! as String,
      version: (row['version']! as num).toInt(),
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
      deletedAt: row['deleted_at'] == null
          ? null
          : DateTime.parse(row['deleted_at']! as String).toUtc(),
      payload: payload is Map
          ? Map<String, Object?>.from(payload)
          : const <String, Object?>{},
      syncRevision: (row['sync_revision']! as num).toInt(),
    );
  }

  @override
  Future<void> uploadAttachment({
    required String remotePath,
    required File file,
  }) async {
    if (!available) throw StateError('Cloud account is not signed in.');
    if (!await file.exists())
      throw FileSystemException('Attachment is missing.', file.path);
    await _client.storage
        .from('attachments')
        .upload(remotePath, file, fileOptions: const FileOptions(upsert: true));
  }

  @override
  Future<String> createAttachmentDownloadUrl(String remotePath) {
    if (!available) throw StateError('Cloud account is not signed in.');
    return _client.storage.from('attachments').createSignedUrl(remotePath, 600);
  }
}
