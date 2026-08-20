// ignore_for_file: prefer_initializing_formals, close_sinks

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/events/entity_change_bus.dart';
import 'package:not_app/core/sync/sync_models.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/core/utils/fractional_indexing_helper.dart';
import 'package:not_app/features/smart_views/domain/entities/content_filter.dart';
import 'package:not_app/features/smart_views/domain/entities/smart_view.dart';
import 'package:not_app/features/smart_views/domain/entities/smart_view_result.dart';
import 'package:not_app/features/smart_views/domain/repositories/smart_views_repository.dart';
import 'package:uuid/uuid.dart';

final class DriftSmartViewsRepository implements SmartViewsRepository {
  DriftSmartViewsRepository({
    required AppDatabase database,
    required SyncQueueRepository syncQueue,
    required AppClock clock,
    required EntityChangeBus changes,
    Uuid? uuid,
  }) : _database = database,
       _syncQueue = syncQueue,
       _clock = clock,
       _changes = changes,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final SyncQueueRepository _syncQueue;
  final AppClock _clock;
  final EntityChangeBus _changes;
  final Uuid _uuid;

  @override
  Stream<List<SmartViewEntity>> watchViews() =>
      _watchCustom<List<SmartViewEntity>>(const <String>{
        'smart_view',
      }, _loadViews);

  @override
  Stream<List<SmartViewResult>> watchResults(ContentFilter filter) {
    late StreamController<List<SmartViewResult>> controller;
    final List<StreamSubscription<dynamic>> subscriptions =
        <StreamSubscription<dynamic>>[];
    bool loading = false;
    bool reloadRequested = false;

    Future<void> emit() async {
      if (loading) {
        reloadRequested = true;
        return;
      }
      loading = true;
      do {
        reloadRequested = false;
        try {
          controller.add(await query(filter));
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
        }
      } while (reloadRequested && !controller.isClosed);
      loading = false;
    }

    controller = StreamController<List<SmartViewResult>>.broadcast(
      onListen: () {
        emit();
        subscriptions.add(
          _changes
              .watchAny(const <String>{'tag', 'tag_assignment'})
              .listen((_) => emit()),
        );
        subscriptions.add(
          _database
              .customSelect(
                'SELECT 1',
                readsFrom: {
                  _database.notes,
                  _database.cards,
                  _database.attachments,
                  _database.reminders,
                },
              )
              .watch()
              .listen((_) => emit()),
        );
      },
      onCancel: () async {
        for (final StreamSubscription<dynamic> subscription in subscriptions) {
          await subscription.cancel();
        }
        subscriptions.clear();
      },
    );
    return controller.stream;
  }

