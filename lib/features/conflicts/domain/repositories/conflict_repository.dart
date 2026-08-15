import 'package:not_app/core/remote/remote_models.dart';
import 'package:not_app/features/conflicts/domain/entities/sync_conflict.dart';

abstract interface class ConflictRepository {
  Stream<List<SyncConflictEntity>> watchOpen();
  Future<String> record({
    required String entityType,
    required String entityId,
    required Map<String, Object?> local,
    required RemoteEntity remote,
  });
  Future<void> resolveUsingLocal(String conflictId);
  Future<void> resolveUsingRemote(String conflictId);
  Future<void> resolveAsCopy(String conflictId);
}
