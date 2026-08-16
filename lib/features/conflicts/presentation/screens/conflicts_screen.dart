import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/theme/app_theme.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
import 'package:not_app/features/conflicts/domain/entities/sync_conflict.dart';
import 'package:not_app/features/conflicts/domain/repositories/conflict_repository.dart';
import 'package:not_app/features/conflicts/presentation/widgets/conflict_diff_view.dart';

class ConflictsScreen extends ConsumerStatefulWidget {
  const ConflictsScreen({super.key});

  @override
  ConsumerState<ConflictsScreen> createState() => _ConflictsScreenState();
}

class _ConflictsScreenState extends ConsumerState<ConflictsScreen> {
  final Set<String> _resolvingIds = <String>{};

  Future<void> _handleResolution({
    required ConflictRepository repo,
    required SyncConflictEntity item,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    if (_resolvingIds.contains(item.id)) return;

    setState(() {
      _resolvingIds.add(item.id);
    });

    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Çakışma çözülemedi: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _resolvingIds.remove(item.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(conflictRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Senkronizasyon çakışmaları')),
      body: StreamBuilder<List<SyncConflictEntity>>(
        stream: repo.watchOpen(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorState(
              message: snapshot.error.toString(),
              onRetry: () => setState(() {}),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.requireData;
          if (data.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Çakışma yok',
              message:
                  'Cihazlar arasındaki tüm değişiklikler uyumlu ve güncel.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              final bool isResolving = _resolvingIds.contains(item.id);

              return Card(
                key: Key('conflict_card_${item.id}'),
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ConflictDiffView(
                    conflict: item,
                    isResolving: isResolving,
                    onResolveLocal: () => _handleResolution(
                      repo: repo,
                      item: item,
                      action: () => repo.resolveUsingLocal(item.id),
                      successMessage:
                          '${item.displayTitle} için bu cihazdaki sürüm korundu.',
                    ),
                    onResolveRemote: () => _handleResolution(
                      repo: repo,
                      item: item,
                      action: () => repo.resolveUsingRemote(item.id),
                      successMessage:
                          '${item.displayTitle} için uzak sürüm kabul edildi.',
                    ),
                    onResolveCopy: item.canResolveAsCopy
                        ? () => _handleResolution(
                            repo: repo,
                            item: item,
                            action: () => repo.resolveAsCopy(item.id),
                            successMessage:
                                '${item.displayTitle} için iki sürüm de kopya olarak saklandı.',
                          )
                        : null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
