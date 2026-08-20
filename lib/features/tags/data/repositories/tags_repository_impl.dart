// ignore_for_file: prefer_initializing_formals, close_sinks

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/events/entity_change_bus.dart';
import 'package:not_app/core/sync/sync_models.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/tags/domain/entities/tag.dart';
import 'package:not_app/features/tags/domain/repositories/tags_repository.dart';

final class DriftTagsRepository implements TagsRepository {
  DriftTagsRepository({
    required AppDatabase database,
    required SyncQueueRepository syncQueue,
    required AppClock clock,
    required EntityChangeBus changes,
  }) : _database = database,
       _syncQueue = syncQueue,
       _clock = clock,
       _changes = changes;

  static const Set<String> supportedColorKeys = <String>{
    'gray',
    'red',
    'orange',
    'amber',
    'green',
    'teal',
    'blue',
    'indigo',
    'violet',
    'pink',
  };

  final AppDatabase _database;
  final SyncQueueRepository _syncQueue;
  final AppClock _clock;
  final EntityChangeBus _changes;

  @override
  Stream<List<TagEntity>> watchTags() =>
      _watch<List<TagEntity>>(const <String>{'tag'}, _loadTags);

  @override
  Stream<List<TagEntity>> watchTagsForTarget({
    required TagTargetType targetType,
    required String targetId,
  }) => _watch<List<TagEntity>>(const <String>{
    'tag',
    'tag_assignment',
  }, () => tagsForTarget(targetType: targetType, targetId: targetId));

  @override
  Stream<int> watchUsageCount(String tagId) =>
      _watch<int>(const <String>{'tag_assignment'}, () async {
        final QueryRow row = await _database
            .customSelect(
              '''
        SELECT count(*) AS usage_count
        FROM tag_assignments
        WHERE tag_id = ? AND deleted_at IS NULL
        ''',
              variables: <Variable<Object>>[Variable<String>(tagId)],
            )
            .getSingle();
        return row.read<int>('usage_count');
      });

  @override
  Future<List<TagEntity>> tagsForTarget({
    required TagTargetType targetType,
    required String targetId,
  }) async {
    final List<QueryRow> rows = await _database
        .customSelect(
          '''
      SELECT t.id, t.name, t.normalized_name, t.color_key,
             t.created_at, t.updated_at, t.version, t.deleted_at
      FROM tags t
      INNER JOIN tag_assignments a ON a.tag_id = t.id
      WHERE a.target_type = ?
        AND a.target_id = ?
        AND a.deleted_at IS NULL
        AND t.deleted_at IS NULL
      ORDER BY lower(t.name), t.name
      ''',
          variables: <Variable<Object>>[
            Variable<String>(targetType.wireName),
            Variable<String>(targetId),
          ],
        )
        .get();
    return rows.map(_mapTag).toList(growable: false);
  }

  @override
  Future<String> createTag({
    required String name,
    String colorKey = 'indigo',
  }) async {
    final String cleanName = _cleanName(name);
    final String normalized = normalizeName(cleanName);
    if (normalized.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Etiket adı boş olamaz.');
    }
    final String id = _tagId(normalized);
    final _TagRow? existingById = await _tagById(id);
    final QueryRow? existingActive = await _database
        .customSelect(
          '''
      SELECT id FROM tags
      WHERE normalized_name = ? AND deleted_at IS NULL
      LIMIT 1
      ''',
          variables: <Variable<Object>>[Variable<String>(normalized)],
        )
        .getSingleOrNull();
    if (existingActive != null) return existingActive.read<String>('id');

    final String color = _validatedColor(colorKey);
    final DateTime now = _clock.nowUtc();
    if (existingById != null) {
      await _database.transaction(() async {
        await _writeTag(
          existingById,
          name: cleanName,
          normalizedName: normalized,
          colorKey: color,
          deletedAt: null,
        );
      });
      _changes.notify('tag');
      return id;
    }

    await _database.transaction(() async {
      await _database.customStatement(
        '''
        INSERT INTO tags(
          id, name, normalized_name, color_key,
          created_at, updated_at, version, deleted_at
        ) VALUES (?, ?, ?, ?, ?, ?, 1, NULL)
        ''',
        <Object?>[
          id,
          cleanName,
          normalized,
          color,
          now.toIso8601String(),
          now.toIso8601String(),
        ],
      );
      await _syncQueue.enqueue(
        entityType: 'tag',
        entityId: id,
        operationType: SyncOperationType.upsert,
        payload: _tagPayload(
          id: id,
          name: cleanName,
          normalizedName: normalized,
          colorKey: color,
          createdAt: now,
          updatedAt: now,
          version: 1,
          deletedAt: null,
        ),
        baseVersion: 0,
      );
    });
    _changes.notify('tag');
    return id;
  }

