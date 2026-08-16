import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/app_shell.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/theme/app_theme.dart';

class NotApp extends ConsumerStatefulWidget {
  const NotApp({super.key});

  @override
  ConsumerState<NotApp> createState() => _NotAppState();
}

class _NotAppState extends ConsumerState<NotApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try {
        final services = ref.read(appServicesProvider);
        services.notifications.refreshTimeZone();
        services.reminders.reconcile();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsRepositoryProvider);
    return StreamBuilder<String>(
      stream: settings.watchThemeMode(),
      initialData: 'system',
      builder: (context, snapshot) {
        final ThemeMode mode = switch (snapshot.data) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
        return MaterialApp(
          title: 'Not',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          builder: (context, child) => _AppFocusDismissLayer(
            child: child ?? const SizedBox.shrink(),
          ),
          home: const AppShell(),
        );
      },
    );
  }
}

/// Clears text-field focus whenever the user taps outside the currently
/// focused editable area. Using a pointer listener at the MaterialApp root
/// makes the behavior consistent across screens, dialogs, and nested routes
/// without competing with child tap gestures.
class _AppFocusDismissLayer extends StatelessWidget {
  const _AppFocusDismissLayer({required this.child});

  final Widget child;

  void _handlePointerDown(PointerDownEvent event) {
    final FocusNode? focus = FocusManager.instance.primaryFocus;
    if (focus == null || !focus.hasFocus) return;

    final BuildContext? focusContext = focus.context;
    final RenderObject? renderObject = focusContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final Offset localPosition = renderObject.globalToLocal(event.position);
      final Rect focusBounds = Offset.zero & renderObject.size;
      if (focusBounds.contains(localPosition)) return;
    }

    focus.unfocus();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _handlePointerDown,
    child: child,
  );
}