  @override
  Future<List<SmartViewResult>> query(ContentFilter filter) async {
    final StringBuffer sql = StringBuffer('''
      WITH content AS (
        SELECT
          'note' AS entity_type,
          n.id AS entity_id,
          n.title AS title,
          n.content_json AS raw_body,
          n.updated_at AS updated_at,
          NULL AS board_id,
          NULL AS column_id,
          n.is_favorite AS is_favorite
        FROM notes n
        WHERE n.deleted_at IS NULL

        UNION ALL

        SELECT
          'card' AS entity_type,
          c.id AS entity_id,
          c.title AS title,
          COALESCE(c.description, '') AS raw_body,
          c.updated_at AS updated_at,
          c.board_id AS board_id,
          c.column_id AS column_id,
          0 AS is_favorite
        FROM cards c
        WHERE c.deleted_at IS NULL
      )
      SELECT
        content.entity_type,
        content.entity_id,
        content.title,
        content.raw_body,
        content.updated_at,
        content.board_id,
        content.column_id,
        content.is_favorite,
        EXISTS(
          SELECT 1 FROM reminders r
          WHERE r.parent_type = content.entity_type
            AND r.parent_id = content.entity_id
            AND r.deleted_at IS NULL
        ) AS has_reminder,
        EXISTS(
          SELECT 1 FROM attachments a
          WHERE a.parent_type = content.entity_type
            AND a.parent_id = content.entity_id
            AND a.deleted_at IS NULL
        ) AS has_attachment
      FROM content
      WHERE 1 = 1
    ''');
    final List<Variable<Object>> variables = <Variable<Object>>[];

    switch (filter.scope) {
      case ContentScope.notes:
        sql.write(" AND content.entity_type = 'note'");
      case ContentScope.cards:
        sql.write(" AND content.entity_type = 'card'");
      case ContentScope.all:
        break;
    }

    final String? textQuery = filter.textQuery?.trim();
    if (textQuery != null && textQuery.isNotEmpty) {
      final String expression = _ftsExpression(textQuery);
      if (expression.isNotEmpty) {
        sql.write('''
          AND EXISTS (
            SELECT 1 FROM search_fts s
            WHERE s.entity_type = content.entity_type
              AND s.entity_id = content.entity_id
              AND search_fts MATCH ?
          )
        ''');
        variables.add(Variable<String>(expression));
      }
    }

    if (filter.favorite != null) {
      sql.write(
        " AND content.entity_type = 'note' AND content.is_favorite = ?",
      );
      variables.add(Variable<int>(filter.favorite! ? 1 : 0));
    }
    if (filter.boardId != null) {
      sql.write(" AND content.entity_type = 'card' AND content.board_id = ?");
      variables.add(Variable<String>(filter.boardId!));
    }
    if (filter.columnId != null) {
      sql.write(" AND content.entity_type = 'card' AND content.column_id = ?");
      variables.add(Variable<String>(filter.columnId!));
    }
    if (filter.updatedWithinDays != null && filter.updatedWithinDays! > 0) {
      final DateTime cutoff = _clock.nowUtc().subtract(
        Duration(days: filter.updatedWithinDays!),
      );
      sql.write(' AND content.updated_at >= ?');
      variables.add(Variable<DateTime>(cutoff));
    }

    _appendTagFilters(sql, variables, filter);
    _appendPresenceFilter(
      sql,
      table: 'reminders',
      alias: 'r_filter',
      value: filter.hasReminder,
    );
    _appendPresenceFilter(
      sql,
      table: 'attachments',
      alias: 'a_filter',
      value: filter.hasAttachment,
    );

    final String sortColumn = switch (filter.sortField) {
      ContentSortField.updatedAt => 'content.updated_at',
      ContentSortField.title => 'lower(content.title)',
    };
    final String direction = switch (filter.sortDirection) {
      ContentSortDirection.ascending => 'ASC',
      ContentSortDirection.descending => 'DESC',
    };
    sql.write(' ORDER BY $sortColumn $direction, content.entity_id ASC');

    final List<QueryRow> rows = await _database
        .customSelect(sql.toString(), variables: variables)
        .get();
    return rows.map(_mapResult).toList(growable: false);
  }

