import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/features/kanban/domain/entities/board_column.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_snapshot.dart';
import 'package:not_app/features/kanban/presentation/screens/card_detail_screen.dart';
import 'package:not_app/features/kanban/presentation/widgets/kanban_card_widget.dart';
import 'package:not_app/features/kanban/presentation/widgets/kanban_color.dart';

class KanbanBoardScreen extends ConsumerStatefulWidget {
  const KanbanBoardScreen({super.key, required this.boardId});
  final String boardId;

  static const double kEdgeThreshold = 48.0;

  @override
  ConsumerState<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends ConsumerState<KanbanBoardScreen> {
  final ScrollController _horizontalScrollController = ScrollController();
  final GlobalKey _boardAreaKey = GlobalKey();

  Timer? _autoScrollTimer;
  double _autoScrollDelta = 0.0;
  Stream<KanbanSnapshot?>? _boardStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(covariant KanbanBoardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.boardId != widget.boardId) {
      _initStream();
    }
  }

  void _initStream() {
    _boardStream = ref
        .read(kanbanRepositoryProvider)
        .watchBoard(widget.boardId);
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _onDragUpdate(Offset globalPosition) {
    final RenderBox? box =
        _boardAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final Offset localPos = box.globalToLocal(globalPosition);
    final double width = box.size.width;

    if (localPos.dx < KanbanBoardScreen.kEdgeThreshold) {
      final double clampedDx = localPos.dx.clamp(
        0.0,
        KanbanBoardScreen.kEdgeThreshold,
      );
      final double proximity =
          ((KanbanBoardScreen.kEdgeThreshold - clampedDx) /
                  KanbanBoardScreen.kEdgeThreshold)
              .clamp(0.0, 1.0);
      final double delta = -(8.0 + proximity * 16.0);
      _startAutoScroll(delta);
    } else if (localPos.dx > width - KanbanBoardScreen.kEdgeThreshold) {
      final double clampedDx = localPos.dx.clamp(
        width - KanbanBoardScreen.kEdgeThreshold,
        width,
      );
      final double proximity =
          ((clampedDx - (width - KanbanBoardScreen.kEdgeThreshold)) /
                  KanbanBoardScreen.kEdgeThreshold)
              .clamp(0.0, 1.0);
      final double delta = 8.0 + proximity * 16.0;
      _startAutoScroll(delta);
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll(double delta) {
    _autoScrollDelta = delta;
    if (_autoScrollTimer != null) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (
      timer,
    ) {
      if (!mounted ||
          _autoScrollDelta == 0.0 ||
          !_horizontalScrollController.hasClients) {
        _stopAutoScroll();
        return;
      }
      final position = _horizontalScrollController.position;
      final double currentPixels = position.pixels;
      if (_autoScrollDelta < 0 && currentPixels <= position.minScrollExtent) {
        return;
      }
      if (_autoScrollDelta > 0 && currentPixels >= position.maxScrollExtent) {
        return;
      }
      final double newPixels = (currentPixels + _autoScrollDelta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (newPixels != currentPixels) {
        _horizontalScrollController.jumpTo(newPixels);
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollDelta = 0.0;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _onDragEnd() {
    _stopAutoScroll();
  }

  Future<void> _addColumn(BuildContext context) async {
    final TitleColorValue? value = await showTitleColorDialog(
      context,
      dialogTitle: 'Yeni kolon',
      fieldLabel: 'Kolon adı',
      confirmLabel: 'Ekle',
    );
    if (value != null) {
      await ref
          .read(kanbanRepositoryProvider)
          .createColumn(
            boardId: widget.boardId,
            title: value.title,
            colorHex: value.colorHex,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: const Text('Pano'),
        actionsPadding: const EdgeInsets.only(right: 12),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => _addColumn(context),
            icon: const Icon(Icons.add),
            label: const Text('Kolon'),
          ),
        ],
      ),
      body: StreamBuilder<KanbanSnapshot?>(
        stream: _boardStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final KanbanSnapshot? data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('Pano bulunamadı.'));
          }
          if (data.columns.isEmpty) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => _addColumn(context),
                icon: const Icon(Icons.add),
                label: const Text('İlk kolonu ekle'),
              ),
            );
          }
          final Color? boardColor = colorFromHex(data.board.colorHex);
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (boardColor != null) ...<Widget>[
                        Container(
                          width: 10,
                          height: 28,
                          decoration: BoxDecoration(
                            color: boardColor,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          data.board.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: KeyedSubtree(
                  key: _boardAreaKey,
                  child: Scrollbar(
                    controller: _horizontalScrollController,
                    child: ListView.separated(
                      controller: _horizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: data.columns.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
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
                            onDragUpdate: _onDragUpdate,
                            onDragEnd: _onDragEnd,
                          ),
                        );
                      },
                    ),
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
    required this.onDragUpdate,
    required this.onDragEnd,
  });
  final KanbanSnapshot snapshot;
  final BoardColumnEntity column;
  final int columnIndex;
  final List<KanbanCard> cards;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

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

  Future<void> _changeCardColor(
    BuildContext context,
    WidgetRef ref,
    KanbanCard card,
  ) async {
    final settings = ref.read(settingsRepositoryProvider);
    final String? current = await settings
        .watchEntityColor('card', card.id)
        .first;
    if (!context.mounted) return;
    final ColorPickerValue? value = await showEntityColorDialog(
      context,
      dialogTitle: 'Kart rengini değiştir',
      initialColorHex: current,
      defaultLabel: 'Kolon rengini kullan',
    );
    if (value == null) return;
    await settings.setEntityColor('card', card.id, value.colorHex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool hasPrev = columnIndex > 0;
    final bool hasNext = columnIndex < snapshot.columns.length - 1;
    final settings = ref.watch(settingsRepositoryProvider);

    return StreamBuilder<String?>(
      stream: settings.watchEntityColor('column', column.id),
      builder: (context, colorSnapshot) {
        final Color? columnColor = colorFromHex(
          colorSnapshot.data ?? column.colorHex,
        );
        return Card(
          color: tintedSurface(context, columnColor, opacity: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color:
                  columnColor?.withOpacity(0.38) ?? Theme.of(context).dividerColor,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
                child: Row(
                  children: <Widget>[
                    if (columnColor != null) ...<Widget>[
                      Container(
                        width: 8,
                        height: 24,
                        decoration: BoxDecoration(
                          color: columnColor,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
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
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
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
                    final bool canTop = cardIndex > 0;
                    final bool canBottom = cardIndex < cards.length - 1;

                    return StreamBuilder<String?>(
                      stream: settings.watchEntityColor('card', card.id),
                      builder: (context, cardColorSnapshot) {
                        final Color? selectedCardColor = colorFromHex(
                          cardColorSnapshot.data,
                        );
                        final Color cardSurface = tintedSurface(
                          context,
                          selectedCardColor ?? columnColor,
                          opacity: selectedCardColor == null ? 0.18 : 0.21,
                        );

                        return LongPressDraggable<_CardDragData>(
                          data: _CardDragData(card),
                          onDragUpdate: (details) =>
                              onDragUpdate(details.globalPosition),
                          onDragEnd: (_) => onDragEnd(),
                          onDraggableCanceled: (_, _) => onDragEnd(),
                          onDragCompleted: () => onDragEnd(),
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: 292,
                              child: KanbanCardWidget(
                                card: card,
                                feedback: true,
                                backgroundColor: cardSurface,
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.25,
                            child: KanbanCardWidget(
                              card: card,
                              backgroundColor: cardSurface,
                              hasPreviousColumn: hasPrev,
                              hasNextColumn: hasNext,
                              canMoveToTop: canTop,
                              canMoveToBottom: canBottom,
                            ),
                          ),
                          child: KanbanCardWidget(
                            card: card,
                            backgroundColor: cardSurface,
                            hasPreviousColumn: hasPrev,
                            hasNextColumn: hasNext,
                            canMoveToTop: canTop,
                            canMoveToBottom: canBottom,
                            onTap: () => AppRouter.push<void>(
                              context,
                              CardDetailScreen(cardId: card.id),
                            ),
                            onChangeColor: () =>
                                _changeCardColor(context, ref, card),
                            onMovePrev: hasPrev
                                ? () => ref
                                      .read(kanbanRepositoryProvider)
                                      .moveCard(
                                        cardId: card.id,
                                        destinationColumnId:
                                            snapshot.columns[columnIndex - 1].id,
                                        destinationIndex:
                                            snapshot
                                                .cardsByColumn[snapshot
                                                    .columns[columnIndex - 1]
                                                    .id]
                                                ?.length ??
                                            0,
                                      )
                                : null,
                            onMoveNext: hasNext
                                ? () => ref
                                      .read(kanbanRepositoryProvider)
                                      .moveCard(
                                        cardId: card.id,
                                        destinationColumnId:
                                            snapshot.columns[columnIndex + 1].id,
                                        destinationIndex:
                                            snapshot
                                                .cardsByColumn[snapshot
                                                    .columns[columnIndex + 1]
                                                    .id]
                                                ?.length ??
                                            0,
                                      )
                                : null,
                            onMoveTop: canTop
                                ? () => ref
                                      .read(kanbanRepositoryProvider)
                                      .moveCard(
                                        cardId: card.id,
                                        destinationColumnId: column.id,
                                        destinationIndex: 0,
                                      )
                                : null,
                            onMoveBottom: canBottom
                                ? () => ref
                                      .read(kanbanRepositoryProvider)
                                      .moveCard(
                                        cardId: card.id,
                                        destinationColumnId: column.id,
                                        destinationIndex: cards.length - 1,
                                      )
                                : null,
                            onDelete: () => ref
                                .read(kanbanRepositoryProvider)
                                .deleteCard(card.id),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
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
      },
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

class _ColumnMenu extends ConsumerWidget {
  const _ColumnMenu({
    required this.snapshot,
    required this.column,
    required this.columnIndex,
  });
  final KanbanSnapshot snapshot;
  final BoardColumnEntity column;
  final int columnIndex;

  Future<void> _editColumn(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsRepositoryProvider);
    final String? override = await settings
        .watchEntityColor('column', column.id)
        .first;
    if (!context.mounted) return;
    final TitleColorValue? value = await showTitleColorDialog(
      context,
      dialogTitle: 'Kolonu düzenle',
      fieldLabel: 'Kolon adı',
      initialTitle: column.title,
      initialColorHex: override ?? column.colorHex,
      confirmLabel: 'Kaydet',
    );
    if (value == null) return;
    final repo = ref.read(kanbanRepositoryProvider);
    if (value.title != column.title) {
      await repo.renameColumn(column.id, value.title);
    }
    final String? colorOverride = value.colorHex == column.colorHex
        ? null
        : value.colorHex;
    await settings.setEntityColor('column', column.id, colorOverride);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    onSelected: (value) async {
      final repo = ref.read(kanbanRepositoryProvider);
      if (value == 'left' && columnIndex > 0) {
        await repo.reorderColumn(
          columnId: column.id,
          destinationIndex: columnIndex - 1,
        );
      } else if (value == 'right' &&
          columnIndex < snapshot.columns.length - 1) {
        await repo.reorderColumn(
          columnId: column.id,
          destinationIndex: columnIndex + 1,
        );
      } else if (value == 'edit') {
        await _editColumn(context, ref);
      } else if (value == 'delete') {
        final List<KanbanCard> cards =
            snapshot.cardsByColumn[column.id] ?? const <KanbanCard>[];
        String? destination;
        if (cards.isNotEmpty) {
          final candidates = snapshot.columns
              .where((item) => item.id != column.id)
              .toList();
          if (candidates.isEmpty) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Kart bulunan tek kolon silinemez. Önce başka bir kolon ekleyin.',
                  ),
                ),
              );
            }
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
      const PopupMenuItem(
        value: 'edit',
        child: Row(
          children: <Widget>[
            Icon(Icons.palette_outlined, size: 18),
            SizedBox(width: 8),
            Text('Adı / rengi düzenle'),
          ],
        ),
      ),
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
