import 'package:flutter/material.dart';

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    this.textFieldKey,
    this.focusNode,
    this.autofocus = false,
    this.hintText = 'Ara…',
    this.shortcutLabel,
    this.busy = false,
    this.onClear,
    this.onSubmitted,
  });

  final Key? textFieldKey;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final String hintText;
  final String? shortcutLabel;
  final bool busy;
  final VoidCallback? onClear;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: textFieldKey,
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        hintText: hintText,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        suffixIcon: busy
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : controller.text.isNotEmpty && onClear != null
            ? IconButton(
                tooltip: 'Aramayı temizle',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
              )
            : shortcutLabel == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    shortcutLabel!,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
      ),
    );
  }
}
