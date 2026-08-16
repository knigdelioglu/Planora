import 'package:flutter/material.dart';

enum TextFormatType { bold, italic, strikethrough, underline, inlineCode, link }

class TextFormattingHelper {
  const TextFormattingHelper._();

  static Set<TextFormatType> detectActiveFormats(TextEditingValue value) {
    if (!value.selection.isValid || value.selection.isCollapsed) {
      return const <TextFormatType>{};
    }
    final text = value.text;
    final start = value.selection.start;
    final end = value.selection.end;
    if (start < 0 || end > text.length || start >= end) {
      return const <TextFormatType>{};
    }
    final selectedText = text.substring(start, end);
    final active = <TextFormatType>{};

    if (selectedText.startsWith('**') &&
        selectedText.endsWith('**') &&
        selectedText.length >= 4) {
      active.add(TextFormatType.bold);
    }
    if (selectedText.startsWith('*') &&
        selectedText.endsWith('*') &&
        !selectedText.startsWith('**') &&
        selectedText.length >= 2) {
      active.add(TextFormatType.italic);
    }
    if (selectedText.startsWith('~~') &&
        selectedText.endsWith('~~') &&
        selectedText.length >= 4) {
      active.add(TextFormatType.strikethrough);
    }
    if (selectedText.startsWith('<u>') &&
        selectedText.endsWith('</u>') &&
        selectedText.length >= 7) {
      active.add(TextFormatType.underline);
    }
    if (selectedText.startsWith('`') &&
        selectedText.endsWith('`') &&
        selectedText.length >= 2) {
      active.add(TextFormatType.inlineCode);
    }
    if (RegExp(r'^\[.*\]\(.*\)').hasMatch(selectedText)) {
      active.add(TextFormatType.link);
    }

    return active;
  }

  static TextEditingValue applyFormat({
    required TextEditingValue value,
    required TextFormatType format,
    String? linkUrl,
  }) {
    final text = value.text;
    final selection = value.selection;
    if (!selection.isValid) return value;

    final start = selection.start;
    final end = selection.end;

    if (selection.isCollapsed) {
      final (prefix, suffix) = switch (format) {
        TextFormatType.bold => ('**', '**'),
        TextFormatType.italic => ('*', '*'),
        TextFormatType.strikethrough => ('~~', '~~'),
        TextFormatType.underline => ('<u>', '</u>'),
        TextFormatType.inlineCode => ('`', '`'),
        TextFormatType.link => ('[', '](${linkUrl ?? "https://"})'),
      };
      final newText = text.replaceRange(start, start, '$prefix$suffix');
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + prefix.length),
      );
    }

    final selectedText = text.substring(start, end);

    switch (format) {
      case TextFormatType.bold:
        if (selectedText.startsWith('**') &&
            selectedText.endsWith('**') &&
            selectedText.length >= 4) {
          final unwrapped = selectedText.substring(2, selectedText.length - 2);
          return _replaceSelection(value, unwrapped);
        }
        return _replaceSelection(value, '**$selectedText**');

      case TextFormatType.italic:
        if (selectedText.startsWith('*') &&
            selectedText.endsWith('*') &&
            !selectedText.startsWith('**') &&
            selectedText.length >= 2) {
          final unwrapped = selectedText.substring(1, selectedText.length - 1);
          return _replaceSelection(value, unwrapped);
        }
        return _replaceSelection(value, '*$selectedText*');

      case TextFormatType.strikethrough:
        if (selectedText.startsWith('~~') &&
            selectedText.endsWith('~~') &&
            selectedText.length >= 4) {
          final unwrapped = selectedText.substring(2, selectedText.length - 2);
          return _replaceSelection(value, unwrapped);
        }
        return _replaceSelection(value, '~~$selectedText~~');

      case TextFormatType.underline:
        if (selectedText.startsWith('<u>') &&
            selectedText.endsWith('</u>') &&
            selectedText.length >= 7) {
          final unwrapped = selectedText.substring(3, selectedText.length - 4);
          return _replaceSelection(value, unwrapped);
        }
        return _replaceSelection(value, '<u>$selectedText</u>');

      case TextFormatType.inlineCode:
        if (selectedText.startsWith('`') &&
            selectedText.endsWith('`') &&
            selectedText.length >= 2) {
          final unwrapped = selectedText.substring(1, selectedText.length - 1);
          return _replaceSelection(value, unwrapped);
        }
        return _replaceSelection(value, '`$selectedText`');

      case TextFormatType.link:
        final url = (linkUrl != null && linkUrl.isNotEmpty)
            ? linkUrl
            : 'https://';
        final linkReg = RegExp(r'^\[(.*)\]\((.*)\)$');
        final match = linkReg.firstMatch(selectedText);
        if (match != null) {
          final label = match.group(1) ?? '';
          return _replaceSelection(value, label);
        }
        return _replaceSelection(value, '[$selectedText]($url)');
    }
  }

  static TextEditingValue _replaceSelection(
    TextEditingValue value,
    String replacement,
  ) {
    final start = value.selection.start;
    final end = value.selection.end;
    final newText = value.text.replaceRange(start, end, replacement);
    return TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + replacement.length,
      ),
    );
  }
}

class FormattedTextEditingController extends TextEditingController {
  FormattedTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final text = this.text;
    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }
    return FormattedSpanBuilder.build(text, baseStyle);
  }
}

class FormattedSpanBuilder {
  const FormattedSpanBuilder._();

