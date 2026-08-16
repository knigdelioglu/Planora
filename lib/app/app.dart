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
          home: const AppShell(),
        );
      },
    );
  }
}
