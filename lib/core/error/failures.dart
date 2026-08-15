sealed class AppFailure implements Exception {
  const AppFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {super.cause});
}

final class StorageFailure extends AppFailure {
  const StorageFailure(super.message, {super.cause});
}

final class DatabaseFailure extends AppFailure {
  const DatabaseFailure(super.message, {super.cause});
}

final class PermissionFailure extends AppFailure {
  const PermissionFailure(super.message, {super.cause});
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.cause});
}

final class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {super.cause});
}

final class SyncFailure extends AppFailure {
  const SyncFailure(super.message, {super.cause});
}

final class ConflictFailure extends AppFailure {
  const ConflictFailure(super.message, {super.cause});
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message, {super.cause});
}
