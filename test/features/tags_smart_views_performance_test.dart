import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/events/entity_change_bus.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/smart_views/data/repositories/smart_views_repository_impl.dart';
import 'package:not_app/features/smart_views/domain/entities/content_filter.dart';

final class _Clock implements AppClock {
  const _Clock();

  @override
  DateTime nowUtc() => DateTime.utc(2026, 8, 20, 12);
}

void main() {
  test('smart view query stays bounded with 10k local items', () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    final EntityChangeBus changes = EntityChangeBus();
    addTearDown(() async {
      await changes.dispose();
      await db.close();
    });
    const _Clock clock = _Clock();
    final DriftSmartViewsRepository smartViews = DriftSmartViewsRepository(
      database: db,
      syncQueue: DriftSyncQueueRepository(database: db, clock: clock),
      clock: clock,
      changes: changes,
    );

    await db.transaction(() async {
      await db.customStatement('''
        INSERT INTO tags(
          id, name, normalized_name, color_key,
          created_at, updated_at, version, deleted_at
        ) VALUES (
          'tag_perf', 'Performans', 'performans', 'indigo',
          '2026-08-20T12:00:00.000Z', '2026-08-20T12:00:00.000Z', 1, NULL
        )
      ''');
      for (int index = 0; index < 10000; index++) {
        final String id = 'note_$index';
        await db.customStatement(
          '''
          INSERT INTO notes(
            id, title, content_json, is_favorite, last_opened_at,
            created_at, updated_at, version, deleted_at
          ) VALUES (?, ?, ?, 0, NULL, ?, ?, 1, NULL)
          ''',
          <Object?>[
            id,
            'Not $index',
            '{"version":1,"blocks":[]}',
            1787227200,
            1787227200,
          ],
        );
        if (index % 10 == 0) {
          await db.customStatement(
            '''
            INSERT INTO tag_assignments(
              id, tag_id, target_type, target_id,
              created_at, updated_at, version, deleted_at
            ) VALUES (?, 'tag_perf', 'note', ?, ?, ?, 1, NULL)
            ''',
            <Object?>[
              'assignment_$index',
              id,
              '2026-08-20T12:00:00.000Z',
              '2026-08-20T12:00:00.000Z',
            ],
          );
        }
      }
    });

    final Stopwatch stopwatch = Stopwatch()..start();
    final results = await smartViews.query(
      const ContentFilter(
        scope: ContentScope.notes,
        allTagIds: <String>['tag_perf'],
      ),
    );
    stopwatch.stop();

    expect(results, hasLength(1000));
    expect(
      stopwatch.elapsed,
      lessThan(const Duration(seconds: 5)),
      reason:
          'Filtering must stay in SQLite instead of scanning 10k items in Dart.',
    );
  });
}
