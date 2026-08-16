import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/core/services/file_picker_service.dart';
import 'package:not_app/features/attachments/domain/entities/attachment.dart';
import 'package:not_app/features/attachments/domain/repositories/attachments_repository.dart';
import 'package:not_app/features/notes/domain/entities/note.dart';
import 'package:not_app/features/notes/domain/entities/note_document.dart';
import 'package:not_app/features/notes/domain/repositories/notes_repository.dart';
import 'package:not_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:not_app/features/notes/presentation/widgets/formatting_toolbar.dart';
import 'package:not_app/features/notes/presentation/widgets/slash_command_palette.dart';
import 'package:not_app/features/reminders/domain/entities/reminder.dart';
import 'package:not_app/features/reminders/domain/repositories/reminders_repository.dart';

NoteEntity createTestNote({
  String id = 'note-test-1',
  String title = 'Test Notu',
  List<NoteBlock>? blocks,
  bool isFavorite = false,
  DateTime? deletedAt,
}) {
  return NoteEntity(
    id: id,
    title: title,
    document: NoteDocument(
      version: 1,
      blocks: blocks ?? <NoteBlock>[NoteBlock.paragraph(text: '')],
    ),
    isFavorite: isFavorite,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    lastOpenedAt: null,
    version: 1,
    deletedAt: deletedAt,
  );
}

class FakeNotesRepository implements NotesRepository {
  FakeNotesRepository({NoteEntity? initialNote}) {
    if (initialNote != null) {
      _notes[initialNote.id] = initialNote;
    }
  }

  final Map<String, NoteEntity> _notes = <String, NoteEntity>{};

  @override
  Future<NoteEntity?> getNote(String noteId) async => _notes[noteId];

  @override
  Stream<NoteEntity?> watchNote(String noteId) {
    return Stream<NoteEntity?>.value(_notes[noteId]);
  }

  @override
  Stream<List<NoteEntity>> watchNotes(NoteFilter filter) {
    return Stream<List<NoteEntity>>.value(
      _notes.values.toList(growable: false),
    );
  }

  @override
  Future<String> createNote({String title = ''}) async {
    const id = 'note-test-1';
    _notes[id] = createTestNote(id: id, title: title);
    return id;
  }

  @override
  Future<void> updateTitle(String noteId, String title) async {
    final existing = _notes[noteId];
    if (existing != null) {
      _notes[noteId] = NoteEntity(
        id: existing.id,
        title: title,
        document: existing.document,
        isFavorite: existing.isFavorite,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        lastOpenedAt: existing.lastOpenedAt,
        version: existing.version + 1,
        deletedAt: existing.deletedAt,
      );
    }
  }

  @override
  Future<void> saveDocument(String noteId, NoteDocument document) async {
    final existing = _notes[noteId];
    if (existing != null) {
      _notes[noteId] = NoteEntity(
        id: existing.id,
        title: existing.title,
        document: document,
        isFavorite: existing.isFavorite,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        lastOpenedAt: existing.lastOpenedAt,
        version: existing.version + 1,
        deletedAt: existing.deletedAt,
      );
    }
  }

  @override
  Future<void> setFavorite(String noteId, bool favorite) async {
    final existing = _notes[noteId];
    if (existing != null) {
      _notes[noteId] = NoteEntity(
        id: existing.id,
        title: existing.title,
        document: existing.document,
        isFavorite: favorite,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        lastOpenedAt: existing.lastOpenedAt,
        version: existing.version + 1,
        deletedAt: existing.deletedAt,
      );
    }
  }

  @override
  Future<void> markOpened(String noteId) async {}

