sealed class Failure {
  const Failure(this.message);

  final String message;
}

final class LocalFailure extends Failure {
  const LocalFailure(super.message);
}

final class RemoteFailure extends Failure {
  const RemoteFailure(super.message);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
