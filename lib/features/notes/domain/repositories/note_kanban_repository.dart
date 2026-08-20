import 'package:not_app/features/notes/domain/entities/linked_note.dart';

abstract interface class NoteKanbanRepository {
  Future<List<LinkedNoteEntity>> linkedNotesForCard(String cardId);
  Future<String?> linkedCardIdForNote(String noteId);

  Future<void> moveNoteToCard({required String noteId, required String cardId});

  Future<String> moveNoteToColumn({
    required String noteId,
    required String boardId,
    required String columnId,
    required String title,
  });

  Future<void> unlinkNote(String noteId);
}
