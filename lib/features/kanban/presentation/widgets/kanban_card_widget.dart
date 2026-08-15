import 'package:flutter/material.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';

class KanbanCardWidget extends StatelessWidget {
  const KanbanCardWidget({required this.card, super.key});

  final KanbanCard card;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(card.title),
      ),
    );
  }
}