  @override
  Future<String> createView({
    required String name,
    required ContentFilter filter,
    String iconKey = 'filter_alt',
  }) async {
    final String cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Görünüm adı boş olamaz.');
    }
    final QueryRow? last = await _database.customSelect('''
      SELECT rank_key FROM smart_views
      WHERE deleted_at IS NULL
      ORDER BY rank_key DESC
      LIMIT 1
      ''').getSingleOrNull();
    final String rank = FractionalIndexing.between(
      last?.read<String>('rank_key'),
      null,
    );
    final String id = _uuid.v7();
    final DateTime now = _clock.nowUtc();
    final String queryJson = filter.encode();
    final String normalizedIcon = iconKey.trim().isEmpty
        ? 'filter_alt'
        : iconKey.trim();
    await _database.transaction(() async {
      await _database.customStatement(
        '''
        INSERT INTO smart_views(
          id, name, icon_key, rank_key, query_json,
          created_at, updated_at, version, deleted_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 1, NULL)
        ''',
        <Object?>[
          id,
          cleanName,
          normalizedIcon,
          rank,
          queryJson,
          now.toIso8601String(),
          now.toIso8601String(),
        ],
      );
      await _syncQueue.enqueue(
        entityType: 'smart_view',
        entityId: id,
        operationType: SyncOperationType.upsert,
        payload: _payload(
          id: id,
          name: cleanName,
          iconKey: normalizedIcon,
          rankKey: rank,
          queryJson: queryJson,
          createdAt: now,
          updatedAt: now,
          version: 1,
          deletedAt: null,
        ),
        baseVersion: 0,
      );
    });
    _changes.notify('smart_view');
    return id;
  }

  @override
  Future<void> updateView({
    required String viewId,
    required String name,
    required ContentFilter filter,
    String? iconKey,
  }) async {
    final _SmartViewRow row = await _require(viewId);
    final String cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Görünüm adı boş olamaz.');
    }
    final DateTime now = _clock.nowUtc();
    final int nextVersion = row.version + 1;
    final String nextIcon = iconKey?.trim().isNotEmpty == true
        ? iconKey!.trim()
        : row.iconKey;
    final String queryJson = filter.encode();
    await _database.transaction(() async {
      await _database.customStatement(
        '''
        UPDATE smart_views
        SET name = ?, icon_key = ?, query_json = ?,
            updated_at = ?, version = ?
        WHERE id = ?
        ''',
        <Object?>[
          cleanName,
          nextIcon,
          queryJson,
          now.toIso8601String(),
          nextVersion,
          viewId,
        ],
      );
      await _syncQueue.enqueue(
        entityType: 'smart_view',
        entityId: viewId,
        operationType: SyncOperationType.upsert,
        payload: _payload(
          id: viewId,
          name: cleanName,
          iconKey: nextIcon,
          rankKey: row.rankKey,
          queryJson: queryJson,
          createdAt: row.createdAt,
          updatedAt: now,
          version: nextVersion,
          deletedAt: row.deletedAt,
        ),
        baseVersion: row.version,
      );
    });
    _changes.notify('smart_view');
  }

  @override
  Future<void> deleteView(String viewId) async {
    final _SmartViewRow row = await _require(viewId);
    if (row.deletedAt != null) return;
    final DateTime now = _clock.nowUtc();
    final int nextVersion = row.version + 1;
    await _database.transaction(() async {
      await _database.customStatement(
        '''
        UPDATE smart_views
        SET updated_at = ?, version = ?, deleted_at = ?
        WHERE id = ?
        ''',
        <Object?>[
          now.toIso8601String(),
          nextVersion,
          now.toIso8601String(),
          viewId,
        ],
      );
      await _syncQueue.enqueue(
        entityType: 'smart_view',
        entityId: viewId,
        operationType: SyncOperationType.upsert,
        payload: _payload(
          id: viewId,
          name: row.name,
          iconKey: row.iconKey,
          rankKey: row.rankKey,
          queryJson: row.queryJson,
          createdAt: row.createdAt,
          updatedAt: now,
          version: nextVersion,
          deletedAt: now,
        ),
        baseVersion: row.version,
      );
    });
    _changes.notify('smart_view');
  }

  void _appendTagFilters(
    StringBuffer sql,
    List<Variable<Object>> variables,
    ContentFilter filter,
  ) {
    if (filter.hasTags != null) {
      sql.write(filter.hasTags! ? ' AND EXISTS (' : ' AND NOT EXISTS (');
      sql.write('''
        SELECT 1
        FROM tag_assignments ta_presence
        INNER JOIN tags t_presence ON t_presence.id = ta_presence.tag_id
        WHERE ta_presence.target_type = content.entity_type
          AND ta_presence.target_id = content.entity_id
          AND ta_presence.deleted_at IS NULL
          AND t_presence.deleted_at IS NULL
      )
      ''');
    }

    for (final String tagId in filter.allTagIds) {
      sql.write('''
        AND EXISTS (
          SELECT 1
          FROM tag_assignments ta_all
          INNER JOIN tags t_all ON t_all.id = ta_all.tag_id
          WHERE ta_all.target_type = content.entity_type
            AND ta_all.target_id = content.entity_id
            AND ta_all.tag_id = ?
            AND ta_all.deleted_at IS NULL
            AND t_all.deleted_at IS NULL
        )
      ''');
      variables.add(Variable<String>(tagId));
    }

    if (filter.anyTagIds.isNotEmpty) {
      sql.write('''
        AND EXISTS (
          SELECT 1
          FROM tag_assignments ta_any
          INNER JOIN tags t_any ON t_any.id = ta_any.tag_id
          WHERE ta_any.target_type = content.entity_type
            AND ta_any.target_id = content.entity_id
            AND ta_any.tag_id IN (${_placeholders(filter.anyTagIds.length)})
            AND ta_any.deleted_at IS NULL
            AND t_any.deleted_at IS NULL
        )
      ''');
      variables.addAll(filter.anyTagIds.map(Variable<String>.new));
    }

    if (filter.noneTagIds.isNotEmpty) {
      sql.write('''
        AND NOT EXISTS (
          SELECT 1
          FROM tag_assignments ta_none
          INNER JOIN tags t_none ON t_none.id = ta_none.tag_id
          WHERE ta_none.target_type = content.entity_type
            AND ta_none.target_id = content.entity_id
            AND ta_none.tag_id IN (${_placeholders(filter.noneTagIds.length)})
            AND ta_none.deleted_at IS NULL
            AND t_none.deleted_at IS NULL
        )
      ''');
      variables.addAll(filter.noneTagIds.map(Variable<String>.new));
    }
  }

  void _appendPresenceFilter(
    StringBuffer sql, {
    required String table,
    required String alias,
    required bool? value,
  }) {
    if (value == null) return;
    sql.write(value ? ' AND EXISTS (' : ' AND NOT EXISTS (');
    sql.write('''
      SELECT 1 FROM $table $alias
      WHERE $alias.parent_type = content.entity_type
        AND $alias.parent_id = content.entity_id
        AND $alias.deleted_at IS NULL
    )
    ''');
  }

  Future<List<SmartViewEntity>> _loadViews() async {
    final List<QueryRow> rows = await _database.customSelect('''
      SELECT id, name, icon_key, rank_key, query_json,
             created_at, updated_at, version, deleted_at
      FROM smart_views
      WHERE deleted_at IS NULL
      ORDER BY rank_key ASC
      ''').get();
    return rows.map(_mapView).toList(growable: false);
  }

  Stream<T> _watchCustom<T>(
    Iterable<String> entityTypes,
    Future<T> Function() load,
  ) {
    late StreamController<T> controller;
    StreamSubscription<void>? subscription;
    Future<void> emit() async {
      try {
        controller.add(await load());
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<T>.broadcast(
      onListen: () {
        emit();
        subscription = _changes.watchAny(entityTypes).listen((_) => emit());
      },
      onCancel: () async {
        await subscription?.cancel();
        subscription = null;
      },
    );
    return controller.stream;
  }

  Future<_SmartViewRow> _require(String viewId) async {
    final QueryRow? row = await _database
        .customSelect(
          '''
      SELECT id, name, icon_key, rank_key, query_json,
             created_at, updated_at, version, deleted_at
      FROM smart_views WHERE id = ? LIMIT 1
      ''',
          variables: <Variable<Object>>[Variable<String>(viewId)],
        )
        .getSingleOrNull();
    if (row == null) throw StateError('Akıllı görünüm bulunamadı: $viewId');
    return _SmartViewRow.fromQuery(row);
  }

  SmartViewEntity _mapView(QueryRow row) => SmartViewEntity(
    id: row.read<String>('id'),
    name: row.read<String>('name'),
    iconKey: row.read<String>('icon_key'),
    rankKey: row.read<String>('rank_key'),
    filter: ContentFilter.decode(row.read<String>('query_json')),
    createdAt: DateTime.parse(row.read<String>('created_at')).toUtc(),
    updatedAt: DateTime.parse(row.read<String>('updated_at')).toUtc(),
    version: row.read<int>('version'),
    deletedAt: _parseDate(row.readNullable<String>('deleted_at')),
  );

  SmartViewResult _mapResult(QueryRow row) {
    final String entityType = row.read<String>('entity_type');
    final String rawBody = row.read<String>('raw_body');
    return SmartViewResult(
      entityType: entityType,
      entityId: row.read<String>('entity_id'),
      title: row.read<String>('title'),
      preview: entityType == 'note' ? _notePlainText(rawBody) : rawBody,
      updatedAt: _readSqliteDate(row, 'updated_at'),
      boardId: row.readNullable<String>('board_id'),
      columnId: row.readNullable<String>('column_id'),
      isFavorite: row.read<int>('is_favorite') != 0,
      hasReminder: row.read<int>('has_reminder') != 0,
      hasAttachment: row.read<int>('has_attachment') != 0,
    );
  }

  Map<String, Object?> _payload({
    required String id,
    required String name,
    required String iconKey,
    required String rankKey,
    required String queryJson,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int version,
    required DateTime? deletedAt,
  }) => <String, Object?>{
    'id': id,
    'name': name,
    'iconKey': iconKey,
    'rankKey': rankKey,
    'queryJson': queryJson,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'version': version,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  String _ftsExpression(String query) => query
      .split(RegExp(r'\s+'))
      .where((String token) => token.trim().isNotEmpty)
      .map((String token) => '"${token.replaceAll('"', '""')}"*')
      .join(' AND ');

  String _notePlainText(String contentJson) {
    try {
      final Object? decoded = jsonDecode(contentJson);
      if (decoded is! Map<Object?, Object?>) return '';
      final Object? blocks = decoded['blocks'];
      if (blocks is! List<Object?>) return '';
      return blocks
          .whereType<Map<Object?, Object?>>()
          .map(
            (Map<Object?, Object?> block) =>
                (block['text'] ?? block['url'] ?? '').toString(),
          )
          .where((String text) => text.isNotEmpty)
          .join('\n');
    } catch (_) {
      return '';
    }
  }

  DateTime _readSqliteDate(QueryRow row, String column) {
    try {
      final int raw = row.read<int>(column);
      if (raw.abs() > 100000000000) {
        return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
      }
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true);
    } catch (_) {
      final String raw = row.read<String>(column);
      return DateTime.tryParse(raw)?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
  }

  String _placeholders(int count) => List<String>.filled(count, '?').join(', ');

  DateTime? _parseDate(String? value) =>
      value == null ? null : DateTime.tryParse(value)?.toUtc();
}

final class _SmartViewRow {
  const _SmartViewRow({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.rankKey,
    required this.queryJson,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.deletedAt,
  });

  factory _SmartViewRow.fromQuery(QueryRow row) => _SmartViewRow(
    id: row.read<String>('id'),
    name: row.read<String>('name'),
    iconKey: row.read<String>('icon_key'),
    rankKey: row.read<String>('rank_key'),
    queryJson: row.read<String>('query_json'),
    createdAt: DateTime.parse(row.read<String>('created_at')).toUtc(),
    updatedAt: DateTime.parse(row.read<String>('updated_at')).toUtc(),
    version: row.read<int>('version'),
    deletedAt: row.readNullable<String>('deleted_at') == null
        ? null
        : DateTime.tryParse(row.read<String>('deleted_at'))?.toUtc(),
  );

  final String id;
  final String name;
  final String iconKey;
  final String rankKey;
  final String queryJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;
}
