import 'package:not_app/features/reminders/domain/entities/reminder.dart';

abstract interface class RemindersRepository {
  Stream<List<Reminder>> watchActive();
  Future<void> schedule(Reminder reminder);
  Future<void> cancel(String reminderId);
  Future<void> reconcileWithOperatingSystem();
}
