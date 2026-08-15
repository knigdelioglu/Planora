import 'package:not_app/features/notes/domain/entities/note.dart';
import 'package:not_app/features/notes/domain/entities/note_document.dart';

abstract interface class NotesRepository {
  Stream<List<NoteEntity>> watchNotes(NoteFilter filter);
  Stream<NoteEntity?> watchNote(String noteId);
  Future<NoteEntity?> getNote(String noteId);
  Future<String> createNote({String title = ''});
  Future<void> updateTitle(String noteId, String title);
  Future<void> saveDocument(String noteId, NoteDocument document);
  Future<void> setFavorite(String noteId, bool favorite);
  Future<void> markOpened(String noteId);
  Future<void> trash(String noteId);
  Future<void> restore(String noteId);
  Future<void> deletePermanently(String noteId);
}
