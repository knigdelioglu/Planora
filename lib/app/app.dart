import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/app_shell.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/theme/app_theme.dart';

class NotApp extends ConsumerWidget {
  const NotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
