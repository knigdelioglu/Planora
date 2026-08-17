import 'package:flutter/material.dart';
import 'package:not_app/app/widgets/overlays/app_sheet.dart';

const List<String> kanbanColorPalette = <String>[
  '#4F46E5',
  '#2563EB',
  '#0891B2',
  '#059669',
  '#65A30D',
  '#D97706',
  '#EA580C',
  '#DC2626',
  '#DB2777',
  '#7C3AED',
];

Color? colorFromHex(String? value) {
  if (value == null) return null;
  final String clean = value.trim().replaceFirst('#', '');
  if (clean.length != 6) return null;
  final int? rgb = int.tryParse(clean, radix: 16);
  if (rgb == null) return null;
  return Color(0xFF000000 | rgb);
}

Color tintedSurface(
  BuildContext context,
  Color? base, {
  double opacity = 0.12,
}) {
  final Color surface = Theme.of(context).colorScheme.surface;
  if (base == null) return surface;
  final double alpha = opacity.clamp(0.0, 1.0).toDouble();
  return Color.alphaBlend(base.withValues(alpha: alpha), surface);
}

class TitleColorValue {
  const TitleColorValue({required this.title, required this.colorHex});

  final String title;
  final String? colorHex;
}

class ColorPickerValue {
  const ColorPickerValue(this.colorHex);

  final String? colorHex;
}

Future<ColorPickerValue?> showEntityColorDialog(
  BuildContext context, {
  required String dialogTitle,
  String? initialColorHex,
  String defaultLabel = 'Varsayılan',
}) {
  return showAppSheet<ColorPickerValue>(
    context: context,
    builder: (sheetContext) => _ColorEditor(
      title: dialogTitle,
      initialColorHex: initialColorHex,
      defaultLabel: defaultLabel,
    ),
  );
}

Future<TitleColorValue?> showTitleColorDialog(
  BuildContext context, {
  required String dialogTitle,
  required String fieldLabel,
  String initialTitle = '',
  String? initialColorHex,
  required String confirmLabel,
}) {
  return showAppSheet<TitleColorValue>(
    context: context,
    builder: (sheetContext) => _TitleColorEditor(
      title: dialogTitle,
      fieldLabel: fieldLabel,
      initialTitle: initialTitle,
      initialColorHex: initialColorHex,
      confirmLabel: confirmLabel,
    ),
  );
}

class _ColorEditor extends StatefulWidget {
  const _ColorEditor({
    required this.title,
    required this.initialColorHex,
    required this.defaultLabel,
  });

  final String title;
  final String? initialColorHex;
  final String defaultLabel;

  @override
  State<_ColorEditor> createState() => _ColorEditorState();
}

class _ColorEditorState extends State<_ColorEditor> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialColorHex;
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      AppSheetHeader(title: widget.title),
      const Divider(height: 1),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Renk', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ChoiceChip(
                    label: Text(widget.defaultLabel),
                    selected: _selected == null,
                    onSelected: (_) => setState(() => _selected = null),
                  ),
                  ...kanbanColorPalette.map(
                    (hex) => ChoiceChip(
                      avatar: CircleAvatar(backgroundColor: colorFromHex(hex)),
                      label: const SizedBox(width: 6),
                      selected: _selected == hex,
                      onSelected: (_) => setState(() => _selected = hex),
                      tooltip: hex,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(ColorPickerValue(_selected)),
            child: const Text('Bitti'),
          ),
        ),
      ),
    ],
  );
}

class _TitleColorEditor extends StatefulWidget {
  const _TitleColorEditor({
    required this.title,
    required this.fieldLabel,
    required this.initialTitle,
    required this.initialColorHex,
    required this.confirmLabel,
  });

  final String title;
  final String fieldLabel;
  final String initialTitle;
  final String? initialColorHex;
  final String confirmLabel;

  @override
  State<_TitleColorEditor> createState() => _TitleColorEditorState();
}

class _TitleColorEditorState extends State<_TitleColorEditor> {
  late final TextEditingController _controller;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
    _selected = widget.initialColorHex;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(
      context,
    ).pop(TitleColorValue(title: title, colorHex: _selected));
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      AppSheetHeader(title: widget.title),
      const Divider(height: 1),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(labelText: widget.fieldLabel),
              ),
              const SizedBox(height: 20),
              Text('Renk', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('Varsayılan'),
                    selected: _selected == null,
                    onSelected: (_) => setState(() => _selected = null),
                  ),
                  ...kanbanColorPalette.map(
                    (hex) => ChoiceChip(
                      avatar: CircleAvatar(backgroundColor: colorFromHex(hex)),
                      label: const SizedBox(width: 6),
                      selected: _selected == hex,
                      onSelected: (_) => setState(() => _selected = hex),
                      tooltip: hex,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submit,
            child: Text(widget.confirmLabel),
          ),
        ),
      ),
    ],
  );
}
