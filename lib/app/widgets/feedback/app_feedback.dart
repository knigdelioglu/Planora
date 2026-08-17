import 'package:flutter/material.dart';
import 'package:not_app/app/theme/app_theme.dart';

enum AppBannerTone { info, warning, error, success }

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = AppBannerTone.info,
    this.compact = true,
  });

  final String label;
  final IconData? icon;
  final AppBannerTone tone;
  final bool compact;

  Color _foreground(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return switch (tone) {
      AppBannerTone.info =>
        dark ? AppColors.onInfoContainerDark : AppColors.onInfoContainerLight,
      AppBannerTone.warning =>
        dark
            ? AppColors.onWarningContainerDark
            : AppColors.onWarningContainerLight,
      AppBannerTone.error =>
        dark ? AppColors.onErrorContainerDark : AppColors.onErrorContainerLight,
      AppBannerTone.success =>
        dark
            ? AppColors.onSuccessContainerDark
            : AppColors.onSuccessContainerLight,
    };
  }

  Color _background(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return switch (tone) {
      AppBannerTone.info =>
        dark ? AppColors.infoContainerDark : AppColors.infoContainerLight,
      AppBannerTone.warning =>
        dark ? AppColors.warningContainerDark : AppColors.warningContainerLight,
      AppBannerTone.error =>
        dark ? AppColors.errorContainerDark : AppColors.errorContainerLight,
      AppBannerTone.success =>
        dark ? AppColors.successContainerDark : AppColors.successContainerLight,
    };
  }

  @override
  Widget build(BuildContext context) {
    final Color foreground = _foreground(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 4),
      decoration: BoxDecoration(
        color: _background(context),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = AppBannerTone.info,
    this.action,
    this.compact = true,
  });

  final String message;
  final String? title;
  final AppBannerTone tone;
  final Widget? action;
  final bool compact;

  IconData get _icon => switch (tone) {
    AppBannerTone.info => Icons.info_outline_rounded,
    AppBannerTone.warning => Icons.warning_amber_rounded,
    AppBannerTone.error => Icons.error_outline_rounded,
    AppBannerTone.success => Icons.check_circle_outline_rounded,
  };

  Color _foreground(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return switch (tone) {
      AppBannerTone.info =>
        dark ? AppColors.onInfoContainerDark : AppColors.onInfoContainerLight,
      AppBannerTone.warning =>
        dark
            ? AppColors.onWarningContainerDark
            : AppColors.onWarningContainerLight,
      AppBannerTone.error =>
        dark ? AppColors.onErrorContainerDark : AppColors.onErrorContainerLight,
      AppBannerTone.success =>
        dark
            ? AppColors.onSuccessContainerDark
            : AppColors.onSuccessContainerLight,
    };
  }

  Color _background(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return switch (tone) {
      AppBannerTone.info =>
        dark ? AppColors.infoContainerDark : AppColors.infoContainerLight,
      AppBannerTone.warning =>
        dark ? AppColors.warningContainerDark : AppColors.warningContainerLight,
      AppBannerTone.error =>
        dark ? AppColors.errorContainerDark : AppColors.errorContainerLight,
      AppBannerTone.success =>
        dark ? AppColors.successContainerDark : AppColors.successContainerLight,
    };
  }

  @override
  Widget build(BuildContext context) {
    final Color foreground = _foreground(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 9 : 12,
      ),
      decoration: BoxDecoration(
        color: _background(context),
        borderRadius: BorderRadius.circular(AppRadius.surface),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(_icon, size: 18, color: foreground),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (title != null)
                  Text(
                    title!,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: foreground),
                  ),
                Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
          if (action != null) ...<Widget>[const SizedBox(width: 10), action!],
        ],
      ),
    );
  }
}
