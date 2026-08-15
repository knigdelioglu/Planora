import 'package:flutter/material.dart';
import 'package:not_app/features/kanban/presentation/widgets/kanban_board_view.dart';

/// Minimal bootstrap router.
/// Replace with declarative routing only when navigation complexity requires it.
class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) => const KanbanBoardView();
}
