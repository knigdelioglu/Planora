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
    final ThemeData baseDarkTheme = AppTheme.dark();
    final ThemeData pureBlackDarkTheme = baseDarkTheme.copyWith(
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      colorScheme: baseDarkTheme.colorScheme.copyWith(
        surfaceContainerLowest: Colors.black,
      ),
      appBarTheme: baseDarkTheme.appBarTheme.copyWith(
        backgroundColor: Colors.black,
      ),
    );

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
          title: 'Planora',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: pureBlackDarkTheme,
          themeMode: mode,
          builder: (context, child) => _AppTextFocusBehavior(
            child: child ?? const SizedBox.shrink(),
          ),
          home: const AppShell(),
        );
      },
    );
  }
}

/// Makes taps outside editable fields dismiss the keyboard on every platform,
/// while still honoring TextFieldTapRegion helpers such as slash-command and
/// formatting overlays that logically belong to the active editor.
class _AppTextFocusBehavior extends StatelessWidget {
  const _AppTextFocusBehavior({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Actions(
    actions: <Type, Action<Intent>>{
      EditableTextTapOutsideIntent:
          CallbackAction<EditableTextTapOutsideIntent>(
            onInvoke: (intent) {
              intent.focusNode.unfocus();
              return null;
            },
          ),
    },
    child: child,
  );
}
