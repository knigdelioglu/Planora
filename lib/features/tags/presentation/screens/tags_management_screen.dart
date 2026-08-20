import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
import 'package:not_app/app/widgets/content/app_content.dart';
import 'package:not_app/app/widgets/navigation/app_toolbar.dart';
import 'package:not_app/features/tags/domain/entities/tag.dart';
import 'package:not_app/features/tags/presentation/widgets/tag_strip.dart';

class TagsManagementScreen extends ConsumerWidget {
  const TagsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(tagsRepositoryProvider);
    return Scaffold(
      body: Column(
        children: <Widget>[
          AppToolbar(
            title: 'Etiketleri Yönet',
            leading: IconButton(
              tooltip: 'Geri',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            actions: <Widget>[
              FilledButton.icon(
                onPressed: () => _editTag(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Yeni etiket'),
              ),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<TagEntity>>(
              stream: repository.watchTags(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorState(message: snapshot.error.toString());
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final List<TagEntity> tags = snapshot.requireData;
                if (tags.isEmpty) {
                  return EmptyState(
                    icon: Icons.sell_outlined,
                    title: 'Henüz etiket yok',
                    message:
                        'Not ve kartlarınızı düzenlemek için ilk etiketinizi oluşturun.',
                    action: FilledButton(
                      onPressed: () => _editTag(context, ref),
                      child: const Text('Etiket oluştur'),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: tags.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final TagEntity tag = tags[index];
                    return StreamBuilder<int>(
                      stream: repository.watchUsageCount(tag.id),
                      initialData: 0,
                      builder: (context, usageSnapshot) => AppListRow(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: tagColor(context, tag.colorKey),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(tag.name),
                        subtitle: Text(
                          '${usageSnapshot.data ?? 0} içerikte kullanılıyor',
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Etiket işlemleri',
                          onSelected: (String value) {
                            if (value == 'edit') {
                              unawaited(_editTag(context, ref, tag: tag));
                            } else if (value == 'delete') {
                              unawaited(_deleteTag(context, ref, tag));
                            }
                          },
                          itemBuilder: (_) => const <PopupMenuEntry<String>>[
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Düzenle'),
                            ),
                            PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Etiketi sil'),
                            ),
                          ],
                        ),
                        onTap: () => _editTag(context, ref, tag: tag),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editTag(
    BuildContext context,
    WidgetRef ref, {
    TagEntity? tag,
  }) async {
    final TextEditingController name = TextEditingController(text: tag?.name);
    String colorKey = tag?.colorKey ?? 'indigo';
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(tag == null ? 'Yeni etiket' : 'Etiketi düzenle'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: name,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Etiket adı'),
                  onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
                ),
                const SizedBox(height: 18),
                Text('Renk', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const <String>[
                    'gray',
                    'red',
                    'orange',
                    'amber',
                    'green',
                    'teal',
                    'blue',
                    'indigo',
                    'violet',
                    'pink',
                  ].map((String key) {
                    final bool selected = colorKey == key;
                    final Color color = tagColor(context, key);
                    return InkWell(
                      onTap: () => setState(() => colorKey = key),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: selected ? 0.22 : 0.10),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? color
                                : color.withValues(alpha: 0.25),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: selected
                            ? Icon(Icons.check_rounded, size: 18, color: color)
                            : null,
                      ),
                    );
                  }).toList(growable: false),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    final String value = name.text.trim();
    name.dispose();
    if (saved != true || value.isEmpty) return;
    try {
      final repository = ref.read(tagsRepositoryProvider);
      if (tag == null) {
        await repository.createTag(name: value, colorKey: colorKey);
      } else {
        if (value != tag.name) await repository.renameTag(tag.id, value);
        if (colorKey != tag.colorKey) {
          await repository.setColor(tag.id, colorKey);
        }
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _deleteTag(
    BuildContext context,
    WidgetRef ref,
    TagEntity tag,
  ) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('“${tag.name}” silinsin mi?'),
            content: const Text(
              'Etiket kaldırılacak; bağlı not ve kartların kendisi silinmeyecek.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Sil'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(tagsRepositoryProvider).deleteTag(tag.id);
  }
}
