import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/utils/clock.dart';

abstract interface class AppSettingsRepository {
  Stream<String> watchThemeMode();
  Future<void> setThemeMode(String mode);
  Stream<int> watchCacheLimitBytes();
  Future<void> setCacheLimitBytes(int bytes);
}

final class DriftAppSettingsRepository implements AppSettingsRepository {
  DriftAppSettingsRepository(this._database, this._clock);

  final AppDatabase _database;
  final AppClock _clock;

  @override
  Stream<String> watchThemeMode() => _watch('theme_mode', 'system');

  @override
  Future<void> setThemeMode(String mode) {
    if (!const <String>{'system', 'light', 'dark'}.contains(mode)) {
      throw ArgumentError.value(mode, 'mode');
    }
    return _set('theme_mode', mode);
  }

  @override
  Stream<int> watchCacheLimitBytes() => _watch(
        'cache_limit_bytes',
        '${512 * 1024 * 1024}',
      ).map((value) => int.tryParse(value) ?? 512 * 1024 * 1024);

  @override
  Future<void> setCacheLimitBytes(int bytes) {
    if (bytes < 50 * 1024 * 1024) {
      throw ArgumentError('Cache limit must be at least 50 MiB.');
    }
    return _set('cache_limit_bytes', bytes.toString());
  }

  Stream<String> _watch(String key, String fallback) {
    return (_database.select(_database.appSettings)
          ..where((tbl) => tbl.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.valueJson ?? fallback)
        .distinct();
  }

  Future<void> _set(String key, String value) {
    return _database.into(_database.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: key,
            valueJson: value,
            updatedAt: _clock.nowUtc(),
          ),
        );
  }
}
