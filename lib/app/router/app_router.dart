import 'package:flutter/material.dart';

abstract final class AppRouter {
  static Widget _safePage(BuildContext context, Widget page) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: SafeArea(child: page),
  );

  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(builder: (routeContext) => _safePage(routeContext, page)),
    );
  }

  static Future<T?> fullscreen<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(
        fullscreenDialog: true,
        builder: (routeContext) => _safePage(routeContext, page),
      ),
    );
  }
}
