import 'package:flutter/material.dart';
import 'package:not_app/app/theme/app_theme.dart';

Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double desktopWidth = 420,
}) {
  final double width = MediaQuery.sizeOf(context).width;
  if (width < AppBreakpoints.compact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: builder(context),
      ),
    );
  }

  final double resolvedWidth = desktopWidth.clamp(360.0, 480.0).toDouble();
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.12),
    builder: (context) => Align(
      alignment: Alignment.centerRight,
      child: SafeArea(
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(AppRadius.floating),
            ),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          child: SizedBox(
            width: resolvedWidth,
            height: double.infinity,
            child: builder(context),
          ),
        ),
      ),
    ),
  );
}

class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({
    super.key,
    required this.title,
    this.onClose,
    this.trailing,
  });

  final String title;
  final VoidCallback? onClose;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
        IconButton(
          tooltip: 'Kapat',
          onPressed: onClose ?? () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}
