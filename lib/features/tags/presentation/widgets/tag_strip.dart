import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/features/tags/domain/entities/tag.dart';

Color tagColor(BuildContext context, String key) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  return switch (key) {
    'gray' => scheme.outline,
    'red' => Colors.red.shade600,
    'orange' => Colors.orange.shade700,
    'amber' => Colors.amber.shade800,
    'green' => Colors.green.shade600,
    'teal' => Colors.teal.shade600,
    'blue' => Colors.blue.shade600,
    'violet' => Colors.deepPurple.shade500,
    'pink' => Colors.pink.shade500,
    _ => scheme.primary,
  };
}

class TagStrip extends ConsumerWidget {
  const TagStrip({
    super.key,
    required this.targetType,
    required this.targetId,
    this.editable = true,
    this.compact = false,
    this.maxVisible,
  });

  final TagTargetType targetType;
  final String targetId;
  final bool editable;
  final bool compact;
  final int? maxVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(tagsRepositoryProvider);
    return StreamBuilder<List<TagEntity>>(
      stream: repository.watchTagsForTarget(
        targetType: targetType,
        targetId: targetId,
      ),
      builder: (context, snapshot) {
        final List<TagEntity> all = snapshot.data ?? const <TagEntity>[];
        final int visibleCount = maxVisible == null
            ? all.length
            : all.length.clamp(0, maxVisible!).toInt();
        final List<TagEntity> visible = all
            .take(visibleCount)
            .toList(growable: false);
        final int hidden = all.length - visible.length;
        if (visible.isEmpty && !editable) return const SizedBox.shrink();

        return Wrap(
          spacing: compact ? 5 : 7,
          runSpacing: compact ? 4 : 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            ...visible.map(
              (TagEntity tag) => _TagChip(
                tag: tag,
                compact: compact,
                onDelete: editable
                    ? () => repository.unassign(
                        tagId: tag.id,
                        targetType: targetType,
                        targetId: targetId,
                      )
                    : null,
              ),
            ),
            if (hidden > 0)
              Text(
                '+$hidden',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            if (editable)
              ActionChip(
                visualDensity: compact ? VisualDensity.compact : null,
                avatar: const Icon(Icons.add_rounded, size: 15),
                label: Text(compact ? 'Etiket' : 'Etiket ekle'),
                onPressed: () => showTagPicker(
                  context,
                  ref,
                  targetType: targetType,
                  targetId: targetId,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, required this.compact, this.onDelete});

  final TagEntity tag;
  final bool compact;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final Color color = tagColor(context, tag.colorKey);
    return InputChip(
      visualDensity: compact ? VisualDensity.compact : null,
      avatar: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      label: Text('#${tag.name}'),
      deleteIcon: onDelete == null
          ? null
          : const Icon(Icons.close_rounded, size: 14),
      onDeleted: onDelete,
      side: BorderSide(color: color.withValues(alpha: 0.28)),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }
}

Future<void> showTagPicker(
  BuildContext context,
  WidgetRef ref, {
  required TagTargetType targetType,
  required String targetId,
}) async {
  final Size size = MediaQuery.sizeOf(context);
  final Widget child = _TagPickerContent(
    targetType: targetType,
    targetId: targetId,
  );
  if (size.width < 600) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.72, child: child),
    );
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: child,
      ),
    ),
  );
}

class _TagPickerContent extends ConsumerStatefulWidget {
  const _TagPickerContent({required this.targetType, required this.targetId});

  final TagTargetType targetType;
  final String targetId;

  @override
  ConsumerState<_TagPickerContent> createState() => _TagPickerContentState();
}

class _TagPickerContentState extends ConsumerState<_TagPickerContent> {
  final TextEditingController _search = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final String name = _search.text.trim();
    if (name.isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      final repository = ref.read(tagsRepositoryProvider);
      final String tagId = await repository.createTag(name: name);
      await repository.assign(
        tagId: tagId,
        targetType: widget.targetType,
        targetId: widget.targetId,
      );
      _search.clear();
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(tagsRepositoryProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        top: 16,
        right: 18,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Etiketler',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Kapat',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => unawaited(_create()),
            decoration: const InputDecoration(
              hintText: 'Etiket ara veya oluştur…',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<List<TagEntity>>(
              stream: repository.watchTags(),
              builder: (context, allSnapshot) => StreamBuilder<List<TagEntity>>(
                stream: repository.watchTagsForTarget(
                  targetType: widget.targetType,
                  targetId: widget.targetId,
                ),
                builder: (context, selectedSnapshot) {
                  final Set<String> selected =
                      (selectedSnapshot.data ?? const <TagEntity>[])
                          .map((TagEntity tag) => tag.id)
                          .toSet();
                  final String query = _search.text.trim().toLowerCase();
                  final List<TagEntity> tags =
                      (allSnapshot.data ?? const <TagEntity>[])
                          .where(
                            (TagEntity tag) =>
                                query.isEmpty ||
                                tag.name.toLowerCase().contains(query),
                          )
                          .toList(growable: false);

                  return ListView(
                    children: <Widget>[
                      ...tags.map(
                        (TagEntity tag) => CheckboxListTile(
                          value: selected.contains(tag.id),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.trailing,
                          secondary: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: tagColor(context, tag.colorKey),
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(tag.name),
                          onChanged: (bool? value) {
                            if (value == true) {
                              unawaited(
                                repository.assign(
                                  tagId: tag.id,
                                  targetType: widget.targetType,
                                  targetId: widget.targetId,
                                ),
                              );
                            } else {
                              unawaited(
                                repository.unassign(
                                  tagId: tag.id,
                                  targetType: widget.targetType,
                                  targetId: widget.targetId,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      if (query.isNotEmpty &&
                          !tags.any(
                            (TagEntity tag) => tag.name.toLowerCase() == query,
                          ))
                        ListTile(
                          leading: _creating
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_rounded),
                          title: Text(
                            '“${_search.text.trim()}” etiketini oluştur',
                          ),
                          onTap: _creating ? null : () => unawaited(_create()),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
