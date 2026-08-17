import 'package:flutter/material.dart';
import 'package:not_app/app/theme/app_theme.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 8),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class AppEntityColorIndicator extends StatelessWidget {
  const AppEntityColorIndicator({
    super.key,
    this.color,
    this.size = 8,
    this.vertical = false,
  });

  final Color? color;
  final double size;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final Color effective =
        color ?? Theme.of(context).colorScheme.outlineVariant;
    return Container(
      width: vertical ? 3 : size,
      height: vertical ? 28 : size,
      decoration: BoxDecoration(
        color: effective,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class AppListRow extends StatefulWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry padding;

  @override
  State<AppListRow> createState() => _AppListRowState();
}

class _AppListRowState extends State<AppListRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool active = widget.selected || _hovered || _focused;
    final Color background = widget.selected
        ? theme.colorScheme.primary.withValues(alpha: 0.075)
        : active
        ? theme.hoverColor
        : Colors.transparent;

    return FocusableActionDetector(
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.surface),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppRadius.surface),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: widget.padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  if (widget.leading != null) ...<Widget>[
                    widget.leading!,
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        widget.title,
                        if (widget.subtitle != null) ...<Widget>[
                          const SizedBox(height: 2),
                          DefaultTextStyle.merge(
                            style: theme.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            child: widget.subtitle!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...<Widget>[
                    const SizedBox(width: 12),
                    widget.trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.border = false,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool border;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.surface),
      border: border ? Border.all(color: Theme.of(context).dividerColor) : null,
    ),
    child: child,
  );
}
