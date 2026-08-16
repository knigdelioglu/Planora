import 'package:flutter/material.dart';
import 'package:not_app/features/notes/domain/entities/note_document.dart';

enum SlashCommandId {
  paragraph,
  heading1,
  heading2,
  heading3,
  bulletList,
  numberedList,
  checkbox,
  quote,
  code,
  divider,
  attachment,
}

class SlashCommandItem {
  const SlashCommandItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.blockType,
    this.level,
    this.keywords = const <String>[],
  });

  final SlashCommandId id;
  final String title;
  final String subtitle;
  final IconData icon;
  final NoteBlockType? blockType;
  final int? level;
  final List<String> keywords;
}

const List<SlashCommandItem> defaultSlashCommands = <SlashCommandItem>[
  SlashCommandItem(
    id: SlashCommandId.paragraph,
    title: 'Paragraf',
    subtitle: 'Düz metin yazmaya başlayın',
    icon: Icons.notes_outlined,
    blockType: NoteBlockType.paragraph,
    keywords: ['paragraf', 'metin', 'text', 'yazı', 'p', 'düz'],
  ),
  SlashCommandItem(
    id: SlashCommandId.heading1,
    title: 'Başlık 1',
    subtitle: 'Büyük bölüm başlığı',
    icon: Icons.title_outlined,
    blockType: NoteBlockType.heading,
    level: 1,
    keywords: ['başlık 1', 'h1', 'baslik 1', 'büyük başlık', 'title', 'başlık'],
  ),
  SlashCommandItem(
    id: SlashCommandId.heading2,
    title: 'Başlık 2',
    subtitle: 'Orta alt başlık',
    icon: Icons.format_size_outlined,
    blockType: NoteBlockType.heading,
    level: 2,
    keywords: [
      'başlık 2',
      'h2',
      'baslik 2',
      'orta başlık',
      'subtitle',
      'alt başlık',
    ],
  ),
  SlashCommandItem(
    id: SlashCommandId.heading3,
    title: 'Başlık 3',
    subtitle: 'Küçük alt başlık',
    icon: Icons.text_fields_outlined,
    blockType: NoteBlockType.heading,
    level: 3,
    keywords: ['başlık 3', 'h3', 'baslik 3', 'küçük başlık', 'sub', 'küçük'],
  ),
  SlashCommandItem(
    id: SlashCommandId.bulletList,
    title: 'Madde Listesi',
    subtitle: 'Noktalı madde işaretli liste',
    icon: Icons.format_list_bulleted,
    blockType: NoteBlockType.bulletList,
    keywords: ['madde', 'madde listesi', 'bullet', 'nokta', 'liste', 'ul'],
  ),
  SlashCommandItem(
    id: SlashCommandId.numberedList,
    title: 'Numaralı Liste',
    subtitle: 'Sıralı 1, 2, 3 listesi',
    icon: Icons.format_list_numbered,
    blockType: NoteBlockType.numberedList,
    keywords: ['numaralı', 'numara', 'number', 'sıralı', 'liste', 'ol', 'sayı'],
  ),
  SlashCommandItem(
    id: SlashCommandId.checkbox,
    title: 'Yapılacaklar',
    subtitle: 'Onay kutulu görev listesi',
    icon: Icons.check_box_outlined,
    blockType: NoteBlockType.checkbox,
    keywords: [
      'yapılacak',
      'yapılacaklar',
      'todo',
      'görev',
      'task',
      'checkbox',
      'check',
      'kutucuk',
    ],
  ),
  SlashCommandItem(
    id: SlashCommandId.quote,
    title: 'Alıntı',
    subtitle: 'Vurgulu alıntı metni',
    icon: Icons.format_quote_outlined,
    blockType: NoteBlockType.quote,
    keywords: ['alıntı', 'alinti', 'quote', 'blockquote', 'blok'],
  ),
  SlashCommandItem(
    id: SlashCommandId.code,
    title: 'Kod Bloğu',
    subtitle: 'Tek satır veya çok satırlı kod',
    icon: Icons.code_outlined,
    blockType: NoteBlockType.code,
    keywords: ['kod', 'kod bloğu', 'code', 'snippet', 'programlama'],
  ),
  SlashCommandItem(
    id: SlashCommandId.divider,
    title: 'Ayraç',
    subtitle: 'Görsel yatay ayırıcı çizgi',
    icon: Icons.horizontal_rule,
    blockType: NoteBlockType.divider,
    keywords: [
      'ayraç',
      'ayrac',
      'divider',
      'çizgi',
      'hr',
      'separator',
      'bölücü',
    ],
  ),
  SlashCommandItem(
    id: SlashCommandId.attachment,
    title: 'Ek Dosya',
    subtitle: 'Cihazdan dosya veya görsel ekleyin',
    icon: Icons.attach_file,
    keywords: [
      'ek dosya',
      'ek',
      'dosya',
      'file',
      'attachment',
      'görsel',
      'resim',
      'image',
      'upload',
    ],
  ),
];

List<SlashCommandItem> filterSlashCommands(
  String query, {
  List<SlashCommandItem> commands = defaultSlashCommands,
}) {
  final clean = query.startsWith('/')
      ? query.substring(1).trim().toLowerCase()
      : query.trim().toLowerCase();
  if (clean.isEmpty) return commands;
  return commands
      .where((cmd) {
        if (cmd.title.toLowerCase().contains(clean)) return true;
        if (cmd.subtitle.toLowerCase().contains(clean)) return true;
        return cmd.keywords.any((k) => k.toLowerCase().contains(clean));
      })
      .toList(growable: false);
}

class SlashCommandPalette extends StatelessWidget {
  const SlashCommandPalette({
    super.key,
    required this.query,
    required this.selectedIndex,
    required this.onSelect,
    required this.onClose,
    this.commands = defaultSlashCommands,
    this.maxHeight = 320,
  });

  final String query;
  final int selectedIndex;
  final ValueChanged<SlashCommandItem> onSelect;
  final VoidCallback onClose;
  final List<SlashCommandItem> commands;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = filterSlashCommands(query, commands: commands);

    return TextFieldTapRegion(
      child: Material(
        key: const Key('slash_command_palette'),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: BoxConstraints(maxWidth: 380, maxHeight: maxHeight),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      'BLOK EKLE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '↑↓ Gezin · ↵ Seç',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Center(
                    child: Text(
                      'Eşleşen komut bulunamadı',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List<Widget>.generate(filtered.length, (index) {
                        final item = filtered[index];
                        final isSelected =
                            index == selectedIndex.clamp(0, filtered.length - 1);

                        return InkWell(
                          key: ValueKey('slash_item_${item.id.name}'),
                          onTap: () => onSelect(item),
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primaryContainer.withValues(
                                      alpha: 0.45,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(
                                      color: theme.colorScheme.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withValues(
                                            alpha: 0.15,
                                          )
                                        : theme
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    size: 18,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        item.title,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              color: theme.colorScheme.onSurface,
                                            ),
                                      ),
                                      Text(
                                        item.subtitle,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontSize: 11,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.keyboard_return,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
