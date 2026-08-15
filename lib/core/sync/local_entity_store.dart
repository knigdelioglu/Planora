import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/remote/remote_models.dart';
import 'package:not_app/core/utils/clock.dart';

final class LocalEntityStore {
  LocalEntityStore({required AppDatabase database, required AppClock clock})
      : _database = database,
        _clock = clock;

  final AppDatabase _database;
  final AppClock _clock;

  Future<bool> hasPendingMutation(String entityType, String entityId) async {
    final row = await (_database.select(_database.syncQueue)
          ..where(
            (tbl) =>
                tbl.entityType.equals(entityType) &
                tbl.entityId.equals(entityId) &
                tbl.status.isNotIn(<String>['completed']),
          )
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  Future<Map<String, Object?>?> payloadFor(String entityType, String entityId) async {
    switch (entityType) {
      case 'note':
        final row = await (_database.select(_database.notes)..where((tbl) => tbl.id.equals(entityId))).getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.id,
          'title': row.title,
          'contentJson': row.contentJson,
          'isFavorite': row.isFavorite,
          'createdAt': row.createdAt.toIso8601String(),
          'updatedAt': row.updatedAt.toIso8601String(),
          'version': row.version,
          'deletedAt': row.deletedAt?.toIso8601String(),
        };
      case 'board':
        final row = await (_database.select(_database.boards)..where((tbl) => tbl.id.equals(entityId))).getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.id,
          'title': row.title,
          'colorHex': row.colorHex,
          'createdAt': row.createdAt.toIso8601String(),
          'updatedAt': row.updatedAt.toIso8601String(),
          'version': row.version,
          'deletedAt': row.deletedAt?.toIso8601String(),
        };
      case 'column':
        final row = await (_database.select(_database.boardColumns)..where((tbl) => tbl.id.equals(entityId))).getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.id,
          'boardId': row.boardId,
          'title': row.title,
          'colorHex': row.colorHex,
          'rankKey': row.rankKey,
          'createdAt': row.createdAt.toIso8601String(),
          'updatedAt': row.updatedAt.toIso8601String(),
          'version': row.version,
          'deletedAt': row.deletedAt?.toIso8601String(),
        };
      case 'card':
        final row = await (_database.select(_database.cards)..where((tbl) => tbl.id.equals(entityId))).getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.id,
          'boardId': row.boardId,
          'columnId': row.columnId,
          'title': row.title,
          'description': row.description,
          'rankKey': row.rankKey,
          'createdAt': row.createdAt.toIso8601String(),
          'updatedAt': row.updatedAt.toIso8601String(),
          'version': row.version,
          'deletedAt': row.deletedAt?.toIso8601String(),
        };
      case 'attachment':
        final row = await (_database.select(_database.attachments)..where((tbl) => tbl.id.equals(entityId))).getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.id,
          'parentType': row.parentType,
          'parentId': row.parentId,
          'fileName': row.fileName,
          'remotePath': row.remotePath,
          'mimeType': row.mimeType,
          'sizeBytes': row.sizeBytes,
          'checksum': row.checksum,
          'createdAt': row.createdAt.toIso8601String(),
          'updatedAt': row.updatedAt.toIso8601String(),
          'version': row.version,
          'deletedAt': row.deletedAt?.toIso8601String(),
        };
      case 'reminder':
        final row = await (_database.select(_database.reminders)..where((tbl) => tbl.id.equals(entityId))).getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.id,
          'parentType': row.parentType,
          'parentId': row.parentId,
          'title': row.title,
          'body': row.body,
          'scheduledAtUtc': row.scheduledAtUtc.toIso8601String(),
          'timeZoneId': row.timeZoneId,
          'enabled': row.enabled,
          'createdAt': row.createdAt.toIso8601String(),
          'updatedAt': row.updatedAt.toIso8601String(),
          'version': row.version,
          'deletedAt': row.deletedAt?.toIso8601String(),
        };
      default:
        return null;
    }
  }

  Future<int> localVersion(String entityType, String entityId) async {
    final payload = await payloadFor(entityType, entityId);
    return (payload?['version'] as num?)?.toInt() ?? 0;
  }

  Future<void> applyRemote(RemoteEntity remote) async {
    final Map<String, Object?> p = remote.payload;
    final DateTime created = _date(p['createdAt']) ?? remote.updatedAt;
    final DateTime updated = remote.updatedAt;
    final DateTime? deleted = remote.deletedAt;
    await _database.transaction(() async {
      switch (remote.entityType) {
        case 'note':
          await _database.into(_database.notes).insertOnConflictUpdate(
                NotesCompanion.insert(
                  id: remote.entityId,
                  title: Value<String>((p['title'] ?? '').toString()),
                  contentJson: Value<String>((p['contentJson'] ?? '{"version":1,"blocks":[]}').toString()),
                  isFavorite: Value<bool>(p['isFavorite'] == true),
                  createdAt: created,
                  updatedAt: updated,
                  version: Value<int>(remote.version),
                  deletedAt: Value<DateTime?>(deleted),
                ),
              );
          if (deleted == null) {
            await _database.upsertSearchEntry(
              entityType: 'note',
              entityId: remote.entityId,
              title: (p['title'] ?? '').toString(),
              body: _notePlainText((p['contentJson'] ?? '').toString()),
            );
          } else {
            await _database.deleteSearchEntry('note', remote.entityId);
          }
        case 'board':
          await _database.into(_database.boards).insertOnConflictUpdate(
                BoardsCompanion.insert(
                  id: remote.entityId,
                  title: (p['title'] ?? '').toString(),
                  colorHex: Value<String?>(p['colorHex'] as String?),
                  createdAt: created,
                  updatedAt: updated,
                  version: Value<int>(remote.version),
                  deletedAt: Value<DateTime?>(deleted),
                ),
              );
          if (deleted == null) {
            await _database.upsertSearchEntry(entityType: 'board', entityId: remote.entityId, title: (p['title'] ?? '').toString(), body: '');
          } else {
            await _database.deleteSearchEntry('board', remote.entityId);
          }
        case 'column':
          await _database.into(_database.boardColumns).insertOnConflictUpdate(
                BoardColumnsCompanion.insert(
                  id: remote.entityId,
                  boardId: p['boardId']! as String,
                  title: (p['title'] ?? '').toString(),
                  colorHex: Value<String?>(p['colorHex'] as String?),
                  rankKey: Value<String>((p['rankKey'] ?? 'hzzzzzzzzzzz').toString()),
                  createdAt: created,
                  updatedAt: updated,
                  version: Value<int>(remote.version),
                  deletedAt: Value<DateTime?>(deleted),
                ),
              );
        case 'card':
          await _database.into(_database.cards).insertOnConflictUpdate(
                CardsCompanion.insert(
                  id: remote.entityId,
                  boardId: p['boardId']! as String,
                  columnId: p['columnId']! as String,
                  title: (p['title'] ?? '').toString(),
                  description: Value<String?>(p['description'] as String?),
                  rankKey: Value<String>((p['rankKey'] ?? 'hzzzzzzzzzzz').toString()),
                  createdAt: created,
                  updatedAt: updated,
                  version: Value<int>(remote.version),
                  deletedAt: Value<DateTime?>(deleted),
                ),
              );
          if (deleted == null) {
            await _database.upsertSearchEntry(entityType: 'card', entityId: remote.entityId, title: (p['title'] ?? '').toString(), body: (p['description'] ?? '').toString());
          } else {
            await _database.deleteSearchEntry('card', remote.entityId);
          }
        case 'attachment':
          final Attachment? existing = await (_database.select(_database.attachments)..where((tbl) => tbl.id.equals(remote.entityId))).getSingleOrNull();
          await _database.into(_database.attachments).insertOnConflictUpdate(
                AttachmentsCompanion.insert(
                  id: remote.entityId,
                  parentType: p['parentType']! as String,
                  parentId: p['parentId']! as String,
                  fileName: (p['fileName'] ?? 'attachment').toString(),
                  localPath: existing?.localPath ?? '',
                  remotePath: Value<String?>(p['remotePath'] as String?),
                  mimeType: Value<String?>(p['mimeType'] as String?),
                  sizeBytes: (p['sizeBytes'] as num?)?.toInt() ?? 0,
                  checksum: Value<String?>(p['checksum'] as String?),
                  isCache: Value<bool>(existing?.isCache ?? false),
                  transferState: const Value<String>('synced'),
                  createdAt: created,
                  updatedAt: updated,
                  version: Value<int>(remote.version),
                  deletedAt: Value<DateTime?>(deleted),
                ),
              );
        case 'reminder':
          final Reminder? existing = await (_database.select(_database.reminders)..where((tbl) => tbl.id.equals(remote.entityId))).getSingleOrNull();
          await _database.into(_database.reminders).insertOnConflictUpdate(
                RemindersCompanion.insert(
                  id: remote.entityId,
                  parentType: p['parentType']! as String,
                  parentId: p['parentId']! as String,
                  title: (p['title'] ?? '').toString(),
                  body: Value<String?>(p['body'] as String?),
                  scheduledAtUtc: _date(p['scheduledAtUtc']) ?? updated,
                  timeZoneId: (p['timeZoneId'] ?? 'UTC').toString(),
                  notificationId: existing?.notificationId ?? _notificationIdFor(remote.entityId),
                  enabled: Value<bool>(p['enabled'] != false),
                  schedulingStatus: const Value<String>('pending'),
                  createdAt: created,
                  updatedAt: updated,
                  version: Value<int>(remote.version),
                  deletedAt: Value<DateTime?>(deleted),
                ),
              );
        default:
          throw StateError('Unsupported remote entity: ${remote.entityType}');
      }
    });
  }

  DateTime? _date(Object? raw) => raw == null ? null : DateTime.tryParse(raw.toString())?.toUtc();

  int _notificationIdFor(String id) {
    final String hex = id.replaceAll('-', '').padRight(8, '0').substring(0, 8);
    final int value = int.tryParse(hex, radix: 16) ?? id.hashCode.abs();
    return (value & 0x7fffffff).clamp(1, 0x7fffffff);
  }

  String _notePlainText(String contentJson) {
    try {
      final Object? decoded = jsonDecode(contentJson);
      if (decoded is! Map) return '';
      final Object? blocks = decoded['blocks'];
      if (blocks is! List) return '';
      return blocks
          .whereType<Map>()
          .map((block) => (block['text'] ?? block['url'] ?? '').toString())
          .where((text) => text.isNotEmpty)
          .join('\n');
    } catch (_) {
      return '';
    }
  }
}
