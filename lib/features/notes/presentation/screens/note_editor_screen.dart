import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/features/attachments/data/repositories/attachments_repository_impl.dart';
import 'package:not_app/features/attachments/domain/entities/attachment.dart';
import 'package:not_app/features/attachments/presentation/attachment_file_opener.dart';
import 'package:not_app/features/notes/domain/entities/note.dart';
import 'package:not_app/features/notes/domain/entities/note_document.dart';
import 'package:not_app/features/notes/presentation/widgets/formatting_toolbar.dart';
import 'package:not_app/features/notes/presentation/widgets/slash_command_palette.dart';
import 'package:not_app/features/reminders/presentation/reminder_widgets.dart';
import 'package:uuid/uuid.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId});
  final String noteId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen>
    with WidgetsBindingObserver {
  final TextEditingController _title = TextEditingController();
  final List<_EditableBlock> _blocks = <_EditableBlock>[];
  Timer? _saveTimer;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  int? _activeSlashBlockIndex;
  String _slashQuery = '';
  int _slashSelectedIndex = 0;

  int? _activeSelectionBlockIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _title.addListener(_scheduleSave);
  }

  Future<void> _load() async {
    try {
      final NoteEntity? note = await ref
          .read(notesRepositoryProvider)
          .getNote(widget.noteId);
      if (note == null) throw StateError('Not bulunamadı.');
      _title.text = note.title;
      _blocks.clear();
      for (final NoteBlock block in note.document.blocks) {
        final editable = _EditableBlock.from(block, _scheduleSave);
        _blocks.add(editable);
      }
      for (int i = 0; i < _blocks.length; i++) {
        _setupBlockListeners(_blocks[i], i);
      }
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  void _setupBlockListeners(_EditableBlock block, int index) {
    block.controller.addListener(() {
      final text = block.controller.text;
      if (text.startsWith('/')) {
        if (_activeSlashBlockIndex != index ||
            _slashQuery != text.substring(1)) {
          setState(() {
            _activeSlashBlockIndex = index;
            _slashQuery = text.substring(1);
            final filtered = filterSlashCommands(_slashQuery);
            _slashSelectedIndex = _slashSelectedIndex.clamp(
              0,
              filtered.isEmpty ? 0 : filtered.length - 1,
            );
          });
        }
      } else if (_activeSlashBlockIndex == index) {
        setState(() {
          _activeSlashBlockIndex = null;
        });
      }

      final selection = block.controller.selection;
      if (block.focusNode.hasFocus &&
          selection.isValid &&
          !selection.isCollapsed) {
        if (_activeSelectionBlockIndex != index) {
          setState(() {
            _activeSelectionBlockIndex = index;
          });
        }
      } else if (_activeSelectionBlockIndex == index) {
        setState(() {
          _activeSelectionBlockIndex = null;
        });
      }
    });

    block.focusNode.addListener(() {
      if (!block.focusNode.hasFocus) {
        if (_activeSlashBlockIndex == index) {
          setState(() => _activeSlashBlockIndex = null);
        }
        if (_activeSelectionBlockIndex == index) {
          setState(() => _activeSelectionBlockIndex = null);
        }
      }
    });
  }

  void _scheduleSave() {
    if (_loading) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 550), _save);
    if (mounted) setState(() {});
  }

  NoteDocument _document() => NoteDocument(
    version: NoteDocument.currentVersion,
    blocks: _blocks.map((item) => item.toBlock()).toList(growable: false),
  );

  Future<void> _persist({bool showState = true}) async {
    if (_loading) return;
    _saveTimer?.cancel();
    final String title = _title.text;
    final NoteDocument document = _document();
    if (showState && mounted) setState(() => _saving = true);
    try {
      final repo = ref.read(notesRepositoryProvider);
      await repo.updateTitle(widget.noteId, title);
      await repo.saveDocument(widget.noteId, document);
      if (showState && mounted) {
        setState(() {
          _saving = false;
          _error = null;
        });
      }
    } catch (error) {
      if (showState && mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _save() => _persist();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_save());
    }
  }

  Future<void> _addAttachment() async {
    final source = await ref.read(filePickerServiceProvider).pickSingleFile();
    if (source == null) return;
    final attachment = await ref
        .read(attachmentsRepositoryProvider)
        .addFromFile(
          parentType: 'note',
          parentId: widget.noteId,
          source: source,
        );
    final bool image = attachment.mimeType?.startsWith('image/') == true;
    setState(() {
      final newBlock = _EditableBlock.from(
        NoteBlock(
          id: attachment.id,
          type: image ? NoteBlockType.image : NoteBlockType.file,
          text: attachment.fileName,
          attachmentId: attachment.id,
        ),
        _scheduleSave,
      );
      _blocks.add(newBlock);
      _setupBlockListeners(newBlock, _blocks.length - 1);
    });
    _scheduleSave();
  }

  Future<void> _addReminder() => createReminderForParent(
    context,
    ref,
    parentType: 'note',
    parentId: widget.noteId,
    defaultTitle: _title.text.trim().isEmpty
        ? 'Not hatırlatıcısı'
        : _title.text.trim(),
    defaultBody: _document().plainText,
  );

  Future<void> _trashNote() async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Not çöpe taşınsın mı?'),
            content: const Text(
              'Not çöp kutusuna taşınır ve daha sonra geri yüklenebilir.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Çöpe taşı'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _persist(showState: false);
    await ref.read(notesRepositoryProvider).trash(widget.noteId);
    if (mounted) Navigator.pop(context);
  }

  void _addTextBlock(NoteBlockType type, {int? level}) {
    setState(() {
      final newBlock = _EditableBlock.from(
        NoteBlock(id: const Uuid().v7(), type: type, level: level),
        _scheduleSave,
      );
      _blocks.add(newBlock);
      _setupBlockListeners(newBlock, _blocks.length - 1);
    });
    _scheduleSave();
  }

  void _applySlashCommand(int index, SlashCommandItem command) {
    if (index >= _blocks.length) return;
    final block = _blocks[index];
    setState(() {
      _activeSlashBlockIndex = null;
    });

    if (command.id == SlashCommandId.attachment) {
      block.controller.text = '';
      _addAttachment();
      return;
    }

    setState(() {
      block.type = command.blockType ?? NoteBlockType.paragraph;
      block.level = command.level;
      block.controller.text = '';
      block.checked = false;
    });
    _scheduleSave();
    block.focusNode.requestFocus();
  }

  void _applyFormatting(int index, TextFormatType format, {String? url}) {
    if (index >= _blocks.length) return;
    final block = _blocks[index];
    final updated = TextFormattingHelper.applyFormat(
      value: block.controller.value,
      format: format,
      linkUrl: url,
    );
    block.controller.value = updated;
    _scheduleSave();
  }

  KeyEventResult _handleBlockKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final block = _blocks[index];
    final isSlashOpen = _activeSlashBlockIndex == index;

    if (isSlashOpen) {
      final filtered = filterSlashCommands(_slashQuery);
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (filtered.isNotEmpty) {
          setState(() {
            _slashSelectedIndex = (_slashSelectedIndex + 1) % filtered.length;
          });
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (filtered.isNotEmpty) {
          setState(() {
            _slashSelectedIndex =
                (_slashSelectedIndex - 1 + filtered.length) % filtered.length;
          });
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (filtered.isNotEmpty) {
          _applySlashCommand(index, filtered[_slashSelectedIndex]);
        } else {
          setState(() => _activeSlashBlockIndex = null);
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _activeSlashBlockIndex = null);
        return KeyEventResult.handled;
      }
    }

    final isMetaOrControl =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (isMetaOrControl) {
      if (event.logicalKey == LogicalKeyboardKey.keyB) {
        _applyFormatting(index, TextFormatType.bold);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyI) {
        _applyFormatting(index, TextFormatType.italic);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyU) {
        _applyFormatting(index, TextFormatType.underline);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyK) {
        _applyFormatting(index, TextFormatType.link);
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored;
      }
      if (block.type == NoteBlockType.code) {
        return KeyEventResult.ignored;
      }

      final isListType =
          block.type == NoteBlockType.bulletList ||
          block.type == NoteBlockType.numberedList ||
          block.type == NoteBlockType.checkbox;
      if (isListType && block.controller.text.trim().isEmpty) {
        setState(() {
          block.type = NoteBlockType.paragraph;
          block.level = null;
          block.checked = false;
        });
        _scheduleSave();
        return KeyEventResult.handled;
      }

      final int cursorPos = block.controller.selection.isValid
          ? block.controller.selection.baseOffset
          : block.controller.text.length;
      final String fullText = block.controller.text;
      final String textBefore = cursorPos >= 0 && cursorPos <= fullText.length
          ? fullText.substring(0, cursorPos)
          : fullText;
      final String textAfter = cursorPos >= 0 && cursorPos <= fullText.length
          ? fullText.substring(cursorPos)
          : '';

      block.controller.text = textBefore;

      final NoteBlockType nextType = switch (block.type) {
        NoteBlockType.bulletList => NoteBlockType.bulletList,
        NoteBlockType.numberedList => NoteBlockType.numberedList,
        NoteBlockType.checkbox => NoteBlockType.checkbox,
        _ => NoteBlockType.paragraph,
      };

      final newBlock = _EditableBlock.from(
        NoteBlock(
          id: const Uuid().v7(),
          type: nextType,
          text: textAfter,
          checked: nextType == NoteBlockType.checkbox ? false : null,
        ),
        _scheduleSave,
      );

      setState(() {
        _blocks.insert(index + 1, newBlock);
        _activeSlashBlockIndex = null;
        _activeSelectionBlockIndex = null;
      });

      for (int i = 0; i < _blocks.length; i++) {
        _setupBlockListeners(_blocks[i], i);
      }
      _scheduleSave();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && index + 1 < _blocks.length) {
          _blocks[index + 1].focusNode.requestFocus();
          _blocks[index + 1].controller.selection =
              const TextSelection.collapsed(offset: 0);
        }
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      final selection = block.controller.selection;
      if (selection.isCollapsed && selection.baseOffset == 0) {
        if (block.type != NoteBlockType.paragraph) {
          setState(() {
            block.type = NoteBlockType.paragraph;
            block.level = null;
            block.checked = false;
          });
          _scheduleSave();
          return KeyEventResult.handled;
        }

        if (index > 0) {
          final String currentText = block.controller.text;
          final _EditableBlock prevBlock = _blocks[index - 1];
          final int prevLength = prevBlock.controller.text.length;

          if (prevBlock.type != NoteBlockType.divider &&
              prevBlock.type != NoteBlockType.image &&
              prevBlock.type != NoteBlockType.file) {
            prevBlock.controller.text =
                '${prevBlock.controller.text}$currentText';
          }

          setState(() {
            _blocks.removeAt(index).dispose();
            if (_activeSlashBlockIndex == index) _activeSlashBlockIndex = null;
            if (_activeSelectionBlockIndex == index) {
              _activeSelectionBlockIndex = null;
            }
          });

          for (int i = 0; i < _blocks.length; i++) {
            _setupBlockListeners(_blocks[i], i);
          }
          _scheduleSave();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && index - 1 < _blocks.length) {
              prevBlock.focusNode.requestFocus();
              prevBlock.controller.selection = TextSelection.collapsed(
                offset: prevLength,
              );
            }
          });
          return KeyEventResult.handled;
        }
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final selection = block.controller.selection;
      if (selection.isCollapsed && selection.baseOffset <= 0) {
        if (index > 0) {
          final prevBlock = _blocks[index - 1];
          prevBlock.focusNode.requestFocus();
          prevBlock.controller.selection = TextSelection.collapsed(
            offset: prevBlock.controller.text.length,
          );
          return KeyEventResult.handled;
        }
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final selection = block.controller.selection;
      if (selection.isCollapsed &&
          selection.baseOffset >= block.controller.text.length) {
        if (index < _blocks.length - 1) {
          final nextBlock = _blocks[index + 1];
          nextBlock.focusNode.requestFocus();
          nextBlock.controller.selection = const TextSelection.collapsed(
            offset: 0,
          );
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  Future<void> _deleteBlock(int index) async {
    final _EditableBlock block = _blocks[index];
    if (block.attachmentId != null) {
      try {
        await ref
            .read(attachmentsRepositoryProvider)
            .remove(block.attachmentId!);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
        return;
      }
    }
    if (!mounted || index >= _blocks.length || _blocks[index] != block) return;
    setState(() {
      _blocks.removeAt(index).dispose();
      if (_activeSlashBlockIndex == index) _activeSlashBlockIndex = null;
      if (_activeSelectionBlockIndex == index) {
        _activeSelectionBlockIndex = null;
      }
      if (_blocks.isEmpty) {
        final newBlock = _EditableBlock.from(
          NoteBlock(id: const Uuid().v7(), type: NoteBlockType.paragraph),
          _scheduleSave,
        );
        _blocks.add(newBlock);
        _setupBlockListeners(newBlock, 0);
      }
    });
    for (int i = 0; i < _blocks.length; i++) {
      _setupBlockListeners(_blocks[i], i);
    }
    _scheduleSave();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    if (!_loading) unawaited(_persist(showState: false));
    _title.dispose();
    for (final block in _blocks) {
      block.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _saving
              ? 'Kaydediliyor…'
              : _error == null
              ? 'Cihazda kaydedildi'
              : 'Kaydetme sorunu',
        ),
        actions: <Widget>[
          PopupMenuButton<String>(
            tooltip: 'Blok ekle',
            onSelected: (value) {
              final parts = value.split(':');
              final typeName = parts[0];
              final level = parts.length > 1 ? int.tryParse(parts[1]) : null;
              final NoteBlockType? type = NoteBlockType.values
                  .where((item) => item.name == typeName)
                  .firstOrNull;
              if (type != null) _addTextBlock(type, level: level);
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'paragraph', child: Text('Paragraf')),
              PopupMenuItem(value: 'heading:1', child: Text('Başlık 1')),
              PopupMenuItem(value: 'heading:2', child: Text('Başlık 2')),
              PopupMenuItem(value: 'heading:3', child: Text('Başlık 3')),
              PopupMenuItem(value: 'bulletList', child: Text('Madde listesi')),
              PopupMenuItem(
                value: 'numberedList',
                child: Text('Numaralı liste'),
              ),
              PopupMenuItem(value: 'checkbox', child: Text('Yapılacak')),
              PopupMenuItem(value: 'quote', child: Text('Alıntı')),
              PopupMenuItem(value: 'divider', child: Text('Ayraç')),
              PopupMenuItem(value: 'code', child: Text('Kod')),
              PopupMenuItem(value: 'link', child: Text('Bağlantı')),
            ],
            icon: const Icon(Icons.add_circle_outline),
          ),
          IconButton(
            tooltip: 'Dosya veya görsel ekle',
            onPressed: _addAttachment,
            icon: const Icon(Icons.attach_file),
          ),
          IconButton(
            tooltip: 'Hatırlatıcı ekle',
            onPressed: _addReminder,
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            tooltip: 'Şimdi kaydet',
            onPressed: _save,
            icon: const Icon(Icons.cloud_done_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Not işlemleri',
            onSelected: (value) {
              if (value == 'trash') unawaited(_trashNote());
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'trash', child: Text('Çöpe taşı')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _blocks.isEmpty
          ? Center(child: Text(_error!))
          : StreamBuilder<List<AttachmentEntity>>(
              stream: ref
                  .watch(attachmentsRepositoryProvider)
                  .watchForParent('note', widget.noteId),
              builder: (context, attachmentSnapshot) {
                final Map<String, AttachmentEntity> attachments =
                    <String, AttachmentEntity>{
                      for (final item
                          in attachmentSnapshot.data ??
                              const <AttachmentEntity>[])
                        item.id: item,
                    };
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 80),
                      children: <Widget>[
                        TextField(
                          controller: _title,
                          maxLines: null,
                          style: Theme.of(context).textTheme.headlineLarge,
                          decoration: const InputDecoration(
                            hintText: 'Başlıksız not',
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...List<Widget>.generate(
                          _blocks.length,
                          (index) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (_activeSelectionBlockIndex == index)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 36,
                                    bottom: 6,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FormattingToolbar(
                                      activeFormats:
                                          TextFormattingHelper.detectActiveFormats(
                                            _blocks[index].controller.value,
                                          ),
                                      onFormat: (format, {url}) =>
                                          _applyFormatting(
                                            index,
                                            format,
                                            url: url,
                                          ),
                                      onClose: () => setState(
                                        () => _activeSelectionBlockIndex = null,
                                      ),
                                    ),
                                  ),
                                ),
                              _BlockEditorRow(
                                key: ValueKey<String>(_blocks[index].id),
                                block: _blocks[index],
                                attachment: _blocks[index].attachmentId == null
                                    ? null
                                    : attachments[_blocks[index].attachmentId],
                                index: index,
                                onKeyEvent: (event) =>
                                    _handleBlockKeyEvent(index, event),
                                onDelete: () => _deleteBlock(index),
                                onChangedType: (type, {level}) {
                                  setState(() {
                                    _blocks[index].type = type;
                                    _blocks[index].level = level;
                                  });
                                  _scheduleSave();
                                },
                                onChecked: (value) {
                                  setState(
                                    () => _blocks[index].checked = value,
                                  );
                                  _scheduleSave();
                                },
                              ),
                              if (_activeSlashBlockIndex == index)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 36,
                                    top: 4,
                                    bottom: 8,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: SlashCommandPalette(
                                      query: _slashQuery,
                                      selectedIndex: _slashSelectedIndex,
                                      onSelect: (command) =>
                                          _applySlashCommand(index, command),
                                      onClose: () => setState(
                                        () => _activeSlashBlockIndex = null,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () =>
                              _addTextBlock(NoteBlockType.paragraph),
                          icon: const Icon(Icons.add),
                          label: const Text('Blok ekle'),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Hatırlatıcılar',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ReminderList(
                          parentType: 'note',
                          parentId: widget.noteId,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _EditableBlock {
  _EditableBlock({
    required this.id,
    required this.type,
    required this.level,
    required this.controller,
    required this.focusNode,
    required this.urlController,
    required this.checked,
    required this.attachmentId,
  });

  factory _EditableBlock.from(NoteBlock block, VoidCallback onChanged) {
    final FormattedTextEditingController controller =
        FormattedTextEditingController(text: block.text)
          ..addListener(onChanged);
    final TextEditingController urlController = TextEditingController(
      text: block.url ?? '',
    )..addListener(onChanged);
    final FocusNode focusNode = FocusNode();

    return _EditableBlock(
      id: block.id,
      type: block.type,
      level: block.level,
      controller: controller,
      focusNode: focusNode,
      urlController: urlController,
      checked: block.checked ?? false,
      attachmentId: block.attachmentId,
    );
  }

  final String id;
  NoteBlockType type;
  int? level;
  final FormattedTextEditingController controller;
  final FocusNode focusNode;
  final TextEditingController urlController;
  bool checked;
  final String? attachmentId;

  NoteBlock toBlock() => NoteBlock(
    id: id,
    type: type,
    text: controller.text,
    checked: type == NoteBlockType.checkbox ? checked : null,
    url: type == NoteBlockType.link && urlController.text.trim().isNotEmpty
        ? urlController.text.trim()
        : null,
    attachmentId: attachmentId,
    level: type == NoteBlockType.heading ? (level ?? 1) : null,
  );

  void dispose() {
    controller.dispose();
    focusNode.dispose();
    urlController.dispose();
  }
}

class _BlockEditorRow extends StatelessWidget {
  const _BlockEditorRow({
    super.key,
    required this.block,
    required this.attachment,
    required this.index,
    required this.onKeyEvent,
    required this.onDelete,
    required this.onChangedType,
    required this.onChecked,
  });

  final _EditableBlock block;
  final AttachmentEntity? attachment;
  final int index;
  final KeyEventResult Function(KeyEvent event) onKeyEvent;
  final Future<void> Function() onDelete;
  final void Function(NoteBlockType type, {int? level}) onChangedType;
  final ValueChanged<bool> onChecked;

  @override
  Widget build(BuildContext context) {
    if (block.type == NoteBlockType.divider) {
      return Row(
        children: <Widget>[
          const Expanded(child: Divider()),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      );
    }
    if (block.type == NoteBlockType.image || block.type == NoteBlockType.file) {
      return _AttachmentBlockRow(
        attachment: attachment,
        fallbackName: block.controller.text,
        image: block.type == NoteBlockType.image,
        onDelete: onDelete,
      );
    }

    final TextStyle? style = switch (block.type) {
      NoteBlockType.heading => switch (block.level ?? 1) {
        1 => Theme.of(
          context,
        ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        2 => Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
        _ => Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      },
      NoteBlockType.code => Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
      NoteBlockType.quote => Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
      _ => Theme.of(context).textTheme.bodyLarge,
    };

    final Widget prefix = switch (block.type) {
      NoteBlockType.checkbox => Checkbox(
        value: block.checked,
        onChanged: (value) => onChecked(value ?? false),
      ),
      NoteBlockType.bulletList => const SizedBox(
        width: 32,
        child: Center(child: Text('•', style: TextStyle(fontSize: 20))),
      ),
      NoteBlockType.numberedList => SizedBox(
        width: 32,
        child: Center(child: Text('${index + 1}.')),
      ),
      NoteBlockType.quote => const SizedBox(
        width: 24,
        child: Center(child: Text('❝', style: TextStyle(fontSize: 18))),
      ),
      _ => const SizedBox(width: 8),
    };

    final String hintText = switch (block.type) {
      NoteBlockType.heading => switch (block.level ?? 1) {
        1 => 'Başlık 1',
        2 => 'Başlık 2',
        _ => 'Başlık 3',
      },
      NoteBlockType.code => 'Kod yazın…',
      NoteBlockType.quote => 'Alıntı yazın…',
      NoteBlockType.bulletList => 'Liste öğesi…',
      NoteBlockType.numberedList => 'Numaralı öğe…',
      NoteBlockType.checkbox => 'Yapılacak görev…',
      _ => "Yazmaya başlayın veya '/' ile komut açın…",
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          prefix,
          Expanded(
            child: Column(
              children: <Widget>[
                Focus(
                  onKeyEvent: (node, event) => onKeyEvent(event),
                  child: TextField(
                    controller: block.controller,
                    focusNode: block.focusNode,
                    maxLines: null,
                    style: style,
                    decoration: InputDecoration(
                      hintText: hintText,
                      border: InputBorder.none,
                      filled: block.type == NoteBlockType.code,
                      fillColor: block.type == NoteBlockType.code
                          ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.35)
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                if (block.type == NoteBlockType.link)
                  TextField(
                    controller: block.urlController,
                    decoration: const InputDecoration(
                      hintText: 'https://…',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Blok türü',
            onSelected: (value) {
              final parts = value.split(':');
              final typeName = parts[0];
              final level = parts.length > 1 ? int.tryParse(parts[1]) : null;
              final NoteBlockType? type = NoteBlockType.values
                  .where((item) => item.name == typeName)
                  .firstOrNull;
              if (type != null) onChangedType(type, level: level);
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'paragraph', child: Text('Paragraf')),
              PopupMenuItem(value: 'heading:1', child: Text('Başlık 1')),
              PopupMenuItem(value: 'heading:2', child: Text('Başlık 2')),
              PopupMenuItem(value: 'heading:3', child: Text('Başlık 3')),
              PopupMenuItem(value: 'bulletList', child: Text('Madde listesi')),
              PopupMenuItem(
                value: 'numberedList',
                child: Text('Numaralı liste'),
              ),
              PopupMenuItem(value: 'checkbox', child: Text('Yapılacak')),
              PopupMenuItem(value: 'quote', child: Text('Alıntı')),
              PopupMenuItem(value: 'code', child: Text('Kod')),
              PopupMenuItem(value: 'link', child: Text('Bağlantı')),
            ],
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.drag_indicator, size: 18),
            ),
          ),
          IconButton(
            tooltip: 'Bloğu sil',
            onPressed: onDelete,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _AttachmentBlockRow extends ConsumerStatefulWidget {
  const _AttachmentBlockRow({
    required this.attachment,
    required this.fallbackName,
    required this.image,
    required this.onDelete,
  });

  final AttachmentEntity? attachment;
  final String fallbackName;
  final bool image;
  final Future<void> Function() onDelete;

  @override
  ConsumerState<_AttachmentBlockRow> createState() =>
      _AttachmentBlockRowState();
}

class _AttachmentBlockRowState extends ConsumerState<_AttachmentBlockRow> {
  File? _preview;
  bool _loadingPreview = false;

  @override
  void initState() {
    super.initState();
    if (widget.image) unawaited(_loadPreview());
  }

  @override
  void didUpdateWidget(covariant _AttachmentBlockRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image && oldWidget.attachment?.id != widget.attachment?.id) {
      _preview = null;
      unawaited(_loadPreview());
    }
  }

  Future<File?> _ensureLocal() async {
    final AttachmentEntity? attachment = widget.attachment;
    if (attachment == null) return null;
    return ref.read(attachmentsRepositoryProvider).ensureLocal(attachment.id);
  }

  Future<void> _loadPreview() async {
    if (_loadingPreview || widget.attachment == null) return;
    _loadingPreview = true;
    try {
      final File? file = await _ensureLocal();
      if (mounted) setState(() => _preview = file);
    } catch (_) {
      if (mounted) setState(() => _preview = null);
    } finally {
      if (mounted) _loadingPreview = false;
    }
  }

  Future<void> _open() async {
    final AttachmentEntity? attachment = widget.attachment;
    if (attachment != null && attachment.isTransferring) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dosya transferi devam ediyor…')),
      );
      return;
    }
    if (attachment != null && attachment.canRetry) {
      try {
        await ref
            .read(attachmentsRepositoryProvider)
            .retryTransfer(attachment.id);
        if (widget.image) unawaited(_loadPreview());
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
      return;
    }
    try {
      final File? file = await _ensureLocal();
      if (file == null) throw StateError('Ek kaydı bulunamadı.');
      if (!mounted) return;
      await openLocalAttachment(
        context,
        file: file,
        mimeType: attachment?.mimeType,
        title: attachment?.fileName ?? widget.fallbackName,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(attachmentsRepositoryProvider);
    final AttachmentEntity? attachment = widget.attachment;
    final String name = attachment?.fileName.trim().isNotEmpty == true
        ? attachment!.fileName
        : widget.fallbackName.trim().isEmpty
        ? 'Ek dosya'
        : widget.fallbackName;

    return StreamBuilder<Map<String, double>>(
      stream: repo.watchActiveProgress(),
      builder: (context, progressSnapshot) {
        final double? progress = attachment != null
            ? (progressSnapshot.data?[attachment.id])
            : null;
        final bool isTransferring = attachment?.isTransferring == true;
        final bool canRetry = attachment?.canRetry == true;
        final String sizeText = attachment != null
            ? '${(attachment.sizeBytes / 1024).ceil()} KB'
            : '';
        final String statusText = attachment == null
            ? 'Ek kaydı bulunamadı'
            : attachment.transferStatusLabel(progress);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (widget.image)
                InkWell(
                  onTap: _open,
                  child: SizedBox(
                    height: 220,
                    child: _preview == null
                        ? Center(
                            child: _loadingPreview
                                ? const CircularProgressIndicator()
                                : const Icon(
                                    Icons.broken_image_outlined,
                                    size: 42,
                                  ),
                          )
                        : Image.file(
                            _preview!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 42,
                              ),
                            ),
                          ),
                  ),
                ),
              ListTile(
                leading: Icon(
                  widget.image
                      ? Icons.image_outlined
                      : Icons.insert_drive_file_outlined,
                  color: canRetry ? Theme.of(context).colorScheme.error : null,
                ),
                title: Text(name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      attachment == null
                          ? 'Ek kaydı bulunamadı'
                          : '$sizeText · $statusText',
                    ),
                    if (isTransferring) ...<Widget>[
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress != null && progress > 0
                              ? progress
                              : null,
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: _open,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (attachment != null && isTransferring)
                      IconButton(
                        tooltip: 'İptal et',
                        icon: const Icon(Icons.cancel_outlined, size: 20),
                        onPressed: () => repo.cancelTransfer(attachment.id),
                      )
                    else if (attachment != null && canRetry) ...<Widget>[
                      IconButton(
                        tooltip: 'Tekrar dene',
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: () async {
                          try {
                            await repo.retryTransfer(attachment.id);
                            if (widget.image) unawaited(_loadPreview());
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Eki sil',
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ] else
                      IconButton(
                        tooltip: 'Eki sil',
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.close, size: 20),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
