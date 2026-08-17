import 'package:not_app/features/attachments/domain/repositories/attachments_repository.dart';
import 'package:not_app/features/notes/domain/entities/note.dart';
import 'package:not_app/features/notes/domain/entities/note_document.dart';
import 'package:not_app/features/notes/domain/repositories/notes_repository.dart';
import 'package:not_app/features/reminders/domain/repositories/reminders_repository.dart';

final class LifecycleNotesRepository implements NotesRepository {
  LifecycleNotesRepository(
    this._delegate,
    this._attachments,
    this._reminders,
  );

  final NotesRepository _delegate;
  final AttachmentsRepository _attachments;
  final RemindersRepository _reminders;

  @override
  Stream<List<NoteEntity>> watchNotes(NoteFilter filter) =>
      _delegate.watchNotes(filter);

  @override
  Stream<NoteEntity?> watchNote(String noteId) => _delegate.watchNote(noteId);

  @override
  Future<NoteEntity?> getNote(String noteId) => _delegate.getNote(noteId);

  @override
  Future<String> createNote({String title = ''}) =>
      _delegate.createNote(title: title);

  @override
  Future<void> updateTitle(String noteId, String title) =>
      _delegate.updateTitle(noteId, title);

  @override
  Future<void> saveDocument(String noteId, NoteDocument document) =>
      _delegate.saveDocument(noteId, document);

  @override
  Future<void> setFavorite(String noteId, bool favorite) =>
      _delegate.setFavorite(noteId, favorite);

  @override
  Future<void> markOpened(String noteId) => _delegate.markOpened(noteId);

  @override
  Future<void> trash(String noteId) => _delegate.trash(noteId);

  @override
  Future<void> restore(String noteId) => _delegate.restore(noteId);

  @override
  Future<void> deletePermanently(String noteId) async {
    final attachments = await _attachments.watchForParent('note', noteId).first;
    for (final attachment in attachments) {
      await _attachments.remove(attachment.id);
    }

    final reminders = await _reminders.watchForParent('note', noteId).first;
    for (final reminder in reminders) {
      await _reminders.remove(reminder.id);
    }

    await _delegate.deletePermanently(noteId);
  }
}
