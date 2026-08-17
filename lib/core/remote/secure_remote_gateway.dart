import 'dart:io';

import 'package:not_app/core/remote/remote_gateway.dart';
import 'package:not_app/core/remote/remote_models.dart';
import 'package:not_app/core/services/encrypted_file_storage_service.dart';
import 'package:path/path.dart' as p;

final class SecureRemoteGateway implements RemoteGateway {
  SecureRemoteGateway(this._delegate, this._storage);

  static final RegExp _entityIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final RegExp _remoteFilePattern = RegExp(r'^[A-Za-z0-9._-]{1,255}$');
  static final Set<String> _entityTypes = <String>{
    'note',
    'board',
    'column',
    'card',
    'attachment',
    'reminder',
  };

  final RemoteGateway _delegate;
  final EncryptedFileStorageService _storage;

  @override
  bool get available => _delegate.available;

  @override
  String? get userId => _delegate.userId;

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
    _validateEntityIdentity(entityType, entityId);
    if (entityType == 'attachment') {
      _validateAttachmentPayload(entityId, payload);
    }
    final RemoteApplyResult result = await _delegate.apply(
      entityType: entityType,
      entityId: entityId,
      baseVersion: baseVersion,
      version: version,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      payload: payload,
    );
    if (result is RemoteApplyConflict) {
      _validateRemoteEntity(result.remote);
    }
    return result;
  }

  @override
  Future<List<RemoteEntity>> pull({
    required int afterRevision,
    int limit = 250,
  }) async {
    final List<RemoteEntity> rows = await _delegate.pull(
      afterRevision: afterRevision,
      limit: limit,
    );
    for (final RemoteEntity row in rows) {
      _validateRemoteEntity(row);
    }
    return rows;
  }

  void _validateRemoteEntity(RemoteEntity entity) {
    _validateEntityIdentity(entity.entityType, entity.entityId);
    if (entity.version < 1 || entity.syncRevision < 0) {
      throw StateError('Remote entity contains an invalid version.');
    }
    if (entity.entityType == 'attachment') {
      _validateAttachmentPayload(entity.entityId, entity.payload);
    }
  }

  void _validateEntityIdentity(String entityType, String entityId) {
    if (!_entityTypes.contains(entityType)) {
      throw StateError('Remote entity type is not supported.');
    }
    if (!_entityIdPattern.hasMatch(entityId)) {
      throw StateError('Remote entity id contains unsafe characters.');
    }
  }

  void _validateAttachmentPayload(
    String entityId,
    Map<String, Object?> payload,
  ) {
    final Object? fileNameRaw = payload['fileName'];
    if (fileNameRaw != null) {
      final String fileName = fileNameRaw.toString();
      if (!_isSafeFileName(fileName)) {
        throw StateError('Remote attachment filename is unsafe.');
      }
    }
    final Object? remotePathRaw = payload['remotePath'];
    if (remotePathRaw != null) {
      _validateRemotePath(remotePathRaw.toString(), expectedEntityId: entityId);
    }
  }

  bool _isSafeFileName(String value) {
    if (value.isEmpty || value.length > 180 || value == '.' || value == '..') {
      return false;
    }
    if (p.basename(value) != value || value.contains('\\')) return false;
    return !RegExp(r'[\x00-\x1F\x7F]').hasMatch(value);
  }

  void _validateRemotePath(String remotePath, {String? expectedEntityId}) {
    final String? uid = userId;
    if (uid == null || uid.isEmpty) {
      throw StateError('Cloud account is not signed in.');
    }
    final List<String> parts = p.posix.split(remotePath);
    if (parts.length != 3 ||
        parts[0] != uid ||
        !_entityIdPattern.hasMatch(parts[1]) ||
        (expectedEntityId != null && parts[1] != expectedEntityId) ||
        !_remoteFilePattern.hasMatch(parts[2]) ||
        parts[2] == '.' ||
        parts[2] == '..') {
      throw StateError(
        'Remote attachment path is outside the account sandbox.',
      );
    }
  }

  @override
  Future<void> uploadAttachment({
    required String remotePath,
    required File file,
  }) async {
    _validateRemotePath(remotePath);
    if (!await _storage.isWithinSandbox(file.path)) {
      throw FileSystemException(
        'Refusing to upload a file outside the managed attachment sandbox.',
        file.path,
      );
    }
    final File clear = await _storage.materializeForRead(
      file.path,
      fileName: p.posix.basename(remotePath),
    );
    try {
      await _delegate.uploadAttachment(remotePath: remotePath, file: clear);
    } finally {
      await _storage.deleteMaterialized(clear);
    }
  }

  @override
  Future<String> createAttachmentDownloadUrl(String remotePath) {
    _validateRemotePath(remotePath);
    return _delegate.createAttachmentDownloadUrl(remotePath);
  }

  @override
  Future<void> deleteAttachment(String remotePath) {
    _validateRemotePath(remotePath);
    return _delegate.deleteAttachment(remotePath);
  }
}
