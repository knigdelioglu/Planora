import 'dart:convert';

import 'package:uuid/uuid.dart';

enum NoteBlockType {
  paragraph,
  heading,
  bulletList,
  numberedList,
  checkbox,
  quote,
  divider,
  code,
  link,
  image,
  file,
  unknown,
}

final class NoteBlock {
  const NoteBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.level,
    this.checked,
    this.url,
    this.attachmentId,
    this.raw,
  });

  factory NoteBlock.paragraph({String text = '', Uuid? uuid}) => NoteBlock(
    id: (uuid ?? const Uuid()).v7(),
    type: NoteBlockType.paragraph,
    text: text,
  );

  factory NoteBlock.fromJson(Map<String, Object?> json) {
    final String typeName = json['type'] as String? ?? 'unknown';
    final NoteBlockType type = NoteBlockType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => NoteBlockType.unknown,
    );
    return NoteBlock(
      id: json['id'] as String? ?? const Uuid().v7(),
      type: type,
      text: json['text'] as String? ?? '',
      level: json['level'] as int?,
      checked: json['checked'] as bool?,
      url: json['url'] as String?,
      attachmentId: json['attachmentId'] as String?,
      raw: type == NoteBlockType.unknown
          ? Map<String, Object?>.from(json)
          : null,
    );
  }

  final String id;
  final NoteBlockType type;
  final String text;
  final int? level;
  final bool? checked;
  final String? url;
  final String? attachmentId;
  final Map<String, Object?>? raw;

  NoteBlock copyWith({
    NoteBlockType? type,
    String? text,
    int? level,
    bool? checked,
    String? url,
    String? attachmentId,
  }) {
    return NoteBlock(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      level: level ?? this.level,
      checked: checked ?? this.checked,
      url: url ?? this.url,
      attachmentId: attachmentId ?? this.attachmentId,
      raw: raw,
    );
  }

  Map<String, Object?> toJson() {
    if (type == NoteBlockType.unknown && raw != null) return raw!;
    return <String, Object?>{
      'id': id,
      'type': type.name,
      'text': text,
      if (level != null) 'level': level,
      if (checked != null) 'checked': checked,
      if (url != null) 'url': url,
      if (attachmentId != null) 'attachmentId': attachmentId,
    };
  }
}

final class NoteDocument {
  const NoteDocument({required this.version, required this.blocks});

  factory NoteDocument.empty() => NoteDocument(
    version: currentVersion,
    blocks: <NoteBlock>[NoteBlock.paragraph()],
  );

  factory NoteDocument.decode(String source) {
    try {
      final Object? decoded = jsonDecode(source);
      if (decoded is! Map<Object?, Object?>) return NoteDocument.empty();
      final Map<String, Object?> map = Map<String, Object?>.from(decoded);
      final Object? rawBlocks = map['blocks'];
      final List<NoteBlock> blocks = rawBlocks is List<Object?>
          ? rawBlocks
                .whereType<Map<Object?, Object?>>()
                .map(
                  (raw) => NoteBlock.fromJson(Map<String, Object?>.from(raw)),
                )
                .toList(growable: false)
          : <NoteBlock>[];
      return NoteDocument(
        version: map['version'] as int? ?? 1,
        blocks: blocks.isEmpty ? <NoteBlock>[NoteBlock.paragraph()] : blocks,
      );
    } on FormatException {
      return NoteDocument.empty();
    }
  }

  static const int currentVersion = 1;
  final int version;
  final List<NoteBlock> blocks;

  NoteDocument copyWith({List<NoteBlock>? blocks}) =>
      NoteDocument(version: currentVersion, blocks: blocks ?? this.blocks);

  String encode() => jsonEncode(<String, Object?>{
    'version': currentVersion,
    'blocks': blocks.map((block) => block.toJson()).toList(growable: false),
  });

  String get plainText => blocks
      .where((block) => block.type != NoteBlockType.divider)
      .map((block) => block.text)
      .where((text) => text.trim().isNotEmpty)
      .join('\n');
}
