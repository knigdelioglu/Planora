abstract interface class AppClock {
  DateTime nowUtc();
}

final class SystemClock implements AppClock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}
