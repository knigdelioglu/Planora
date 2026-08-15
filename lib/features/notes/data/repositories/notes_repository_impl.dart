import 'package:drift/drift.dart';
import 'package:not_app/core/database/app_database.dart';
import 'package:not_app/core/sync/sync_models.dart';
import 'package:not_app/core/sync/sync_queue_repository.dart';
import 'package:not_app/core/utils/clock.dart';
import 'package:not_app/features/notes/domain/entities/note.dart';
import 'package:not_app/features/notes/domain/entities/note_document.dart';
import 'package:not_app/features/notes/domain/repositories/notes_repository.dart';
import 'package:uuid/uuid.dart';

final class DriftNotesRepository implements NotesRepository {
  DriftNotesRepository({
    required AppDatabase database,
    required SyncQueueRepository syncQueue,
    required AppClock clock,
    Uuid? uuid,
  }) : _database = database,
       _syncQueue = syncQueue,
       _clock = clock,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final SyncQueueRepository _syncQueue;
  final AppClock _clock;
  final Uuid _uuid;

  @override
  Stream<List<NoteEntity>> watchNotes(NoteFilter filter) {
    final query = _database.select(_database.notes);
    switch (filter) {
      case NoteFilter.all:
        query.where((tbl) => tbl.deletedAt.isNull());
        query.orderBy(<OrderingTerm Function($NotesTable)>[
          (tbl) => OrderingTerm.desc(tbl.updatedAt),
        ]);
      case NoteFilter.favorites:
        query.where(
          (tbl) => tbl.deletedAt.isNull() & tbl.isFavorite.equals(true),
        );
        query.orderBy(<OrderingTerm Function($NotesTable)>[
          (tbl) => OrderingTerm.desc(tbl.updatedAt),
        ]);
      case NoteFilter.recent:
        query.where((tbl) => tbl.deletedAt.isNull());
        query.orderBy(<OrderingTerm Function($NotesTable)>[
          (tbl) => OrderingTerm.desc(tbl.lastOpenedAt),
          (tbl) => OrderingTerm.desc(tbl.updatedAt),
        ]);
        query.limit(50);
      case NoteFilter.trash:
        query.where((tbl) => tbl.deletedAt.isNotNull());
        query.orderBy(<OrderingTerm Function($NotesTable)>[
          (tbl) => OrderingTerm.desc(tbl.deletedAt),
        ]);
    }
    return query.watch().map((rows) => rows.map(_map).toList(growable: false));
  }

