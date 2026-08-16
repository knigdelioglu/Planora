import 'package:flutter/material.dart';
import 'package:not_app/app/theme/app_theme.dart';

/// App page header with title, optional subtitle, and actions.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
  });
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
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
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

/// Standard empty state container.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
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
            Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: action!,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Standard error state container.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.error_outline_rounded,
    title: 'Bir sorun oluştu',
    message: message,
    action: onRetry == null
        ? null
        : AppButton.filled(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: 'Tekrar dene',
            tooltip: 'İşlemi tekrar dene',
          ),
  );
}

/// Sync status indicator widget.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({
    super.key,
    required this.pendingCount,
    required this.cloudConfigured,
    required this.signedIn,
    required this.isSyncing,
    required this.isOnline,
    required this.lastSuccessfulSyncAt,
    required this.lastError,
  });
  final int pendingCount;
  final bool cloudConfigured;
  final bool signedIn;
  final bool isSyncing;
  final bool? isOnline;
  final DateTime? lastSuccessfulSyncAt;
  final String? lastError;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;
    String tooltip;
    if (!cloudConfigured) {
      icon = Icons.cloud_off_outlined;
      label = 'Yalnız cihaz';
      tooltip = label;
    } else if (!signedIn) {
      icon = Icons.cloud_outlined;
      label = 'Bulut bağlı değil';
      tooltip = label;
    } else if (isSyncing) {
      icon = Icons.sync_rounded;
      label = 'Eşitleniyor…';
      tooltip = label;
    } else if (isOnline == false) {
      icon = Icons.cloud_off_outlined;
      label = 'Çevrimdışı';
      tooltip = lastSuccessfulSyncAt == null
          ? label
          : '$label · Son başarılı eşitleme mevcut';
    } else if (lastError?.trim().isNotEmpty == true) {
      icon = Icons.cloud_off_outlined;
      label = 'Senkronizasyon sorunu';
      tooltip = '$label: $lastError';
    } else if (pendingCount > 0) {
      icon = Icons.sync_rounded;
      label = '$pendingCount değişiklik bekliyor';
      tooltip = label;
    } else if (lastSuccessfulSyncAt == null) {
      icon = Icons.cloud_queue_outlined;
      label = 'Henüz eşitlenmedi';
      tooltip = label;
    } else {
      icon = Icons.cloud_done_outlined;
      label = 'Senkronize';
      final DateTime local = lastSuccessfulSyncAt!.toLocal();
      tooltip =
          '$label · ${MaterialLocalizations.of(context).formatShortDate(local)} ${TimeOfDay.fromDateTime(local).format(context)}';
    }
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Backwards-compatible section card.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

/// Button variants for [AppButton].
enum AppButtonVariant { filled, outlined, text, danger }

/// Standardized accessible button component with full 48x48 dp touch target,
/// semantic labels, loading state indicator, tooltips, and keyboard focus styling.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.tooltip,
    this.semanticLabel,
    this.isLoading = false,
    this.isFullWidth = false,
    this.variant = AppButtonVariant.filled,
    this.focusNode,
    this.autofocus = false,
    this.minWidth,
    this.minHeight = 48.0,
  });

  const AppButton.filled({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.tooltip,
    this.semanticLabel,
    this.isLoading = false,
    this.isFullWidth = false,
    this.focusNode,
    this.autofocus = false,
    this.minWidth,
    this.minHeight = 48.0,
  }) : variant = AppButtonVariant.filled;

  const AppButton.outlined({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.tooltip,
    this.semanticLabel,
    this.isLoading = false,
    this.isFullWidth = false,
    this.focusNode,
    this.autofocus = false,
    this.minWidth,
    this.minHeight = 48.0,
  }) : variant = AppButtonVariant.outlined;

  const AppButton.text({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.tooltip,
    this.semanticLabel,
    this.isLoading = false,
    this.isFullWidth = false,
    this.focusNode,
    this.autofocus = false,
    this.minWidth,
    this.minHeight = 48.0,
  }) : variant = AppButtonVariant.text;

  const AppButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.tooltip,
    this.semanticLabel,
    this.isLoading = false,
    this.isFullWidth = false,
    this.focusNode,
    this.autofocus = false,
    this.minWidth,
    this.minHeight = 48.0,
  }) : variant = AppButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final String? tooltip;
  final String? semanticLabel;
  final bool isLoading;
  final bool isFullWidth;
  final AppButtonVariant variant;
  final FocusNode? focusNode;
  final bool autofocus;
  final double? minWidth;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final VoidCallback? effectiveOnPressed = isLoading ? null : onPressed;

    Widget childContent;
    if (isLoading) {
      childContent = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == AppButtonVariant.filled ||
                        variant == AppButtonVariant.danger
                    ? Colors.white
                    : theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    } else if (icon != null) {
      childContent = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[icon!, const SizedBox(width: 8), Text(label)],
      );
    } else {
      childContent = Text(label);
    }

    final Size minSize = Size(
      minWidth ?? (isFullWidth ? double.infinity : 48.0),
      minHeight,
    );

    Widget button;
    switch (variant) {
      case AppButtonVariant.filled:
        button = FilledButton(
          onPressed: effectiveOnPressed,
          focusNode: focusNode,
          autofocus: autofocus,
          style: FilledButton.styleFrom(minimumSize: minSize),
          child: childContent,
        );
        break;
      case AppButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: effectiveOnPressed,
          focusNode: focusNode,
          autofocus: autofocus,
          style: OutlinedButton.styleFrom(minimumSize: minSize),
          child: childContent,
        );
        break;
      case AppButtonVariant.text:
        button = TextButton(
          onPressed: effectiveOnPressed,
          focusNode: focusNode,
          autofocus: autofocus,
          style: TextButton.styleFrom(minimumSize: minSize),
          child: childContent,
        );
        break;
      case AppButtonVariant.danger:
        button = FilledButton(
          onPressed: effectiveOnPressed,
          focusNode: focusNode,
          autofocus: autofocus,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            minimumSize: minSize,
          ),
          child: childContent,
        );
        break;
    }

    if (isFullWidth) {
      button = SizedBox(width: double.infinity, child: button);
    }

    if (semanticLabel != null || isLoading) {
      final String semLabel =
          semanticLabel ?? (isLoading ? '$label (Yükleniyor)' : label);
      button = Semantics(
        label: semLabel,
        button: true,
        enabled: effectiveOnPressed != null,
        container: true,
        child: button,
      );
    }

    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minWidth ?? 48.0,
        minHeight: minHeight,
      ),
      child: button,
    );
  }
}

