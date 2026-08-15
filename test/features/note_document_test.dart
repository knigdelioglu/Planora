import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/features/notes/domain/entities/note_document.dart';

void main() {
  test('note document round-trips supported blocks', () {
    final doc = NoteDocument(
      version: 1,
      blocks: <NoteBlock>[
        const NoteBlock(
          id: '1',
          type: NoteBlockType.heading,
          text: 'Başlık',
          level: 2,
        ),
        const NoteBlock(
          id: '2',
          type: NoteBlockType.checkbox,
          text: 'Görev',
          checked: true,
        ),
        const NoteBlock(
          id: '3',
          type: NoteBlockType.link,
          text: 'OpenAI',
          url: 'https://openai.com',
        ),
      ],
    );
    final restored = NoteDocument.decode(doc.encode());
    expect(restored.blocks.length, 3);
    expect(restored.blocks[1].checked, isTrue);
    expect(restored.plainText, contains('Görev'));
  });

  test('unknown blocks are preserved instead of corrupting the note', () {
    final raw = jsonEncode(<String, Object?>{
      'version': 99,
      'blocks': <Object?>[
        <String, Object?>{
          'id': 'future',
          'type': 'futureWidget',
          'payload': <String, Object?>{'x': 1},
        },
      ],
    });
    final doc = NoteDocument.decode(raw);
    expect(doc.blocks.single.type, NoteBlockType.unknown);
    expect(jsonDecode(doc.encode()), isA<Map>());
  });
}
