import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/features/kanban/domain/entities/board_column.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_snapshot.dart';
import 'package:not_app/features/kanban/presentation/screens/card_detail_screen.dart';

class KanbanBoardScreen extends ConsumerWidget {
  const KanbanBoardScreen({super.key, required this.boardId});
  final String boardId;

  Future<void> _addColumn(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final String? title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni kolon'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Kolon adı'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title != null && title.isNotEmpty)
      await ref
          .read(kanbanRepositoryProvider)
          .createColumn(boardId: boardId, title: title);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(kanbanRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pano'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => _addColumn(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Kolon'),
          ),
        ],
      ),
      body: StreamBuilder<KanbanSnapshot?>(
        stream: repo.watchBoard(boardId),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text(snapshot.error.toString()));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final KanbanSnapshot? data = snapshot.data;
          if (data == null)
            return const Center(child: Text('Pano bulunamadı.'));
          if (data.columns.isEmpty) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => _addColumn(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('İlk kolonu ekle'),
              ),
            );
          }
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    data.board.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
              Expanded(
                child: Scrollbar(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: data.columns.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, columnIndex) {
                      final column = data.columns[columnIndex];
                      return SizedBox(
                        width: 320,
                        child: _KanbanColumn(
                          snapshot: data,
                          column: column,
                          columnIndex: columnIndex,
                          cards:
                              data.cardsByColumn[column.id] ??
                              const <KanbanCard>[],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CardDragData {
  const _CardDragData(this.card);
  final KanbanCard card;
}

class _KanbanColumn extends ConsumerWidget {
  const _KanbanColumn({
    required this.snapshot,
    required this.column,
    required this.columnIndex,
    required this.cards,
  });
  final KanbanSnapshot snapshot;
  final BoardColumnEntity column;
  final int columnIndex;
  final List<KanbanCard> cards;

  Future<void> _newCard(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final String? title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${column.title} — yeni kart'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Kart başlığı'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title != null && title.isNotEmpty) {
      await ref
          .read(kanbanRepositoryProvider)
          .createCard(
            boardId: column.boardId,
            columnId: column.id,
            title: title,
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${column.title}  ${cards.length}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _ColumnMenu(
                  snapshot: snapshot,
                  column: column,
                  columnIndex: columnIndex,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: cards.length * 2 + 1,
              itemBuilder: (context, rawIndex) {
                if (rawIndex.isEven) {
                  final int destination = rawIndex ~/ 2;
                  return _DropZone(
                    onDrop: (drag) => ref
                        .read(kanbanRepositoryProvider)
                        .moveCard(
                          cardId: drag.card.id,
                          destinationColumnId: column.id,
                          destinationIndex: destination,
                        ),
                  );
                }
                final int cardIndex = rawIndex ~/ 2;
                final KanbanCard card = cards[cardIndex];
                return LongPressDraggable<_CardDragData>(
                  data: _CardDragData(card),
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: 292,
                      child: _CardTile(card: card, feedback: true),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.25,
                    child: _CardTile(card: card),
                  ),
                  child: _CardTile(card: card),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _newCard(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Kart ekle'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({required this.onDrop});
  final ValueChanged<_CardDragData> onDrop;
  @override
  Widget build(BuildContext context) => DragTarget<_CardDragData>(
    onAcceptWithDetails: (details) => onDrop(details.data),
    builder: (context, candidates, rejects) => AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: candidates.isEmpty ? 8 : 38,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: candidates.isEmpty
            ? Colors.transparent
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: candidates.isEmpty
          ? null
          : const Center(child: Text('Buraya taşı')),
    ),
  );
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, this.feedback = false});
  final KanbanCard card;
  final bool feedback;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 3),
    child: InkWell(
      onTap: feedback
          ? null
          : () => AppRouter.push<void>(
              context,
              CardDetailScreen(cardId: card.id),
            ),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(card.title, style: Theme.of(context).textTheme.titleMedium),
            if (card.description?.trim().isNotEmpty == true) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                card.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ColumnMenu extends ConsumerWidget {
  const _ColumnMenu({
    required this.snapshot,
    required this.column,
    required this.columnIndex,
  });
  final KanbanSnapshot snapshot;
  final BoardColumnEntity column;
  final int columnIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    onSelected: (value) async {
      final repo = ref.read(kanbanRepositoryProvider);
      if (value == 'left' && columnIndex > 0)
        await repo.reorderColumn(
          columnId: column.id,
          destinationIndex: columnIndex - 1,
        );
      if (value == 'right' && columnIndex < snapshot.columns.length - 1)
        await repo.reorderColumn(
          columnId: column.id,
          destinationIndex: columnIndex + 1,
        );
      if (value == 'rename') {
        final controller = TextEditingController(text: column.title);
        final String? title = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Kolonu yeniden adlandır'),
            content: TextField(controller: controller, autofocus: true),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Kaydet'),
              ),
            ],
          ),
        );
        controller.dispose();
        if (title != null && title.isNotEmpty)
          await repo.renameColumn(column.id, title);
      }
      if (value == 'delete') {
        final List<KanbanCard> cards =
            snapshot.cardsByColumn[column.id] ?? const <KanbanCard>[];
        String? destination;
        if (cards.isNotEmpty) {
          final candidates = snapshot.columns
              .where((item) => item.id != column.id)
              .toList();
          if (candidates.isEmpty) {
            if (context.mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Kart bulunan tek kolon silinemez. Önce başka bir kolon ekleyin.',
                  ),
                ),
              );
            return;
          }
          destination = await showDialog<String>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('Kartlar hangi kolona taşınsın?'),
              children: candidates
                  .map(
                    (item) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, item.id),
                      child: Text(item.title),
                    ),
                  )
                  .toList(),
            ),
          );
          if (destination == null) return;
        }
        await repo.deleteColumn(column.id, moveCardsToColumnId: destination);
      }
    },
    itemBuilder: (_) => <PopupMenuEntry<String>>[
      const PopupMenuItem(value: 'rename', child: Text('Yeniden adlandır')),
      PopupMenuItem(
        value: 'left',
        enabled: columnIndex > 0,
        child: const Text('Sola taşı'),
      ),
      PopupMenuItem(
        value: 'right',
        enabled: columnIndex < snapshot.columns.length - 1,
        child: const Text('Sağa taşı'),
      ),
      const PopupMenuItem(value: 'delete', child: Text('Kolonu sil')),
    ],
  );
}
