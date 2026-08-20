import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/events/entity_change_bus.dart';
import 'package:not_app/core/remote/remote_models.dart';
import 'package:not_app/core/utils/clock.dart';

final class LocalEntityStore {
  LocalEntityStore({
    required this._database,
    required AppClock clock,
    EntityChangeBus? changes,
  }) : _changes = changes;

  final AppDatabase _database;
  final EntityChangeBus? _changes;

  Future<bool> hasPendingMutation(String entityType, String entityId) async {
    final row =
        await (_database.select(_database.syncQueue)
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

  Future<Map<String, Object?>?> payloadFor(
    String entityType,
    String entityId,
  ) async {
    switch (entityType) {
      case 'note':
        final row = await (_database.select(
          _database.notes,
        )..where((tbl) => tbl.id.equals(entityId))).getSingleOrNull();
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
        final row = await (_database.select(
          _database.boards,
        )..where((tbl) => tbl.id.equals(entityId))).getSingleOrNull();
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
        final row = await (_database.select(
          _database.boardColumns,
        )..where((tbl) => tbl.id.equals(entityId))).getSingleOrNull();
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
        final row = await (_database.select(
          _database.cards,
        )..where((tbl) => tbl.id.equals(entityId))).getSingleOrNull();
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
      case 'card_note_link':
        final row = await _database
            .customSelect(
              '''
          SELECT id, note_id, card_id, created_at, updated_at, version, deleted_at
          FROM card_note_links
          WHERE id = ?
          LIMIT 1
          ''',
              variables: <Variable<Object>>[Variable<String>(entityId)],
            )
            .getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.read<String>('id'),
          'noteId': row.read<String>('note_id'),
          'cardId': row.read<String>('card_id'),
          'createdAt': row.read<String>('created_at'),
          'updatedAt': row.read<String>('updated_at'),
          'version': row.read<int>('version'),
          'deletedAt': row.readNullable<String>('deleted_at'),
        };
      case 'attachment':
        final row = await (_database.select(
          _database.attachments,
        )..where((tbl) => tbl.id.equals(entityId))).getSingleOrNull();
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
        final row = await (_database.select(
          _database.reminders,
        )..where((tbl) => tbl.id.equals(entityId))).getSingleOrNull();
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
      case 'tag':
        final row = await _database
            .customSelect(
              '''
          SELECT id, name, normalized_name, color_key,
                 created_at, updated_at, version, deleted_at
          FROM tags WHERE id = ? LIMIT 1
          ''',
              variables: <Variable<Object>>[Variable<String>(entityId)],
            )
            .getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.read<String>('id'),
          'name': row.read<String>('name'),
          'normalizedName': row.read<String>('normalized_name'),
          'colorKey': row.read<String>('color_key'),
          'createdAt': row.read<String>('created_at'),
          'updatedAt': row.read<String>('updated_at'),
          'version': row.read<int>('version'),
          'deletedAt': row.readNullable<String>('deleted_at'),
        };
      case 'tag_assignment':
        final row = await _database
            .customSelect(
              '''
          SELECT id, tag_id, target_type, target_id,
                 created_at, updated_at, version, deleted_at
          FROM tag_assignments WHERE id = ? LIMIT 1
          ''',
              variables: <Variable<Object>>[Variable<String>(entityId)],
            )
            .getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.read<String>('id'),
          'tagId': row.read<String>('tag_id'),
          'targetType': row.read<String>('target_type'),
          'targetId': row.read<String>('target_id'),
          'createdAt': row.read<String>('created_at'),
          'updatedAt': row.read<String>('updated_at'),
          'version': row.read<int>('version'),
          'deletedAt': row.readNullable<String>('deleted_at'),
        };
      case 'smart_view':
        final row = await _database
            .customSelect(
              '''
          SELECT id, name, icon_key, rank_key, query_json,
                 created_at, updated_at, version, deleted_at
          FROM smart_views WHERE id = ? LIMIT 1
          ''',
              variables: <Variable<Object>>[Variable<String>(entityId)],
            )
            .getSingleOrNull();
        if (row == null) return null;
        return <String, Object?>{
          'id': row.read<String>('id'),
          'name': row.read<String>('name'),
          'iconKey': row.read<String>('icon_key'),
          'rankKey': row.read<String>('rank_key'),
          'queryJson': row.read<String>('query_json'),
          'createdAt': row.read<String>('created_at'),
          'updatedAt': row.read<String>('updated_at'),
          'version': row.read<int>('version'),
          'deletedAt': row.readNullable<String>('deleted_at'),
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
    final Map<String, Object?> p = _normalizePayload(remote.payload);
    final DateTime created = _date(p['createdAt']) ?? remote.updatedAt;
    final DateTime updated = remote.updatedAt;
    final DateTime? deleted = remote.deletedAt;
    await _database.transaction(() async {
      switch (remote.entityType) {
        case 'note':
          await _database
              .into(_database.notes)
              .insertOnConflictUpdate(
                NotesCompanion.insert(
                  id: remote.entityId,
                  title: Value<String>((p['title'] ?? '').toString()),
                  contentJson: Value<String>(
                    (p['contentJson'] ?? '{"version":1,"blocks":[]}')
                        .toString(),
                  ),
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
          await _database
              .into(_database.boards)
              .insertOnConflictUpdate(
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
            await _database.upsertSearchEntry(
              entityType: 'board',
              entityId: remote.entityId,
              title: (p['title'] ?? '').toString(),
              body: '',
            );
          } else {
            await _database.deleteSearchEntry('board', remote.entityId);
          }
        case 'column':
          final BoardColumn? existing = await (_database.select(
            _database.boardColumns,
          )..where((tbl) => tbl.id.equals(remote.entityId))).getSingleOrNull();
          final String? boardId =
              _optionalText(p, 'boardId') ?? existing?.boardId;
          if (boardId == null && deleted != null && existing == null) return;
          await _database
              .into(_database.boardColumns)
              .insertOnConflictUpdate(
                BoardColumnsCompanion.insert(
                  id: remote.entityId,
                  boardId: boardId ?? _requiredText(p, 'boardId', remote),
                  title: (p['title'] ?? '').toString(),
                  colorHex: Value<String?>(p['colorHex'] as String?),
                  rankKey: Value<String>(
                    (p['rankKey'] ?? 'hzzzzzzzzzzz').toString(),
                  ),
                  createdAt: created,
                  updatedAt: updated,
                  version: Value<int>(remote.version),
                  deletedAt: Value<DateTime?>(deleted),
                ),
              );
        case 'card':
          final Card? existing = await (_database.select(
            _database.cards,
          )..where((tbl) => tbl.id.equals(remote.entityId))).getSingleOrNull();
          final String? boardId =
              _optionalText(p, 'boardId') ?? existing?.boardId;
          final String? columnId =
              _optionalText(p, 'columnId') ?? existing?.columnId;
          if ((boardId == null || columnId == null) &&
              deleted != null &&
              existing == null) {
            return;
          }
          await _database
              .into(_database.cards)
              .insertOnConflictUpdate(
                CardsCompanion.insert(
                  id: remote.entityId,
                  boardId: boardId ?? _requiredText(p, 'boardId', remote),
                  columnId: columnId ?? _requiredText(p, 'columnId', remote),
                  title: (p['title'] ?? '').toString(),
                  description: Value<String?>(p['description'] as String?),
                  rankKey: Value<String>(
                    (p['rankKey'] ?? 'hzzzzzzzzzzz').toString(),
                  ),
                  createdAt: created,
                  updatedAt: updated,
                  version: Value<int>(remote.version),
                  deletedAt: Value<DateTime?>(deleted),
                ),
              );
          if (deleted == null) {
            await _database.upsertSearchEntry(
              entityType: 'card',
              entityId: remote.entityId,
              title: (p['title'] ?? '').toString(),
              body: (p['description'] ?? '').toString(),
            );
          } else {
            await _database.deleteSearchEntry('card', remote.entityId);
          }
        case 'card_note_link':
          final String? noteId = p['noteId']?.toString();
          final String? cardId = p['cardId']?.toString();
          if (noteId == null ||
              noteId.isEmpty ||
              cardId == null ||
              cardId.isEmpty) {
            if (deleted != null) {
              await _database.customStatement(
                'DELETE FROM card_note_links WHERE id = ?',
                <Object?>[remote.entityId],
              );
              return;
            }
            throw StateError('Card-note link payload is incomplete.');
          }
          await _database.customStatement(
            '''
            INSERT INTO card_note_links(
              id, note_id, card_id, created_at, updated_at, version, deleted_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              note_id = excluded.note_id,
              card_id = excluded.card_id,
              created_at = excluded.created_at,
              updated_at = excluded.updated_at,
              version = excluded.version,
              deleted_at = excluded.deleted_at
            ''',
            <Object?>[
              remote.entityId,
              noteId,
              cardId,
              (p['createdAt'] ?? created.toIso8601String()).toString(),
              updated.toIso8601String(),
              remote.version,
              deleted?.toIso8601String(),
            ],
          );
        case 'attachment':
          final Attachment? existing = await (_database.select(
            _database.attachments,
          )..where((tbl) => tbl.id.equals(remote.entityId))).getSingleOrNull();
          final String? parentType =
              _optionalText(p, 'parentType') ?? existing?.parentType;
          final String? parentId =
              _optionalText(p, 'parentId') ?? existing?.parentId;
          if ((parentType == null || parentId == null) &&
              deleted != null &&
              existing == null) {
            return;
          }
          await _database
              .into(_database.attachments)
              .insertOnConflictUpdate(
                AttachmentsCompanion.insert(
                  id: remote.entityId,
                  parentType:
                      parentType ?? _requiredText(p, 'parentType', remote),
                  parentId: parentId ?? _requiredText(p, 'parentId', remote),
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
          final Reminder? existing = await (_database.select(
            _database.reminders,
          )..where((tbl) => tbl.id.equals(remote.entityId))).getSingleOrNull();
          final String? parentType =
              _optionalText(p, 'parentType') ?? existing?.parentType;
          final String? parentId =
              _optionalText(p, 'parentId') ?? existing?.parentId;
          if ((parentType == null || parentId == null) &&
              deleted != null &&
              existing == null) {
            return;
          }
          await _database
              .into(_database.reminders)
              .insertOnConflictUpdate(
                RemindersCompanion.insert(
                  id: remote.entityId,
                  parentType:
                      parentType ?? _requiredText(p, 'parentType', remote),
                  parentId: parentId ?? _requiredText(p, 'parentId', remote),
                  title: (p['title'] ?? '').toString(),
                  body: Value<String?>(p['body'] as String?),
                  scheduledAtUtc: _date(p['scheduledAtUtc']) ?? updated,
                  timeZoneId: (p['timeZoneId'] ?? 'UTC').toString(),
                  notificationId:
                      existing?.notificationId ??
                      _notificationIdFor(remote.entityId),
                  enabled: Value<bool>(p['enabled'] != false),
                  schedulingStatus: const Value<String>('pending'),
                  createdAt: created,
                  updatedAt: updated,
                  version: Value<int>(remote.version),
                  deletedAt: Value<DateTime?>(deleted),
                ),
              );
        case 'tag':
          final String name = (p['name'] ?? '').toString().trim();
          final String normalizedName =
              (p['normalizedName'] ?? name.toLowerCase()).toString().trim();
          await _database.customStatement(
            '''
            INSERT INTO tags(
              id, name, normalized_name, color_key,
              created_at, updated_at, version, deleted_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              name = excluded.name,
              normalized_name = excluded.normalized_name,
              color_key = excluded.color_key,
              created_at = excluded.created_at,
              updated_at = excluded.updated_at,
              version = excluded.version,
              deleted_at = excluded.deleted_at
            ''',
            <Object?>[
              remote.entityId,
              name,
              normalizedName,
              (p['colorKey'] ?? 'indigo').toString(),
              (p['createdAt'] ?? created.toIso8601String()).toString(),
              updated.toIso8601String(),
              remote.version,
              deleted?.toIso8601String(),
            ],
          );
        case 'tag_assignment':
          final String? tagId = _optionalText(p, 'tagId');
          final String? targetType = _optionalText(p, 'targetType');
          final String? targetId = _optionalText(p, 'targetId');
          if (tagId == null || targetType == null || targetId == null) {
            if (deleted != null) {
              await _database.customStatement(
                'DELETE FROM tag_assignments WHERE id = ?',
                <Object?>[remote.entityId],
              );
              return;
            }
            throw StateError('Tag assignment payload is incomplete.');
          }
          if (targetType != 'note' && targetType != 'card') {
            throw StateError('Unsupported tag assignment target: $targetType');
          }
          await _database.customStatement(
            '''
            INSERT INTO tag_assignments(
              id, tag_id, target_type, target_id,
              created_at, updated_at, version, deleted_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              tag_id = excluded.tag_id,
              target_type = excluded.target_type,
              target_id = excluded.target_id,
              created_at = excluded.created_at,
              updated_at = excluded.updated_at,
              version = excluded.version,
              deleted_at = excluded.deleted_at
            ''',
            <Object?>[
              remote.entityId,
              tagId,
              targetType,
              targetId,
              (p['createdAt'] ?? created.toIso8601String()).toString(),
              updated.toIso8601String(),
              remote.version,
              deleted?.toIso8601String(),
            ],
          );
        case 'smart_view':
          await _database.customStatement(
            '''
            INSERT INTO smart_views(
              id, name, icon_key, rank_key, query_json,
              created_at, updated_at, version, deleted_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              name = excluded.name,
              icon_key = excluded.icon_key,
              rank_key = excluded.rank_key,
              query_json = excluded.query_json,
              created_at = excluded.created_at,
              updated_at = excluded.updated_at,
              version = excluded.version,
              deleted_at = excluded.deleted_at
            ''',
            <Object?>[
              remote.entityId,
              (p['name'] ?? 'Akıllı görünüm').toString(),
              (p['iconKey'] ?? 'filter_alt').toString(),
              (p['rankKey'] ?? 'hzzzzzzzzzzz').toString(),
              (p['queryJson'] ?? '{"version":1}').toString(),
              (p['createdAt'] ?? created.toIso8601String()).toString(),
              updated.toIso8601String(),
              remote.version,
              deleted?.toIso8601String(),
            ],
          );
        default:
          throw StateError('Unsupported remote entity: ${remote.entityType}');
      }
    });
    if (remote.entityType == 'tag' ||
        remote.entityType == 'tag_assignment' ||
        remote.entityType == 'smart_view') {
      _changes?.notify(remote.entityType);
    }
  }

  DateTime? _date(Object? raw) =>
      raw == null ? null : DateTime.tryParse(raw.toString())?.toUtc();

  Map<String, Object?> _normalizePayload(Map<String, Object?> payload) {
    final Map<String, Object?> normalized = Map<String, Object?>.from(payload);
    const Map<String, String> aliases = <String, String>{
      'createdAt': 'created_at',
      'updatedAt': 'updated_at',
      'deletedAt': 'deleted_at',
      'contentJson': 'content_json',
      'isFavorite': 'is_favorite',
      'boardId': 'board_id',
      'columnId': 'column_id',
      'noteId': 'note_id',
      'cardId': 'card_id',
      'rankKey': 'rank_key',
      'parentType': 'parent_type',
      'parentId': 'parent_id',
      'fileName': 'file_name',
      'remotePath': 'remote_path',
      'mimeType': 'mime_type',
      'sizeBytes': 'size_bytes',
      'scheduledAtUtc': 'scheduled_at_utc',
      'timeZoneId': 'time_zone_id',
      'normalizedName': 'normalized_name',
      'colorKey': 'color_key',
      'tagId': 'tag_id',
      'targetType': 'target_type',
      'targetId': 'target_id',
      'iconKey': 'icon_key',
      'queryJson': 'query_json',
    };
    for (final MapEntry<String, String> alias in aliases.entries) {
      if (!normalized.containsKey(alias.key) &&
          normalized.containsKey(alias.value)) {
        normalized[alias.key] = normalized[alias.value];
      }
    }
    return normalized;
  }

  String _requiredText(
    Map<String, Object?> payload,
    String field,
    RemoteEntity remote,
  ) {
    final Object? value = payload[field];
    final String text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw StateError(
        'Remote ${remote.entityType}/${remote.entityId} is missing $field.',
      );
    }
    return text;
  }

  String? _optionalText(Map<String, Object?> payload, String field) {
    final Object? value = payload[field];
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  int _notificationIdFor(String id) {
    final String hex = id.replaceAll('-', '').padRight(8, '0').substring(0, 8);
    final int value = int.tryParse(hex, radix: 16) ?? id.hashCode.abs();
    return (value & 0x7fffffff).clamp(1, 0x7fffffff);
  }

  String _notePlainText(String contentJson) {
    try {
      final Object? decoded = jsonDecode(contentJson);
      if (decoded is! Map<Object?, Object?>) return '';
      final Object? blocks = decoded['blocks'];
      if (blocks is! List<Object?>) return '';
      return blocks
          .whereType<Map<Object?, Object?>>()
          .map((block) => (block['text'] ?? block['url'] ?? '').toString())
          .where((text) => text.isNotEmpty)
          .join('\n');
    } catch (_) {
      return '';
    }
  }
}
