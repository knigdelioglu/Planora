import 'dart:convert';
import 'dart:io';

import 'package:not_app/core/remote/remote_gateway.dart';
import 'package:not_app/core/remote/remote_models.dart';

import 'postgres_rls_harness.dart';

final class PostgresRemoteGateway implements RemoteGateway {
  PostgresRemoteGateway({
    required this.harness,
    required this.currentUserId,
    this.online = true,
  });

  final PostgresRlsHarness harness;
  final String currentUserId;
  bool online;
  bool failAfterNextApply = false;

  @override
  bool get available => online;

  @override
  String? get userId => online ? currentUserId : null;

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
    if (!online) {
      throw StateError('remote unavailable');
    }
    final ApplyRpcResult rpcRes = await harness.asUser(
      currentUserId,
      (session) => session.applyEntityChange(
        entityType: entityType,
        entityId: entityId,
        baseVersion: baseVersion,
        version: version,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
        payload: payload,
      ),
    );
    if (!rpcRes.isSuccess) {
      throw StateError('remote apply failed: ${rpcRes.errorMessage}');
    }
    if (failAfterNextApply) {
      failAfterNextApply = false;
      throw StateError('remote response lost after commit');
    }
    if (rpcRes.status == 'conflict') {
      final Map<String, dynamic> remote = rpcRes.remoteConflict!;
      return RemoteApplyConflict(_mapRow(remote));
    }
    return RemoteApplySuccess(rpcRes.revision ?? 0);
  }

  @override
  Future<List<RemoteEntity>> pull({
    required int afterRevision,
    int limit = 250,
  }) async {
    if (!online) {
      throw StateError('remote unavailable');
    }
    final List<Map<String, dynamic>> rows = await harness.asUser(
      currentUserId,
      (session) =>
          session.selectEntities(whereClause: 'sync_revision > $afterRevision'),
    );
    final List<RemoteEntity> entities = rows.map(_mapRow).toList();
    return entities.take(limit).toList(growable: false);
  }

  RemoteEntity _mapRow(Map<String, dynamic> row) {
    final dynamic payloadRaw = row['payload'];
    final Map<String, Object?> payload = payloadRaw is Map
        ? Map<String, Object?>.from(payloadRaw)
        : (payloadRaw is String && payloadRaw.isNotEmpty
              ? Map<String, Object?>.from(jsonDecode(payloadRaw) as Map)
              : const <String, Object?>{});
    return RemoteEntity(
      entityType: row['entity_type'] as String,
      entityId: row['entity_id'] as String,
      version: (row['version'] as num).toInt(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
      deletedAt: row['deleted_at'] == null
          ? null
          : DateTime.parse(row['deleted_at'] as String).toUtc(),
      payload: payload,
      syncRevision: (row['sync_revision'] as num).toInt(),
    );
  }

  @override
  Future<void> uploadAttachment({
    required String remotePath,
    required File file,
  }) async {
    if (!online) throw StateError('remote unavailable');
    if (!await file.exists()) {
      throw FileSystemException('Attachment is missing.', file.path);
    }
    await harness.asUser(
      currentUserId,
      (session) => session.insertStorageObject(
        bucketId: 'attachments',
        name: remotePath,
        owner: currentUserId,
        metadata: <String, dynamic>{
          'size': file.lengthSync(),
          'mimetype': 'application/octet-stream',
        },
      ),
    );
  }

  @override
  Future<String> createAttachmentDownloadUrl(String remotePath) async {
    if (!online) throw StateError('remote unavailable');
    return 'https://supabase.local/storage/v1/object/public/attachments/$remotePath';
  }

  @override
  Future<void> deleteAttachment(String remotePath) async {
    if (!online) throw StateError('remote unavailable');
    await harness.asUser(
      currentUserId,
      (session) => session.deleteStorageObjects(
        whereClause: "bucket_id = 'attachments' AND name = '$remotePath'",
      ),
    );
  }
}
