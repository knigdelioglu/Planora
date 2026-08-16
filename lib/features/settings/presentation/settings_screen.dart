import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
import 'package:not_app/core/auth/auth_service.dart';
import 'package:not_app/core/services/notification_service.dart';
import 'package:not_app/features/conflicts/presentation/screens/conflicts_screen.dart';
import 'package:not_app/features/settings/presentation/screens/sync_queue_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.resumed) {
      _loadPermissions();
    }
  }

  Future<void> _loadPermissions() async {
    if (!mounted) return;
    setState(() => _loadingPermissions = true);
    try {
      final state = await ref
          .read(notificationServiceProvider)
          .permissionState();
      if (mounted) {
        setState(() {
          _permissionState = state;
          _loadingPermissions = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingPermissions = false);
      }
    }
  }

  Future<void> _requestPermissions() async {
    final state = await ref
        .read(notificationServiceProvider)
        .requestPermissions();
    if (!mounted) return;
    setState(() => _permissionState = state);
    final String message = state.notificationsAllowed
        ? state.exactAlarmsAllowed
              ? 'Bildirim izinleri tam olarak açık.'
              : 'Bildirim açık; kesin alarm izni olmadığı için yaklaşık zamanlama devrede.'
        : 'Bildirim izni verilmedi. Ayarlardan açabilirsiniz.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    await ref.read(remindersRepositoryProvider).reconcile();
  }

  Future<void> _openAppSettings() async {
    final opened = await ref
        .read(notificationServiceProvider)
        .openAppSettings();
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ayarlar sayfası açılamadı. Lütfen cihaz ayarlarından kontrol edin.',
          ),
        ),
      );
    }
  }

  Future<void> _signIn(
    BuildContext context,
    WidgetRef ref, {
    required bool create,
  }) async {
    final email = TextEditingController();
    final password = TextEditingController();
    final result = await showDialog<(String, String)?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(create ? 'Bulut hesabı oluştur' : 'Bulut hesabına bağlan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Parola'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, (email.text, password.text)),
            child: Text(create ? 'Oluştur' : 'Bağlan'),
          ),
        ],
      ),
    );
    email.dispose();
    password.dispose();
    if (result == null) return;
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
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(appServicesProvider);
    final settings = ref.watch(settingsRepositoryProvider);
    final NotificationPermissionState permState =
        _permissionState ??
        const NotificationPermissionState(
          notificationsAllowed: true,
          exactAlarmsAllowed: true,
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: <Widget>[
        const AppPageHeader(
          title: 'Ayarlar',
          subtitle: 'Görünüm, bildirim, senkronizasyon ve depolama.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: <Widget>[
              SectionCard(
                child: StreamBuilder<String>(
                  stream: settings.watchThemeMode(),
                  initialData: 'system',
                  builder: (context, snapshot) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Görünüm',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const <ButtonSegment<String>>[
                          ButtonSegment(value: 'system', label: Text('Sistem')),
                          ButtonSegment(value: 'light', label: Text('Açık')),
                          ButtonSegment(value: 'dark', label: Text('Koyu')),
                        ],
                        selected: <String>{snapshot.data ?? 'system'},
                        onSelectionChanged: (value) =>
                            settings.setThemeMode(value.first),
                        showSelectedIcon: false,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Bildirimler ve İzinler',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (_loadingPermissions)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hatırlatıcılar cihaz üzerinde çalışır. Kesin alarm izni olmayan cihazlarda inexact modda planlama yapılır.',
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        permState.notificationsAllowed
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        color: permState.notificationsAllowed
                            ? Colors.green
                            : Theme.of(context).colorScheme.error,
                      ),
                      title: const Text('Bildirim İzni'),
                      subtitle: Text(
                        permState.notificationsAllowed
                            ? 'Etkin — bildirimler iletiliyor'
                            : 'Kapalı — hatırlatıcı bildirimleri iletilemez',
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        permState.exactAlarmsAllowed
                            ? Icons.alarm_on_outlined
                            : Icons.alarm_off_outlined,
                        color: permState.exactAlarmsAllowed
                            ? Colors.green
                            : Colors.orange,
                      ),
                      title: const Text('Kesin Alarm İzni (Exact Alarm)'),
                      subtitle: Text(
                        permState.exactAlarmsAllowed
                            ? 'Etkin — tam zamanında iletilir'
                            : 'Kapalı — yaklaşık zaman garantisi (inexact fallback)',
                      ),
                    ),
                    if (permState.isDenied) ...<Widget>[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.errorContainer.withAlpha(50),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Bildirim izni kalıcı olarak reddedilmiş olabilir. Hatırlatıcı almak için lütfen sistem ayarlarından bildirimleri açın.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (permState.hasInexactFallbackOnly) ...<Widget>[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: const Row(
                          children: <Widget>[
                            Icon(Icons.info_outline, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Kesin alarm izni kapalı. Hatırlatıcılar inexact modda planlanarak zaman kaybı önlenir; tam zaman doğruluğu için ayarları kontrol edin.',
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
                        FilledButton.icon(
                          onPressed: _requestPermissions,
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: const Text('İzinleri iste / Kontrol et'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openAppSettings,
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text('Sistem ayarlarını aç'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await ref
                                .read(remindersRepositoryProvider)
                                .reconcile();
                            await _loadPermissions();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Hatırlatıcılar OS ile senkronize edildi.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.sync),
                          label: const Text('Senkronize et'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                child: StreamBuilder<AuthSessionState>(
                  stream: services.auth.watchState(),
                  initialData: services.auth.currentState,
                  builder: (context, snapshot) {
                    final state = snapshot.data ?? services.auth.currentState;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Senkronizasyon',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          !state.isConfigured
                              ? 'Bu build için Supabase yapılandırılmamış. Uygulama yalnız cihazda çalışmaya devam eder.'
                              : state.isSignedIn
                              ? '${state.email ?? 'Hesap'} bağlı.'
                              : 'Bulut yapılandırıldı ancak hesap bağlı değil.',
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<int>(
                          stream: services.syncQueue.watchPendingCount(),
                          initialData: 0,
                          builder: (context, queueSnap) {
                            final int count = queueSnap.data ?? 0;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                if (count > 0) ...<Widget>[
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withAlpha(25),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.orange.withAlpha(120),
                                      ),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        const Icon(
                                          Icons.sync_problem_outlined,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Kuyrukta $count işlem bekliyor. Durumu inceleyebilir veya kurtarma işlemi yapabilirsiniz.',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    if (state.isConfigured &&
                                        !state.isSignedIn) ...<Widget>[
                                      FilledButton(
                                        onPressed: () => _signIn(
                                          context,
                                          ref,
                                          create: false,
                                        ),
                                        child: const Text('Hesaba bağlan'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () =>
                                            _signIn(context, ref, create: true),
                                        child: const Text('Hesap oluştur'),
                                      ),
                                    ],
                                    if (state.isSignedIn) ...<Widget>[
                                      FilledButton.icon(
                                        onPressed: () async {
                                          final result = await services
                                              .syncCoordinator
                                              .syncNow();
                                          if (!context.mounted) return;
                                          final health = services
                                              .syncCoordinator
                                              .currentHealth;
                                          final String message =
                                              health.lastError
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true
                                              ? 'Eşitleme başarısız: ${health.lastError}'
                                              : 'Eşitleme tamamlandı: ${result.pushed} gönderildi, ${result.pulled} alındı, ${result.conflicts} çakışma.';
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(content: Text(message)),
                                          );
                                        },
                                        icon: const Icon(Icons.sync),
                                        label: const Text('Şimdi eşitle'),
                                      ),
                                      OutlinedButton(
                                        onPressed: services.auth.signOut,
                                        child: const Text(
                                          'Bulut hesabından çık',
                                        ),
                                      ),
                                    ],
                                    OutlinedButton(
                                      onPressed: () => AppRouter.push<void>(
                                        context,
                                        const ConflictsScreen(),
                                      ),
                                      child: const Text('Çakışmaları gör'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => AppRouter.push<void>(
                                        context,
                                        const SyncQueueScreen(),
                                      ),
                                      icon: const Icon(Icons.queue_outlined),
                                      label: const Text(
                                        'Senkronizasyon Kuyruğu',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Depolama',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<int>(
                      future: services.attachments.cacheSizeBytes(),
                      builder: (context, snapshot) => Text(
                        'İndirilebilir dosya önbelleği: ${((snapshot.data ?? 0) / (1024 * 1024)).toStringAsFixed(1)} MB',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => services.attachments.evictCacheUntil(0),
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('İndirilebilir önbelleği temizle'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Hakkında',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Not 1.0.0 · tek kullanıcılı, offline-first kişisel çalışma alanı.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
