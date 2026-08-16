import 'dart:async';

import 'package:drift/drift.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/error/exceptions.dart';
import 'package:not_app/core/sync/sync_models.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/core/utils/fractional_indexing_helper.dart';
import 'package:not_app/features/kanban/domain/entities/board.dart';
import 'package:not_app/features/kanban/domain/entities/board_column.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_snapshot.dart';
import 'package:not_app/features/kanban/domain/repositories/kanban_repository.dart';
import 'package:uuid/uuid.dart';

final class DriftKanbanRepository implements KanbanRepository {
  DriftKanbanRepository({
    required this._database,
    required this._syncQueue,
    required this._clock,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final SyncQueueRepository _syncQueue;
  final AppClock _clock;
  final Uuid _uuid;

  @override
  Stream<List<BoardEntity>> watchBoards() {
    final query = _database.select(_database.boards)
      ..where((tbl) => tbl.deletedAt.isNull())
      ..orderBy(<OrderingTerm Function($BoardsTable)>[
        (tbl) => OrderingTerm.desc(tbl.updatedAt),
      ]);
    return query.watch().map(
      (rows) => rows.map(_mapBoard).toList(growable: false),
    );
  }

  @override
  Stream<KanbanSnapshot?> watchBoard(String boardId) {
    final boardStream =
        (_database.select(_database.boards)
              ..where((tbl) => tbl.id.equals(boardId) & tbl.deletedAt.isNull()))
            .watchSingleOrNull();
    final columnStream =
        (_database.select(_database.boardColumns)
              ..where(
                (tbl) => tbl.boardId.equals(boardId) & tbl.deletedAt.isNull(),
              )
              ..orderBy(<OrderingTerm Function($BoardColumnsTable)>[
                (tbl) => OrderingTerm.asc(tbl.rankKey),
              ]))
            .watch();
    final cardStream =
        (_database.select(_database.cards)
              ..where(
                (tbl) => tbl.boardId.equals(boardId) & tbl.deletedAt.isNull(),
              )
              ..orderBy(<OrderingTerm Function($CardsTable)>[
                (tbl) => OrderingTerm.asc(tbl.rankKey),
              ]))
            .watch();

    return _combine3(boardStream, columnStream, cardStream, (
      board,
      columns,
      cards,
    ) {
      if (board == null) return null;
      final Map<String, List<KanbanCard>> grouped = <String, List<KanbanCard>>{
        for (final BoardColumn column in columns) column.id: <KanbanCard>[],
      };
      for (final Card card in cards) {
        (grouped[card.columnId] ??= <KanbanCard>[]).add(_mapCard(card));
      }
      return KanbanSnapshot(
        board: _mapBoard(board),
        columns: columns.map(_mapColumn).toList(growable: false),
        cardsByColumn: grouped,
      );
    });
  }

  @override
  Stream<KanbanCard?> watchCard(String cardId) {
    return (_database.select(
      _database.cards,
    )..where((tbl) => tbl.id.equals(cardId))).watchSingleOrNull().map(
      (row) => row == null || row.deletedAt != null ? null : _mapCard(row),
    );
  }

  @override
  Future<String> createBoard({required String title, String? colorHex}) async {
    final String cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('Board title cannot be empty.');
    final String id = _uuid.v7();
    final DateTime now = _clock.nowUtc();
    await _database.transaction(() async {
      await _database
          .into(_database.boards)
          .insert(
            BoardsCompanion.insert(
              id: id,
              title: cleanTitle,
              colorHex: Value<String?>(colorHex),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _database.upsertSearchEntry(
        entityType: 'board',
        entityId: id,
        title: cleanTitle,
        body: '',
      );
      await _syncQueue.enqueue(
        entityType: 'board',
        entityId: id,
        operationType: SyncOperationType.upsert,
        payload: _boardPayload(id, cleanTitle, colorHex, now, now, 1, null),
        baseVersion: 0,
      );
    });
    return id;
  }

  @override
  Future<void> renameBoard(String boardId, String title) async {
    final String clean = title.trim();
    if (clean.isEmpty) throw ArgumentError('Board title cannot be empty.');
    final Board row = await _requireBoard(boardId);
    final DateTime now = _clock.nowUtc();
    final int version = row.version + 1;
    await _database.transaction(() async {
      await (_database.update(
        _database.boards,
      )..where((tbl) => tbl.id.equals(boardId))).write(
        BoardsCompanion(
          title: Value<String>(clean),
          updatedAt: Value<DateTime>(now),
          version: Value<int>(version),
        ),
      );
      await _database.upsertSearchEntry(
        entityType: 'board',
        entityId: boardId,
        title: clean,
        body: '',
      );
      await _syncQueue.enqueue(
        entityType: 'board',
        entityId: boardId,
        operationType: SyncOperationType.upsert,
        payload: _boardPayload(
          boardId,
          clean,
          row.colorHex,
          row.createdAt,
          now,
          version,
          row.deletedAt,
        ),
        baseVersion: row.version,
      );
    });
  }

  @override
  Future<void> deleteBoard(String boardId) async {
    final Board board = await _requireBoard(boardId);
    final DateTime now = _clock.nowUtc();
    await _database.transaction(() async {
      final List<BoardColumn> columns =
          await (_database.select(_database.boardColumns)..where(
                (tbl) => tbl.boardId.equals(boardId) & tbl.deletedAt.isNull(),
              ))
              .get();
      final List<Card> cards =
          await (_database.select(_database.cards)..where(
                (tbl) => tbl.boardId.equals(boardId) & tbl.deletedAt.isNull(),
              ))
              .get();
      for (final Card card in cards) {
        await _tombstoneCard(card, now);
      }
      for (final BoardColumn column in columns) {
        await _tombstoneColumn(column, now);
      }
      await (_database.update(
        _database.boards,
      )..where((tbl) => tbl.id.equals(boardId))).write(
        BoardsCompanion(
          deletedAt: Value<DateTime?>(now),
          updatedAt: Value<DateTime>(now),
          version: Value<int>(board.version + 1),
        ),
      );
      await _database.deleteSearchEntry('board', boardId);
      await _syncQueue.enqueue(
        entityType: 'board',
        entityId: boardId,
        operationType: SyncOperationType.delete,
        payload: <String, Object?>{
          'id': boardId,
          'version': board.version + 1,
          'updatedAt': now.toIso8601String(),
          'deletedAt': now.toIso8601String(),
        },
        baseVersion: board.version,
      );
    });
  }

  @override
  Future<String> createColumn({
    required String boardId,
    required String title,
    String? colorHex,
  }) async {
    await _requireBoard(boardId);
    final String clean = title.trim();
    if (clean.isEmpty) throw ArgumentError('Column title cannot be empty.');
    final List<BoardColumn> existing = await _columns(boardId);
    final String rank = await _rankForColumnInsert(
      boardId,
      existing.length,
      existing,
    );
    final String id = _uuid.v7();
    final DateTime now = _clock.nowUtc();
    await _database.transaction(() async {
      await _database
          .into(_database.boardColumns)
          .insert(
            BoardColumnsCompanion.insert(
              id: id,
              boardId: boardId,
              title: clean,
              colorHex: Value<String?>(colorHex),
              rank: const Value<double?>.absent(),
              rankKey: Value<String>(rank),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _syncQueue.enqueue(
        entityType: 'column',
        entityId: id,
        operationType: SyncOperationType.upsert,
        payload: _columnPayload(
          id,
          boardId,
          clean,
          colorHex,
          rank,
          now,
          now,
          1,
          null,
        ),
        baseVersion: 0,
      );
    });
    return id;
  }

  @override
  Future<void> renameColumn(String columnId, String title) async {
    final String clean = title.trim();
    if (clean.isEmpty) throw ArgumentError('Column title cannot be empty.');
    final BoardColumn row = await _requireColumn(columnId);
    final DateTime now = _clock.nowUtc();
    final int version = row.version + 1;
    await _database.transaction(() async {
      await (_database.update(
        _database.boardColumns,
      )..where((tbl) => tbl.id.equals(columnId))).write(
        BoardColumnsCompanion(
          title: Value<String>(clean),
          updatedAt: Value<DateTime>(now),
          version: Value<int>(version),
        ),
      );
      await _syncQueue.enqueue(
        entityType: 'column',
        entityId: columnId,
        operationType: SyncOperationType.upsert,
        payload: _columnPayload(
          row.id,
          row.boardId,
          clean,
          row.colorHex,
          row.rankKey,
          row.createdAt,
          now,
          version,
          row.deletedAt,
        ),
        baseVersion: row.version,
      );
    });
  }

  @override
  Future<void> reorderColumn({
    required String columnId,
    required int destinationIndex,
  }) async {
    final BoardColumn row = await _requireColumn(columnId);
    final List<BoardColumn> columns = await _columns(row.boardId);
    final List<BoardColumn> without = columns
        .where((column) => column.id != columnId)
        .toList();
    final int index = destinationIndex.clamp(0, without.length);
    final String rank = await _rankForColumnInsert(row.boardId, index, without);
    await _writeColumnRank(row, rank);
  }

  @override
  Future<void> deleteColumn(
    String columnId, {
    String? moveCardsToColumnId,
  }) async {
    final BoardColumn row = await _requireColumn(columnId);
    final List<Card> cards = await _cards(columnId);
    if (cards.isNotEmpty && moveCardsToColumnId == null) {
      throw StateError(
        'Column contains cards; choose a destination column before deleting.',
      );
    }
    if (moveCardsToColumnId == columnId) {
      throw ArgumentError(
        'Destination column must be different from deleted column.',
      );
    }
    if (moveCardsToColumnId != null) await _requireColumn(moveCardsToColumnId);
    final DateTime now = _clock.nowUtc();
    await _database.transaction(() async {
      if (moveCardsToColumnId != null) {
        final List<Card> destination = await _cards(moveCardsToColumnId);
        final List<String> ranks = FractionalIndexing.rebalance(
          destination.length + cards.length,
        );
        int rankIndex = 0;
        for (final Card card in destination) {
          if (card.rankKey != ranks[rankIndex]) {
            await _writeCardPosition(
              card,
              moveCardsToColumnId,
              ranks[rankIndex],
            );
          }
          rankIndex++;
        }
        for (final Card card in cards) {
          await _writeCardPosition(card, moveCardsToColumnId, ranks[rankIndex]);
          rankIndex++;
        }
      }
      await _tombstoneColumn(row, now);
    });
  }

  @override
  Future<String> createCard({
    required String boardId,
    required String columnId,
    required String title,
    String? description,
  }) async {
    final BoardColumn column = await _requireColumn(columnId);
    if (column.boardId != boardId) {
      throw StateError('Column does not belong to board.');
    }
    final String clean = title.trim();
    if (clean.isEmpty) throw ArgumentError('Card title cannot be empty.');
    final List<Card> existing = await _cards(columnId);
    final String rank = await _rankForCardInsert(
      columnId,
      existing.length,
      existing,
    );
    final String id = _uuid.v7();
    final DateTime now = _clock.nowUtc();
    await _database.transaction(() async {
      await _database
          .into(_database.cards)
          .insert(
            CardsCompanion.insert(
              id: id,
              boardId: boardId,
              columnId: columnId,
              title: clean,
              description: Value<String?>(_cleanNullable(description)),
              rank: const Value<double?>.absent(),
              rankKey: Value<String>(rank),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _database.upsertSearchEntry(
        entityType: 'card',
        entityId: id,
        title: clean,
        body: description ?? '',
      );
      await _syncQueue.enqueue(
        entityType: 'card',
        entityId: id,
        operationType: SyncOperationType.upsert,
        payload: _cardPayload(
          id,
          boardId,
          columnId,
          clean,
          _cleanNullable(description),
          rank,
          now,
          now,
          1,
          null,
        ),
        baseVersion: 0,
      );
    });
    return id;
  }

  @override
  Future<void> updateCard({
    required String cardId,
    required String title,
    String? description,
  }) async {
    final Card row = await _requireCard(cardId);
    final String clean = title.trim();
    if (clean.isEmpty) throw ArgumentError('Card title cannot be empty.');
    final DateTime now = _clock.nowUtc();
    final int version = row.version + 1;
    final String? cleanDescription = _cleanNullable(description);
    await _database.transaction(() async {
      await (_database.update(
        _database.cards,
      )..where((tbl) => tbl.id.equals(cardId))).write(
        CardsCompanion(
          title: Value<String>(clean),
          description: Value<String?>(cleanDescription),
          updatedAt: Value<DateTime>(now),
          version: Value<int>(version),
        ),
      );
      await _database.upsertSearchEntry(
        entityType: 'card',
        entityId: cardId,
        title: clean,
        body: cleanDescription ?? '',
      );
      await _syncQueue.enqueue(
        entityType: 'card',
        entityId: cardId,
        operationType: SyncOperationType.upsert,
        payload: _cardPayload(
          row.id,
          row.boardId,
          row.columnId,
          clean,
          cleanDescription,
          row.rankKey,
          row.createdAt,
          now,
          version,
          row.deletedAt,
        ),
        baseVersion: row.version,
      );
    });
  }

  @override
  Future<void> moveCard({
    required String cardId,
    required String destinationColumnId,
    required int destinationIndex,
  }) async {
    final Card row = await _requireCard(cardId);
    final BoardColumn destinationColumn = await _requireColumn(
      destinationColumnId,
    );
    if (destinationColumn.boardId != row.boardId) {
      throw StateError('Cards cannot be moved across boards.');
    }
    final List<Card> destination = await _cards(destinationColumnId);
    final List<Card> without = destination
        .where((card) => card.id != cardId)
        .toList();
    final int index = destinationIndex.clamp(0, without.length);
    final String rank = await _rankForCardInsert(
      destinationColumnId,
      index,
      without,
    );
    await _database.transaction(() async {
      await _writeCardPosition(row, destinationColumnId, rank);
    });
  }

  @override
  Future<void> deleteCard(String cardId) async {
    final Card row = await _requireCard(cardId);
    await _database.transaction(() async {
      await _tombstoneCard(row, _clock.nowUtc());
    });
  }

  Future<List<BoardColumn>> _columns(String boardId) {
    return (_database.select(_database.boardColumns)
          ..where((tbl) => tbl.boardId.equals(boardId) & tbl.deletedAt.isNull())
          ..orderBy(<OrderingTerm Function($BoardColumnsTable)>[
            (tbl) => OrderingTerm.asc(tbl.rankKey),
          ]))
        .get();
  }

  Future<List<Card>> _cards(String columnId) {
    return (_database.select(_database.cards)
          ..where(
            (tbl) => tbl.columnId.equals(columnId) & tbl.deletedAt.isNull(),
          )
          ..orderBy(<OrderingTerm Function($CardsTable)>[
            (tbl) => OrderingTerm.asc(tbl.rankKey),
          ]))
        .get();
  }

  Future<String> _rankForColumnInsert(
    String boardId,
    int index,
    List<BoardColumn> ordered,
  ) async {
    try {
      return FractionalIndexing.between(
        index == 0 ? null : ordered[index - 1].rankKey,
        index == ordered.length ? null : ordered[index].rankKey,
      );
    } on RankSpaceExhaustedException {
      await _rebalanceColumns(boardId, ordered);
      final List<BoardColumn> refreshed = await _columns(boardId);
      return FractionalIndexing.between(
        index == 0 ? null : refreshed[index - 1].rankKey,
        index == refreshed.length ? null : refreshed[index].rankKey,
      );
    }
  }

  Future<String> _rankForCardInsert(
    String columnId,
    int index,
    List<Card> ordered,
  ) async {
    try {
      return FractionalIndexing.between(
        index == 0 ? null : ordered[index - 1].rankKey,
        index == ordered.length ? null : ordered[index].rankKey,
      );
    } on RankSpaceExhaustedException {
      await _rebalanceCards(columnId, ordered);
      final List<Card> refreshed = await _cards(columnId);
      return FractionalIndexing.between(
        index == 0 ? null : refreshed[index - 1].rankKey,
        index == refreshed.length ? null : refreshed[index].rankKey,
      );
    }
  }

  Future<void> _rebalanceColumns(
    String boardId,
    List<BoardColumn> ordered,
  ) async {
    final List<String> ranks = FractionalIndexing.rebalance(ordered.length);
    await _database.transaction(() async {
      for (int index = 0; index < ordered.length; index++) {
        if (ordered[index].rankKey != ranks[index]) {
          await _writeColumnRank(ordered[index], ranks[index]);
        }
      }
    });
  }

  Future<void> _rebalanceCards(String columnId, List<Card> ordered) async {
    final List<String> ranks = FractionalIndexing.rebalance(ordered.length);
    await _database.transaction(() async {
      for (int index = 0; index < ordered.length; index++) {
        if (ordered[index].rankKey != ranks[index]) {
          await _writeCardPosition(ordered[index], columnId, ranks[index]);
        }
      }
    });
  }

  Future<void> _writeColumnRank(BoardColumn row, String rank) async {
    final DateTime now = _clock.nowUtc();
    final int version = row.version + 1;
    await (_database.update(
      _database.boardColumns,
    )..where((tbl) => tbl.id.equals(row.id))).write(
      BoardColumnsCompanion(
        rankKey: Value<String>(rank),
        updatedAt: Value<DateTime>(now),
        version: Value<int>(version),
      ),
    );
    await _syncQueue.enqueue(
      entityType: 'column',
      entityId: row.id,
      operationType: SyncOperationType.upsert,
      payload: _columnPayload(
        row.id,
        row.boardId,
        row.title,
        row.colorHex,
        rank,
        row.createdAt,
        now,
        version,
        row.deletedAt,
      ),
      baseVersion: row.version,
    );
  }

  Future<void> _writeCardPosition(
    Card row,
    String columnId,
    String rank,
  ) async {
    final DateTime now = _clock.nowUtc();
    final int version = row.version + 1;
    await (_database.update(
      _database.cards,
    )..where((tbl) => tbl.id.equals(row.id))).write(
      CardsCompanion(
        columnId: Value<String>(columnId),
        rankKey: Value<String>(rank),
        updatedAt: Value<DateTime>(now),
        version: Value<int>(version),
      ),
    );
    await _syncQueue.enqueue(
      entityType: 'card',
      entityId: row.id,
      operationType: SyncOperationType.upsert,
      payload: _cardPayload(
        row.id,
        row.boardId,
        columnId,
        row.title,
        row.description,
        rank,
        row.createdAt,
        now,
        version,
        row.deletedAt,
      ),
      baseVersion: row.version,
    );
  }

  Future<void> _tombstoneCard(Card row, DateTime now) async {
    await (_database.update(
      _database.cards,
    )..where((tbl) => tbl.id.equals(row.id))).write(
      CardsCompanion(
        deletedAt: Value<DateTime?>(now),
        updatedAt: Value<DateTime>(now),
        version: Value<int>(row.version + 1),
      ),
    );
    await _database.deleteSearchEntry('card', row.id);
    await _syncQueue.enqueue(
      entityType: 'card',
      entityId: row.id,
      operationType: SyncOperationType.delete,
      payload: <String, Object?>{
        'id': row.id,
        'version': row.version + 1,
        'updatedAt': now.toIso8601String(),
        'deletedAt': now.toIso8601String(),
      },
      baseVersion: row.version,
    );
  }

  Future<void> _tombstoneColumn(BoardColumn row, DateTime now) async {
    await (_database.update(
      _database.boardColumns,
    )..where((tbl) => tbl.id.equals(row.id))).write(
      BoardColumnsCompanion(
        deletedAt: Value<DateTime?>(now),
        updatedAt: Value<DateTime>(now),
        version: Value<int>(row.version + 1),
      ),
    );
    await _syncQueue.enqueue(
      entityType: 'column',
      entityId: row.id,
      operationType: SyncOperationType.delete,
      payload: <String, Object?>{
        'id': row.id,
        'version': row.version + 1,
        'updatedAt': now.toIso8601String(),
        'deletedAt': now.toIso8601String(),
      },
      baseVersion: row.version,
    );
  }

  Future<Board> _requireBoard(String id) async {
    final Board? row =
        await (_database.select(_database.boards)
              ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
            .getSingleOrNull();
    if (row == null) throw StateError('Board not found: $id');
    return row;
  }

  Future<BoardColumn> _requireColumn(String id) async {
    final BoardColumn? row =
        await (_database.select(_database.boardColumns)
              ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
            .getSingleOrNull();
    if (row == null) throw StateError('Column not found: $id');
    return row;
  }

  Future<Card> _requireCard(String id) async {
    final Card? row =
        await (_database.select(_database.cards)
              ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
            .getSingleOrNull();
    if (row == null) throw StateError('Card not found: $id');
    return row;
  }

  BoardEntity _mapBoard(Board row) => BoardEntity(
    id: row.id,
    title: row.title,
    colorHex: row.colorHex,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    version: row.version,
    deletedAt: row.deletedAt,
  );

  BoardColumnEntity _mapColumn(BoardColumn row) => BoardColumnEntity(
    id: row.id,
    boardId: row.boardId,
    title: row.title,
    colorHex: row.colorHex,
    rankKey: row.rankKey,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    version: row.version,
    deletedAt: row.deletedAt,
  );

  KanbanCard _mapCard(Card row) => KanbanCard(
    id: row.id,
    boardId: row.boardId,
    columnId: row.columnId,
    title: row.title,
    description: row.description,
    rankKey: row.rankKey,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    version: row.version,
    deletedAt: row.deletedAt,
  );

  String? _cleanNullable(String? value) {
    final String? clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  Map<String, Object?> _boardPayload(
    String id,
    String title,
    String? colorHex,
    DateTime createdAt,
    DateTime updatedAt,
    int version,
    DateTime? deletedAt,
  ) => <String, Object?>{
    'id': id,
    'title': title,
    'colorHex': colorHex,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'version': version,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  Map<String, Object?> _columnPayload(
    String id,
    String boardId,
    String title,
    String? colorHex,
    String rankKey,
    DateTime createdAt,
    DateTime updatedAt,
    int version,
    DateTime? deletedAt,
  ) => <String, Object?>{
    'id': id,
    'boardId': boardId,
    'title': title,
    'colorHex': colorHex,
    'rankKey': rankKey,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'version': version,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  Map<String, Object?> _cardPayload(
    String id,
    String boardId,
    String columnId,
    String title,
    String? description,
    String rankKey,
    DateTime createdAt,
    DateTime updatedAt,
    int version,
    DateTime? deletedAt,
  ) => <String, Object?>{
    'id': id,
    'boardId': boardId,
    'columnId': columnId,
    'title': title,
    'description': description,
    'rankKey': rankKey,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'version': version,
    'deletedAt': deletedAt?.toIso8601String(),
  };
}

Stream<R> _combine3<A, B, C, R>(
  Stream<A> a,
  Stream<B> b,
  Stream<C> c,
  R Function(A, B, C) combine,
) {
  late final StreamController<R> controller;
  A? av;
  B? bv;
  C? cv;
  bool hasA = false;
  bool hasB = false;
  bool hasC = false;
  StreamSubscription<A>? sa;
  StreamSubscription<B>? sb;
  StreamSubscription<C>? sc;

  void emit() {
    if (hasA && hasB && hasC) {
      controller.add(combine(av as A, bv as B, cv as C));
    }
  }

  controller = StreamController<R>(
    onListen: () {
      sa = a.listen((value) {
        av = value;
        hasA = true;
        emit();
      }, onError: controller.addError);
      sb = b.listen((value) {
        bv = value;
        hasB = true;
        emit();
      }, onError: controller.addError);
      sc = c.listen((value) {
        cv = value;
        hasC = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await sa?.cancel();
      await sb?.cancel();
      await sc?.cancel();
      if (!controller.isClosed) {
        unawaited(controller.close());
      }
    },
  );
  return controller.stream;
}
