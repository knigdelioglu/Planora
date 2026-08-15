final class RankSpaceExhaustedException implements Exception {
  const RankSpaceExhaustedException();

  @override
  String toString() => 'No sortable rank remains between adjacent values.';
}

final class StartupException implements Exception {
  const StartupException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'StartupException: $message';
}
