import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
import 'package:not_app/core/sync/sync_models.dart';
import 'package:not_app/features/conflicts/presentation/screens/conflicts_screen.dart';

class SyncQueueScreen extends ConsumerStatefulWidget {
  const SyncQueueScreen({super.key});

  @override
  ConsumerState<SyncQueueScreen> createState() => _SyncQueueScreenState();
}

class _SyncQueueScreenState extends ConsumerState<SyncQueueScreen> {
  SyncOperationStatus? _selectedFilter;

  String _formatDateTime(BuildContext context, DateTime dt) {
    final DateTime local = dt.toLocal();
    final MaterialLocalizations loc = MaterialLocalizations.of(context);
    final String time = TimeOfDay.fromDateTime(local).format(context);
    return '${loc.formatShortDate(local)} $time';
  }

  Future<void> _retrySingle(SyncOperation op) async {
    final queue = ref.read(syncQueueRepositoryProvider);
    final coordinator = ref.read(syncCoordinatorProvider);
    await queue.retryOperation(op.id);
    await coordinator.syncNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('İşlem yeniden deneme için sıraya alındı.'),
        ),
      );
  }

  Future<void> _retryAll() async {
    final queue = ref.read(syncQueueRepositoryProvider);
    final coordinator = ref.read(syncCoordinatorProvider);
    await queue.retryAll(status: _selectedFilter);
    final result = await coordinator.syncNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Tüm işlemler sıraya alındı (${result.pushed} gönderildi, ${result.pulled} alındı, ${result.conflicts} çakışma).',
          ),
        ),
      );
  }

  Future<void> _deleteSingle(SyncOperation op) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İşlemi kuyruktan kaldır'),
        content: const Text(
          'Bu işlem henüz buluta gönderilmemiş yerel değişiklikleri içerebilir. '
          'Kuyruktan silmek veri kaybına yol açabilir. Devam etmek istiyor musunuz?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kuyruktan Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(syncQueueRepositoryProvider).deleteOperation(op.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İşlem kuyruktan silindi.')));
    }
  }

  Future<void> _clearQueue() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kuyruğu temizle / sıfırla'),
        content: const Text(
          'Kuyruktaki tüm bekleyen ve başarısız senkronizasyon işlemleri silinecektir. '
          'Bu durum henüz eşitlenmemiş yerel değişikliklerin kaybolmasına neden olabilir. '
          'Emin misiniz?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kuyruğu Sıfırla'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(syncQueueRepositoryProvider)
          .clearQueue(status: _selectedFilter);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senkronizasyon kuyruğu temizlendi.')),
      );
    }
  }

  Color _statusColor(BuildContext context, SyncOperationStatus status) {
    switch (status) {
      case SyncOperationStatus.pending:
        return Colors.blue;
      case SyncOperationStatus.processing:
        return Colors.indigo;
      case SyncOperationStatus.retryWaiting:
        return Colors.orange;
      case SyncOperationStatus.failedRecoverable:
        return Theme.of(context).colorScheme.error;
      case SyncOperationStatus.blockedConflict:
        return Colors.purple;
      case SyncOperationStatus.completed:
        return Colors.green;
    }
  }

  IconData _statusIcon(SyncOperationStatus status) {
    switch (status) {
      case SyncOperationStatus.pending:
        return Icons.schedule;
      case SyncOperationStatus.processing:
        return Icons.sync;
      case SyncOperationStatus.retryWaiting:
        return Icons.update;
      case SyncOperationStatus.failedRecoverable:
        return Icons.error_outline;
      case SyncOperationStatus.blockedConflict:
        return Icons.warning_amber_rounded;
      case SyncOperationStatus.completed:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(syncQueueRepositoryProvider);
    final coordinator = ref.watch(syncCoordinatorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Senkronizasyon Kuyruğu'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Şimdi Eşitle',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              final result = await coordinator.syncNow();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Eşitleme tamamlandı (${result.pushed} gönderildi, ${result.pulled} alındı, ${result.conflicts} çakışma).',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StreamBuilder<Map<SyncOperationStatus, int>>(
            stream: queue.watchStatusCounts(),
            initialData: const <SyncOperationStatus, int>{},
            builder: (context, snapshot) {
              final counts =
                  snapshot.data ?? const <SyncOperationStatus, int>{};
              final int pending = counts[SyncOperationStatus.pending] ?? 0;
              final int retry = counts[SyncOperationStatus.retryWaiting] ?? 0;
              final int failed =
                  counts[SyncOperationStatus.failedRecoverable] ?? 0;
              final int conflict =
                  counts[SyncOperationStatus.blockedConflict] ?? 0;
              final int total = pending + retry + failed + conflict;

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              'Kuyruk Durumu',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '$total işlem bekliyor',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _StatusBadge(
                              label: 'Bekleyen: $pending',
                              color: Colors.blue,
                              icon: Icons.schedule,
                            ),
                            _StatusBadge(
                              label: 'Yeniden Denenecek: $retry',
                              color: Colors.orange,
                              icon: Icons.update,
                            ),
                            _StatusBadge(
                              label: 'Başarısız: $failed',
                              color: Theme.of(context).colorScheme.error,
                              icon: Icons.error_outline,
                            ),
                            _StatusBadge(
                              label: 'Çakışmada: $conflict',
                              color: Colors.purple,
                              icon: Icons.warning_amber_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  FilterChip(
                    label: const Text('Tümü'),
                    selected: _selectedFilter == null,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = null);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Bekleyenler'),
                    selected: _selectedFilter == SyncOperationStatus.pending,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = selected
                            ? SyncOperationStatus.pending
                            : null;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Tekrar Denenecek'),
                    selected:
                        _selectedFilter == SyncOperationStatus.retryWaiting,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = selected
                            ? SyncOperationStatus.retryWaiting
                            : null;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Başarısız'),
                    selected:
                        _selectedFilter ==
                        SyncOperationStatus.failedRecoverable,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = selected
                            ? SyncOperationStatus.failedRecoverable
                            : null;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Çakışmada'),
                    selected:
                        _selectedFilter == SyncOperationStatus.blockedConflict,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = selected
                            ? SyncOperationStatus.blockedConflict
                            : null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _retryAll,
                  icon: const Icon(Icons.replay),
                  label: const Text('Tümünü Tekrar Dene'),
                ),
                OutlinedButton.icon(
                  onPressed: _clearQueue,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Kuyruktan Temizle/Sıfırla'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<SyncOperation>>(
              stream: queue.watchOperations(status: _selectedFilter),
              initialData: const <SyncOperation>[],
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorState(message: snapshot.error.toString());
                }
                final operations = snapshot.data ?? const <SyncOperation>[];
                if (operations.isEmpty) {
                  return const EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'Kuyruk boş',
                    message:
                        'Senkronizasyon bekleyen herhangi bir işlem bulunmuyor.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: operations.length,
                  itemBuilder: (context, index) {
                    final op = operations[index];
                    final Color statusColor = _statusColor(context, op.status);
                    final IconData statusIcon = _statusIcon(op.status);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withAlpha(25),
                                    border: Border.all(
                                      color: statusColor.withAlpha(150),
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(
                                        statusIcon,
                                        size: 14,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        op.status.displayName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    op.operationType.displayName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatDateTime(context, op.createdAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              op.targetEntityDisplayName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Varlık: ${op.entityType} · Kimlik: ${op.entityId}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              runSpacing: 4,
                              children: <Widget>[
                                Text(
                                  'Deneme sayısı: ${op.attemptCount}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (op.nextAttemptAt != null)
                                  Text(
                                    'Sonraki deneme: ${_formatDateTime(context, op.nextAttemptAt!)}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                              ],
                            ),
                            if (op.lastError?.trim().isNotEmpty ==
                                true) ...<Widget>[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.errorContainer.withAlpha(40),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.error.withAlpha(100),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Icon(
                                      Icons.error_outline,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Hata: ${op.lastError}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                FilledButton.tonalIcon(
                                  onPressed: () => _retrySingle(op),
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Şimdi Tekrar Dene'),
                                ),
                                if (op.status ==
                                    SyncOperationStatus.blockedConflict)
                                  FilledButton.icon(
                                    onPressed: () => AppRouter.push<void>(
                                      context,
                                      const ConflictsScreen(),
                                    ),
                                    icon: const Icon(
                                      Icons.compare_arrows_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Çakışmaya Git'),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () => _deleteSingle(op),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Kuyruktan Temizle'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
