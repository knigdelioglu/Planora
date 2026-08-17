import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/utils/clock.dart';

enum NoteViewMode { list, grid }

abstract interface class AppSettingsRepository {
  Stream<String> watchThemeMode();
  Future<void> setThemeMode(String mode);
  Stream<int> watchCacheLimitBytes();
  Future<void> setCacheLimitBytes(int bytes);
  Stream<NoteViewMode> watchNotesViewMode();
  Future<void> setNotesViewMode(NoteViewMode mode);
  Stream<String?> watchEntityColor(String entityType, String entityId);
  Future<void> setEntityColor(
    String entityType,
    String entityId,
    String? colorHex,
  );
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

  @override
  Stream<NoteViewMode> watchNotesViewMode() =>
      _watch('notes_view_mode', NoteViewMode.list.name).map(
        (value) => value == NoteViewMode.grid.name
            ? NoteViewMode.grid
            : NoteViewMode.list,
      );

  @override
  Future<void> setNotesViewMode(NoteViewMode mode) =>
      _set('notes_view_mode', mode.name);

  @override
  Stream<String?> watchEntityColor(String entityType, String entityId) {
    final String key = _entityColorKey(entityType, entityId);
    return (_database.select(_database.appSettings)
          ..where((tbl) => tbl.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.valueJson)
        .distinct();
  }

  @override
  Future<void> setEntityColor(
    String entityType,
    String entityId,
    String? colorHex,
  ) async {
    final String key = _entityColorKey(entityType, entityId);
    final String? normalized = _normalizeColor(colorHex);
    if (normalized == null) {
      await (_database.delete(
        _database.appSettings,
      )..where((tbl) => tbl.key.equals(key))).go();
      return;
    }
    await _set(key, normalized);
  }

  String _entityColorKey(String entityType, String entityId) {
    final String cleanType = entityType.trim().toLowerCase();
    final String cleanId = entityId.trim();
    if (cleanType.isEmpty || cleanId.isEmpty) {
      throw ArgumentError('Entity type and id cannot be empty.');
    }
    return 'entity_color:$cleanType:$cleanId';
  }

  String? _normalizeColor(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final String clean = value.trim().toUpperCase();
    if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(clean)) {
      throw ArgumentError.value(value, 'colorHex', 'Expected #RRGGBB.');
    }
    return clean;
  }

  Stream<String> _watch(String key, String fallback) {
    return (_database.select(_database.appSettings)
          ..where((tbl) => tbl.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.valueJson ?? fallback)
        .distinct();
  }

  Future<void> _set(String key, String value) {
    return _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: key,
            valueJson: value,
            updatedAt: _clock.nowUtc(),
          ),
        );
  }
}
