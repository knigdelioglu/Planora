import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:not_app/app/theme/app_theme.dart';
import 'package:not_app/features/conflicts/domain/entities/sync_conflict.dart';
import 'package:not_app/features/notes/domain/entities/note_document.dart';

class ConflictDiffView extends StatelessWidget {
  const ConflictDiffView({
    super.key,
    required this.conflict,
    required this.onResolveLocal,
    required this.onResolveRemote,
    this.onResolveCopy,
    this.isResolving = false,
  });

  final SyncConflictEntity conflict;
  final VoidCallback onResolveLocal;
  final VoidCallback onResolveRemote;
  final VoidCallback? onResolveCopy;
  final bool isResolving;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ConflictHeader(conflict: conflict),
        const SizedBox(height: AppSpacing.md),
        _TimestampsComparison(conflict: conflict),
        const SizedBox(height: AppSpacing.md),
        if (conflict.isNote)
          _NoteConflictDiff(conflict: conflict)
        else if (conflict.isCard)
          _CardConflictDiff(conflict: conflict)
        else
          _GenericConflictDiff(conflict: conflict),
        const SizedBox(height: AppSpacing.md),
        _TechnicalDetailsAccordion(conflict: conflict),
        const SizedBox(height: AppSpacing.lg),
        _ActionBar(
          conflict: conflict,
          onResolveLocal: onResolveLocal,
          onResolveRemote: onResolveRemote,
          onResolveCopy: onResolveCopy,
          isResolving: isResolving,
        ),
      ],
    );
  }
}

class _ConflictHeader extends StatelessWidget {
  const _ConflictHeader({required this.conflict});

  final SyncConflictEntity conflict;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final IconData icon = switch (conflict.entityType.toLowerCase()) {
      'note' => Icons.description_outlined,
      'card' => Icons.view_kanban_outlined,
      'board' => Icons.dashboard_customize_outlined,
      'column' => Icons.view_column_outlined,
      'attachment' => Icons.attach_file_outlined,
      'reminder' => Icons.notifications_active_outlined,
      _ => Icons.sync_problem_outlined,
    };

    final shortId = conflict.entityId.length > 8
        ? conflict.entityId.substring(0, 8)
        : conflict.entityId;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: colorScheme.error, size: 24),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      conflict.entityTypeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '#$shortId',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                conflict.displayTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimestampsComparison extends StatelessWidget {
  const _TimestampsComparison({required this.conflict});

  final SyncConflictEntity conflict;

  String _formatTimestamp(BuildContext context, DateTime? utc) {
    if (utc == null) return 'Bilinmiyor';
    final local = utc.toLocal();
    final timeStr =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final dateStr =
        '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
    return '$dateStr $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final localTime = conflict.localUpdatedAt;
    final remoteTime = conflict.remoteUpdatedAt;

    final bool isLocalNewer =
        localTime != null &&
        remoteTime != null &&
        localTime.isAfter(remoteTime);
    final bool isRemoteNewer =
        localTime != null &&
        remoteTime != null &&
        remoteTime.isAfter(localTime);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 460;

        final localCard = _TimestampBox(
          label: 'Bu Cihaz (Yerel)',
          icon: Icons.phone_android_rounded,
          timeText: _formatTimestamp(context, localTime),
          version: conflict.localVersion,
          isNewer: isLocalNewer,
          color: colorScheme.primary,
        );

        final remoteCard = _TimestampBox(
          label: 'Sunucu (Uzak)',
          icon: Icons.cloud_outlined,
          timeText: _formatTimestamp(context, remoteTime),
          version: conflict.remoteVersion,
          isNewer: isRemoteNewer,
          color: colorScheme.secondary,
        );

        if (isCompact) {
          return Column(
            children: <Widget>[
              localCard,
              const SizedBox(height: AppSpacing.sm),
              remoteCard,
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: localCard),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: remoteCard),
          ],
        );
      },
    );
  }
}

class _TimestampBox extends StatelessWidget {
  const _TimestampBox({
    required this.label,
    required this.icon,
    required this.timeText,
    required this.version,
    required this.isNewer,
    required this.color,
  });

