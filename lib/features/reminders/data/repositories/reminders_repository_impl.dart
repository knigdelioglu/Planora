import 'package:drift/drift.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/services/notification_service.dart';
import 'package:not_app/core/sync/sync_models.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/reminders/domain/entities/reminder.dart';
import 'package:not_app/features/reminders/domain/repositories/reminders_repository.dart';
import 'package:uuid/uuid.dart';

final class DriftRemindersRepository implements RemindersRepository {
  DriftRemindersRepository({
    required AppDatabase database,
    required NotificationService notifications,
    required SyncQueueRepository syncQueue,
    required AppClock clock,
    Uuid? uuid,
  }) : _database = database,
       _notifications = notifications,
       _syncQueue = syncQueue,
       _clock = clock,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final NotificationService _notifications;
  final SyncQueueRepository _syncQueue;
  final AppClock _clock;
  final Uuid _uuid;

  @override
  Stream<List<ReminderEntity>> watchUpcoming() {
    final DateTime now = _clock.nowUtc();
    final query = _database.select(_database.reminders)
      ..where(
        (tbl) =>
            tbl.deletedAt.isNull() &
            tbl.enabled.equals(true) &
            tbl.scheduledAtUtc.isBiggerOrEqualValue(now),
      )
      ..orderBy(<OrderingTerm Function($RemindersTable)>[
        (tbl) => OrderingTerm.asc(tbl.scheduledAtUtc),
      ]);
    return query.watch().map((rows) => rows.map(_map).toList(growable: false));
  }

  @override
  Stream<List<ReminderEntity>> watchPast() {
    final DateTime now = _clock.nowUtc();
    final query = _database.select(_database.reminders)
      ..where(
        (tbl) =>
            tbl.deletedAt.isNull() &
            tbl.enabled.equals(true) &
            tbl.scheduledAtUtc.isSmallerThanValue(now),
      )
      ..orderBy(<OrderingTerm Function($RemindersTable)>[
        (tbl) => OrderingTerm.desc(tbl.scheduledAtUtc),
      ]);
    return query.watch().map((rows) => rows.map(_map).toList(growable: false));
  }

  @override
  Stream<List<ReminderEntity>> watchDisabled() {
    final query = _database.select(_database.reminders)
      ..where(
        (tbl) => tbl.deletedAt.isNull() & tbl.enabled.equals(false),
      )
      ..orderBy(<OrderingTerm Function($RemindersTable)>[
        (tbl) => OrderingTerm.desc(tbl.scheduledAtUtc),
      ]);
    return query.watch().map((rows) => rows.map(_map).toList(growable: false));
  }

  @override
  Stream<List<ReminderEntity>> watchForParent(
    String parentType,
    String parentId,
  ) {
    final query = _database.select(_database.reminders)
      ..where(
        (tbl) =>
            tbl.parentType.equals(parentType) &
            tbl.parentId.equals(parentId) &
            tbl.deletedAt.isNull(),
      )
      ..orderBy(<OrderingTerm Function($RemindersTable)>[
        (tbl) => OrderingTerm.asc(tbl.scheduledAtUtc),
      ]);
    return query.watch().map((rows) => rows.map(_map).toList(growable: false));
  }

