import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/app.dart';
import 'package:not_app/app/app_bootstrap.dart';
import 'package:not_app/app/app_services.dart';
import 'package:not_app/app/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootstrapHost());
}

class BootstrapHost extends StatefulWidget {
  const BootstrapHost({super.key});

  @override
  State<BootstrapHost> createState() => _BootstrapHostState();
}

class _BootstrapHostState extends State<BootstrapHost> {
  late Future<AppServices> _future = AppBootstrap.create();
  AppServices? _services;

  void _retry() {
    setState(() {
      _future = AppBootstrap.create();
    });
  }

  @override
  void dispose() {
    final AppServices? services = _services;
    AppServiceRegistry.clear();
    if (services != null) services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppServices>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _services = snapshot.requireData;
          AppServiceRegistry.current = snapshot.requireData;
          return ProviderScope(
            overrides: [
              appServicesProvider.overrideWithValue(snapshot.requireData),
            ],
            child: const NotApp(),
          );
        }
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.error_outline_rounded, size: 52),
                        const SizedBox(height: 16),
                        const Text(
                          'Not başlatılamadı',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Yerel veritabanı veya cihaz servisleri hazırlanamadı. Veriler silinmedi. Tekrar deneyebilirsiniz.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tekrar dene'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      },
    );
  }
}