/// Standard accessible text input field.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.label,
    this.hintText,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.maxLines = 1,
    this.minLines,
    this.semanticLabel,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? label;
  final String? hintText;
  final String? errorText;
  final String? helperText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final int? maxLines;
  final int? minLines;
  final String? semanticLabel;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget field = TextFormField(
      controller: controller,
      initialValue: initialValue,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      enabled: enabled,
      autofocus: autofocus,
      focusNode: focusNode,
      maxLines: maxLines,
      minLines: minLines,
      readOnly: readOnly,
      onTap: onTap,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        errorText: errorText,
        helperText: helperText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );

    if (semanticLabel != null) {
      field = Semantics(label: semanticLabel, child: field);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48.0),
      child: field,
    );
  }
}

/// Status types for [AppStatusChip].
enum AppStatusType { neutral, success, warning, error, info, syncing }

/// Standardized status chip / badge.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    this.icon,
    this.statusType = AppStatusType.neutral,
    this.tooltip,
    this.semanticLabel,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final AppStatusType statusType;
  final String? tooltip;
  final String? semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    Color bgColor;
    Color fgColor;
    IconData? effectiveIcon = icon;

    switch (statusType) {
      case AppStatusType.neutral:
        bgColor = isDark ? AppColors.darkSubtle : AppColors.lightSubtle;
        fgColor = isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
        break;
      case AppStatusType.success:
        bgColor = isDark
            ? AppColors.successContainerDark
            : AppColors.successContainerLight;
        fgColor = isDark
            ? AppColors.onSuccessContainerDark
            : AppColors.onSuccessContainerLight;
        effectiveIcon ??= Icons.check_circle_outline_rounded;
        break;
      case AppStatusType.warning:
        bgColor = isDark
            ? AppColors.warningContainerDark
            : AppColors.warningContainerLight;
        fgColor = isDark
            ? AppColors.onWarningContainerDark
            : AppColors.onWarningContainerLight;
        effectiveIcon ??= Icons.warning_amber_rounded;
        break;
      case AppStatusType.error:
        bgColor = isDark
            ? AppColors.errorContainerDark
            : AppColors.errorContainerLight;
        fgColor = isDark
            ? AppColors.onErrorContainerDark
            : AppColors.onErrorContainerLight;
        effectiveIcon ??= Icons.error_outline_rounded;
        break;
      case AppStatusType.info:
        bgColor = isDark
            ? AppColors.infoContainerDark
            : AppColors.infoContainerLight;
        fgColor = isDark
            ? AppColors.onInfoContainerDark
            : AppColors.onInfoContainerLight;
        effectiveIcon ??= Icons.info_outline_rounded;
        break;
      case AppStatusType.syncing:
        bgColor = isDark ? AppColors.darkSelected : AppColors.lightSelected;
        fgColor = isDark ? AppColors.darkAccent : AppColors.lightAccent;
        effectiveIcon ??= Icons.sync_rounded;
        break;
    }

    Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fgColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (effectiveIcon != null) ...<Widget>[
            Icon(effectiveIcon, size: 14, color: fgColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style:
                theme.textTheme.labelMedium?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w600,
                ) ??
                TextStyle(
                  color: fgColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      chip = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(child: chip),
        ),
      );
    }

    chip = Semantics(
      label: semanticLabel ?? label,
      button: onTap != null,
      child: chip,
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      chip = Tooltip(message: tooltip!, child: chip);
    }

    return chip;
  }
}

