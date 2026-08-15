import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/router/app_router.dart';
import 'package:not_app/app/widgets/common_widgets.dart';
import 'package:not_app/core/auth/auth_service.dart';
import 'package:not_app/features/conflicts/presentation/screens/conflicts_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(appServicesProvider);
    final settings = ref.watch(settingsRepositoryProvider);
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
                    Text(
                      'Bildirimler',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hatırlatıcılar cihaz üzerinde çalışır. İzin verilmezse not ve kart verileriniz yine kaydedilir.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final state = await services.notifications
                            .requestPermissions();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                state.notificationsAllowed
                                    ? 'Bildirim izni açık.'
                                    : 'Bildirim izni verilmedi.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Bildirim izinlerini iste'),
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            if (state.isConfigured &&
                                !state.isSignedIn) ...<Widget>[
                              FilledButton(
                                onPressed: () =>
                                    _signIn(context, ref, create: false),
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
                                  final result = await services.syncCoordinator
                                      .syncNow();
                                  if (!context.mounted) return;
                                  final health =
                                      services.syncCoordinator.currentHealth;
                                  final String message =
                                      health.lastError?.trim().isNotEmpty ==
                                          true
                                      ? 'Eşitleme başarısız: ${health.lastError}'
                                      : 'Eşitleme tamamlandı: ${result.pushed} gönderildi, ${result.pulled} alındı, ${result.conflicts} çakışma.';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                },
                                icon: const Icon(Icons.sync),
                                label: const Text('Şimdi eşitle'),
                              ),
                              OutlinedButton(
                                onPressed: services.auth.signOut,
                                child: const Text('Bulut hesabından çık'),
                              ),
                            ],
                            OutlinedButton(
                              onPressed: () => AppRouter.push<void>(
                                context,
                                const ConflictsScreen(),
                              ),
                              child: const Text('Çakışmaları gör'),
                            ),
                          ],
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