  final String label;
  final IconData icon;
  final String timeText;
  final int? version;
  final bool isNewer;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isNewer ? color.withValues(alpha: 0.6) : theme.dividerColor,
          width: isNewer ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isNewer)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Daha yeni',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            timeText,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (version != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              'Sürüm: v$version',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteConflictDiff extends StatelessWidget {
  const _NoteConflictDiff({required this.conflict});

  final SyncConflictEntity conflict;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localMap = conflict.localPayload;
    final remoteMap = conflict.remotePayload;

    final String localTitle = (localMap['title'] as String?) ?? '';
    final String remoteTitle = (remoteMap['title'] as String?) ?? '';
    final bool titleChanged = localTitle != remoteTitle;

    final String localContentJson =
        (localMap['contentJson'] as String?) ?? '{"version":1,"blocks":[]}';
    final String remoteContentJson =
        (remoteMap['contentJson'] as String?) ?? '{"version":1,"blocks":[]}';

    final NoteDocument localDoc = NoteDocument.decode(localContentJson);
    final NoteDocument remoteDoc = NoteDocument.decode(remoteContentJson);

    final bool isFavoriteLocal = localMap['isFavorite'] == true;
    final bool isFavoriteRemote = remoteMap['isFavorite'] == true;
    final bool favoriteChanged = isFavoriteLocal != isFavoriteRemote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Title diff section
        _DiffSectionCard(
          title: 'Not Başlığı',
          hasDifference: titleChanged,
          child: _TwoColumnDiff(
            localContent: Text(
              localTitle.isEmpty ? '(Başlık yok)' : localTitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: titleChanged ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            remoteContent: Text(
              remoteTitle.isEmpty ? '(Başlık yok)' : remoteTitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: titleChanged ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Content / Block differences section
        _DiffSectionCard(
          title: 'Not İçeriği ve Bloklar',
          hasDifference: localContentJson != remoteContentJson,
          subtitle:
              'Yerel: ${localDoc.blocks.length} blok · Uzak: ${remoteDoc.blocks.length} blok',
          child: _NoteBlocksDiff(localDoc: localDoc, remoteDoc: remoteDoc),
        ),

        if (favoriteChanged) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _DiffSectionCard(
            title: 'Favori Durumu',
            hasDifference: true,
            child: _TwoColumnDiff(
              localContent: Row(
                children: <Widget>[
                  Icon(
                    isFavoriteLocal ? Icons.star : Icons.star_border,
                    size: 18,
                    color: isFavoriteLocal ? Colors.amber : null,
                  ),
                  const SizedBox(width: 6),
                  Text(isFavoriteLocal ? 'Favorilerde' : 'Favori değil'),
                ],
              ),
              remoteContent: Row(
                children: <Widget>[
                  Icon(
                    isFavoriteRemote ? Icons.star : Icons.star_border,
                    size: 18,
                    color: isFavoriteRemote ? Colors.amber : null,
                  ),
                  const SizedBox(width: 6),
                  Text(isFavoriteRemote ? 'Favorilerde' : 'Favori değil'),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NoteBlocksDiff extends StatelessWidget {
  const _NoteBlocksDiff({required this.localDoc, required this.remoteDoc});

  final NoteDocument localDoc;
  final NoteDocument remoteDoc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 540;

        final localWidget = _BlockListPreview(
          title: 'Yerel İçerik',
          doc: localDoc,
          badgeColor: colorScheme.primary,
        );

        final remoteWidget = _BlockListPreview(
          title: 'Uzak İçerik',
          doc: remoteDoc,
          badgeColor: colorScheme.secondary,
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              localWidget,
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              remoteWidget,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: localWidget),
            const SizedBox(width: AppSpacing.md),
            Container(width: 1, height: 180, color: theme.dividerColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: remoteWidget),
          ],
        );
      },
    );
  }
}

class _BlockListPreview extends StatelessWidget {
  const _BlockListPreview({
    required this.title,
    required this.doc,
    required this.badgeColor,
  });

  final String title;
  final NoteDocument doc;
  final Color badgeColor;

  IconData _blockIcon(NoteBlock block) {
    return switch (block.type) {
      NoteBlockType.paragraph => Icons.short_text,
      NoteBlockType.heading => Icons.title,
      NoteBlockType.bulletList => Icons.format_list_bulleted,
      NoteBlockType.numberedList => Icons.format_list_numbered,
      NoteBlockType.checkbox =>
        block.checked == true
            ? Icons.check_box_outlined
            : Icons.check_box_outline_blank,
      NoteBlockType.quote => Icons.format_quote,
      NoteBlockType.code => Icons.code,
      NoteBlockType.divider => Icons.horizontal_rule,
      NoteBlockType.link => Icons.link,
      NoteBlockType.image => Icons.image,
      NoteBlockType.file => Icons.attach_file,
      NoteBlockType.unknown => Icons.help_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (doc.blocks.isEmpty) {
      return Text('(İçerik boş)', style: theme.textTheme.bodySmall);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...doc.blocks.map((block) {
          final icon = _blockIcon(block);
          final text = block.type == NoteBlockType.divider
              ? '——— (Çizgi)'
              : block.text.isEmpty
              ? '(Boş blok)'
              : block.text;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  icon,
                  size: 15,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: block.type == NoteBlockType.heading
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _CardConflictDiff extends StatelessWidget {
  const _CardConflictDiff({required this.conflict});

  final SyncConflictEntity conflict;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localMap = conflict.localPayload;
    final remoteMap = conflict.remotePayload;

    final String localTitle = (localMap['title'] as String?) ?? '';
    final String remoteTitle = (remoteMap['title'] as String?) ?? '';
    final bool titleChanged = localTitle != remoteTitle;

    final String? localDesc = localMap['description'] as String?;
    final String? remoteDesc = remoteMap['description'] as String?;
    final bool descChanged = localDesc != remoteDesc;

    final String? localCol = localMap['columnId'] as String?;
    final String? remoteCol = remoteMap['columnId'] as String?;
    final bool colChanged = localCol != remoteCol;

    final String? localRank = localMap['rankKey'] as String?;
    final String? remoteRank = remoteMap['rankKey'] as String?;
    final bool rankChanged = localRank != remoteRank;

    // Check reminder / due status in payload
    final Object? localDue = localMap['dueAt'] ?? localMap['reminderAt'];
    final Object? remoteDue = remoteMap['dueAt'] ?? remoteMap['reminderAt'];
    final bool reminderChanged = localDue != remoteDue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Title diff
        _DiffSectionCard(
          title: 'Kart Başlığı',
          hasDifference: titleChanged,
          child: _TwoColumnDiff(
            localContent: Text(
              localTitle.isEmpty ? '(Başlık yok)' : localTitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: titleChanged ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            remoteContent: Text(
              remoteTitle.isEmpty ? '(Başlık yok)' : remoteTitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: titleChanged ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Description diff
        _DiffSectionCard(
          title: 'Açıklama',
          hasDifference: descChanged,
          child: _TwoColumnDiff(
            localContent: Text(
              (localDesc == null || localDesc.isEmpty)
                  ? '(Açıklama yok)'
                  : localDesc,
              style: theme.textTheme.bodySmall,
            ),
            remoteContent: Text(
              (remoteDesc == null || remoteDesc.isEmpty)
                  ? '(Açıklama yok)'
                  : remoteDesc,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Column and Rank diff
        _DiffSectionCard(
          title: 'Kolon ve Sıralama Durumu',
          hasDifference: colChanged || rankChanged,
          child: Column(
            children: <Widget>[
              _TwoColumnDiff(
                localContent: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Kolon: ${localCol ?? 'Bilinmiyor'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: colChanged
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sıra Anahtarı: ${localRank ?? 'Varsayılan'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                remoteContent: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Kolon: ${remoteCol ?? 'Bilinmiyor'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: colChanged
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sıra Anahtarı: ${remoteRank ?? 'Varsayılan'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Reminder status diff
        _DiffSectionCard(
          title: 'Hatırlatıcı Durumu',
          hasDifference: reminderChanged,
          child: _TwoColumnDiff(
            localContent: Row(
              children: <Widget>[
                Icon(
                  localDue != null
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  size: 16,
                  color: localDue != null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    localDue != null ? localDue.toString() : 'Hatırlatıcı yok',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            remoteContent: Row(
              children: <Widget>[
                Icon(
                  remoteDue != null
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  size: 16,
                  color: remoteDue != null
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    remoteDue != null
                        ? remoteDue.toString()
                        : 'Hatırlatıcı yok',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GenericConflictDiff extends StatelessWidget {
  const _GenericConflictDiff({required this.conflict});

  final SyncConflictEntity conflict;

  @override
  Widget build(BuildContext context) {
    final localMap = conflict.localPayload;
    final remoteMap = conflict.remotePayload;

    final allKeys = <String>{
      ...localMap.keys,
      ...remoteMap.keys,
    }.where((k) => k != 'version' && k != 'updatedAt').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: allKeys.map((key) {
        final localVal = localMap[key]?.toString() ?? '-';
        final remoteVal = remoteMap[key]?.toString() ?? '-';
        final bool isDifferent = localVal != remoteVal;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _DiffSectionCard(
            title: key,
            hasDifference: isDifferent,
            child: _TwoColumnDiff(
              localContent: Text(localVal),
              remoteContent: Text(remoteVal),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DiffSectionCard extends StatelessWidget {
  const _DiffSectionCard({
    required this.title,
    required this.hasDifference,
    this.subtitle,
    required this.child,
  });

  final String title;
  final bool hasDifference;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasDifference
              ? colorScheme.error.withValues(alpha: 0.4)
              : theme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (hasDifference)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Farklı',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                )
              else
                Text(
                  'Eşleşiyor',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.outline,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _TwoColumnDiff extends StatelessWidget {
  const _TwoColumnDiff({
    required this.localContent,
    required this.remoteContent,
  });

  final Widget localContent;
  final Widget remoteContent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 460;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _LabeledField(label: 'Yerel (Bu cihaz)', child: localContent),
              const SizedBox(height: 8),
              _LabeledField(label: 'Uzak (Sunucu)', child: remoteContent),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _LabeledField(
                label: 'Yerel (Bu cihaz)',
                child: localContent,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _LabeledField(
                label: 'Uzak (Sunucu)',
                child: remoteContent,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 3),
        child,
      ],
    );
  }
}

class _TechnicalDetailsAccordion extends StatelessWidget {
  const _TechnicalDetailsAccordion({required this.conflict});

  final SyncConflictEntity conflict;

  String _formatJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label panoya kopyalandı.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final prettyLocal = _formatJson(conflict.localJson);
    final prettyRemote = _formatJson(conflict.remoteJson);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ExpansionTile(
        key: Key('technical_details_${conflict.id}'),
        initiallyExpanded: false,
        leading: Icon(
          Icons.data_object_rounded,
          size: 20,
          color: colorScheme.outline,
        ),
        title: Text(
          'Teknik Detaylar (JSON)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Geliştiriciler için ham JSON ve sistem kimlikleri',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          const Divider(),
          const SizedBox(height: 8),
          // Metadata IDs
          _IdRow(label: 'Çakışma ID', value: conflict.id),
          _IdRow(label: 'Varlık ID', value: conflict.entityId),
          _IdRow(label: 'Varlık Türü', value: conflict.entityType),
          const SizedBox(height: AppSpacing.md),

          // Local JSON
          _JsonCodeBox(
            label: 'Yerel JSON (Bu cihaz)',
            jsonContent: prettyLocal,
            onCopy: () => _copyToClipboard(context, prettyLocal, 'Yerel JSON'),
          ),
          const SizedBox(height: AppSpacing.md),

          // Remote JSON
          _JsonCodeBox(
            label: 'Uzak JSON (Sunucu)',
            jsonContent: prettyRemote,
            onCopy: () => _copyToClipboard(context, prettyRemote, 'Uzak JSON'),
          ),
        ],
      ),
    );
  }
}

class _IdRow extends StatelessWidget {
  const _IdRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JsonCodeBox extends StatelessWidget {
  const _JsonCodeBox({
    required this.label,
    required this.jsonContent,
    required this.onCopy,
  });

  final String label;
  final String jsonContent;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
            ),
            child: Row(
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: onCopy,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Kopyala',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: SelectableText(
              jsonContent,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.conflict,
    required this.onResolveLocal,
    required this.onResolveRemote,
    this.onResolveCopy,
    required this.isResolving,
  });

  final SyncConflictEntity conflict;
  final VoidCallback onResolveLocal;
  final VoidCallback onResolveRemote;
  final VoidCallback? onResolveCopy;
  final bool isResolving;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        FilledButton.icon(
          key: Key('btn_resolve_local_${conflict.id}'),
          onPressed: isResolving ? null : onResolveLocal,
          icon: const Icon(Icons.phone_android_rounded, size: 18),
          label: const Text('Bu cihazdaki sürümü koru'),
        ),
        OutlinedButton.icon(
          key: Key('btn_resolve_remote_${conflict.id}'),
          onPressed: isResolving ? null : onResolveRemote,
          icon: const Icon(Icons.cloud_download_outlined, size: 18),
          label: const Text('Uzak sürümü kabul et'),
        ),
        if (conflict.canResolveAsCopy && onResolveCopy != null)
          OutlinedButton.icon(
            key: Key('btn_resolve_copy_${conflict.id}'),
            onPressed: isResolving ? null : onResolveCopy,
            icon: const Icon(Icons.copy_all_rounded, size: 18),
            label: const Text('Kopya olarak iki sürümü de sakla'),
          ),
      ],
    );
  }
}
