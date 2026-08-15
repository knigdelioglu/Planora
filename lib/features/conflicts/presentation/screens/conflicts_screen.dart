import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
import 'package:not_app/features/conflicts/domain/entities/sync_conflict.dart';

class ConflictsScreen extends ConsumerWidget {
  const ConflictsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(conflictRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Senkronizasyon çakışmaları')),
      body: StreamBuilder<List<SyncConflictEntity>>(
        stream: repo.watchOpen(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return ErrorState(message: snapshot.error.toString());
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final data = snapshot.requireData;
          if (data.isEmpty)
            return const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Çakışma yok',
              message: 'Cihazlar arasındaki değişiklikler uyumlu.',
            );
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: const Icon(Icons.compare_arrows_rounded),
                  title: Text('${item.entityType} · ${item.entityId}'),
                  subtitle: Text(
                    'İki cihaz aynı kaydı farklı biçimde değiştirdi.',
                  ),
                  childrenPadding: const EdgeInsets.all(16),
                  children: <Widget>[
                    _JsonPreview(label: 'Bu cihaz', raw: item.localJson),
                    const SizedBox(height: 12),
                    _JsonPreview(label: 'Diğer cihaz', raw: item.remoteJson),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton(
                          onPressed: () => repo.resolveUsingLocal(item.id),
                          child: const Text('Bu sürümü kullan'),
                        ),
                        OutlinedButton(
                          onPressed: () => repo.resolveUsingRemote(item.id),
                          child: const Text('Diğer sürümü kullan'),
                        ),
                        OutlinedButton(
                          onPressed: () => repo.resolveAsCopy(item.id),
                          child: const Text('Kopya olarak sakla'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _JsonPreview extends StatelessWidget {
  const _JsonPreview({required this.label, required this.raw});
  final String label;
  final String raw;
  @override
  Widget build(BuildContext context) {
    String pretty = raw;
    try {
      pretty = const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {}
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        SelectableText(
          pretty,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