  @override
  Future<void> renameTag(String tagId, String name) async {
    final _TagRow row = await _requireTag(tagId);
    final String cleanName = _cleanName(name);
    final String normalized = normalizeName(cleanName);
    if (normalized.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Etiket adı boş olamaz.');
    }
    final QueryRow? duplicate = await _database
        .customSelect(
          '''
      SELECT id FROM tags
      WHERE normalized_name = ? AND deleted_at IS NULL AND id <> ?
      LIMIT 1
      ''',
          variables: <Variable<Object>>[
            Variable<String>(normalized),
            Variable<String>(tagId),
          ],
        )
        .getSingleOrNull();
    if (duplicate != null) {
      throw StateError('Aynı ada sahip başka bir etiket zaten var.');
    }
    await _database.transaction(() async {
      await _writeTag(
        row,
        name: cleanName,
        normalizedName: normalized,
        colorKey: row.colorKey,
        deletedAt: row.deletedAt,
      );
    });
    _changes.notify('tag');
  }

  @override
  Future<void> setColor(String tagId, String colorKey) async {
    final _TagRow row = await _requireTag(tagId);
    await _database.transaction(() async {
      await _writeTag(
        row,
        name: row.name,
        normalizedName: row.normalizedName,
        colorKey: _validatedColor(colorKey),
        deletedAt: row.deletedAt,
      );
    });
    _changes.notify('tag');
  }

  @override
  Future<void> deleteTag(String tagId) async {
    final _TagRow row = await _requireTag(tagId);
    if (row.deletedAt != null) return;
    final DateTime now = _clock.nowUtc();
    final List<_AssignmentRow> assignments = await _activeAssignments(
      tagId: tagId,
    );
    await _database.transaction(() async {
      for (final _AssignmentRow assignment in assignments) {
        await _writeAssignment(assignment, deletedAt: now);
      }
      await _writeTag(
        row,
        name: row.name,
        normalizedName: row.normalizedName,
        colorKey: row.colorKey,
        deletedAt: now,
      );
    });
    _changes.notify('tag_assignment');
    _changes.notify('tag');
  }

  @override
  Future<void> assign({
    required String tagId,
    required TagTargetType targetType,
    required String targetId,
  }) async {
    final _TagRow tag = await _requireTag(tagId);
    if (tag.deletedAt != null) {
      throw StateError('Silinmiş etiket içeriğe atanamaz.');
    }
    await _requireTarget(targetType, targetId);
    final String assignmentId = _assignmentId(tagId, targetType, targetId);
    final _AssignmentRow? existing = await _assignmentById(assignmentId);
    if (existing != null && existing.deletedAt == null) return;

    final DateTime now = _clock.nowUtc();
    if (existing != null) {
      await _database.transaction(() async {
        await _writeAssignment(existing, deletedAt: null);
      });
    } else {
      await _database.transaction(() async {
        await _database.customStatement(
          '''
          INSERT INTO tag_assignments(
            id, tag_id, target_type, target_id,
            created_at, updated_at, version, deleted_at
          ) VALUES (?, ?, ?, ?, ?, ?, 1, NULL)
          ''',
          <Object?>[
            assignmentId,
            tagId,
            targetType.wireName,
            targetId,
            now.toIso8601String(),
            now.toIso8601String(),
          ],
        );
        await _syncQueue.enqueue(
          entityType: 'tag_assignment',
          entityId: assignmentId,
          operationType: SyncOperationType.upsert,
          payload: _assignmentPayload(
            id: assignmentId,
            tagId: tagId,
            targetType: targetType.wireName,
            targetId: targetId,
            createdAt: now,
            updatedAt: now,
            version: 1,
            deletedAt: null,
          ),
          baseVersion: 0,
        );
      });
    }
    _changes.notify('tag_assignment');
  }

