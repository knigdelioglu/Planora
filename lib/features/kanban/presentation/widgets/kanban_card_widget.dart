import 'package:flutter/material.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';

class KanbanCardWidget extends StatelessWidget {
  const KanbanCardWidget({
    required this.card,
    super.key,
    this.feedback = false,
    this.onTap,
    this.onMovePrev,
    this.onMoveNext,
    this.onMoveTop,
    this.onMoveBottom,
    this.onDelete,
    this.hasPreviousColumn = false,
    this.hasNextColumn = false,
    this.canMoveToTop = false,
    this.canMoveToBottom = false,
    this.showMenu = true,
  });

  final KanbanCard card;
  final bool feedback;
  final VoidCallback? onTap;
  final VoidCallback? onMovePrev;
  final VoidCallback? onMoveNext;
  final VoidCallback? onMoveTop;
  final VoidCallback? onMoveBottom;
  final VoidCallback? onDelete;
  final bool hasPreviousColumn;
  final bool hasNextColumn;
  final bool canMoveToTop;
  final bool canMoveToBottom;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    final bool hasActions =
        showMenu &&
        !feedback &&
        (onMovePrev != null ||
            onMoveNext != null ||
            onMoveTop != null ||
            onMoveBottom != null ||
            onTap != null ||
            onDelete != null);

    return Semantics(
      label: 'Kanban kartı: ${card.title}',
      button: onTap != null,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 3),
        elevation: feedback ? 6 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: feedback
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                )
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: feedback ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        card.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (hasActions) ...<Widget>[
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        key: ValueKey<String>('card_menu_${card.id}'),
                        icon: const Icon(Icons.more_vert, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Kart seçenekleri',
                        onSelected: (value) {
                          switch (value) {
                            case 'move_prev':
                              onMovePrev?.call();
                              break;
                            case 'move_next':
                              onMoveNext?.call();
                              break;
                            case 'move_top':
                              onMoveTop?.call();
                              break;
                            case 'move_bottom':
                              onMoveBottom?.call();
                              break;
                            case 'detail':
                              onTap?.call();
                              break;
                            case 'delete':
                              onDelete?.call();
                              break;
                          }
                        },
                        itemBuilder: (context) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            key: const ValueKey<String>('menu_move_prev'),
                            value: 'move_prev',
                            enabled: hasPreviousColumn && onMovePrev != null,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.arrow_back, size: 18),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Önceki kolona taşı',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            key: const ValueKey<String>('menu_move_next'),
                            value: 'move_next',
                            enabled: hasNextColumn && onMoveNext != null,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.arrow_forward, size: 18),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Sonraki kolona taşı',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            key: const ValueKey<String>('menu_move_top'),
                            value: 'move_top',
                            enabled: canMoveToTop && onMoveTop != null,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.vertical_align_top, size: 18),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Kolonun en üstüne taşı',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            key: const ValueKey<String>('menu_move_bottom'),
                            value: 'move_bottom',
                            enabled: canMoveToBottom && onMoveBottom != null,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.vertical_align_bottom, size: 18),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Kolonun en altına taşı',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (onTap != null || onDelete != null)
                            const PopupMenuDivider(),
                          if (onTap != null)
                            const PopupMenuItem<String>(
                              key: ValueKey<String>('menu_detail'),
                              value: 'detail',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Ayrıntılar',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (onDelete != null)
                            const PopupMenuItem<String>(
                              key: ValueKey<String>('menu_delete'),
                              value: 'delete',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Sil',
                                      style: TextStyle(color: Colors.red),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
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
      ),
    );
  }
}
