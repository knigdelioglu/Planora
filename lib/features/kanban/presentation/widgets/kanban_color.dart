import 'package:flutter/material.dart';

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

class TitleColorValue {
  const TitleColorValue({required this.title, required this.colorHex});

  final String title;
  final String? colorHex;
}

Future<TitleColorValue?> showTitleColorDialog(
  BuildContext context, {
  required String dialogTitle,
  required String fieldLabel,
  String initialTitle = '',
  String? initialColorHex,
  required String confirmLabel,
}) async {
  final TextEditingController controller = TextEditingController(
    text: initialTitle,
  );
  String? selected = initialColorHex;

  final TitleColorValue? result = await showDialog<TitleColorValue>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(dialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(labelText: fieldLabel),
              ),
              const SizedBox(height: 16),
              Text('Renk', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('Varsayılan'),
                    selected: selected == null,
                    onSelected: (_) => setDialogState(() => selected = null),
                  ),
                  ...kanbanColorPalette.map(
                    (hex) => ChoiceChip(
                      avatar: CircleAvatar(backgroundColor: colorFromHex(hex)),
                      label: const Text(''),
                      selected: selected == hex,
                      onSelected: (_) => setDialogState(() => selected = hex),
                      tooltip: hex,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              final String title = controller.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(
                context,
                TitleColorValue(title: title, colorHex: selected),
              );
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );

  controller.dispose();
  return result;
}
