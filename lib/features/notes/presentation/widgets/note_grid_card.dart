import 'package:flutter/material.dart';
import 'package:not_app/app/widgets/common_widgets.dart';

class NoteGridCard extends StatelessWidget {
  const NoteGridCard({
    super.key,
    required this.title,
    required this.preview,
    required this.updatedAt,
    required this.isFavorite,
    required this.accent,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onChangeColor,
    required this.onMoveToKanban,
    required this.onTrash,
  });

  final String title;
  final String preview;
  final DateTime updatedAt;
  final bool isFavorite;
  final Color? accent;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onChangeColor;
  final VoidCallback onMoveToKanban;
  final VoidCallback onTrash;

  @override
  Widget build(BuildContext context) {
    final String date =
        '${updatedAt.day.toString().padLeft(2, '0')}.'
        '${updatedAt.month.toString().padLeft(2, '0')}.'
        '${updatedAt.year}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  AppEntityColorIndicator(color: accent),
                  const SizedBox(width: 8),
                  const Icon(Icons.description_outlined, size: 18),
                  const Spacer(),
                  if (isFavorite)
                    const Icon(Icons.star_rounded, size: 18),
                  PopupMenuButton<String>(
                    tooltip: 'Not işlemleri',
                    onSelected: (value) {
                      switch (value) {
                        case 'favorite':
                          onToggleFavorite();
                        case 'color':
                          onChangeColor();
                        case 'move':
                          onMoveToKanban();
                        case 'trash':
                          onTrash();
                      }
                    },
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'favorite',
                        child: Text(
                          isFavorite ? 'Favoriden çıkar' : 'Favoriye ekle',
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'color',
                        child: Text('Rengi değiştir'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'move',
                        child: Text('Panoya taşı'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'trash',
                        child: Text('Çöpe taşı'),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz_rounded, size: 19),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  preview,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Güncellendi $date',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