  @override
  Future<void> unassign({
    required String tagId,
    required TagTargetType targetType,
    required String targetId,
  }) async {
    final _AssignmentRow? existing = await _assignmentById(
      _assignmentId(tagId, targetType, targetId),
    );
    if (existing == null || existing.deletedAt != null) return;
    await _database.transaction(() async {
      await _writeAssignment(existing, deletedAt: _clock.nowUtc());
    });
    _changes.notify('tag_assignment');
  }

  @override
  Future<void> deleteAssignmentsForTarget({
    required TagTargetType targetType,
    required String targetId,
  }) async {
    final List<_AssignmentRow> rows = await _activeAssignments(
      targetType: targetType,
      targetId: targetId,
    );
    if (rows.isEmpty) return;
    final DateTime now = _clock.nowUtc();
    await _database.transaction(() async {
      for (final _AssignmentRow row in rows) {
        await _writeAssignment(row, deletedAt: now);
      }
    });
    _changes.notify('tag_assignment');
  }

  Future<List<TagEntity>> _loadTags() async {
    final List<QueryRow> rows = await _database.customSelect('''
      SELECT id, name, normalized_name, color_key,
             created_at, updated_at, version, deleted_at
      FROM tags
      WHERE deleted_at IS NULL
      ORDER BY lower(name), name
      ''').get();
    return rows.map(_mapTag).toList(growable: false);
  }

  Future<_TagRow?> _tagById(String id) async {
    final QueryRow? row = await _database
        .customSelect(
          '''
      SELECT id, name, normalized_name, color_key,
             created_at, updated_at, version, deleted_at
      FROM tags WHERE id = ? LIMIT 1
      ''',
          variables: <Variable<Object>>[Variable<String>(id)],
        )
        .getSingleOrNull();
    return row == null ? null : _TagRow.fromQuery(row);
  }

  Future<_TagRow> _requireTag(String id) async {
    final _TagRow? row = await _tagById(id);
    if (row == null) throw StateError('Etiket bulunamadı: $id');
    return row;
  }

  Future<_AssignmentRow?> _assignmentById(String id) async {
    final QueryRow? row = await _database
        .customSelect(
          '''
      SELECT id, tag_id, target_type, target_id,
             created_at, updated_at, version, deleted_at
      FROM tag_assignments WHERE id = ? LIMIT 1
      ''',
          variables: <Variable<Object>>[Variable<String>(id)],
        )
        .getSingleOrNull();
    return row == null ? null : _AssignmentRow.fromQuery(row);
  }

  Future<List<_AssignmentRow>> _activeAssignments({
    String? tagId,
    TagTargetType? targetType,
    String? targetId,
  }) async {
    final List<String> clauses = <String>['deleted_at IS NULL'];
    final List<Variable<Object>> variables = <Variable<Object>>[];
    if (tagId != null) {
      clauses.add('tag_id = ?');
      variables.add(Variable<String>(tagId));
    }
    if (targetType != null) {
      clauses.add('target_type = ?');
      variables.add(Variable<String>(targetType.wireName));
    }
    if (targetId != null) {
      clauses.add('target_id = ?');
      variables.add(Variable<String>(targetId));
    }
    final List<QueryRow> rows = await _database.customSelect('''
      SELECT id, tag_id, target_type, target_id,
             created_at, updated_at, version, deleted_at
      FROM tag_assignments
      WHERE ${clauses.join(' AND ')}
      ''', variables: variables).get();
    return rows.map(_AssignmentRow.fromQuery).toList(growable: false);
  }

