import 'package:flutter/material.dart';

abstract final class AppRouter {
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));
  }

  static Future<T?> fullscreen<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(MaterialPageRoute<T>(fullscreenDialog: true, builder: (_) => page));
  }
}
