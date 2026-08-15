import 'package:flutter/material.dart';
import 'package:not_app/app/theme/app_theme.dart';

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({super.key, required this.title, this.subtitle, this.actions = const <Widget>[]});
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.headlineMedium),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            ...actions,
          ],
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 46, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                if (action != null) ...<Widget>[const SizedBox(height: 20), action!],
              ],
            ),
          ),
        ),
      );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Bir sorun oluştu',
        message: message,
        action: onRetry == null ? null : FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Tekrar dene')),
      );
}

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key, required this.pendingCount, required this.cloudConfigured, required this.signedIn});
  final int pendingCount;
  final bool cloudConfigured;
  final bool signedIn;
  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;
    if (!cloudConfigured) {
      icon = Icons.cloud_off_outlined;
      label = 'Yalnız cihaz';
    } else if (!signedIn) {
      icon = Icons.cloud_outlined;
      label = 'Bulut bağlı değil';
    } else if (pendingCount > 0) {
      icon = Icons.sync_rounded;
      label = '$pendingCount değişiklik bekliyor';
    } else {
      icon = Icons.cloud_done_outlined;
      label = 'Senkronize';
    }
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[Icon(icon, size: 18), const SizedBox(width: 6), Text(label, style: Theme.of(context).textTheme.bodySmall)]),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpacing.lg)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: padding, child: child));
}
