import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/features/attachments/data/repositories/attachments_repository_impl.dart';
import 'package:not_app/features/attachments/domain/attachment_backup_policy.dart';
import 'package:not_app/features/attachments/domain/entities/attachment.dart';
import 'package:not_app/features/attachments/presentation/attachment_file_opener.dart';

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
    return StreamBuilder<Map<String, double>>(
      stream: repo.watchActiveProgress(),
      builder: (context, progressSnapshot) {
        final Map<String, double> progressMap =
            progressSnapshot.data ?? const <String, double>{};
        return StreamBuilder<List<AttachmentEntity>>(
          stream: repo.watchForParent(parentType, parentId),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text(snapshot.error.toString());
            final List<AttachmentEntity> data =
                snapshot.data ?? const <AttachmentEntity>[];
            if (data.isEmpty) return Text(emptyText);
            return Column(
              children: data
                  .map((item) {
                    final double? progress = progressMap[item.id];
                    final String sizeText = AttachmentBackupPolicy.formatBytes(
                      item.sizeBytes,
                    );
                    final bool exceedsCloudLimit =
                        !const AttachmentBackupPolicy().allowsSize(
                          item.sizeBytes,
                        ) &&
                        item.remotePath == null;
                    final bool localOnly =
                        item.isLocalOnly || exceedsCloudLimit;
                    final String statusLabel = localOnly
                        ? 'Cihazda · Buluta yedeklenmiyor'
                        : item.transferStatusLabel(progress);
                    final bool isTransferring =
                        item.isTransferring && !localOnly;
                    final bool canRetry = item.canRetry && !localOnly;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        localOnly
                            ? Icons.cloud_off_outlined
                            : item.mimeType?.startsWith('image/') == true
                            ? Icons.image_outlined
                            : Icons.insert_drive_file_outlined,
                        color: canRetry
                            ? Theme.of(context).colorScheme.error
                            : localOnly
                            ? Theme.of(context).colorScheme.tertiary
                            : null,
                      ),
                      title: Text(item.fileName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text('$sizeText · $statusLabel'),
                          if (localOnly) ...<Widget>[
                            const SizedBox(height: 3),
                            Text(
                              'Bu ek yalnızca bu cihazda tutulur; diğer cihazlarda otomatik görünmez.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.tertiary,
                                  ),
                            ),
                          ],
                          if (isTransferring) ...<Widget>[
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progress != null && progress > 0
                                    ? progress
                                    : null,
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ],
                      ),
                      onTap: () async {
                        if (isTransferring) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Dosya transferi devam ediyor…'),
                            ),
                          );
                          return;
                        }
                        if (canRetry) {
                          try {
                            await repo.retryTransfer(item.id);
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          }
                          return;
                        }
                        try {
                          final file = await repo.ensureLocal(item.id);
                          if (!context.mounted) return;
                          await openLocalAttachment(
                            context,
                            file: file,
                            mimeType: item.mimeType,
                            title: item.fileName,
                          );
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        }
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (isTransferring)
                            IconButton(
                              tooltip: 'İptal et',
                              icon: const Icon(Icons.cancel_outlined, size: 20),
                              onPressed: () => repo.cancelTransfer(item.id),
                            )
                          else if (canRetry) ...<Widget>[
                            IconButton(
                              tooltip: 'Tekrar dene',
                              icon: const Icon(Icons.refresh, size: 20),
                              onPressed: () async {
                                try {
                                  await repo.retryTransfer(item.id);
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                  }
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'Eki sil',
                              icon: const Icon(Icons.close, size: 20),
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
                            ),
                          ] else
                            IconButton(
                              tooltip: 'Eki sil',
                              icon: const Icon(Icons.close, size: 20),
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
                            ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            );
          },
        );
      },
    );
  }
}
