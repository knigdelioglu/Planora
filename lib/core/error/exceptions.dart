class LocalDataException implements Exception {
  const LocalDataException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'LocalDataException: $message';
}

class RemoteDataException implements Exception {
  const RemoteDataException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'RemoteDataException: $message';
}