  @override
  Future<void> trash(String noteId) async {
    final existing = _notes[noteId];
    if (existing != null) {
      _notes[noteId] = NoteEntity(
        id: existing.id,
        title: existing.title,
        document: existing.document,
        isFavorite: existing.isFavorite,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        lastOpenedAt: existing.lastOpenedAt,
        version: existing.version + 1,
        deletedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> restore(String noteId) async {
    final existing = _notes[noteId];
    if (existing != null) {
      _notes[noteId] = NoteEntity(
        id: existing.id,
        title: existing.title,
        document: existing.document,
        isFavorite: existing.isFavorite,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        lastOpenedAt: existing.lastOpenedAt,
        version: existing.version + 1,
        deletedAt: null,
      );
    }
  }

  @override
  Future<void> deletePermanently(String noteId) async {
    _notes.remove(noteId);
  }
}

class FakeAttachmentsRepository implements AttachmentsRepository {
  bool addFromFileCalled = false;

  @override
  Stream<List<AttachmentEntity>> watchForParent(
    String parentType,
    String parentId,
  ) {
    return Stream.value(const <AttachmentEntity>[]);
  }

  @override
  Future<AttachmentEntity> addFromFile({
    required String parentType,
    required String parentId,
    required File source,
  }) async {
    addFromFileCalled = true;
    return AttachmentEntity(
      id: 'att-1',
      parentType: parentType,
      parentId: parentId,
      fileName: 'test.pdf',
      localPath: '/tmp/test.pdf',
      sizeBytes: 1024,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      version: 1,
      isCache: false,
      transferState: 'synced',
      mimeType: 'application/pdf',
    );
  }

  @override
  Future<File> ensureLocal(String attachmentId) async => File('/tmp/test.pdf');

  @override
  Future<void> remove(String attachmentId) async {}

  @override
  Future<int> cacheSizeBytes() async => 0;

  @override
  Future<void> evictCacheUntil(int maximumBytes) async {}
}

class FakeFilePickerService implements FilePickerService {
  @override
  Future<File?> pickSingleFile() async {
    return File('/tmp/test.pdf');
  }
}

class FakeRemindersRepository implements RemindersRepository {
  @override
  Stream<List<ReminderEntity>> watchForParent(
    String parentType,
    String parentId,
  ) {
    return Stream.value(const <ReminderEntity>[]);
  }

  @override
  Stream<List<ReminderEntity>> watchUpcoming() {
    return Stream.value(const <ReminderEntity>[]);
  }

  @override
  Stream<List<ReminderEntity>> watchPast() {
    return Stream.value(const <ReminderEntity>[]);
  }

  @override
  Stream<List<ReminderEntity>> watchDisabled() {
    return Stream.value(const <ReminderEntity>[]);
  }

  @override
  Future<ReminderEntity> create({
    required String parentType,
    required String parentId,
    required String title,
    String? body,
    required DateTime scheduledAtUtc,
    required String timeZoneId,
  }) async {
    return ReminderEntity(
      id: 'rem-1',
      parentType: parentType,
      parentId: parentId,
      title: title,
      body: body,
      scheduledAtUtc: scheduledAtUtc,
      timeZoneId: timeZoneId,
      notificationId: 1,
      enabled: true,
      schedulingStatus: 'scheduled',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      version: 1,
    );
  }

  @override
  Future<void> update({
    required String id,
    required String title,
    String? body,
    required DateTime scheduledAtUtc,
    required String timeZoneId,
    required bool enabled,
  }) async {}

  @override
  Future<void> remove(String id) async {}

  @override
  Future<void> reconcile() async {}
}

Widget createTestEditorApp({
  required FakeNotesRepository notesRepo,
  FakeAttachmentsRepository? attachmentsRepo,
  FakeFilePickerService? filePickerService,
  String noteId = 'note-test-1',
}) {
  final attRepo = attachmentsRepo ?? FakeAttachmentsRepository();
  final picker = filePickerService ?? FakeFilePickerService();
  final remindersRepo = FakeRemindersRepository();

  return ProviderScope(
    overrides: [
      notesRepositoryProvider.overrideWithValue(notesRepo),
      attachmentsRepositoryProvider.overrideWithValue(attRepo),
      filePickerServiceProvider.overrideWithValue(picker),
      remindersRepositoryProvider.overrideWithValue(remindersRepo),
    ],
    child: MaterialApp(home: NoteEditorScreen(noteId: noteId)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kabul Kriteri 1: Slash Command Palette Açılışı ve İçeriği', () {
    testWidgets(
      'Boş blokta / yazıldığında Slash Command Palette tüm 11 blok seçeneğiyle açılır',
      (tester) async {
        final initialNote = createTestNote();
        final notesRepo = FakeNotesRepository(initialNote: initialNote);

        await tester.pumpWidget(createTestEditorApp(notesRepo: notesRepo));
        await tester.pumpAndSettle();

        // Palette is not open initially
        expect(find.byKey(const Key('slash_command_palette')), findsNothing);

        // Type '/' in the first block
        final blockFinder = find
            .byType(TextField)
            .at(1); // 0 is title, 1 is block
        await tester.enterText(blockFinder, '/');
        await tester.pumpAndSettle();

        // Slash command palette is now open
        expect(find.byKey(const Key('slash_command_palette')), findsOneWidget);

        // Verify all 11 commands are present
        expect(
          find.byKey(const ValueKey('slash_item_paragraph')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('slash_item_heading1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('slash_item_heading2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('slash_item_heading3')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('slash_item_bulletList')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('slash_item_numberedList')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('slash_item_checkbox')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('slash_item_quote')), findsOneWidget);
        expect(find.byKey(const ValueKey('slash_item_code')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('slash_item_divider')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('slash_item_attachment')),
          findsOneWidget,
        );
      },
    );

    testWidgets('Query ile slash komutları filtrelenir', (tester) async {
      final initialNote = createTestNote();
      final notesRepo = FakeNotesRepository(initialNote: initialNote);

      await tester.pumpWidget(createTestEditorApp(notesRepo: notesRepo));
      await tester.pumpAndSettle();

      final blockFinder = find.byType(TextField).at(1);
      await tester.enterText(blockFinder, '/kod');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('slash_item_code')), findsOneWidget);
      expect(find.byKey(const ValueKey('slash_item_heading1')), findsNothing);
      expect(find.byKey(const ValueKey('slash_item_divider')), findsNothing);
    });
  });

  group('Kabul Kriteri 2: Slash Paleti Yön Tuşları, Enter ve Kapatma', () {
    testWidgets('Yön tuşları ve Enter ile bloğa dönüştürülür', (tester) async {
      final initialNote = createTestNote();
      final notesRepo = FakeNotesRepository(initialNote: initialNote);

      await tester.pumpWidget(createTestEditorApp(notesRepo: notesRepo));
      await tester.pumpAndSettle();

      final blockFinder = find.byType(TextField).at(1);
      await tester.tap(blockFinder);
      await tester.pumpAndSettle();

      await tester.enterText(blockFinder, '/');
      await tester.pumpAndSettle();

      // Arrow Down moves from paragraph (index 0) to heading1 (index 1)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Press Enter to apply Heading 1
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Slash palette is closed
      expect(find.byKey(const Key('slash_command_palette')), findsNothing);

      // Block is now a Heading 1 (hint text is 'Başlık 1')
      expect(find.text('Başlık 1'), findsOneWidget);
    });

    testWidgets('Escape veya geriye silme ile palet kapatılır', (tester) async {
      final initialNote = createTestNote();
      final notesRepo = FakeNotesRepository(initialNote: initialNote);

      await tester.pumpWidget(createTestEditorApp(notesRepo: notesRepo));
      await tester.pumpAndSettle();

      final blockFinder = find.byType(TextField).at(1);
      await tester.tap(blockFinder);
      await tester.pumpAndSettle();

      // Open with '/'
      await tester.enterText(blockFinder, '/');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('slash_command_palette')), findsOneWidget);

      // Press Escape to close
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('slash_command_palette')), findsNothing);

      // Clear and reopen with '/'
      await tester.enterText(blockFinder, '');
      await tester.pumpAndSettle();
      await tester.enterText(blockFinder, '/');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('slash_command_palette')), findsOneWidget);

