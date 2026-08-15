import 'package:flutter/material.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/theme/app_theme.dart';

class NotApp extends StatelessWidget {
  const NotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Not',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const AppRouter(),
    );
  }
}