  Future<void> _writeTag(
    _TagRow row, {
    required String name,
    required String normalizedName,
    required String colorKey,
    required DateTime? deletedAt,
  }) async {
    final DateTime now = _clock.nowUtc();
    final int version = row.version + 1;
    await _database.customStatement(
      '''
      UPDATE tags
      SET name = ?, normalized_name = ?, color_key = ?,
          updated_at = ?, version = ?, deleted_at = ?
      WHERE id = ?
      ''',
      <Object?>[
        name,
        normalizedName,
        colorKey,
        now.toIso8601String(),
        version,
        deletedAt?.toIso8601String(),
        row.id,
      ],
    );
    await _syncQueue.enqueue(
      entityType: 'tag',
      entityId: row.id,
      operationType: SyncOperationType.upsert,
      payload: _tagPayload(
        id: row.id,
        name: name,
        normalizedName: normalizedName,
        colorKey: colorKey,
        createdAt: row.createdAt,
        updatedAt: now,
        version: version,
        deletedAt: deletedAt,
      ),
      baseVersion: row.version,
    );
  }

  Future<void> _writeAssignment(
    _AssignmentRow row, {
    required DateTime? deletedAt,
  }) async {
    final DateTime now = _clock.nowUtc();
    final int version = row.version + 1;
    await _database.customStatement(
      '''
      UPDATE tag_assignments
      SET updated_at = ?, version = ?, deleted_at = ?
      WHERE id = ?
      ''',
      <Object?>[
        now.toIso8601String(),
        version,
        deletedAt?.toIso8601String(),
        row.id,
      ],
    );
    await _syncQueue.enqueue(
      entityType: 'tag_assignment',
      entityId: row.id,
      operationType: SyncOperationType.upsert,
      payload: _assignmentPayload(
        id: row.id,
        tagId: row.tagId,
        targetType: row.targetType,
        targetId: row.targetId,
        createdAt: row.createdAt,
        updatedAt: now,
        version: version,
        deletedAt: deletedAt,
      ),
      baseVersion: row.version,
    );
  }

  Future<void> _requireTarget(TagTargetType type, String targetId) async {
    final bool exists;
    switch (type) {
      case TagTargetType.note:
        exists =
            await (_database.select(_database.notes)
                  ..where((t) => t.id.equals(targetId) & t.deletedAt.isNull()))
                .getSingleOrNull() !=
            null;
      case TagTargetType.card:
        exists =
            await (_database.select(_database.cards)
                  ..where((t) => t.id.equals(targetId) & t.deletedAt.isNull()))
                .getSingleOrNull() !=
            null;
    }
    if (!exists) {
      throw StateError(
        'Etiketlenecek içerik bulunamadı: ${type.wireName}/$targetId',
      );
    }
  }

  Stream<T> _watch<T>(Iterable<String> types, Future<T> Function() load) {
    late StreamController<T> controller;
    StreamSubscription<void>? subscription;
    bool loading = false;
    bool pending = false;

    Future<void> emit() async {
      if (loading) {
        pending = true;
        return;
      }
      loading = true;
      do {
        pending = false;
        try {
          controller.add(await load());
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
        }
      } while (pending && !controller.isClosed);
      loading = false;
    }

    controller = StreamController<T>.broadcast(
      onListen: () {
        emit();
        subscription = _changes.watchAny(types).listen((_) => emit());
      },
      onCancel: () async {
        await subscription?.cancel();
        subscription = null;
      },
    );
    return controller.stream;
  }

