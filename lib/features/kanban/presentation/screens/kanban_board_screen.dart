import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/theme/app_theme.dart';
import 'package:not_app/app/widgets/content/app_content.dart';
import 'package:not_app/app/widgets/navigation/app_toolbar.dart';
import 'package:not_app/app/widgets/overlays/app_sheet.dart';
import 'package:not_app/features/kanban/domain/entities/board_column.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_snapshot.dart';
import 'package:not_app/features/kanban/presentation/screens/card_detail_screen.dart';
import 'package:not_app/features/kanban/presentation/widgets/kanban_card_widget.dart';
import 'package:not_app/features/kanban/presentation/widgets/kanban_color.dart';

class KanbanBoardScreen extends ConsumerStatefulWidget {
  const KanbanBoardScreen({super.key, required this.boardId});

  final String boardId;

  static const double kEdgeThreshold = 48;

  @override
  ConsumerState<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends ConsumerState<KanbanBoardScreen> {
  final ScrollController _horizontalScrollController = ScrollController();
  final GlobalKey _boardAreaKey = GlobalKey();
  Timer? _autoScrollTimer;
  double _autoScrollDelta = 0;
  Stream<KanbanSnapshot?>? _boardStream;
  String? _selectedCardId;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(covariant KanbanBoardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.boardId != widget.boardId) {
      _selectedCardId = null;
      _initStream();
    }
  }

