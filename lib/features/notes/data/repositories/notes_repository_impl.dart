import 'package:not_app/features/notes/domain/entities/note.dart';
import 'package:not_app/features/notes/domain/repositories/notes_repository.dart';

/// Concrete Drift-backed implementation belongs here.
final class NotesRepositoryImpl implements NotesRepository {
  const NotesRepositoryImpl();

  @override
  Future<void> save(Note note) => throw UnimplementedError();

  @override
  Future<void> softDelete(String noteId) => throw UnimplementedError();

  @override
  Stream<List<Note>> watchNotes() => const Stream.empty();
}