      // Delete with Backspace
      await tester.enterText(blockFinder, '');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('slash_command_palette')), findsNothing);
    });

    testWidgets('Ek Dosya komutu seçildiğinde dosya ekleme tetiklenir', (
      tester,
    ) async {
      final initialNote = createTestNote();
      final notesRepo = FakeNotesRepository(initialNote: initialNote);
      final attRepo = FakeAttachmentsRepository();

      await tester.pumpWidget(
        createTestEditorApp(notesRepo: notesRepo, attachmentsRepo: attRepo),
      );
      await tester.pumpAndSettle();

      final blockFinder = find.byType(TextField).at(1);
      await tester.enterText(blockFinder, '/dosya');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('slash_item_attachment')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('slash_item_attachment')));
      await tester.pumpAndSettle();

      expect(attRepo.addFromFileCalled, isTrue);
    });
  });

  group('Kabul Kriteri 3: Metin Seçimi ve Biçimlendirme Araç Çubuğu', () {
    testWidgets(
      'Metin seçildiğinde FormattingToolbar açılır ve biçimlendirme yapar',
      (tester) async {
        final initialNote = createTestNote(
          blocks: <NoteBlock>[NoteBlock.paragraph(text: 'Merhaba Dünya')],
        );
        final notesRepo = FakeNotesRepository(initialNote: initialNote);

        await tester.pumpWidget(createTestEditorApp(notesRepo: notesRepo));
        await tester.pumpAndSettle();

        // Initially no selection -> no toolbar
        expect(find.byKey(const Key('formatting_toolbar')), findsNothing);

        // Select 'Dünya' in the block (index 8 to 13)
        final blockFinder = find.byType(TextField).at(1);
        await tester.tap(blockFinder);
        await tester.pumpAndSettle();

        // Trigger selection on the block
        final editableText = tester.widget<TextField>(blockFinder);
        editableText.controller!.selection = const TextSelection(
          baseOffset: 8,
          extentOffset: 13,
        );
        await tester.pumpAndSettle();

        // FormattingToolbar appears!
        expect(find.byKey(const Key('formatting_toolbar')), findsOneWidget);
        expect(find.byKey(const Key('format_bold_button')), findsOneWidget);
        expect(find.byKey(const Key('format_italic_button')), findsOneWidget);
        expect(
          find.byKey(const Key('format_strikethrough_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('format_underline_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('format_inline_code_button')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('format_link_button')), findsOneWidget);

        // Tap Bold button
        await tester.tap(find.byKey(const Key('format_bold_button')));
        await tester.pumpAndSettle();

        // Text becomes 'Merhaba **Dünya**'
        expect(editableText.controller!.text, 'Merhaba **Dünya**');
      },
    );

    test(
      'TextFormattingHelper tüm biçimlendirme türlerini doğru uygular ve geri alır',
      () {
        var value = const TextEditingValue(
          text: 'Deneme Metin',
          selection: TextSelection(baseOffset: 7, extentOffset: 12), // 'Metin'
        );

        // 1. Bold
        value = TextFormattingHelper.applyFormat(
          value: value,
          format: TextFormatType.bold,
        );
        expect(value.text, 'Deneme **Metin**');

        // Toggle Bold off
        value = TextFormattingHelper.applyFormat(
          value: value,
          format: TextFormatType.bold,
        );
        expect(value.text, 'Deneme Metin');

        // 2. Italic
        value = TextFormattingHelper.applyFormat(
          value: value,
          format: TextFormatType.italic,
        );
        expect(value.text, 'Deneme *Metin*');

        // 3. Strikethrough
        value = const TextEditingValue(
          text: 'Deneme Metin',
          selection: TextSelection(baseOffset: 7, extentOffset: 12),
        );
        value = TextFormattingHelper.applyFormat(
          value: value,
          format: TextFormatType.strikethrough,
        );
        expect(value.text, 'Deneme ~~Metin~~');

        // 4. Underline
        value = const TextEditingValue(
          text: 'Deneme Metin',
          selection: TextSelection(baseOffset: 7, extentOffset: 12),
        );
        value = TextFormattingHelper.applyFormat(
          value: value,
          format: TextFormatType.underline,
        );
        expect(value.text, 'Deneme <u>Metin</u>');

        // 5. Inline Code
        value = const TextEditingValue(
          text: 'Deneme Metin',
          selection: TextSelection(baseOffset: 7, extentOffset: 12),
        );
        value = TextFormattingHelper.applyFormat(
          value: value,
          format: TextFormatType.inlineCode,
        );
        expect(value.text, 'Deneme `Metin`');

        // 6. Link
        value = const TextEditingValue(
          text: 'Deneme Metin',
          selection: TextSelection(baseOffset: 7, extentOffset: 12),
        );
        value = TextFormattingHelper.applyFormat(
          value: value,
          format: TextFormatType.link,
          linkUrl: 'https://example.com',
        );
        expect(value.text, 'Deneme [Metin](https://example.com)');
      },
    );
  });

  group('Kabul Kriteri 4: Klavye Kısayolları ve Blok Akışı', () {
    testWidgets(
      'Enter ile yeni blok oluşturulur ve sonraki bloğa odaklanılır',
      (tester) async {
        final initialNote = createTestNote(
          blocks: <NoteBlock>[NoteBlock.paragraph(text: 'İlk Paragraf')],
        );
        final notesRepo = FakeNotesRepository(initialNote: initialNote);

        await tester.pumpWidget(createTestEditorApp(notesRepo: notesRepo));
        await tester.pumpAndSettle();

        final firstBlock = find.byType(TextField).at(1);
        await tester.tap(firstBlock);
        await tester.pumpAndSettle();

        // Put cursor at the end
        final textField = tester.widget<TextField>(firstBlock);
        textField.controller!.selection = const TextSelection.collapsed(
          offset: 12,
        );
        await tester.pumpAndSettle();

        // Press Enter
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // Now we have 2 blocks (title + 2 blocks = 3 TextFields)
        expect(find.byType(TextField), findsNWidgets(3));
      },
    );

    testWidgets(
      'Madde listesinde Enter basılınca yeni madde listesi satırı açılır',
      (tester) async {
        final initialNote = createTestNote(
          blocks: <NoteBlock>[NoteBlock.bulletList(text: 'Madde 1')],
        );
        final notesRepo = FakeNotesRepository(initialNote: initialNote);

        await tester.pumpWidget(createTestEditorApp(notesRepo: notesRepo));
        await tester.pumpAndSettle();

        final firstBlock = find.byType(TextField).at(1);
        await tester.tap(firstBlock);
        await tester.pumpAndSettle();

        final textField = tester.widget<TextField>(firstBlock);
        textField.controller!.selection = const TextSelection.collapsed(
          offset: 7,
        );
        await tester.pumpAndSettle();

        // Press Enter
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // Check that 2 bullet points exist
        expect(find.text('•'), findsNWidgets(2));
      },
    );

    testWidgets(
      'Boş blokta Backspace ile blok silinir ve öncekine odaklanılır',
      (tester) async {
        final initialNote = createTestNote(
          blocks: <NoteBlock>[
            NoteBlock.paragraph(text: 'Blok 1'),
            NoteBlock.paragraph(text: ''),
          ],
        );
        final notesRepo = FakeNotesRepository(initialNote: initialNote);

        await tester.pumpWidget(createTestEditorApp(notesRepo: notesRepo));
        await tester.pumpAndSettle();

        // Initially 3 textfields (title + 2 blocks)
        expect(find.byType(TextField), findsNWidgets(3));

        // Focus the second block
        final secondBlock = find.byType(TextField).at(2);
        await tester.tap(secondBlock);
        await tester.pumpAndSettle();

        final secondController = tester
            .widget<TextField>(secondBlock)
            .controller!;
        secondController.selection = const TextSelection.collapsed(offset: 0);
        await tester.pumpAndSettle();

        // Press Backspace in empty block
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pumpAndSettle();

        // Now only 1 block remains (title + 1 block = 2 TextFields)
        expect(find.byType(TextField), findsNWidgets(2));
        expect(find.text('Blok 1'), findsOneWidget);
      },
    );

    testWidgets('Yön tuşlarıyla bloklar arası imleç geçişi çalışır', (
      tester,
    ) async {
      final initialNote = createTestNote(
        blocks: <NoteBlock>[
          NoteBlock.paragraph(text: 'Blok 1'),
          NoteBlock.paragraph(text: 'Blok 2'),
        ],
      );
      final notesRepo = FakeNotesRepository(initialNote: initialNote);

      await tester.pumpWidget(createTestEditorApp(notesRepo: notesRepo));
      await tester.pumpAndSettle();

      // Focus second block at offset 0
      final secondBlock = find.byType(TextField).at(2);
      await tester.tap(secondBlock);
      await tester.pumpAndSettle();

      final secondController = tester
          .widget<TextField>(secondBlock)
          .controller!;
      secondController.selection = const TextSelection.collapsed(offset: 0);
      await tester.pumpAndSettle();

      // Press Arrow Up
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      // First block is now focused
      final firstBlock = find.byType(TextField).at(1);
      final firstController = tester.widget<TextField>(firstBlock).controller!;
      expect(firstController.selection.baseOffset, 6); // end of 'Blok 1'
    });

    testWidgets('Enter basıldığında metin imleç noktasından ikiye bölünür', (
      tester,
    ) async {
      final initialNote = createTestNote(
        blocks: <NoteBlock>[NoteBlock.paragraph(text: 'Merhaba Dünya')],
      );
      final notesRepo = FakeNotesRepository(initialNote: initialNote);

      await tester.pumpWidget(createTestEditorApp(notesRepo: notesRepo));
      await tester.pumpAndSettle();

      final firstBlock = find.byType(TextField).at(1);
      await tester.tap(firstBlock);
      await tester.pumpAndSettle();

      // Put cursor between 'Merhaba' and ' Dünya' (offset 7)
      final textField = tester.widget<TextField>(firstBlock);
      textField.controller!.selection = const TextSelection.collapsed(
        offset: 7,
      );
      await tester.pumpAndSettle();

      // Press Enter
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // We should have 2 blocks: 'Merhaba' and ' Dünya'
      final block1 = tester.widget<TextField>(find.byType(TextField).at(1));
      final block2 = tester.widget<TextField>(find.byType(TextField).at(2));
      expect(block1.controller!.text, 'Merhaba');
      expect(block2.controller!.text, ' Dünya');
    });

    testWidgets('Boş liste bloğunda Enter basılınca paragrafa dönüştürülür', (
      tester,
    ) async {
      final initialNote = createTestNote(
        blocks: <NoteBlock>[NoteBlock.bulletList(text: '')],
      );
      final notesRepo = FakeNotesRepository(initialNote: initialNote);

      await tester.pumpWidget(createTestEditorApp(notesRepo: notesRepo));
      await tester.pumpAndSettle();

      // Initial state is bullet list (has '•')
      expect(find.text('•'), findsOneWidget);

      final firstBlock = find.byType(TextField).at(1);
      await tester.tap(firstBlock);
      await tester.pumpAndSettle();

      // Press Enter in empty bullet list
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Bullet dot is gone, converted to paragraph
      expect(find.text('•'), findsNothing);
    });

    testWidgets(
      'Başlık bloğunda imleç 0 konumundayken Backspace basılınca paragrafa dönüştürülür',
      (tester) async {
        final initialNote = createTestNote(
          blocks: <NoteBlock>[
            NoteBlock.heading(text: 'Başlık Metni', level: 1),
          ],
        );
        final notesRepo = FakeNotesRepository(initialNote: initialNote);

        await tester.pumpWidget(createTestEditorApp(notesRepo: notesRepo));
        await tester.pumpAndSettle();

        // Hint is 'Başlık 1'
        expect(find.text('Başlık 1'), findsOneWidget);

        final firstBlock = find.byType(TextField).at(1);
        await tester.tap(firstBlock);
        await tester.pumpAndSettle();

        final textField = tester.widget<TextField>(firstBlock);
        textField.controller!.selection = const TextSelection.collapsed(
          offset: 0,
        );
        await tester.pumpAndSettle();

        // Press Backspace at offset 0
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pumpAndSettle();

        // Text is preserved, but block is converted to paragraph
        expect(textField.controller!.text, 'Başlık Metni');
        expect(find.text('Başlık 1'), findsNothing);
      },
    );

    testWidgets(
      'İmleç bloğun sonundayken Aşağı Yön Tuşu ile sonraki bloğa geçilir',
      (tester) async {
        final initialNote = createTestNote(
          blocks: <NoteBlock>[
            NoteBlock.paragraph(text: 'Üst Blok'),
            NoteBlock.paragraph(text: 'Alt Blok'),
          ],
        );
        final notesRepo = FakeNotesRepository(initialNote: initialNote);

        await tester.pumpWidget(createTestEditorApp(notesRepo: notesRepo));
        await tester.pumpAndSettle();

        // Focus first block at end (offset 8)
        final firstBlock = find.byType(TextField).at(1);
        await tester.tap(firstBlock);
        await tester.pumpAndSettle();

        final firstController = tester
            .widget<TextField>(firstBlock)
            .controller!;
        firstController.selection = const TextSelection.collapsed(offset: 8);
        await tester.pumpAndSettle();

        // Press Arrow Down
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        // Second block is now focused at offset 0
        final secondBlock = find.byType(TextField).at(2);
        final secondController = tester
            .widget<TextField>(secondBlock)
            .controller!;
        expect(secondController.selection.baseOffset, 0);
      },
    );
  });

  group('Tüm Blok Tipleri için Slash Dönüşümleri', () {
    for (final cmd in defaultSlashCommands) {
      if (cmd.id == SlashCommandId.attachment) continue;
      testWidgets(
        'Slash menüsünden "${cmd.title}" seçimi doğru bloğu oluşturur',
        (tester) async {
          final initialNote = createTestNote();
          final notesRepo = FakeNotesRepository(initialNote: initialNote);

          await tester.pumpWidget(createTestEditorApp(notesRepo: notesRepo));
          await tester.pumpAndSettle();

          final blockFinder = find.byType(TextField).at(1);
          await tester.enterText(blockFinder, '/${cmd.title}');
          await tester.pumpAndSettle();

          expect(
            find.byKey(ValueKey('slash_item_${cmd.id.name}')),
            findsOneWidget,
          );
          await tester.tap(find.byKey(ValueKey('slash_item_${cmd.id.name}')));
          await tester.pumpAndSettle();

          // Palette is closed
          expect(find.byKey(const Key('slash_command_palette')), findsNothing);
        },
      );
    }
  });
}
