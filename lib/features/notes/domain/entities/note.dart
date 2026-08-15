import 'package:not_app/features/notes/domain/entities/note_document.dart';

final class NoteEntity {
  const NoteEntity({
    required this.id,
    required this.title,
    required this.document,
    required this.isFavorite,
    required this.createdAt,
    required this.updatedAt,
    required this.lastOpenedAt,
    required this.version,
    required this.deletedAt,
  });

  final String id;
  final String title;
  final NoteDocument document;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;
  final int version;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}

enum NoteFilter { all, favorites, recent, trash }
