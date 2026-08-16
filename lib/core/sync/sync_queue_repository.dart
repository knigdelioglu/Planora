import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/sync/sync_models.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:uuid/uuid.dart';

abstract interface class SyncQueueRepository {
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required SyncOperationType operationType,
    required Map<String, Object?> payload,
    int? baseVersion,
  });

  Future<List<SyncOperation>> dueOperations({int limit = 50});
  Future<List<SyncOperation>> allOperations({
    SyncOperationStatus? status,
    bool includeCompleted = false,
  });
  Stream<List<SyncOperation>> watchOperations({
    SyncOperationStatus? status,
    bool includeCompleted = false,
  });
  Future<Map<SyncOperationStatus, int>> statusCounts();
  Stream<Map<SyncOperationStatus, int>> watchStatusCounts();

  Future<void> retryOperation(String operationId);
  Future<void> retryAll({SyncOperationStatus? status});
  Future<void> deleteOperation(String operationId);
  Future<void> clearQueue({
    SyncOperationStatus? status,
    bool onlyUncompleted = true,
  });

  Future<void> markProcessing(String operationId);
  Future<void> markCompleted(String operationId);
  Future<void> markRetry(String operationId, {required String error});
  Future<void> markFailedRecoverable(
    String operationId, {
    required String error,
  });
  Future<void> markConflict(String operationId, {required String error});
  Future<void> resolveBlockedConflicts({
    required String entityType,
    required String entityId,
  });
  Stream<int> watchPendingCount();
}

