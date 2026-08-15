import 'package:flutter/material.dart';
import 'package:not_app/features/kanban/domain/entities/kanban_card.dart';
import 'package:not_app/features/kanban/presentation/widgets/kanban_card_widget.dart';

class KanbanColumnWidget extends StatelessWidget {
  const KanbanColumnWidget({
    required this.title,
    required this.cards,
    super.key,
  });

  final String title;
  final List<KanbanCard> cards;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: cards.length,
              itemBuilder: (context, index) => KanbanCardWidget(card: cards[index]),
            ),
          ),
        ],
      ),
    );
  }
}
