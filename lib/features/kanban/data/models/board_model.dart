import 'package:not_app/features/kanban/domain/entities/board.dart';

final class BoardModel {
  const BoardModel({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  Board toEntity() => Board(
        id: id,
        title: title,
        createdAt: createdAt,
        updatedAt: updatedAt,
        version: version,
      );
}
