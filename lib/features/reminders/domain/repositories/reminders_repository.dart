import 'package:not_app/features/reminders/domain/entities/reminder.dart';

abstract interface class RemindersRepository {
  Stream<List<ReminderEntity>> watchUpcoming();
  Stream<List<ReminderEntity>> watchPast();
  Stream<List<ReminderEntity>> watchForParent(
    String parentType,
    String parentId,
  );
  Future<ReminderEntity> create({
    required String parentType,
    required String parentId,
    required String title,
    String? body,
    required DateTime scheduledAtUtc,
    required String timeZoneId,
  });
  Future<void> update({
    required String id,
    required String title,
    String? body,
    required DateTime scheduledAtUtc,
    required String timeZoneId,
    required bool enabled,
  });
  Future<void> remove(String id);
  Future<void> reconcile();
}
