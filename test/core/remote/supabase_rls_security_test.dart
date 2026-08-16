import 'package:flutter_test/flutter_test.dart';

import '../../helpers/postgres_rls_harness.dart';

void main() {
  late PostgresRlsHarness harness;

  const String userAId = '11111111-1111-1111-1111-111111111111';
  const String userBId = '22222222-2222-2222-2222-222222222222';
  const String userAEmail = 'user_a@example.com';
  const String userBEmail = 'user_b@example.com';

  setUpAll(() async {
    harness = PostgresRlsHarness();
    await harness.setupSchema(
      migrationFilePath: 'supabase/migrations/0001_initial.sql',
    );
  });

  setUp(() async {
    await harness.resetData();
    await harness.createUser(id: userAId, email: userAEmail);
    await harness.createUser(id: userBId, email: userBEmail);
  });

  group('AC1 — User A JWT session querying User B entities returns 0 rows', () {
    setUp(() async {
      // Seed User B entities for all 6 entity types
      final DateTime now = DateTime.utc(2026, 8, 16, 10, 0, 0);
      final List<String> types = <String>[
        'note',
        'board',
        'column',
        'card',
        'attachment',
        'reminder',
      ];
      for (final String type in types) {
        await harness.insertEntityAsSuperuser(
          userId: userBId,
          entityType: type,
          entityId: '${type}_b_1',
          version: 1,
          updatedAt: now,
          payload: <String, dynamic>{
            'title': 'User B $type',
            'owner': 'user_b',
          },
        );
      }
    });

    test('User A sees 0 total entities when querying entities table', () async {
      await harness.asUser(userAId, (session) async {
        final int count = await session.countEntities();
        expect(
          count,
          equals(0),
          reason: 'User A must not see any entities belonging to User B.',
        );

        final List<Map<String, dynamic>> allRows = await session
            .selectEntities();
        expect(allRows, isEmpty);
      });
    });

    test(
      'User A querying specifically for User B user_id returns 0 rows',
      () async {
        await harness.asUser(userAId, (session) async {
          final int count = await session.countEntities(
            whereClause: "user_id = '$userBId'",
          );
          expect(count, equals(0));

          final List<Map<String, dynamic>> rows = await session.selectEntities(
            whereClause: "user_id = '$userBId'",
          );
          expect(rows, isEmpty);
        });
      },
    );

    test(
      'User A querying each entity_type (note, board, column, card, attachment, reminder) returns 0 rows',
      () async {
        await harness.asUser(userAId, (session) async {
          final List<String> types = <String>[
            'note',
            'board',
            'column',
            'card',
            'attachment',
            'reminder',
          ];
          for (final String type in types) {
            final int count = await session.countEntities(
              whereClause: "entity_type = '$type'",
            );
            expect(
              count,
              equals(0),
              reason:
                  'User A querying type "$type" must return 0 rows when only User B records exist.',
            );
          }
        });
      },
    );

    test(
      'User A can successfully create and query own entities while User B entities remain invisible',
      () async {
        final DateTime now = DateTime.utc(2026, 8, 16, 10, 15, 0);

        await harness.asUser(userAId, (session) async {
          final DbResult insertRes = await session.insertEntity(
            userId: userAId,
            entityType: 'note',
            entityId: 'note_a_1',
            version: 1,
            updatedAt: now,
            payload: <String, dynamic>{'title': 'User A Note'},
          );
          expect(insertRes.isSuccess, isTrue);

          final int totalCount = await session.countEntities();
          expect(totalCount, equals(1));

          final List<Map<String, dynamic>> rows = await session
              .selectEntities();
          expect(rows.length, equals(1));
          expect(rows.first['entity_id'], equals('note_a_1'));
          expect(rows.first['user_id'], equals(userAId));
        });

        // Confirm User B also only sees their own 6 entities and not User A's note
        await harness.asUser(userBId, (session) async {
          final int totalCount = await session.countEntities();
          expect(totalCount, equals(6));

          final int userANotesSeenByB = await session.countEntities(
            whereClause: "entity_id = 'note_a_1'",
          );
          expect(userANotesSeenByB, equals(0));
        });
      },
    );
  });

  group(
    'AC2 — Direct INSERT, UPDATE, and DELETE attempts by User A on User B are rejected',
    () {
      final DateTime now = DateTime.utc(2026, 8, 16, 10, 0, 0);

      setUp(() async {
        await harness.insertEntityAsSuperuser(
          userId: userBId,
          entityType: 'note',
          entityId: 'note_b_target',
          version: 1,
          updatedAt: now,
          payload: <String, dynamic>{'title': 'Target Note User B'},
        );
        await harness.insertEntityAsSuperuser(
          userId: userAId,
          entityType: 'note',
          entityId: 'note_a_target',
          version: 1,
          updatedAt: now,
          payload: <String, dynamic>{'title': 'Original Note User A'},
        );
      });

      test(
        'User A cannot directly INSERT an entity with User B user_id (fails with RLS error)',
        () async {
          await harness.asUser(userAId, (session) async {
            final DbResult result = await session.insertEntity(
              userId: userBId,
              entityType: 'note',
              entityId: 'malicious_note',
              version: 1,
              updatedAt: now,
              payload: <String, dynamic>{'title': 'Injected by User A'},
            );
            expect(result.isSuccess, isFalse);
            expect(result.isRlsViolation, isTrue);
          });
        },
      );

      test(
        'User A cannot directly UPDATE User B entities (affects 0 rows)',
        () async {
          await harness.asUser(userAId, (session) async {
            final DbResult result = await session.updateEntities(
              setClause: "payload = '{\"hacked\": true}'::jsonb",
              whereClause: "user_id = '$userBId'",
            );
            expect(result.isSuccess, isTrue);
            expect(
              result.rowsAffected,
              equals(0),
              reason: 'RLS must hide User B rows from UPDATE statement.',
            );
          });

          // Verify User B's entity payload is unmodified
          await harness.asUser(userBId, (session) async {
            final List<Map<String, dynamic>> rows = await session
                .selectEntities(whereClause: "entity_id = 'note_b_target'");
            expect(rows.length, equals(1));
            final Map<String, dynamic> payload =
                rows.first['payload'] as Map<String, dynamic>;
            expect(payload, isA<Map<String, dynamic>>());
            expect(payload['title'], equals('Target Note User B'));
            expect(payload['hacked'], isNull);
          });
        },
      );

      test(
        'User A cannot change own entity user_id to User B user_id (fails with RLS with check error)',
        () async {
          await harness.asUser(userAId, (session) async {
            final DbResult result = await session.updateEntities(
              setClause: "user_id = '$userBId'",
              whereClause: "entity_id = 'note_a_target'",
            );
            expect(result.isSuccess, isFalse);
            expect(result.isRlsViolation, isTrue);
          });
        },
      );

      test(
        'User A cannot directly DELETE User B entities (affects 0 rows)',
        () async {
          await harness.asUser(userAId, (session) async {
            final DbResult result = await session.deleteEntities(
              whereClause: "user_id = '$userBId'",
            );
            expect(result.isSuccess, isTrue);
            expect(
              result.rowsAffected,
              equals(0),
              reason: 'RLS must prevent User A from deleting User B rows.',
            );
          });

          // Verify User B's entity still exists
          await harness.asUser(userBId, (session) async {
            final int count = await session.countEntities(
              whereClause: "entity_id = 'note_b_target'",
            );
            expect(count, equals(1));
          });
        },
      );
    },
  );

  group(
    'AC3 — apply_entity_change RPC security context and unauthenticated protection',
    () {
      final DateTime now = DateTime.utc(2026, 8, 16, 11, 0, 0);

      setUp(() async {
        await harness.insertEntityAsSuperuser(
          userId: userBId,
          entityType: 'note',
          entityId: 'shared_id_1',
          version: 1,
          updatedAt: now,
          payload: <String, dynamic>{'title': 'User B Official Note'},
        );
      });

      test(
        'User A calling apply_entity_change with an existing User B entity_id creates User A own row without affecting User B',
        () async {
          await harness.asUser(userAId, (session) async {
            final ApplyRpcResult rpcRes = await session.applyEntityChange(
              entityType: 'note',
              entityId: 'shared_id_1',
              baseVersion: null,
              version: 1,
              updatedAt: now.add(const Duration(minutes: 5)),
              payload: <String, dynamic>{'title': 'User A Cloned ID Note'},
            );
            expect(rpcRes.isSuccess, isTrue);
            expect(rpcRes.status, equals('ok'));
            expect(rpcRes.revision, isNotNull);
            expect(rpcRes.revision!, greaterThan(0));

            final List<Map<String, dynamic>> userARows = await session
                .selectEntities(whereClause: "entity_id = 'shared_id_1'");
            expect(userARows.length, equals(1));
            expect(userARows.first['user_id'], equals(userAId));
            final Map<String, dynamic> payloadA =
                userARows.first['payload'] as Map<String, dynamic>;
            expect(
              payloadA['title'],
              equals('User A Cloned ID Note'),
            );
          });

          // Verify User B's original record is unchanged
          await harness.asUser(userBId, (session) async {
            final List<Map<String, dynamic>> userBRows = await session
                .selectEntities(whereClause: "entity_id = 'shared_id_1'");
            expect(userBRows.length, equals(1));
            expect(userBRows.first['user_id'], equals(userBId));
            expect(userBRows.first['version'], equals(1));
            final Map<String, dynamic> payloadB =
                userBRows.first['payload'] as Map<String, dynamic>;
            expect(
              payloadB['title'],
              equals('User B Official Note'),
            );
          });
        },
      );

      test(
        'Optimistic concurrency conflict detection works within User A isolated context',
        () async {
          await harness.asUser(userAId, (session) async {
            // Create initial note
            final ApplyRpcResult firstApply = await session.applyEntityChange(
              entityType: 'note',
              entityId: 'note_conflict_test',
              baseVersion: null,
              version: 1,
              updatedAt: now,
              payload: <String, dynamic>{'title': 'Initial'},
            );
            expect(firstApply.isSuccess, isTrue);

            // Update to version 2
            final ApplyRpcResult secondApply = await session.applyEntityChange(
              entityType: 'note',
              entityId: 'note_conflict_test',
              baseVersion: 1,
              version: 2,
              updatedAt: now.add(const Duration(minutes: 1)),
              payload: <String, dynamic>{'title': 'Version 2'},
            );
            expect(secondApply.isSuccess, isTrue);

            // Stale update using baseVersion = 1 should return conflict
            final ApplyRpcResult staleApply = await session.applyEntityChange(
              entityType: 'note',
              entityId: 'note_conflict_test',
              baseVersion: 1,
              version: 3,
              updatedAt: now.add(const Duration(minutes: 2)),
              payload: <String, dynamic>{'title': 'Conflicting edit'},
            );
            expect(staleApply.isSuccess, isTrue);
            expect(staleApply.status, equals('conflict'));
            expect(staleApply.remoteConflict, isNotNull);
            expect(staleApply.remoteConflict!['version'], equals(2));
          });
        },
      );

      test(
        'Unauthenticated / anon callers cannot execute apply_entity_change (fails with auth error)',
        () async {
          await harness.asAnonymous((session) async {
            final ApplyRpcResult result = await session.applyEntityChange(
              entityType: 'note',
              entityId: 'anon_attempt',
              version: 1,
              updatedAt: now,
              payload: <String, dynamic>{'title': 'Anon note'},
            );
            expect(result.isSuccess, isFalse);
            expect(result.isAuthRequired, isTrue);
          });
        },
      );
    },
  );

  group('AC4 — Attachments storage bucket RLS restricts access to owner folder', () {
    const String userBAttachmentPath = '$userBId/att_b_1/screenshot.png';
    const String userAAttachmentPath = '$userAId/att_a_1/document.pdf';

    setUp(() async {
      await harness.insertStorageObjectAsSuperuser(
        bucketId: 'attachments',
        name: userBAttachmentPath,
        owner: userBId,
        metadata: <String, dynamic>{'size': 1024, 'mimetype': 'image/png'},
      );
    });

    test(
      'User A cannot SELECT User B storage objects in attachments bucket',
      () async {
        await harness.asUser(userAId, (session) async {
          final int count = await session.countStorageObjects();
          expect(
            count,
            equals(0),
            reason: 'User A must not see User B storage objects.',
          );

          final List<Map<String, dynamic>> rows = await session
              .selectStorageObjects(whereClause: "name LIKE '$userBId/%'");
          expect(rows, isEmpty);
        });
      },
    );

    test(
      'User A cannot INSERT storage objects under User B path (fails with RLS error)',
      () async {
        await harness.asUser(userAId, (session) async {
          final DbResult result = await session.insertStorageObject(
            bucketId: 'attachments',
            name: '$userBId/att_a_malicious/exploit.bin',
            owner: userAId,
            metadata: <String, dynamic>{'size': 512},
          );
          expect(result.isSuccess, isFalse);
          expect(result.isRlsViolation, isTrue);
        });
      },
    );

    test(
      'User A cannot UPDATE User B storage objects (affects 0 rows)',
      () async {
        await harness.asUser(userAId, (session) async {
          final DbResult result = await session.updateStorageObjects(
            setClause: "metadata = '{\"corrupted\": true}'::jsonb",
            whereClause: "name = '$userBAttachmentPath'",
          );
          expect(result.isSuccess, isTrue);
          expect(result.rowsAffected, equals(0));
        });

        // Verify User B's attachment metadata was not modified
        await harness.asUser(userBId, (session) async {
          final List<Map<String, dynamic>> rows = await session
              .selectStorageObjects(
                whereClause: "name = '$userBAttachmentPath'",
              );
          expect(rows.length, equals(1));
          final Map<String, dynamic> metadata =
              rows.first['metadata'] as Map<String, dynamic>;
          expect(metadata['mimetype'], equals('image/png'));
          expect(metadata['corrupted'], isNull);
        });
      },
    );

    test(
      'User A cannot DELETE User B storage objects (affects 0 rows)',
      () async {
        await harness.asUser(userAId, (session) async {
          final DbResult result = await session.deleteStorageObjects(
            whereClause: "name = '$userBAttachmentPath'",
          );
          expect(result.isSuccess, isTrue);
          expect(result.rowsAffected, equals(0));
        });

        // Verify User B's attachment still exists
        await harness.asUser(userBId, (session) async {
          final int count = await session.countStorageObjects(
            whereClause: "name = '$userBAttachmentPath'",
          );
          expect(count, equals(1));
        });
      },
    );

    test(
      'User A can successfully SELECT, INSERT, UPDATE, and DELETE own storage objects',
      () async {
        await harness.asUser(userAId, (session) async {
          // Insert own
          final DbResult insertRes = await session.insertStorageObject(
            bucketId: 'attachments',
            name: userAAttachmentPath,
            owner: userAId,
            metadata: <String, dynamic>{
              'size': 2048,
              'mimetype': 'application/pdf',
            },
          );
          expect(insertRes.isSuccess, isTrue);

          // Select own
          final int count = await session.countStorageObjects();
          expect(count, equals(1));

          // Update own
          final DbResult updateRes = await session.updateStorageObjects(
            setClause:
                "metadata = '{\"size\": 4096, \"mimetype\": \"application/pdf\"}'::jsonb",
            whereClause: "name = '$userAAttachmentPath'",
          );
          expect(updateRes.isSuccess, isTrue);
          expect(updateRes.rowsAffected, equals(1));

          // Delete own
          final DbResult deleteRes = await session.deleteStorageObjects(
            whereClause: "name = '$userAAttachmentPath'",
          );
          expect(deleteRes.isSuccess, isTrue);
          expect(deleteRes.rowsAffected, equals(1));

          final int finalCount = await session.countStorageObjects();
          expect(finalCount, equals(0));
        });
      },
    );
  });

  group(
    'AC5 — Anonymous / unauthenticated access to tables and storage is completely rejected',
    () {
      final DateTime now = DateTime.utc(2026, 8, 16, 12, 0, 0);

      setUp(() async {
        await harness.insertEntityAsSuperuser(
          userId: userAId,
          entityType: 'note',
          entityId: 'protected_note_a',
          version: 1,
          updatedAt: now,
          payload: <String, dynamic>{'title': 'Protected Note'},
        );
        await harness.insertStorageObjectAsSuperuser(
          bucketId: 'attachments',
          name: '$userAId/att_1/secret.png',
          owner: userAId,
        );
      });

      test('Anonymous query on public.entities returns 0 rows', () async {
        await harness.asAnonymous((session) async {
          final int count = await session.countEntities();
          expect(count, equals(0));

          final List<Map<String, dynamic>> rows = await session
              .selectEntities();
          expect(rows, isEmpty);
        });
      });

      test(
        'Anonymous INSERT into public.entities is rejected by RLS',
        () async {
          await harness.asAnonymous((session) async {
            final DbResult result = await session.insertEntity(
              userId: userAId,
              entityType: 'note',
              entityId: 'anon_note',
              version: 1,
              updatedAt: now,
              payload: <String, dynamic>{'title': 'Anon Note'},
            );
            expect(result.isSuccess, isFalse);
            expect(result.isRlsViolation, isTrue);
          });
        },
      );

      test('Anonymous UPDATE on public.entities affects 0 rows', () async {
        await harness.asAnonymous((session) async {
          final DbResult result = await session.updateEntities(
            setClause: "payload = '{\"hacked\": true}'::jsonb",
          );
          expect(result.isSuccess, isTrue);
          expect(result.rowsAffected, equals(0));
        });
      });

      test('Anonymous DELETE on public.entities affects 0 rows', () async {
        await harness.asAnonymous((session) async {
          final DbResult result = await session.deleteEntities();
          expect(result.isSuccess, isTrue);
          expect(result.rowsAffected, equals(0));
        });
      });

      test('Anonymous query on storage.objects returns 0 rows', () async {
        await harness.asAnonymous((session) async {
          final int count = await session.countStorageObjects();
          expect(count, equals(0));

          final List<Map<String, dynamic>> rows = await session
              .selectStorageObjects();
          expect(rows, isEmpty);
        });
      });

      test(
        'Anonymous INSERT into storage.objects is rejected by storage RLS',
        () async {
          await harness.asAnonymous((session) async {
            final DbResult result = await session.insertStorageObject(
              bucketId: 'attachments',
              name: '$userAId/att_anon/file.png',
              owner: userAId,
            );
            expect(result.isSuccess, isFalse);
            expect(result.isRlsViolation, isTrue);
          });
        },
      );

      test('Anonymous UPDATE on storage.objects affects 0 rows', () async {
        await harness.asAnonymous((session) async {
          final DbResult result = await session.updateStorageObjects(
            setClause: "metadata = '{\"tampered\": true}'::jsonb",
          );
          expect(result.isSuccess, isTrue);
          expect(result.rowsAffected, equals(0));
        });
      });

      test('Anonymous DELETE on storage.objects affects 0 rows', () async {
        await harness.asAnonymous((session) async {
          final DbResult result = await session.deleteStorageObjects();
          expect(result.isSuccess, isTrue);
          expect(result.rowsAffected, equals(0));
        });
      });
    },
  );
}