  @override
  Stream<NoteEntity?> watchNote(String noteId) {
    return (_database.select(_database.notes)
          ..where((tbl) => tbl.id.equals(noteId)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _map(row));
  }

  @override
  Future<NoteEntity?> getNote(String noteId) async {
    final Note? row = await (_database.select(
      _database.notes,
    )..where((tbl) => tbl.id.equals(noteId))).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<String> createNote({String title = ''}) async {
    final String id = _uuid.v7();
    final DateTime now = _clock.nowUtc();
    final NoteDocument document = NoteDocument.empty();
    await _database.transaction(() async {
      await _database
          .into(_database.notes)
          .insert(
            NotesCompanion.insert(
              id: id,
              title: Value<String>(title.trim()),
              contentJson: Value<String>(document.encode()),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _database.upsertSearchEntry(
        entityType: 'note',
        entityId: id,
        title: title.trim(),
        body: '',
      );
      await _syncQueue.enqueue(
        entityType: 'note',
        entityId: id,
        operationType: SyncOperationType.upsert,
        payload: _payload(
          id: id,
          title: title.trim(),
          document: document,
          favorite: false,
          createdAt: now,
          updatedAt: now,
          version: 1,
          deletedAt: null,
        ),
        baseVersion: 0,
      );
    });
    return id;
  }

  @override
  Future<void> updateTitle(String noteId, String title) async {
    final Note row = await _require(noteId);
    await _mutate(
      row,
      title: title.trim(),
      document: NoteDocument.decode(row.contentJson),
      favorite: row.isFavorite,
      deletedAt: row.deletedAt,
    );
  }

  @override
  Future<void> saveDocument(String noteId, NoteDocument document) async {
    final Note row = await _require(noteId);
    await _mutate(
      row,
      title: row.title,
      document: document,
      favorite: row.isFavorite,
      deletedAt: row.deletedAt,
    );
  }

  @override
  Future<void> setFavorite(String noteId, bool favorite) async {
    final Note row = await _require(noteId);
    await _mutate(
      row,
      title: row.title,
      document: NoteDocument.decode(row.contentJson),
      favorite: favorite,
      deletedAt: row.deletedAt,
    );
  }

  @override
  Future<void> markOpened(String noteId) async {
    await (_database.update(_database.notes)
          ..where((tbl) => tbl.id.equals(noteId)))
        .write(NotesCompanion(lastOpenedAt: Value<DateTime>(_clock.nowUtc())));
  }

  @override
  Future<void> trash(String noteId) async {
    final Note row = await _require(noteId);
    await _mutate(
      row,
      title: row.title,
      document: NoteDocument.decode(row.contentJson),
      favorite: row.isFavorite,
      deletedAt: _clock.nowUtc(),
    );
  }

  @override
  Future<void> restore(String noteId) async {
    final Note row = await _require(noteId);
    await _mutate(
      row,
      title: row.title,
      document: NoteDocument.decode(row.contentJson),
      favorite: row.isFavorite,
      deletedAt: null,
    );
  }

  @override
  Future<void> deletePermanently(String noteId) async {
    final Note row = await _require(noteId);
    if (row.deletedAt == null) {
      throw StateError('Only trashed notes can be permanently deleted.');
    }
    await _database.transaction(() async {
      await (_database.delete(_database.attachments)..where(
            (tbl) =>
                tbl.parentType.equals('note') & tbl.parentId.equals(noteId),
          ))
          .go();
      await (_database.delete(_database.reminders)..where(
            (tbl) =>
                tbl.parentType.equals('note') & tbl.parentId.equals(noteId),
          ))
          .go();
      await (_database.delete(
        _database.notes,
      )..where((tbl) => tbl.id.equals(noteId))).go();
      await _database.deleteSearchEntry('note', noteId);
      await _syncQueue.enqueue(
        entityType: 'note',
        entityId: noteId,
        operationType: SyncOperationType.delete,
        payload: <String, Object?>{
          'id': noteId,
          'version': row.version + 1,
          'updatedAt': _clock.nowUtc().toIso8601String(),
          'deletedAt': _clock.nowUtc().toIso8601String(),
        },
        baseVersion: row.version,
      );
    });
  }

  Future<Note> _require(String noteId) async {
    final Note? row = await (_database.select(
      _database.notes,
    )..where((tbl) => tbl.id.equals(noteId))).getSingleOrNull();
    if (row == null) throw StateError('Note not found: $noteId');
    return row;
  }

  Future<void> _mutate(
    Note row, {
    required String title,
    required NoteDocument document,
    required bool favorite,
    required DateTime? deletedAt,
  }) async {
    final DateTime now = _clock.nowUtc();
    final int newVersion = row.version + 1;
    await _database.transaction(() async {
      await (_database.update(
        _database.notes,
      )..where((tbl) => tbl.id.equals(row.id))).write(
        NotesCompanion(
          title: Value<String>(title),
          contentJson: Value<String>(document.encode()),
          isFavorite: Value<bool>(favorite),
          updatedAt: Value<DateTime>(now),
          version: Value<int>(newVersion),
          deletedAt: Value<DateTime?>(deletedAt),
        ),
      );
      if (deletedAt == null) {
        await _database.upsertSearchEntry(
          entityType: 'note',
          entityId: row.id,
          title: title,
          body: document.plainText,
        );
      } else {
        await _database.deleteSearchEntry('note', row.id);
      }
      await _syncQueue.enqueue(
        entityType: 'note',
        entityId: row.id,
        operationType: SyncOperationType.upsert,
        payload: _payload(
          id: row.id,
          title: title,
          document: document,
          favorite: favorite,
          createdAt: row.createdAt,
          updatedAt: now,
          version: newVersion,
          deletedAt: deletedAt,
        ),
        baseVersion: row.version,
      );
    });
  }

  Map<String, Object?> _payload({
    required String id,
    required String title,
    required NoteDocument document,
    required bool favorite,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int version,
    required DateTime? deletedAt,
  }) {
    return <String, Object?>{
      'id': id,
      'title': title,
      'contentJson': document.encode(),
      'isFavorite': favorite,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'version': version,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  NoteEntity _map(Note row) => NoteEntity(
    id: row.id,
    title: row.title,
    document: NoteDocument.decode(row.contentJson),
    isFavorite: row.isFavorite,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    lastOpenedAt: row.lastOpenedAt,
    version: row.version,
    deletedAt: row.deletedAt,
  );
}