  TagEntity _mapTag(QueryRow row) => TagEntity(
    id: row.read<String>('id'),
    name: row.read<String>('name'),
    normalizedName: row.read<String>('normalized_name'),
    colorKey: row.read<String>('color_key'),
    createdAt: DateTime.parse(row.read<String>('created_at')).toUtc(),
    updatedAt: DateTime.parse(row.read<String>('updated_at')).toUtc(),
    version: row.read<int>('version'),
    deletedAt: _date(row.readNullable<String>('deleted_at')),
  );

  Map<String, Object?> _tagPayload({
    required String id,
    required String name,
    required String normalizedName,
    required String colorKey,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int version,
    required DateTime? deletedAt,
  }) => <String, Object?>{
    'id': id,
    'name': name,
    'normalizedName': normalizedName,
    'colorKey': colorKey,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'version': version,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  Map<String, Object?> _assignmentPayload({
    required String id,
    required String tagId,
    required String targetType,
    required String targetId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int version,
    required DateTime? deletedAt,
  }) => <String, Object?>{
    'id': id,
    'tagId': tagId,
    'targetType': targetType,
    'targetId': targetId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'version': version,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  String _tagId(String normalizedName) {
    final String digest = sha256
        .convert(utf8.encode(normalizedName))
        .toString();
    return 'tag-${digest.substring(0, 32)}';
  }

  String _assignmentId(
    String tagId,
    TagTargetType targetType,
    String targetId,
  ) => 'ta-${tagId.substring(4)}-${targetType.wireName}-$targetId';

  String _validatedColor(String value) {
    final String normalized = value.trim().toLowerCase();
    return supportedColorKeys.contains(normalized) ? normalized : 'indigo';
  }

  String _cleanName(String value) => value
      .trim()
      .replaceFirst(RegExp(r'^#+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String normalizeName(String value) => value
      .trim()
      .replaceFirst(RegExp(r'^#+'), '')
      .toLowerCase()
      .replaceAll('\u0307', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  DateTime? _date(String? value) =>
      value == null ? null : DateTime.tryParse(value)?.toUtc();
}

final class _TagRow {
  const _TagRow({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.colorKey,
    required this.createdAt,
    required this.version,
    required this.deletedAt,
  });

  factory _TagRow.fromQuery(QueryRow row) => _TagRow(
    id: row.read<String>('id'),
    name: row.read<String>('name'),
    normalizedName: row.read<String>('normalized_name'),
    colorKey: row.read<String>('color_key'),
    createdAt: DateTime.parse(row.read<String>('created_at')).toUtc(),
    version: row.read<int>('version'),
    deletedAt: row.readNullable<String>('deleted_at') == null
        ? null
        : DateTime.tryParse(row.read<String>('deleted_at'))?.toUtc(),
  );

  final String id;
  final String name;
  final String normalizedName;
  final String colorKey;
  final DateTime createdAt;
  final int version;
  final DateTime? deletedAt;
}

final class _AssignmentRow {
  const _AssignmentRow({
    required this.id,
    required this.tagId,
    required this.targetType,
    required this.targetId,
    required this.createdAt,
    required this.version,
    required this.deletedAt,
  });

  factory _AssignmentRow.fromQuery(QueryRow row) => _AssignmentRow(
    id: row.read<String>('id'),
    tagId: row.read<String>('tag_id'),
    targetType: row.read<String>('target_type'),
    targetId: row.read<String>('target_id'),
    createdAt: DateTime.parse(row.read<String>('created_at')).toUtc(),
    version: row.read<int>('version'),
    deletedAt: row.readNullable<String>('deleted_at') == null
        ? null
        : DateTime.tryParse(row.read<String>('deleted_at'))?.toUtc(),
  );

  final String id;
  final String tagId;
  final String targetType;
  final String targetId;
  final DateTime createdAt;
  final int version;
  final DateTime? deletedAt;
}
