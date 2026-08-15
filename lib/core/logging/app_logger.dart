import 'dart:developer' as developer;

final class AppLogger {
  const AppLogger({this.enabled = true});
  final bool enabled;

  void info(String message, {String name = 'Not'}) {
    if (enabled) developer.log(message, name: name);
  }

  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (!enabled) return;
    developer.log(message, name: 'Not', level: 900, error: error, stackTrace: stackTrace);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (!enabled) return;
    developer.log(message, name: 'Not', level: 1000, error: error, stackTrace: stackTrace);
  }
}
