import 'package:flutter/material.dart';
import 'package:not_app/app/theme/app_theme.dart';
import 'package:not_app/app/widgets/content/app_content.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';

class KanbanCardWidget extends StatefulWidget {
  const KanbanCardWidget({
    required this.card,
    super.key,
    this.feedback = false,
    this.backgroundColor,
    this.accentColor,
    this.onTap,
    this.onMovePrev,
    this.onMoveNext,
    this.onMoveTop,
    this.onMoveBottom,
    this.onChangeColor,
    this.onDelete,
    this.hasPreviousColumn = false,
    this.hasNextColumn = false,
    this.canMoveToTop = false,
    this.canMoveToBottom = false,
    this.showMenu = true,
  });

  final KanbanCard card;
  final bool feedback;
  final Color? backgroundColor;
  final Color? accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onMovePrev;
  final VoidCallback? onMoveNext;
  final VoidCallback? onMoveTop;
  final VoidCallback? onMoveBottom;
  final VoidCallback? onChangeColor;
  final VoidCallback? onDelete;
  final bool hasPreviousColumn;
  final bool hasNextColumn;
  final bool canMoveToTop;
  final bool canMoveToBottom;
  final bool showMenu;

  @override
  State<KanbanCardWidget> createState() => _KanbanCardWidgetState();
}

class _KanbanCardWidgetState extends State<KanbanCardWidget> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Duration motion = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 120);
    final Duration quickMotion = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 110);
    final bool showActions =
        !widget.feedback &&
        (_hovered || _focused || MediaQuery.sizeOf(context).width < 600);
    final Color baseSurface =
        widget.backgroundColor ?? theme.colorScheme.surface;
    final double tintAlpha = theme.brightness == Brightness.dark ? 0.22 : 0.15;
    final Color surface = widget.accentColor == null
        ? baseSurface
        : Color.alphaBlend(
            widget.accentColor!.withValues(alpha: tintAlpha),
            baseSurface,
          );
    final Color borderColor = widget.accentColor == null
        ? theme.dividerColor.withValues(alpha: 0.7)
        : widget.accentColor!.withValues(alpha: 0.36);

    return Semantics(
      label: 'Kanban kartı: ${widget.card.title}',
      button: widget.onTap != null,
      child: FocusableActionDetector(
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedScale(
            duration: motion,
            scale: widget.feedback && !reduceMotion ? 0.98 : 1,
            child: Material(
              color: surface,
              elevation: widget.feedback ? 8 : (_hovered ? 1 : 0),
              shadowColor: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.surface),
              child: InkWell(
                onTap: widget.feedback ? null : widget.onTap,
                borderRadius: BorderRadius.circular(AppRadius.surface),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.surface),
                    border: Border.all(
                      color: widget.feedback
                          ? theme.colorScheme.primary.withValues(alpha: 0.75)
                          : borderColor,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      AppEntityColorIndicator(
                        color: widget.accentColor,
                        vertical: true,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                if (!widget.feedback && widget.onMovePrev != null)
                                  AnimatedOpacity(
                                    opacity: showActions ? 1 : 0.58,
                                    duration: quickMotion,
                                    child: _QuickMoveButton(
                                      key: ValueKey<String>(
                                        'card_move_left_${widget.card.id}',
                                      ),
                                      tooltip: 'Önceki kolona taşı',
                                      icon: Icons.arrow_back_rounded,
                                      onPressed: widget.onMovePrev!,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    widget.card.title,
                                    style: theme.textTheme.titleMedium,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!widget.feedback && widget.onMoveNext != null)
                                  AnimatedOpacity(
                                    opacity: showActions ? 1 : 0.58,
                                    duration: quickMotion,
                                    child: _QuickMoveButton(
                                      key: ValueKey<String>(
                                        'card_move_right_${widget.card.id}',
                                      ),
                                      tooltip: 'Sonraki kolona taşı',
                                      icon: Icons.arrow_forward_rounded,
                                      onPressed: widget.onMoveNext!,
                                    ),
                                  ),
                                if (widget.showMenu && !widget.feedback)
                                  AnimatedOpacity(
                                    opacity: showActions ? 1 : 0.62,
                                    duration: quickMotion,
                                    child: _CardMenu(widget: widget),
                                  ),
                              ],
                            ),
                            if (widget.card.description?.trim().isNotEmpty ==
                                true) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(
                                widget.card.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickMoveButton extends StatelessWidget {
  const _QuickMoveButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        style: IconButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
}

class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.widget});

  final KanbanCardWidget widget;

  @override
  Widget build(BuildContext context) {
    final Color danger = Theme.of(context).colorScheme.error;
    return PopupMenuButton<String>(
      key: ValueKey<String>('card_menu_${widget.card.id}'),
      icon: const Icon(Icons.more_horiz_rounded, size: 18),
      padding: EdgeInsets.zero,
      tooltip: 'Kart seçenekleri',
      onSelected: (value) {
        switch (value) {
          case 'move_prev':
            widget.onMovePrev?.call();
            break;
          case 'move_next':
            widget.onMoveNext?.call();
            break;
          case 'move_top':
            widget.onMoveTop?.call();
            break;
          case 'move_bottom':
            widget.onMoveBottom?.call();
            break;
          case 'change_color':
            widget.onChangeColor?.call();
            break;
          case 'detail':
            widget.onTap?.call();
            break;
          case 'delete':
            widget.onDelete?.call();
            break;
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          key: const ValueKey<String>('menu_move_prev'),
          value: 'move_prev',
          enabled: widget.hasPreviousColumn && widget.onMovePrev != null,
          child: const Text('Önceki kolona taşı'),
        ),
        PopupMenuItem<String>(
          key: const ValueKey<String>('menu_move_next'),
          value: 'move_next',
          enabled: widget.hasNextColumn && widget.onMoveNext != null,
          child: const Text('Sonraki kolona taşı'),
        ),
        PopupMenuItem<String>(
          key: const ValueKey<String>('menu_move_top'),
          value: 'move_top',
          enabled: widget.canMoveToTop && widget.onMoveTop != null,
          child: const Text('Kolonun en üstüne taşı'),
        ),
        PopupMenuItem<String>(
          key: const ValueKey<String>('menu_move_bottom'),
          value: 'move_bottom',
          enabled: widget.canMoveToBottom && widget.onMoveBottom != null,
          child: const Text('Kolonun en altına taşı'),
        ),
        if (widget.onChangeColor != null)
          const PopupMenuItem<String>(
            key: ValueKey<String>('menu_change_color'),
            value: 'change_color',
            child: Text('Rengi değiştir'),
          ),
        if (widget.onTap != null)
          const PopupMenuItem<String>(
            key: ValueKey<String>('menu_detail'),
            value: 'detail',
            child: Text('Ayrıntılar'),
          ),
        if (widget.onDelete != null) const PopupMenuDivider(),
        if (widget.onDelete != null)
          PopupMenuItem<String>(
            key: const ValueKey<String>('menu_delete'),
            value: 'delete',
            child: Text('Sil', style: TextStyle(color: danger)),
          ),
      ],
    );
  }
}
