import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/theme/app_theme.dart';
import 'package:not_app/app/widgets/content/app_content.dart';
import 'package:not_app/app/widgets/feedback/app_feedback.dart';
import 'package:not_app/app/widgets/navigation/app_toolbar.dart';
import 'package:not_app/core/auth/auth_service.dart';
import 'package:not_app/core/services/notification_service.dart';
import 'package:not_app/features/conflicts/presentation/screens/conflicts_screen.dart';
import 'package:not_app/features/settings/presentation/screens/sync_queue_screen.dart';

enum _SettingsSection { appearance, notifications, sync, storage, about }

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  _SettingsSection _selected = _SettingsSection.appearance;
  bool _compactDetailOpen = false;
  NotificationPermissionState? _permissionState;
  bool _loadingPermissions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    if (mounted) setState(() => _loadingPermissions = true);
    try {
      final NotificationPermissionState state =
          await ref.read(notificationServiceProvider).permissionState();
      if (mounted) {
        setState(() {
          _permissionState = state;
          _loadingPermissions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPermissions = false);
    }
  }

  Future<void> _requestPermissions() async {
    final NotificationPermissionState state =
        await ref.read(notificationServiceProvider).requestPermissions();
    if (!mounted) return;
    setState(() => _permissionState = state);
    await ref.read(remindersRepositoryProvider).reconcile();
    if (!mounted) return;
    final String message = state.notificationsAllowed
        ? state.exactAlarmsAllowed
            ? 'Bildirimler hazır.'
            : 'Bildirimler açık; bazı hatırlatıcılar yaklaşık zamanda gelebilir.'
        : 'Bildirimler kapalı.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openAppSettings() async {
    final bool opened =
        await ref.read(notificationServiceProvider).openAppSettings();
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sistem ayarları açılamadı.')),
    );
  }

  Future<void> _signIn({required bool create}) async {
    final TextEditingController email = TextEditingController();
    final TextEditingController password = TextEditingController();
    final (String, String)? result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(create ? 'Bulut hesabı oluştur' : 'Bulut hesabına bağlan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const <String>[AutofillHints.email],
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: password,
              obscureText: true,
              autofillHints: const <String>[AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Parola'),
              onSubmitted: (_) => Navigator.of(dialogContext).pop(
                (email.text.trim(), password.text),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              (email.text.trim(), password.text),
            ),
            child: Text(create ? 'Oluştur' : 'Bağlan'),
          ),
        ],
      ),
    );
    email.dispose();
    password.dispose();
    if (result == null || result.$1.isEmpty || result.$2.isEmpty) return;
    try {
      if (create) {
        await ref
            .read(authServiceProvider)
            .signUp(email: result.$1, password: result.$2);
      } else {
        await ref
            .read(authServiceProvider)
            .signIn(email: result.$1, password: result.$2);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  String _title(_SettingsSection section) => switch (section) {
        _SettingsSection.appearance => 'Görünüm',
        _SettingsSection.notifications => 'Bildirimler',
        _SettingsSection.sync => 'Senkronizasyon',
        _SettingsSection.storage => 'Depolama',
        _SettingsSection.about => 'Hakkında',
      };

  String _subtitle(_SettingsSection section) => switch (section) {
        _SettingsSection.appearance => 'Tema ve görünüm',
        _SettingsSection.notifications => 'Hatırlatıcı izinleri',
        _SettingsSection.sync => 'Cihazlar arası eşitleme',
        _SettingsSection.storage => 'Yerel dosya önbelleği',
        _SettingsSection.about => 'Uygulama bilgileri',
      };

  IconData _icon(_SettingsSection section) => switch (section) {
        _SettingsSection.appearance => Icons.palette_outlined,
        _SettingsSection.notifications => Icons.notifications_none_rounded,
        _SettingsSection.sync => Icons.cloud_outlined,
        _SettingsSection.storage => Icons.storage_outlined,
        _SettingsSection.about => Icons.info_outline_rounded,
      };

  void _select(_SettingsSection section, bool compact) {
    setState(() {
      _selected = section;
      if (compact) _compactDetailOpen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 760;
        if (compact) {
          return Column(
            children: <Widget>[
              AppToolbar(
                title: _compactDetailOpen ? _title(_selected) : 'Ayarlar',
                leading: _compactDetailOpen
                    ? IconButton(
                        tooltip: 'Ayarlar',
                        onPressed: () =>
                            setState(() => _compactDetailOpen = false),
                        icon: const Icon(Icons.arrow_back_rounded),
                      )
                    : null,
              ),
              Expanded(
                child: _compactDetailOpen
                    ? _SettingsDetail(
                        section: _selected,
                        child: _sectionContent(_selected),
                      )
                    : _categoryList(compact: true),
              ),
            ],
          );
        }

        return Column(
          children: <Widget>[
            const AppToolbar(title: 'Ayarlar'),
            Expanded(
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 240,
                    child: _categoryList(compact: false),
                  ),
                  VerticalDivider(
                    width: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                  Expanded(
                    child: _SettingsDetail(
                      section: _selected,
                      child: _sectionContent(_selected),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _categoryList({required bool compact}) => ListView(
        padding: EdgeInsets.fromLTRB(compact ? 12 : 10, 14, compact ? 12 : 10, 28),
        children: _SettingsSection.values.map((section) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: AppListRow(
              selected: !compact && _selected == section,
              leading: Icon(_icon(section), size: 20),
              title: Text(_title(section)),
              subtitle: Text(_subtitle(section)),
              trailing: compact
                  ? const Icon(Icons.chevron_right_rounded, size: 19)
                  : null,
              onTap: () => _select(section, compact),
            ),
          );
        }).toList(growable: false),
      );

  Widget _sectionContent(_SettingsSection section) => switch (section) {
        _SettingsSection.appearance => _appearance(),
        _SettingsSection.notifications => _notifications(),
        _SettingsSection.sync => _sync(),
        _SettingsSection.storage => _storage(),
        _SettingsSection.about => _about(),
      };

  Widget _appearance() {
    final settings = ref.watch(settingsRepositoryProvider);
    return StreamBuilder<String>(
      stream: settings.watchThemeMode(),
      initialData: 'system',
      builder: (context, snapshot) {
        final String current = snapshot.data ?? 'system';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AppSectionHeader(title: 'Tema'),
            Text(
              'Uygulamanın açık veya koyu görünümünü seçin.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment(value: 'system', label: Text('Sistem')),
                ButtonSegment(value: 'light', label: Text('Açık')),
                ButtonSegment(value: 'dark', label: Text('Koyu')),
              ],
              selected: <String>{current},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  settings.setThemeMode(value.first),
            ),
          ],
        );
      },
    );
  }

  Widget _notifications() {
    final NotificationPermissionState permission =
        _permissionState ??
        const NotificationPermissionState(
          notificationsAllowed: true,
          exactAlarmsAllowed: true,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(child: AppSectionHeader(title: 'Bildirim izinleri')),
            if (_loadingPermissions)
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        if (permission.isDenied)
          AppBanner(
            tone: AppBannerTone.warning,
            message:
                'Bildirimler kapalı. Hatırlatıcılar kaydedilir ancak cihaz bildirimi gösterilemez.',
            action: TextButton(
              onPressed: _openAppSettings,
              child: const Text('Ayarları aç'),
            ),
          )
        else if (permission.hasInexactFallbackOnly)
          AppBanner(
            tone: AppBannerTone.info,
            message: 'Bazı hatırlatıcılar yaklaşık zamanda bildirilebilir.',
          )
        else
          const AppBanner(
            tone: AppBannerTone.success,
            message: 'Hatırlatıcı bildirimleri hazır.',
          ),
        const SizedBox(height: 18),
        AppListRow(
          leading: Icon(
            permission.notificationsAllowed
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            size: 20,
          ),
          title: const Text('Bildirimler'),
          subtitle: Text(
            permission.notificationsAllowed ? 'Açık' : 'Kapalı',
          ),
        ),
        AppListRow(
          leading: Icon(
            permission.exactAlarmsAllowed
                ? Icons.alarm_on_outlined
                : Icons.schedule_rounded,
            size: 20,
          ),
          title: const Text('Tam zamanlı bildirim'),
          subtitle: Text(
            permission.exactAlarmsAllowed
                ? 'Destekleniyor'
                : 'Yaklaşık zamanda bildirim kullanılacak',
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.icon(
              onPressed: _requestPermissions,
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text('İzinleri kontrol et'),
            ),
            OutlinedButton.icon(
              onPressed: _openAppSettings,
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Sistem ayarlarını aç'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(remindersRepositoryProvider).reconcile();
                await _loadPermissions();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hatırlatıcılar yenilendi.')),
                );
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Hatırlatıcıları yenile'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sync() {
    final services = ref.watch(appServicesProvider);
    return StreamBuilder<AuthSessionState>(
      stream: services.auth.watchState(),
      initialData: services.auth.currentState,
      builder: (context, snapshot) {
        final AuthSessionState state =
            snapshot.data ?? services.auth.currentState;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AppSectionHeader(title: 'Bulut senkronizasyonu'),
            Text(
              !state.isConfigured
                  ? 'Bulut bağlantısı bu sürümde yapılandırılmamış. Veriler bu cihazda çalışmaya devam eder.'
                  : state.isSignedIn
                      ? '${state.email ?? 'Hesap'} bağlı.'
                      : 'İsterseniz cihazlar arasında eşitlemek için bir hesap bağlayabilirsiniz.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            StreamBuilder<int>(
              stream: services.syncQueue.watchPendingCount(),
              initialData: 0,
              builder: (context, queueSnapshot) {
                final int pending = queueSnapshot.data ?? 0;
                return AppBanner(
                  tone: pending > 0
                      ? AppBannerTone.warning
                      : AppBannerTone.success,
                  message: pending > 0
                      ? '$pending değişiklik eşitleme bekliyor.'
                      : state.isSignedIn
                          ? 'Değişiklikler güncel.'
                          : 'Yerel çalışma hazır.',
                );
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (state.isConfigured && !state.isSignedIn) ...<Widget>[
                  FilledButton(
                    onPressed: () => _signIn(create: false),
                    child: const Text('Hesaba bağlan'),
                  ),
                  OutlinedButton(
                    onPressed: () => _signIn(create: true),
                    child: const Text('Hesap oluştur'),
                  ),
                ],
                if (state.isSignedIn) ...<Widget>[
                  FilledButton.icon(
                    onPressed: () async {
                      final result = await services.syncCoordinator.syncNow();
                      if (!mounted) return;
                      final health = services.syncCoordinator.currentHealth;
                      final String message =
                          health.lastError?.trim().isNotEmpty == true
                              ? 'Eşitleme tamamlanamadı: ${health.lastError}'
                              : 'Eşitleme tamamlandı · ${result.pushed} gönderildi · ${result.pulled} alındı';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                    },
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: const Text('Şimdi eşitle'),
                  ),
                  OutlinedButton(
                    onPressed: services.auth.signOut,
                    child: const Text('Hesaptan çık'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 28),
            const AppSectionHeader(title: 'Gelişmiş'),
            Text(
              'Sorun giderme ve teknik eşitleme ayrıntıları.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            AppListRow(
              leading: const Icon(Icons.rule_folder_outlined, size: 20),
              title: const Text('Çakışmalar'),
              subtitle: const Text('Aynı içeriğin farklı sürümlerini inceleyin.'),
              trailing: const Icon(Icons.chevron_right_rounded, size: 18),
              onTap: () => AppRouter.push<void>(
                context,
                const ConflictsScreen(),
              ),
            ),
            AppListRow(
              leading: const Icon(Icons.queue_outlined, size: 20),
              title: const Text('Eşitleme kuyruğu'),
              subtitle: const Text('Bekleyen teknik işlemleri görüntüleyin.'),
              trailing: const Icon(Icons.chevron_right_rounded, size: 18),
              onTap: () => AppRouter.push<void>(
                context,
                const SyncQueueScreen(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _storage() {
    final services = ref.watch(appServicesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppSectionHeader(title: 'Dosya önbelleği'),
        FutureBuilder<int>(
          future: services.attachments.cacheSizeBytes(),
          builder: (context, snapshot) {
            final double megabytes = (snapshot.data ?? 0) / (1024 * 1024);
            return AppListRow(
              leading: const Icon(Icons.folder_outlined, size: 20),
              title: const Text('İndirilebilir dosyalar'),
              subtitle: Text('${megabytes.toStringAsFixed(1)} MB bu cihazda'),
            );
          },
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () async {
            await services.attachments.evictCacheUntil(0);
            if (!mounted) return;
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Dosya önbelleği temizlendi.')),
            );
          },
          icon: const Icon(Icons.cleaning_services_outlined, size: 18),
          label: const Text('Önbelleği temizle'),
        ),
        const SizedBox(height: 8),
        Text(
          'Not ve kart kayıtları silinmez; gerektiğinde yeniden indirilebilen dosyalar temizlenir.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _about() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AppSectionHeader(title: 'Not'),
          Text(
            'Sürüm 1.0.0',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Tek kullanıcılı, çevrimdışı öncelikli kişisel not ve çalışma alanı.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
}

class _SettingsDetail extends StatelessWidget {
  const _SettingsDetail({required this.section, required this.child});

  final _SettingsSection section;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 44),
            children: <Widget>[child],
          ),
        ),
      );
}