final class DriftSyncQueueRepository implements SyncQueueRepository {
  DriftSyncQueueRepository({
    required this._database,
    required this._clock,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final AppClock _clock;
  final Uuid _uuid;

  @override
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required SyncOperationType operationType,
    required Map<String, Object?> payload,
    int? baseVersion,
  }) async {
    final DateTime now = _clock.nowUtc();
    await _database
        .into(_database.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            operationId: _uuid.v7(),
            entityType: entityType,
            entityId: entityId,
            operationType: operationType.name,
            payloadJson: jsonEncode(payload),
            baseVersion: Value<int?>(baseVersion),
            createdAt: now,
          ),
        );
  }

  @override
  Future<List<SyncOperation>> dueOperations({int limit = 50}) async {
    final DateTime now = _clock.nowUtc();
    final List<SyncQueueData> rows =
        await (_database.select(_database.syncQueue)
              ..where(
                (tbl) =>
                    tbl.status.isIn(<String>[
                      SyncOperationStatus.pending.name,
                      SyncOperationStatus.processing.name,
                      SyncOperationStatus.retryWaiting.name,
                      SyncOperationStatus.failedRecoverable.name,
                    ]) &
                    (tbl.nextAttemptAt.isNull() |
                        tbl.nextAttemptAt.isSmallerOrEqualValue(now)),
              )
              ..orderBy(<OrderingTerm Function($SyncQueueTable)>[
                (tbl) => OrderingTerm.asc(tbl.createdAt),
              ])
              ..limit(limit))
            .get();
    return rows.map(_map).toList(growable: false);
  }

  @override
  Future<List<SyncOperation>> allOperations({
    SyncOperationStatus? status,
    bool includeCompleted = false,
  }) async {
    final selectQuery = _database.select(_database.syncQueue);
    if (status != null) {
      selectQuery.where((tbl) => tbl.status.equals(status.name));
    } else if (!includeCompleted) {
      selectQuery.where(
        (tbl) =>
            tbl.status.isNotIn(<String>[SyncOperationStatus.completed.name]),
      );
    }
    selectQuery.orderBy(<OrderingTerm Function($SyncQueueTable)>[
      (tbl) => OrderingTerm.desc(tbl.createdAt),
    ]);
    final rows = await selectQuery.get();
    return rows.map(_map).toList(growable: false);
  }

  @override
  Stream<List<SyncOperation>> watchOperations({
    SyncOperationStatus? status,
    bool includeCompleted = false,
  }) {
    final selectQuery = _database.select(_database.syncQueue);
    if (status != null) {
      selectQuery.where((tbl) => tbl.status.equals(status.name));
    } else if (!includeCompleted) {
      selectQuery.where(
        (tbl) =>
            tbl.status.isNotIn(<String>[SyncOperationStatus.completed.name]),
      );
    }
    selectQuery.orderBy(<OrderingTerm Function($SyncQueueTable)>[
      (tbl) => OrderingTerm.desc(tbl.createdAt),
    ]);
    return selectQuery.watch().map(
      (rows) => rows.map(_map).toList(growable: false),
    );
  }

  @override
  Future<Map<SyncOperationStatus, int>> statusCounts() async {
    final rows = await _database.select(_database.syncQueue).get();
    final counts = <SyncOperationStatus, int>{
      for (final s in SyncOperationStatus.values) s: 0,
    };
    for (final row in rows) {
      final status = SyncOperationStatus.values.asNameMap()[row.status];
      if (status != null) {
        counts[status] = (counts[status] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Stream<Map<SyncOperationStatus, int>> watchStatusCounts() {
    return _database.select(_database.syncQueue).watch().map((rows) {
      final counts = <SyncOperationStatus, int>{
        for (final s in SyncOperationStatus.values) s: 0,
      };
      for (final row in rows) {
        final status = SyncOperationStatus.values.asNameMap()[row.status];
        if (status != null) {
          counts[status] = (counts[status] ?? 0) + 1;
        }
      }
      return counts;
    });
  }

  @override
  Future<void> retryOperation(String operationId) async {
    await (_database.update(
      _database.syncQueue,
    )..where((tbl) => tbl.operationId.equals(operationId))).write(
      const SyncQueueCompanion(
        status: Value<String>('pending'),
        nextAttemptAt: Value<DateTime?>(null),
      ),
    );
  }

  @override
  Future<void> retryAll({SyncOperationStatus? status}) async {
    final updateQuery = _database.update(_database.syncQueue);
    if (status != null) {
      updateQuery.where((tbl) => tbl.status.equals(status.name));
    } else {
      updateQuery.where(
        (tbl) =>
            tbl.status.isNotIn(<String>[SyncOperationStatus.completed.name]),
      );
    }
    await updateQuery.write(
      const SyncQueueCompanion(
        status: Value<String>('pending'),
        nextAttemptAt: Value<DateTime?>(null),
      ),
    );
  }

  @override
  Future<void> deleteOperation(String operationId) async {
    await (_database.delete(
      _database.syncQueue,
    )..where((tbl) => tbl.operationId.equals(operationId))).go();
  }

  @override
  Future<void> clearQueue({
    SyncOperationStatus? status,
    bool onlyUncompleted = true,
  }) async {
    final deleteQuery = _database.delete(_database.syncQueue);
    if (status != null) {
      deleteQuery.where((tbl) => tbl.status.equals(status.name));
    } else if (onlyUncompleted) {
      deleteQuery.where(
        (tbl) =>
            tbl.status.isNotIn(<String>[SyncOperationStatus.completed.name]),
      );
    }
    await deleteQuery.go();
  }

  @override
  Future<void> markProcessing(String operationId) =>
      _setStatus(operationId, SyncOperationStatus.processing, clearError: true);

  @override
  Future<void> markCompleted(String operationId) =>
      _setStatus(operationId, SyncOperationStatus.completed, clearError: true);

  @override
  Future<void> markFailedRecoverable(
    String operationId, {
    required String error,
  }) => _setStatus(
    operationId,
    SyncOperationStatus.failedRecoverable,
    error: error,
  );

  @override
  Future<void> markConflict(String operationId, {required String error}) =>
      _setStatus(
        operationId,
        SyncOperationStatus.blockedConflict,
        error: error,
      );

  @override
  Future<void> resolveBlockedConflicts({
    required String entityType,
    required String entityId,
  }) {
    return (_database.update(_database.syncQueue)..where(
          (tbl) =>
              tbl.entityType.equals(entityType) &
              tbl.entityId.equals(entityId) &
              tbl.status.equals(SyncOperationStatus.blockedConflict.name),
        ))
        .write(
          SyncQueueCompanion(
            status: Value<String>(SyncOperationStatus.completed.name),
            nextAttemptAt: const Value<DateTime?>(null),
            lastError: const Value<String?>(null),
          ),
        );
  }

  @override
  Future<void> markRetry(String operationId, {required String error}) async {
    final SyncQueueData? row = await (_database.select(
      _database.syncQueue,
    )..where((tbl) => tbl.operationId.equals(operationId))).getSingleOrNull();
    if (row == null) return;
    final int nextAttempt = row.attemptCount + 1;
    final Duration delay = retryDelay(nextAttempt, operationId.hashCode);
    await (_database.update(
      _database.syncQueue,
    )..where((tbl) => tbl.operationId.equals(operationId))).write(
      SyncQueueCompanion(
        status: Value<String>(SyncOperationStatus.retryWaiting.name),
        attemptCount: Value<int>(nextAttempt),
        nextAttemptAt: Value<DateTime>(_clock.nowUtc().add(delay)),
        lastError: Value<String>(error),
      ),
    );
  }

  static Duration retryDelay(int attempt, int seed) {
    final int bounded = attempt.clamp(1, 10);
    final int baseSeconds = 1 << bounded;
    final int jitter = seed.abs() % 17;
    return Duration(seconds: (baseSeconds + jitter).clamp(2, 3600));
  }

  @override
  Stream<int> watchPendingCount() {
    final query = _database.select(_database.syncQueue)
      ..where(
        (tbl) =>
            tbl.status.isNotIn(<String>[SyncOperationStatus.completed.name]),
      );
    return query.watch().map((rows) => rows.length).distinct();
  }

  Future<void> _setStatus(
    String operationId,
    SyncOperationStatus status, {
    String? error,
    bool clearError = false,
  }) {
    return (_database.update(
      _database.syncQueue,
    )..where((tbl) => tbl.operationId.equals(operationId))).write(
      SyncQueueCompanion(
        status: Value<String>(status.name),
        nextAttemptAt: const Value<DateTime?>.absent(),
        lastError: clearError
            ? const Value<String?>(null)
            : error == null
            ? const Value<String?>.absent()
            : Value<String?>(error),
      ),
    );
  }

  SyncOperation _map(SyncQueueData row) {
    final Object? decoded = jsonDecode(row.payloadJson);
    return SyncOperation(
      id: row.operationId,
      entityType: row.entityType,
      entityId: row.entityId,
      operationType: SyncOperationType.values.byName(row.operationType),
      payload: decoded is Map
          ? Map<String, Object?>.from(decoded)
          : <String, Object?>{},
      baseVersion: row.baseVersion,
      createdAt: row.createdAt,
      attemptCount: row.attemptCount,
      nextAttemptAt: row.nextAttemptAt,
      status: SyncOperationStatus.values.byName(row.status),
      lastError: row.lastError,
    );
  }
}
