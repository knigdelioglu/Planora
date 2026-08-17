import 'package:flutter/material.dart';
import 'package:not_app/app/theme/app_theme.dart';

class AppToolbar extends StatelessWidget {
  const AppToolbar({
    super.key,
    required this.title,
    this.leading,
    this.breadcrumb,
    this.status,
    this.actions = const <Widget>[],
    this.compact = false,
  });

  final String title;
  final Widget? leading;
  final String? breadcrumb;
  final Widget? status;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double horizontal = MediaQuery.sizeOf(context).width < 600 ? 16 : 24;
    return SafeArea(
      left: false,
      right: false,
      bottom: false,
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 50 : 54),
        padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (breadcrumb != null && breadcrumb!.isNotEmpty)
                          Text(
                            breadcrumb!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status != null) ...<Widget>[
                    const SizedBox(width: 10),
                    Flexible(child: status!),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty) ...<Widget>[
              const SizedBox(width: 12),
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.selected = false,
    this.semanticLabel,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget button = IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        foregroundColor: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
        backgroundColor: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.09)
            : Colors.transparent,
        minimumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    );
    if (semanticLabel != null) {
      button = Semantics(label: semanticLabel, button: true, child: button);
    }
    return button;
  }
}
