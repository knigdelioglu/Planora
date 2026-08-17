import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_app/features/attachments/domain/entities/attachment.dart';
import 'package:not_app/features/attachments/domain/repositories/attachments_repository.dart';
import 'package:not_app/features/notes/data/repositories/lifecycle_notes_repository.dart';
import 'package:not_app/features/notes/domain/repositories/notes_repository.dart';
import 'package:not_app/features/reminders/domain/entities/reminder.dart';
import 'package:not_app/features/reminders/domain/repositories/reminders_repository.dart';

class _NotesMock extends Mock implements NotesRepository {}

class _AttachmentsMock extends Mock implements AttachmentsRepository {}

class _RemindersMock extends Mock implements RemindersRepository {}

void main() {
  test(
    'permanent note deletion tombstones children before deleting note',
    () async {
      final NotesRepository notes = _NotesMock();
      final AttachmentsRepository attachments = _AttachmentsMock();
      final RemindersRepository reminders = _RemindersMock();
      final DateTime now = DateTime.utc(2026, 8, 17, 12);

      final AttachmentEntity attachment = AttachmentEntity(
        id: 'att_1',
        parentType: 'note',
        parentId: 'note_1',
        fileName: 'report.pdf',
        localPath: '/managed/report.pdf',
        remotePath: 'user/att_1/report.pdf',
        sizeBytes: 12,
        isCache: false,
        transferState: 'synced',
        createdAt: now,
        updatedAt: now,
        version: 1,
      );
      final ReminderEntity reminder = ReminderEntity(
        id: 'rem_1',
        parentType: 'note',
        parentId: 'note_1',
        title: 'Reminder',
        scheduledAtUtc: now,
        timeZoneId: 'UTC',
        notificationId: 42,
        enabled: true,
        schedulingStatus: 'scheduled',
        createdAt: now,
        updatedAt: now,
        version: 1,
      );

      when(
        () => attachments.watchForParent('note', 'note_1'),
      ).thenAnswer((_) => Stream.value(<AttachmentEntity>[attachment]));
      when(
        () => reminders.watchForParent('note', 'note_1'),
      ).thenAnswer((_) => Stream.value(<ReminderEntity>[reminder]));
      when(() => attachments.remove('att_1')).thenAnswer((_) async {});
      when(() => reminders.remove('rem_1')).thenAnswer((_) async {});
      when(() => notes.deletePermanently('note_1')).thenAnswer((_) async {});

      final LifecycleNotesRepository repository = LifecycleNotesRepository(
        delegate: notes,
        attachments: attachments,
        reminders: reminders,
      );

      await repository.deletePermanently('note_1');

      verify(() => attachments.remove('att_1')).called(1);
      verify(() => reminders.remove('rem_1')).called(1);
      verify(() => notes.deletePermanently('note_1')).called(1);
    },
  );
}
