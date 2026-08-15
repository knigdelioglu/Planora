import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/app/theme/app_theme.dart';
import 'package:not_app/app/widgets/common_widgets.dart';

void main() {
  testWidgets('empty state is accessible and renders its action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: EmptyState(
            icon: Icons.note,
            title: 'Henüz not yok',
            message: 'İlk notunuzu oluşturun.',
          ),
        ),
      ),
    );
    expect(find.text('Henüz not yok'), findsOneWidget);
    expect(find.byIcon(Icons.note), findsOneWidget);
  });
}
