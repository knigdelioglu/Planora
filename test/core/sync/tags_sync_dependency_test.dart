import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/events/entity_change_bus.dart';
import 'package:not_app/core/logging/app_logger.dart';
import 'package:not_app/core/remote/remote_gateway.dart';
import 'package:not_app/core/remote/remote_models.dart';
import 'package:not_app/core/sync/local_entity_store.dart';
import 'package:not_app/core/sync/sync_engine.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/conflicts/data/repositories/conflict_repository_impl.dart';

final class _Clock implements AppClock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 8, 20, 12);
}

final class _ReverseTagRemote implements RemoteGateway {
  _ReverseTagRemote(this.tag, this.assignment);

  final RemoteEntity tag;
  final RemoteEntity assignment;

  @override
  bool get available => true;

  @override
  String? get userId => 'test-user';

  @override
  Future<RemoteApplyResult> apply({
    required String entityType,
    required String entityId,
    required int? baseVersion,
    required int version,
    required DateTime updatedAt,
    required DateTime? deletedAt,
    required Map<String, Object?> payload,
  }) async => const RemoteApplySuccess(1);

  @override
  Future<List<RemoteEntity>> pull({
    required int afterRevision,
    int limit = 250,
  }) async {
    if (afterRevision >= assignment.syncRevision) return const <RemoteEntity>[];
    // Intentionally return the child first. SyncEngine must dependency-sort it.
    return <RemoteEntity>[assignment, tag];
  }

  @override
  Future<void> uploadAttachment({
    required String remotePath,
    required File file,
  }) async {}

  @override
  Future<String> createAttachmentDownloadUrl(String remotePath) async =>
      'memory://$remotePath';

  @override
  Future<void> deleteAttachment(String remotePath) async {}
}

void main() {
  test('remote tag is applied before a reversed tag assignment', () async {
    final DateTime now = DateTime.utc(2026, 8, 20, 12);
    final RemoteEntity tag = RemoteEntity(
      entityType: 'tag',
      entityId: 'tag_test',
      version: 1,
      updatedAt: now,
      deletedAt: null,
      payload: <String, Object?>{
        'id': 'tag_test',
        'name': 'Okul',
        'normalizedName': 'okul',
        'colorKey': 'indigo',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'version': 1,
        'deletedAt': null,
      },
      syncRevision: 1,
    );
    final RemoteEntity assignment = RemoteEntity(
      entityType: 'tag_assignment',
      entityId: 'assignment_test',
      version: 1,
      updatedAt: now,
      deletedAt: null,
      payload: <String, Object?>{
        'id': 'assignment_test',
        'tagId': 'tag_test',
        'targetType': 'note',
        'targetId': 'note_remote',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'version': 1,
        'deletedAt': null,
      },
      syncRevision: 2,
    );

    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    final EntityChangeBus changes = EntityChangeBus();
    addTearDown(() async {
      await changes.dispose();
      await database.close();
    });
    const _Clock clock = _Clock();
    final DriftSyncQueueRepository queue = DriftSyncQueueRepository(
      database: database,
      clock: clock,
    );
    final LocalEntityStore localStore = LocalEntityStore(
      database: database,
      clock: clock,
      changes: changes,
    );
    final DriftConflictRepository conflicts = DriftConflictRepository(
      database: database,
      syncQueue: queue,
      localStore: localStore,
      clock: clock,
    );
    final SyncEngine engine = SyncEngine(
      database: database,
      queue: queue,
      remote: _ReverseTagRemote(tag, assignment),
      localStore: localStore,
      conflicts: conflicts,
      clock: clock,
      logger: const AppLogger(enabled: false),
    );

    final SyncRunResult result = await engine.runOnce();
    expect(result.pulled, 2);

    final tagRows = await database.customSelect(
      'SELECT id FROM tags WHERE id = ?',
      variables: const [],
    ).get();
    // Direct identity assertions below avoid relying on repository listeners.
    final storedTag = await database.customSelect(
      "SELECT id FROM tags WHERE id = 'tag_test' LIMIT 1",
    ).getSingleOrNull();
    final storedAssignment = await database.customSelect(
      "SELECT id, tag_id FROM tag_assignments WHERE id = 'assignment_test' LIMIT 1",
    ).getSingleOrNull();

    expect(tagRows, isNotEmpty);
    expect(storedTag?.read<String>('id'), 'tag_test');
    expect(storedAssignment?.read<String>('tag_id'), 'tag_test');
  });
}
