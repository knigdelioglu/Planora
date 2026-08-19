final class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  factory AppConfig.fromEnvironment() {
    String rawUrl = const String.fromEnvironment('SUPABASE_URL').trim();
    if (rawUrl.isNotEmpty &&
        !rawUrl.startsWith('http://') &&
        !rawUrl.startsWith('https://')) {
      rawUrl = 'https://$rawUrl';
    }
    return AppConfig(
      environment: const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'production',
      ),
      supabaseUrl: rawUrl,
      supabasePublishableKey: const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ).trim(),
    );
  }

  final String environment;
  final String supabaseUrl;
  final String supabasePublishableKey;

  bool get cloudConfigured =>
      supabaseUrl.trim().isNotEmpty && supabasePublishableKey.trim().isNotEmpty;

  bool get isProduction => environment == 'production';
}
