import 'package:not_app/features/reminders/domain/entities/reminder.dart';
import 'package:not_app/features/reminders/domain/repositories/reminders_repository.dart';

/// Concrete implementation coordinates Drift and NotificationService.
final class RemindersRepositoryImpl implements RemindersRepository {
  const RemindersRepositoryImpl();

  @override
  Future<void> cancel(String reminderId) => throw UnimplementedError();

  @override
  Future<void> reconcileWithOperatingSystem() => throw UnimplementedError();

  @override
  Future<void> schedule(Reminder reminder) => throw UnimplementedError();

  @override
  Stream<List<Reminder>> watchActive() => const Stream.empty();
}
