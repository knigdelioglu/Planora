import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/features/attachments/domain/entities/attachment.dart';
import 'package:url_launcher/url_launcher.dart';

class AttachmentsSection extends ConsumerWidget {
  const AttachmentsSection({
    super.key,
    required this.parentType,
    required this.parentId,
    this.emptyText = 'Ek dosya yok.',
  });

  final String parentType;
  final String parentId;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(attachmentsRepositoryProvider);
    return StreamBuilder<List<AttachmentEntity>>(
      stream: repo.watchForParent(parentType, parentId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text(snapshot.error.toString());
        final List<AttachmentEntity> data =
            snapshot.data ?? const <AttachmentEntity>[];
        if (data.isEmpty) return Text(emptyText);
        return Column(
          children: data
              .map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.mimeType?.startsWith('image/') == true
                        ? Icons.image_outlined
                        : Icons.insert_drive_file_outlined,
                  ),
                  title: Text(item.fileName),
                  subtitle: Text(
                    '${(item.sizeBytes / 1024).ceil()} KB · ${item.transferState}',
                  ),
                  onTap: () async {
                    try {
                      final file = await repo.ensureLocal(item.id);
                      final bool opened = await launchUrl(Uri.file(file.path));
                      if (!opened && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Dosya bu cihazda açılamadı.'),
                          ),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
                  trailing: IconButton(
                    tooltip: 'Eki sil',
                    onPressed: () async {
                      try {
                        await repo.remove(item.id);
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.close),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}
