import 'package:not_app/features/attachments/domain/repositories/attachments_repository.dart';
import 'package:not_app/features/kanban/domain/entities/board.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_snapshot.dart';
import 'package:not_app/features/kanban/domain/repositories/kanban_repository.dart';
import 'package:not_app/features/reminders/domain/repositories/reminders_repository.dart';
import 'package:not_app/features/tags/domain/entities/tag.dart';
import 'package:not_app/features/tags/domain/repositories/tags_repository.dart';

final class LifecycleKanbanRepository implements KanbanRepository {
  LifecycleKanbanRepository({
    required this.delegate,
    required this.attachments,
    required this.reminders,
    required this.tags,
  });

  final KanbanRepository delegate;
  final AttachmentsRepository attachments;
  final RemindersRepository reminders;
  final TagsRepository tags;

  @override
  Stream<List<BoardEntity>> watchBoards() => delegate.watchBoards();

  @override
  Stream<KanbanSnapshot?> watchBoard(String boardId) =>
      delegate.watchBoard(boardId);

  @override
  Stream<KanbanCard?> watchCard(String cardId) => delegate.watchCard(cardId);

  @override
  Future<String> createBoard({required String title, String? colorHex}) =>
      delegate.createBoard(title: title, colorHex: colorHex);

  @override
  Future<void> renameBoard(String boardId, String title) =>
      delegate.renameBoard(boardId, title);

  @override
  Future<void> deleteBoard(String boardId) async {
    final KanbanSnapshot? snapshot = await delegate.watchBoard(boardId).first;
    if (snapshot != null) {
      final List<KanbanCard> cards = snapshot.cardsByColumn.values
          .expand((items) => items)
          .toList(growable: false);
      for (final KanbanCard card in cards) {
        await _deleteChildren('card', card.id);
      }
    }
    await delegate.deleteBoard(boardId);
  }

  @override
  Future<String> createColumn({
    required String boardId,
    required String title,
    String? colorHex,
  }) => delegate.createColumn(
    boardId: boardId,
    title: title,
    colorHex: colorHex,
  );

  @override
  Future<void> renameColumn(String columnId, String title) =>
      delegate.renameColumn(columnId, title);

  @override
  Future<void> reorderColumn({
    required String columnId,
    required int destinationIndex,
  }) => delegate.reorderColumn(
    columnId: columnId,
    destinationIndex: destinationIndex,
  );

  @override
  Future<void> deleteColumn(
    String columnId, {
    String? moveCardsToColumnId,
  }) async {
    if (moveCardsToColumnId == null) {
      final List<BoardEntity> boards = await delegate.watchBoards().first;
      for (final BoardEntity board in boards) {
        final KanbanSnapshot? snapshot = await delegate.watchBoard(board.id).first;
        if (snapshot == null ||
            !snapshot.columns.any((column) => column.id == columnId)) {
          continue;
        }
        final List<KanbanCard> cards =
            snapshot.cardsByColumn[columnId] ?? const <KanbanCard>[];
        for (final KanbanCard card in cards) {
          await _deleteChildren('card', card.id);
        }
        break;
      }
    }
    await delegate.deleteColumn(
      columnId,
      moveCardsToColumnId: moveCardsToColumnId,
    );
  }

  @override
  Future<String> createCard({
    required String boardId,
    required String columnId,
    required String title,
    String? description,
  }) => delegate.createCard(
    boardId: boardId,
    columnId: columnId,
    title: title,
    description: description,
  );

  @override
  Future<void> updateCard({
    required String cardId,
    required String title,
    String? description,
  }) => delegate.updateCard(
    cardId: cardId,
    title: title,
    description: description,
  );

  @override
  Future<void> moveCard({
    required String cardId,
    required String destinationColumnId,
    required int destinationIndex,
  }) => delegate.moveCard(
    cardId: cardId,
    destinationColumnId: destinationColumnId,
    destinationIndex: destinationIndex,
  );

  @override
  Future<void> deleteCard(String cardId) async {
    await _deleteChildren('card', cardId);
    await delegate.deleteCard(cardId);
  }

  Future<void> _deleteChildren(String parentType, String parentId) async {
    final attachmentRows = await attachments
        .watchForParent(parentType, parentId)
        .first;
    for (final attachment in attachmentRows) {
      await attachments.remove(attachment.id);
    }
    final reminderRows = await reminders.watchForParent(parentType, parentId).first;
    for (final reminder in reminderRows) {
      await reminders.remove(reminder.id);
    }
    if (parentType == 'card') {
      await tags.deleteAssignmentsForTarget(
        targetType: TagTargetType.card,
        targetId: parentId,
      );
    }
  }
}
