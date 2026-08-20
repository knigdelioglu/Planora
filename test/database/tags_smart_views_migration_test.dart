import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('schema v4 upgrades to v5 with tag and smart-view tables', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'planora_schema_v5_',
    );
    final File file = File('${directory.path}/planora.sqlite');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    // Build a complete current database first, then strip the v5-only tables
    // and mark it as v4. This keeps the legacy schema realistic without
    // duplicating all pre-v5 CREATE TABLE statements in this regression test.
    final AppDatabase seed = AppDatabase(NativeDatabase(file));
    await seed.customSelect('SELECT 1').getSingle();
    await seed.close();

    final Database raw = sqlite3.open(file.path);
    try {
      raw.execute('PRAGMA foreign_keys = OFF;');
      raw.execute('DROP TABLE IF EXISTS tag_assignments;');
      raw.execute('DROP TABLE IF EXISTS tags;');
      raw.execute('DROP TABLE IF EXISTS smart_views;');
      raw.execute('PRAGMA user_version = 4;');
    } finally {
      raw.close();
    }

    final AppDatabase migrated = AppDatabase(NativeDatabase(file));
    addTearDown(migrated.close);
    final rows = await migrated.customSelect('''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
        AND name IN ('tags', 'tag_assignments', 'smart_views')
      ORDER BY name
    ''').get();
    final versionRow = await migrated.customSelect('PRAGMA user_version').getSingle();

    expect(
      rows.map((row) => row.read<String>('name')).toList(growable: false),
      <String>['smart_views', 'tag_assignments', 'tags'],
    );
    expect(versionRow.read<int>('user_version'), 5);
  });
}