  void _initStream() {
    _boardStream = ref.read(kanbanRepositoryProvider).watchBoard(widget.boardId);
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

    final Offset local = box.globalToLocal(globalPosition);
    final double width = box.size.width;
    if (local.dx < KanbanBoardScreen.kEdgeThreshold) {
      final double clampedDx = local.dx
          .clamp(0.0, KanbanBoardScreen.kEdgeThreshold)
          .toDouble();
      final double proximity =
          ((KanbanBoardScreen.kEdgeThreshold - clampedDx) /
                  KanbanBoardScreen.kEdgeThreshold)
              .clamp(0.0, 1.0)
              .toDouble();
      _startAutoScroll(-(8.0 + proximity * 16.0));
    } else if (local.dx > width - KanbanBoardScreen.kEdgeThreshold) {
      final double start = width - KanbanBoardScreen.kEdgeThreshold;
      final double clampedDx = local.dx.clamp(start, width).toDouble();
      final double proximity =
          ((clampedDx - start) / KanbanBoardScreen.kEdgeThreshold)
              .clamp(0.0, 1.0)
              .toDouble();
      _startAutoScroll(8.0 + proximity * 16.0);
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll(double delta) {
    _autoScrollDelta = delta;
    if (_autoScrollTimer != null) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || !_horizontalScrollController.hasClients) {
        _stopAutoScroll();
        return;
      }
      final position = _horizontalScrollController.position;
      final double next = (position.pixels + _autoScrollDelta)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (next != position.pixels) {
        _horizontalScrollController.jumpTo(next);
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollDelta = 0;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  Future<void> _addColumn(BuildContext context) async {
    final TitleColorValue? value = await showTitleColorDialog(
      context,
      dialogTitle: 'Yeni kolon',
      fieldLabel: 'Kolon adı',
      confirmLabel: 'Ekle',
    );
    if (value == null) return;
    await ref.read(kanbanRepositoryProvider).createColumn(
          boardId: widget.boardId,
          title: value.title,
          colorHex: value.colorHex,
        );
  }

  Future<void> _renameBoard(BuildContext context, KanbanSnapshot data) async {
    final TitleColorValue? value = await showTitleColorDialog(
      context,
      dialogTitle: 'Panoyu yeniden adlandır',
      fieldLabel: 'Pano adı',
      initialTitle: data.board.title,
      initialColorHex: data.board.colorHex,
      confirmLabel: 'Kaydet',
    );
    if (value == null || value.title == data.board.title) return;
    await ref
        .read(kanbanRepositoryProvider)
        .renameBoard(data.board.id, value.title);
  }

  Future<void> _newCardOnBoard(
    BuildContext context,
    KanbanSnapshot data,
  ) async {
    if (data.columns.isEmpty) {
      await _addColumn(context);
      return;
    }
    final (String, String)? value = await showAppSheet<(String, String)>(
      context: context,
      builder: (_) => _NewCardSheet(columns: data.columns),
    );
    if (value == null) return;
    await ref.read(kanbanRepositoryProvider).createCard(
          boardId: data.board.id,
          columnId: value.$2,
          title: value.$1,
        );
  }

  Future<void> _openCard(BuildContext context, String cardId) async {
    if (MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded) {
      setState(() => _selectedCardId = cardId);
      return;
    }
    await AppRouter.push<void>(context, CardDetailScreen(cardId: cardId));
  }

  double _columnWidth(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    if (width < AppBreakpoints.compact) {
      return (width * 0.86).clamp(272.0, 312.0).toDouble();
    }
    if (width < AppBreakpoints.expanded) return 292;
    return 304;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

          final Widget workspace = Column(
            children: <Widget>[
              AppToolbar(
                title: data.board.title,
                breadcrumb: 'Panolar',
                leading: IconButton(
                  tooltip: 'Geri',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                actions: <Widget>[
                  FilledButton.icon(
                    onPressed: () => _newCardOnBoard(context, data),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Kart'),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Pano işlemleri',
                    onSelected: (value) {
                      if (value == 'column') {
                        unawaited(_addColumn(context));
                      } else if (value == 'rename') {
                        unawaited(_renameBoard(context, data));
                      }
                    },
                    itemBuilder: (_) => const <PopupMenuEntry<String>>[
                      PopupMenuItem(value: 'column', child: Text('Kolon ekle')),
                      PopupMenuItem(
                        value: 'rename',
                        child: Text('Panoyu yeniden adlandır'),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              ),
              Expanded(
                child: data.columns.isEmpty
                    ? _EmptyBoard(onAddColumn: () => _addColumn(context))
                    : KeyedSubtree(
                        key: _boardAreaKey,
                        child: Scrollbar(
                          controller: _horizontalScrollController,
                          thumbVisibility: MediaQuery.sizeOf(context).width >=
                              AppBreakpoints.expanded,
                          child: ListView.separated(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                            itemCount: data.columns.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, columnIndex) {
                              if (columnIndex == data.columns.length) {
                                return _AddColumnSurface(
                                  onTap: () => _addColumn(context),
                                  width: _columnWidth(context),
                                );
                              }
                              final BoardColumnEntity column =
                                  data.columns[columnIndex];
                              return SizedBox(
                                width: _columnWidth(context),
                                child: _KanbanColumn(
                                  snapshot: data,
                                  column: column,
                                  columnIndex: columnIndex,
                                  cards: data.cardsByColumn[column.id] ??
                                      const <KanbanCard>[],
                                  onDragUpdate: _onDragUpdate,
                                  onDragEnd: _stopAutoScroll,
                                  onOpenCard: (cardId) =>
                                      _openCard(context, cardId),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),
            ],
          );

          if (MediaQuery.sizeOf(context).width < AppBreakpoints.expanded ||
              _selectedCardId == null) {
            return workspace;
          }

          return Row(
            children: <Widget>[
              Expanded(child: workspace),
              Container(
                width: 420,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    left: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: CardDetailPane(
                  cardId: _selectedCardId!,
                  embedded: true,
                  onClose: () => setState(() => _selectedCardId = null),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard({required this.onAddColumn});

  final VoidCallback onAddColumn;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.view_column_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text('Bu pano boş', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAddColumn,
              icon: const Icon(Icons.add_rounded),
              label: const Text('İlk kolonu oluştur'),
            ),
          ],
        ),
      );
}

class _AddColumnSurface extends StatelessWidget {
  const _AddColumnSurface({required this.onTap, required this.width});

  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainer
                .withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.surface),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.surface),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.add_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Kolon ekle'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
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
    required this.onOpenCard,
  });

  final KanbanSnapshot snapshot;
  final BoardColumnEntity column;
  final int columnIndex;
  final List<KanbanCard> cards;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueChanged<String> onOpenCard;

  Future<void> _newCard(BuildContext context, WidgetRef ref) async {
    final TextEditingController controller = TextEditingController();
    final String? title = await showAppSheet<String>(
      context: context,
      builder: (_) => _SimpleTitleSheet(
        title: '${column.title} · yeni kart',
        fieldLabel: 'Kart başlığı',
        confirmLabel: 'Ekle',
        controller: controller,
      ),
    );
    controller.dispose();
    if (title == null || title.trim().isEmpty) return;
    await ref.read(kanbanRepositoryProvider).createCard(
          boardId: column.boardId,
          columnId: column.id,
          title: title.trim(),
        );
  }

  Future<void> _changeCardColor(
    BuildContext context,
    WidgetRef ref,
    KanbanCard card,
  ) async {
    final settings = ref.read(settingsRepositoryProvider);
    final String? current =
        await settings.watchEntityColor('card', card.id).first;
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
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainer
                .withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(AppRadius.surface),
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 7),
                child: Row(
                  children: <Widget>[
                    AppEntityColorIndicator(color: columnColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              column.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '${cards.length}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
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
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  itemCount: cards.length * 2 + 1,
                  itemBuilder: (context, rawIndex) {
                    if (rawIndex.isEven) {
                      final int destination = rawIndex ~/ 2;
                      return _InsertionDropZone(
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
                        final Color? cardColor =
                            colorFromHex(cardColorSnapshot.data) ?? columnColor;
                        final Widget cardWidget = KanbanCardWidget(
                          card: card,
                          backgroundColor: Theme.of(context).colorScheme.surface,
                          accentColor: cardColor,
                          hasPreviousColumn: hasPrev,
                          hasNextColumn: hasNext,
                          canMoveToTop: canTop,
                          canMoveToBottom: canBottom,
                          onTap: () => onOpenCard(card.id),
                          onChangeColor: () =>
                              _changeCardColor(context, ref, card),
                          onMovePrev: hasPrev
                              ? () => ref
                                  .read(kanbanRepositoryProvider)
                                  .moveCard(
                                    cardId: card.id,
                                    destinationColumnId:
                                        snapshot.columns[columnIndex - 1].id,
                                    destinationIndex: snapshot
                                            .cardsByColumn[
                                                snapshot.columns[columnIndex - 1]
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
                                    destinationIndex: snapshot
                                            .cardsByColumn[
                                                snapshot.columns[columnIndex + 1]
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
                        );
                        return _AdaptiveDraggableCard(
                          data: _CardDragData(card),
                          onDragUpdate: onDragUpdate,
                          onDragEnd: onDragEnd,
                          feedback: SizedBox(
                            width: 282,
                            child: KanbanCardWidget(
                              card: card,
                              feedback: true,
                              backgroundColor:
                                  Theme.of(context).colorScheme.surface,
                              accentColor: cardColor,
                            ),
                          ),
                          child: cardWidget,
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _newCard(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 17),
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

class _InsertionDropZone extends StatelessWidget {
  const _InsertionDropZone({required this.onDrop});

  final ValueChanged<_CardDragData> onDrop;

  @override
  Widget build(BuildContext context) => DragTarget<_CardDragData>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) => onDrop(details.data),
        builder: (context, candidates, rejects) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: candidates.isEmpty ? 8 : 18,
          margin: const EdgeInsets.symmetric(vertical: 1),
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: candidates.isEmpty ? 0 : 3,
            decoration: BoxDecoration(
              color: candidates.isEmpty
                  ? Colors.transparent
                  : Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      );
}

class _AdaptiveDraggableCard extends StatelessWidget {
  const _AdaptiveDraggableCard({
    required this.data,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.feedback,
    required this.child,
  });

  final _CardDragData data;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final Widget feedback;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool touchLayout = MediaQuery.sizeOf(context).width < 600;
    if (touchLayout) {
      return LongPressDraggable<_CardDragData>(
        data: data,
        feedback: Material(color: Colors.transparent, child: feedback),
        childWhenDragging: Opacity(opacity: 0.24, child: child),
        onDragUpdate: (details) => onDragUpdate(details.globalPosition),
        onDragEnd: (_) => onDragEnd(),
        onDraggableCanceled: (_, __) => onDragEnd(),
        onDragCompleted: onDragEnd,
        child: child,
      );
    }
    return Draggable<_CardDragData>(
      data: data,
      feedback: Material(color: Colors.transparent, child: feedback),
      childWhenDragging: Opacity(opacity: 0.24, child: child),
      onDragUpdate: (details) => onDragUpdate(details.globalPosition),
      onDragEnd: (_) => onDragEnd(),
      onDraggableCanceled: (_, __) => onDragEnd(),
      onDragCompleted: onDragEnd,
      child: child,
    );
  }
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
    final String? override =
        await settings.watchEntityColor('column', column.id).first;
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
    final String? colorOverride =
        value.colorHex == column.colorHex ? null : value.colorHex;
    await settings.setEntityColor('column', column.id, colorOverride);
  }

  Future<void> _deleteColumn(BuildContext context, WidgetRef ref) async {
    final List<KanbanCard> cards =
        snapshot.cardsByColumn[column.id] ?? const <KanbanCard>[];
    String? destination;
    if (cards.isNotEmpty) {
      final List<BoardColumnEntity> candidates = snapshot.columns
          .where((item) => item.id != column.id)
          .toList(growable: false);
      if (candidates.isEmpty) {
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
              .toList(growable: false),
        ),
      );
      if (destination == null) return;
    }
    await ref.read(kanbanRepositoryProvider).deleteColumn(
          column.id,
          moveCardsToColumnId: destination,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
        tooltip: 'Kolon işlemleri',
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
            await _deleteColumn(context, ref);
          }
        },
        itemBuilder: (_) => <PopupMenuEntry<String>>[
          const PopupMenuItem(value: 'edit', child: Text('Adı / rengi düzenle')),
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
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'delete', child: Text('Kolonu sil')),
        ],
        icon: const Icon(Icons.more_horiz_rounded, size: 18),
      );
}

class _SimpleTitleSheet extends StatelessWidget {
  const _SimpleTitleSheet({
    required this.title,
    required this.fieldLabel,
    required this.confirmLabel,
    required this.controller,
  });

  final String title;
  final String fieldLabel;
  final String confirmLabel;
  final TextEditingController controller;

  void _submit(BuildContext context) {
    final String value = controller.text.trim();
    if (value.isNotEmpty) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppSheetHeader(title: title),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(context),
                  decoration: InputDecoration(labelText: fieldLabel),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _submit(context),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _NewCardSheet extends StatefulWidget {
  const _NewCardSheet({required this.columns});

  final List<BoardColumnEntity> columns;

  @override
  State<_NewCardSheet> createState() => _NewCardSheetState();
}

class _NewCardSheetState extends State<_NewCardSheet> {
  final TextEditingController _controller = TextEditingController();
  late String _columnId;

  @override
  void initState() {
    super.initState();
    _columnId = widget.columns.first.id;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop((title, _columnId));
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const AppSheetHeader(title: 'Yeni kart'),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(labelText: 'Kart başlığı'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _columnId,
                  decoration: const InputDecoration(labelText: 'Kolon'),
                  items: widget.columns
                      .map(
                        (column) => DropdownMenuItem<String>(
                          value: column.id,
                          child: Text(column.title),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setState(() => _columnId = value);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Ekle'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