  @override
  Future<ReminderEntity> create({
    required String parentType,
    required String parentId,
    required String title,
    String? body,
    required DateTime scheduledAtUtc,
    required String timeZoneId,
  }) async {
    _validate(parentType, title, scheduledAtUtc);
    final String id = _uuid.v7();
    final int notificationId = await _allocateNotificationId(id);
    final DateTime now = _clock.nowUtc();
    await _database.transaction(() async {
      await _database
          .into(_database.reminders)
          .insert(
            RemindersCompanion.insert(
              id: id,
              parentType: parentType,
              parentId: parentId,
              title: title.trim(),
              body: Value<String?>(_clean(body)),
              scheduledAtUtc: scheduledAtUtc.toUtc(),
              timeZoneId: timeZoneId,
              notificationId: notificationId,
              schedulingStatus: const Value<String>('pending'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueue(
        id,
        parentType,
        parentId,
        title.trim(),
        body,
        scheduledAtUtc,
        timeZoneId,
        notificationId,
        true,
        1,
        0,
        null,
      );
    });
    await _scheduleAndMark(id);
    final row = await (_database.select(
      _database.reminders,
    )..where((tbl) => tbl.id.equals(id))).getSingle();
    return _map(row);
  }

  @override
  Future<void> update({
    required String id,
    required String title,
    String? body,
    required DateTime scheduledAtUtc,
    required String timeZoneId,
    required bool enabled,
  }) async {
    if (enabled) {
      _validate('note', title, scheduledAtUtc, skipParentValidation: true);
    }
    final Reminder? row = await (_database.select(
      _database.reminders,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (row == null || row.deletedAt != null) {
      throw StateError('Reminder does not exist.');
    }
    final DateTime now = _clock.nowUtc();
    final int nextVersion = row.version + 1;
    await _database.transaction(() async {
      await (_database.update(
        _database.reminders,
      )..where((tbl) => tbl.id.equals(id))).write(
        RemindersCompanion(
          title: Value<String>(title.trim()),
          body: Value<String?>(_clean(body)),
          scheduledAtUtc: Value<DateTime>(scheduledAtUtc.toUtc()),
          timeZoneId: Value<String>(timeZoneId),
          enabled: Value<bool>(enabled),
          schedulingStatus: Value<String>(enabled ? 'pending' : 'disabled'),
          updatedAt: Value<DateTime>(now),
          version: Value<int>(nextVersion),
        ),
      );
      await _enqueue(
        id,
        row.parentType,
        row.parentId,
        title.trim(),
        body,
        scheduledAtUtc,
        timeZoneId,
        row.notificationId,
        enabled,
        nextVersion,
        row.version,
        null,
      );
    });
    await _notifications.cancel(row.notificationId);
    if (enabled) await _scheduleAndMark(id);
  }

  @override
  Future<void> remove(String id) async {
    final Reminder? row = await (_database.select(
      _database.reminders,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (row == null || row.deletedAt != null) return;
    final DateTime now = _clock.nowUtc();
    await _database.transaction(() async {
      await (_database.update(
        _database.reminders,
      )..where((tbl) => tbl.id.equals(id))).write(
        RemindersCompanion(
          deletedAt: Value<DateTime?>(now),
          enabled: const Value<bool>(false),
          schedulingStatus: const Value<String>('deleted'),
          updatedAt: Value<DateTime>(now),
          version: Value<int>(row.version + 1),
        ),
      );
      await _syncQueue.enqueue(
        entityType: 'reminder',
        entityId: id,
        operationType: SyncOperationType.delete,
        baseVersion: row.version,
        payload: <String, Object?>{
          'id': id,
          'version': row.version + 1,
          'updatedAt': now.toIso8601String(),
          'deletedAt': now.toIso8601String(),
        },
      );
    });
    await _notifications.cancel(row.notificationId);
  }

  @override
  Future<void> reconcile() async {
    final DateTime now = _clock.nowUtc();
    final List<Reminder> rows = await _database
        .select(_database.reminders)
        .get();
    final Set<int> pending = await _notifications.pendingIds();
    for (final Reminder row in rows) {
      final bool shouldExist =
          row.deletedAt == null &&
          row.enabled &&
          row.scheduledAtUtc.isAfter(now);
      if (!shouldExist) {
        if (pending.contains(row.notificationId)) {
          await _notifications.cancel(row.notificationId);
        }
        continue;
      }
      if (!pending.contains(row.notificationId)) {
        await _scheduleAndMark(row.id);
      } else {
        await (_database.update(
          _database.reminders,
        )..where((tbl) => tbl.id.equals(row.id))).write(
          RemindersCompanion(
            schedulingStatus: const Value<String>('scheduled'),
            lastReconciledAt: Value<DateTime?>(now),
          ),
        );
      }
    }
  }

  Future<void> _scheduleAndMark(String id) async {
    final Reminder row = await (_database.select(
      _database.reminders,
    )..where((tbl) => tbl.id.equals(id))).getSingle();
    try {
      await _notifications.schedule(
        id: row.notificationId,
        title: row.title,
        body: row.body ?? 'Hatırlatıcınız hazır.',
        scheduledAtUtc: row.scheduledAtUtc,
        timeZoneId: row.timeZoneId,
        payload: '${row.parentType}:${row.parentId}',
      );
      await (_database.update(
        _database.reminders,
      )..where((tbl) => tbl.id.equals(id))).write(
        RemindersCompanion(
          schedulingStatus: const Value<String>('scheduled'),
          lastReconciledAt: Value<DateTime?>(_clock.nowUtc()),
        ),
      );
    } catch (_) {
      await (_database.update(
        _database.reminders,
      )..where((tbl) => tbl.id.equals(id))).write(
        RemindersCompanion(
          schedulingStatus: const Value<String>('failed'),
          lastReconciledAt: Value<DateTime?>(_clock.nowUtc()),
        ),
      );
      rethrow;
    }
  }

  Future<int> _allocateNotificationId(String id) async {
    int candidate =
        int.parse(id.replaceAll('-', '').substring(0, 8), radix: 16) &
        0x7fffffff;
    if (candidate == 0) candidate = 1;
    while (await (_database.select(_database.reminders)
              ..where((tbl) => tbl.notificationId.equals(candidate)))
            .getSingleOrNull() !=
        null) {
      candidate = candidate == 0x7fffffff ? 1 : candidate + 1;
    }
    return candidate;
  }

  void _validate(
    String parentType,
    String title,
    DateTime scheduledAtUtc, {
    bool skipParentValidation = false,
  }) {
    if (!skipParentValidation && parentType != 'note' && parentType != 'card') {
      throw ArgumentError.value(
        parentType,
        'parentType',
        'Only note and card reminders are supported.',
      );
    }
    if (title.trim().isEmpty) {
      throw ArgumentError('Reminder title cannot be empty.');
    }
    if (!scheduledAtUtc.toUtc().isAfter(_clock.nowUtc())) {
      throw ArgumentError('Reminder time must be in the future.');
    }
  }

  String? _clean(String? value) {
    final String? clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  Future<void> _enqueue(
    String id,
    String parentType,
    String parentId,
    String title,
    String? body,
    DateTime scheduledAtUtc,
    String timeZoneId,
    int notificationId,
    bool enabled,
    int version,
    int baseVersion,
    DateTime? deletedAt,
  ) {
    return _syncQueue.enqueue(
      entityType: 'reminder',
      entityId: id,
      operationType: SyncOperationType.upsert,
      baseVersion: baseVersion,
      payload: <String, Object?>{
        'id': id,
        'parentType': parentType,
        'parentId': parentId,
        'title': title,
        'body': _clean(body),
        'scheduledAtUtc': scheduledAtUtc.toUtc().toIso8601String(),
        'timeZoneId': timeZoneId,
        'notificationId': notificationId,
        'enabled': enabled,
        'version': version,
        'updatedAt': _clock.nowUtc().toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      },
    );
  }

  ReminderEntity _map(Reminder row) => ReminderEntity(
    id: row.id,
    parentType: row.parentType,
    parentId: row.parentId,
    title: row.title,
    body: row.body,
    scheduledAtUtc: row.scheduledAtUtc,
    timeZoneId: row.timeZoneId,
    notificationId: row.notificationId,
    enabled: row.enabled,
    schedulingStatus: row.schedulingStatus,
    lastReconciledAt: row.lastReconciledAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    version: row.version,
    deletedAt: row.deletedAt,
  );
}
