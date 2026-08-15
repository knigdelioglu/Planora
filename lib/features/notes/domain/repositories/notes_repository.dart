import 'package:not_app/features/notes/domain/entities/note.dart';

abstract interface class NotesRepository {
  Stream<List<Note>> watchNotes();
  Future<void> save(Note note);
  Future<void> softDelete(String noteId);
}