/// Banner variants for [AppBanner].
enum AppBannerVariant { info, warning, error, success }

/// Standardized in-app notification / alert banner with liveRegion semantics.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.actionText,
    this.onAction,
    this.onDismiss,
    this.variant = AppBannerVariant.info,
  });

  final String message;
  final String? title;
  final IconData? icon;
  final String? actionText;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final AppBannerVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    Color bgColor;
    Color fgColor;
    Color borderColor;
    IconData effectiveIcon;

    switch (variant) {
      case AppBannerVariant.info:
        bgColor = isDark
            ? AppColors.infoContainerDark
            : AppColors.infoContainerLight;
        fgColor = isDark
            ? AppColors.onInfoContainerDark
            : AppColors.onInfoContainerLight;
        borderColor = isDark
            ? AppColors.info.withValues(alpha: 0.4)
            : AppColors.info.withValues(alpha: 0.3);
        effectiveIcon = icon ?? Icons.info_outline_rounded;
        break;
      case AppBannerVariant.warning:
        bgColor = isDark
            ? AppColors.warningContainerDark
            : AppColors.warningContainerLight;
        fgColor = isDark
            ? AppColors.onWarningContainerDark
            : AppColors.onWarningContainerLight;
        borderColor = isDark
            ? AppColors.warning.withValues(alpha: 0.4)
            : AppColors.warning.withValues(alpha: 0.3);
        effectiveIcon = icon ?? Icons.warning_amber_rounded;
        break;
      case AppBannerVariant.error:
        bgColor = isDark
            ? AppColors.errorContainerDark
            : AppColors.errorContainerLight;
        fgColor = isDark
            ? AppColors.onErrorContainerDark
            : AppColors.onErrorContainerLight;
        borderColor = isDark
            ? AppColors.error.withValues(alpha: 0.4)
            : AppColors.error.withValues(alpha: 0.3);
        effectiveIcon = icon ?? Icons.error_outline_rounded;
        break;
      case AppBannerVariant.success:
        bgColor = isDark
            ? AppColors.successContainerDark
            : AppColors.successContainerLight;
        fgColor = isDark
            ? AppColors.onSuccessContainerDark
            : AppColors.onSuccessContainerLight;
        borderColor = isDark
            ? AppColors.success.withValues(alpha: 0.4)
            : AppColors.success.withValues(alpha: 0.3);
        effectiveIcon = icon ?? Icons.check_circle_outline_rounded;
        break;
    }

    return Semantics(
      container: true,
      liveRegion: true,
      label: title != null ? '$title: $message' : message,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(effectiveIcon, size: 20, color: fgColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (title != null && title!.isNotEmpty) ...<Widget>[
                    Text(
                      title!,
                      style:
                          theme.textTheme.titleSmall?.copyWith(
                            color: fgColor,
                            fontWeight: FontWeight.w600,
                          ) ??
                          TextStyle(
                            color: fgColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    message,
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: fgColor) ??
                        TextStyle(color: fgColor, fontSize: 13),
                  ),
                  if (actionText != null && onAction != null) ...<Widget>[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: onAction,
                      child: Text(
                        actionText!,
                        style: TextStyle(
                          color: fgColor,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onDismiss != null) ...<Widget>[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.close, size: 16, color: fgColor),
                onPressed: onDismiss,
                tooltip: 'Kapat',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standardized section container for grouping content with a semantic header.
class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.isCard = false,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool isCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget header = const SizedBox.shrink();
    if (title != null || subtitle != null || trailing != null) {
      header = Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (title != null)
                    Semantics(
                      header: true,
                      child: Text(
                        title!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      );
    }

    final Widget sectionContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (title != null || subtitle != null || trailing != null) header,
        child,
      ],
    );

    if (isCard) {
      return Card(
        child: Padding(padding: padding, child: sectionContent),
      );
    }

    return Padding(padding: padding, child: sectionContent);
  }
}

/// Standardized accessible modal dialog.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    this.content,
    this.message,
    this.icon,
    this.actions = const <Widget>[],
    this.isDestructive = false,
  });

  final String title;
  final Widget? content;
  final String? message;
  final IconData? icon;
  final List<Widget> actions;
  final bool isDestructive;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    Widget? content,
    String? message,
    IconData? icon,
    List<Widget> actions = const <Widget>[],
    bool isDestructive = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext ctx) => AppDialog(
        title: title,
        content: content,
        message: message,
        icon: icon,
        actions: actions,
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              color: isDestructive
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
          ),
        ],
      ),
      content:
          content ??
          (message != null
              ? Text(message!, style: theme.textTheme.bodyMedium)
              : null),
      actions: actions,
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
