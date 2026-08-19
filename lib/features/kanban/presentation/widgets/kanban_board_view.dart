import 'package:flutter/material.dart';

class KanbanBoardView extends StatelessWidget {
  const KanbanBoardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planora')),
      body: const Center(
        child: Text('Offline-first workspace scaffold is ready.'),
      ),
    );
  }
}