  static TextSpan build(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(
      r'(\*\*[^*]+\*\*)|(\*[^*]+\*)|(~~[^~]+~~)|(<u>.*?<\/u>)|(`[^`]+`)|(\[[^\]]+\]\([^)]+\))',
    );

    int lastIndex = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      final matchedStr = match.group(0)!;
      if (matchedStr.startsWith('**') && matchedStr.endsWith('**')) {
        spans.add(
          TextSpan(
            text: matchedStr,
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (matchedStr.startsWith('*') && matchedStr.endsWith('*')) {
        spans.add(
          TextSpan(
            text: matchedStr,
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (matchedStr.startsWith('~~') && matchedStr.endsWith('~~')) {
        spans.add(
          TextSpan(
            text: matchedStr,
            style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
          ),
        );
      } else if (matchedStr.startsWith('<u>') && matchedStr.endsWith('</u>')) {
        spans.add(
          TextSpan(
            text: matchedStr,
            style: baseStyle.copyWith(decoration: TextDecoration.underline),
          ),
        );
      } else if (matchedStr.startsWith('`') && matchedStr.endsWith('`')) {
        spans.add(
          TextSpan(
            text: matchedStr,
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor: Colors.black.withValues(alpha: 0.06),
            ),
          ),
        );
      } else if (matchedStr.startsWith('[') && matchedStr.contains('](')) {
        spans.add(
          TextSpan(
            text: matchedStr,
            style: baseStyle.copyWith(
              color: const Color(0xFF5B57D9),
              decoration: TextDecoration.underline,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: matchedStr, style: baseStyle));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }

    return TextSpan(children: spans, style: baseStyle);
  }
}

class FormattingToolbar extends StatefulWidget {
  const FormattingToolbar({
    super.key,
    required this.onFormat,
    this.activeFormats = const <TextFormatType>{},
    this.onClose,
  });

  final void Function(TextFormatType format, {String? url}) onFormat;
  final Set<TextFormatType> activeFormats;
  final VoidCallback? onClose;

  @override
  State<FormattingToolbar> createState() => _FormattingToolbarState();
}

class _FormattingToolbarState extends State<FormattingToolbar> {
  bool _showLinkInput = false;
  final TextEditingController _urlController = TextEditingController(
    text: 'https://',
  );

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _submitLink() {
    final url = _urlController.text.trim();
    widget.onFormat(TextFormatType.link, url: url.isEmpty ? 'https://' : url);
    setState(() => _showLinkInput = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      key: const Key('formatting_toolbar'),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(10),
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: _showLinkInput
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: 200,
                    height: 36,
                    child: TextField(
                      key: const Key('format_link_url_input'),
                      controller: _urlController,
                      autofocus: true,
                      style: theme.textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'https://...',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _submitLink(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: const Key('format_link_url_submit'),
                    tooltip: 'Uygula',
                    icon: const Icon(Icons.check, size: 18),
                    onPressed: _submitLink,
                  ),
                  IconButton(
                    tooltip: 'Vazgeç',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _showLinkInput = false),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _FormatButton(
                    key: const Key('format_bold_button'),
                    icon: Icons.format_bold,
                    tooltip: 'Kalın (Bold)',
                    isActive: widget.activeFormats.contains(
                      TextFormatType.bold,
                    ),
                    onPressed: () => widget.onFormat(TextFormatType.bold),
                  ),
                  _FormatButton(
                    key: const Key('format_italic_button'),
                    icon: Icons.format_italic,
                    tooltip: 'İtalik (Italic)',
                    isActive: widget.activeFormats.contains(
                      TextFormatType.italic,
                    ),
                    onPressed: () => widget.onFormat(TextFormatType.italic),
                  ),
                  _FormatButton(
                    key: const Key('format_strikethrough_button'),
                    icon: Icons.format_strikethrough,
                    tooltip: 'Üstü Çizili',
                    isActive: widget.activeFormats.contains(
                      TextFormatType.strikethrough,
                    ),
                    onPressed: () =>
                        widget.onFormat(TextFormatType.strikethrough),
                  ),
                  _FormatButton(
                    key: const Key('format_underline_button'),
                    icon: Icons.format_underlined,
                    tooltip: 'Altı Çizili',
                    isActive: widget.activeFormats.contains(
                      TextFormatType.underline,
                    ),
                    onPressed: () => widget.onFormat(TextFormatType.underline),
                  ),
                  _FormatButton(
                    key: const Key('format_inline_code_button'),
                    icon: Icons.code,
                    tooltip: 'Satır İçi Kod',
                    isActive: widget.activeFormats.contains(
                      TextFormatType.inlineCode,
                    ),
                    onPressed: () => widget.onFormat(TextFormatType.inlineCode),
                  ),
                  Container(
                    height: 20,
                    width: 1,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                  ),
                  _FormatButton(
                    key: const Key('format_link_button'),
                    icon: Icons.link,
                    tooltip: 'Bağlantı',
                    isActive: widget.activeFormats.contains(
                      TextFormatType.link,
                    ),
                    onPressed: () {
                      if (widget.activeFormats.contains(TextFormatType.link)) {
                        widget.onFormat(TextFormatType.link);
                      } else {
                        setState(() => _showLinkInput = true);
                      }
                    },
                  ),
                  if (widget.onClose != null) ...<Widget>[
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      tooltip: 'Kapat',
                      onPressed: widget.onClose,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
