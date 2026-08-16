import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/app/widgets/navigation/app_toolbar.dart';
import 'package:not_app/app/widgets/overlays/app_sheet.dart';
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
  final ScrollController _scrollController = ScrollController();
  Timer? _saveTimer;
  OverlayEntry? _slashOverlay;
  OverlayEntry? _formatOverlay;
  bool _loading = true;
  bool _saving = false;
  bool _favorite = false;
  String? _error;
  int? _activeSlashBlockIndex;
  String _slashQuery = '';
  int _slashSelectedIndex = 0;
  int? _activeSelectionBlockIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _title.addListener(_scheduleSave);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_persist(showState: false));
    }
  }

  Future<void> _load() async {
    try {
      final NoteEntity? note = await ref
          .read(notesRepositoryProvider)
          .getNote(widget.noteId);
      if (note == null) throw StateError('Not bulunamadı.');
      _title.text = note.title;
      _favorite = note.isFavorite;
      _blocks.clear();
      final List<NoteBlock> source = note.document.blocks.isEmpty
          ? <NoteBlock>[NoteBlock.paragraph()]
          : note.document.blocks;
      for (final NoteBlock block in source) {
        _blocks.add(_EditableBlock.from(block));
      }
      for (final _EditableBlock block in _blocks) {
        _attachBlockListeners(block);
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

  void _attachBlockListeners(_EditableBlock block) {
    block.controller.addListener(() {
      _scheduleSave();
      final int index = _blocks.indexOf(block);
      if (index < 0) return;
      final String text = block.controller.text;
      final TextSelection selection = block.controller.selection;

      if (block.focusNode.hasFocus && text.startsWith('/')) {
        final String query = text.substring(1);
        if (_activeSlashBlockIndex != index || _slashQuery != query) {
          _activeSlashBlockIndex = index;
          _slashQuery = query;
          final int maxIndex = filterSlashCommands(query).length - 1;
          _slashSelectedIndex = maxIndex < 0
              ? 0
              : _slashSelectedIndex.clamp(0, maxIndex);
          _scheduleOverlayRefresh();
        }
      } else if (_activeSlashBlockIndex == index) {
        _activeSlashBlockIndex = null;
        _removeSlashOverlay();
      }

      if (block.focusNode.hasFocus &&
          selection.isValid &&
          !selection.isCollapsed) {
        if (_activeSelectionBlockIndex != index) {
          _activeSelectionBlockIndex = index;
          _scheduleOverlayRefresh();
        }
      } else if (_activeSelectionBlockIndex == index) {
        _activeSelectionBlockIndex = null;
        _removeFormatOverlay();
      }
    });

    block.urlController.addListener(_scheduleSave);
    block.focusNode.addListener(() {
      final int index = _blocks.indexOf(block);
      if (index < 0) return;
      if (!block.focusNode.hasFocus) {
        if (_activeSlashBlockIndex == index) {
          _activeSlashBlockIndex = null;
          _removeSlashOverlay();
        }
        if (_activeSelectionBlockIndex == index) {
          _activeSelectionBlockIndex = null;
          _removeFormatOverlay();
        }
      }
    });
  }

  void _scheduleOverlayRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshSlashOverlay();
      _refreshFormatOverlay();
    });
  }

  void _removeSlashOverlay() {
    _slashOverlay?.remove();
    _slashOverlay = null;
  }

  void _removeFormatOverlay() {
    _formatOverlay?.remove();
    _formatOverlay = null;
  }

  void _refreshSlashOverlay() {
    _removeSlashOverlay();
    final int? index = _activeSlashBlockIndex;
    if (index == null || index < 0 || index >= _blocks.length) return;
    final _EditableBlock block = _blocks[index];
    final OverlayState overlay = Overlay.of(context);
    _slashOverlay = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: CompositedTransformFollower(
          link: block.layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(34, 4),
          child: Align(
            alignment: Alignment.topLeft,
            child: SlashCommandPalette(
              query: _slashQuery,
              selectedIndex: _slashSelectedIndex,
              onSelect: (command) => _applySlashCommand(index, command),
              onClose: () {
                _activeSlashBlockIndex = null;
                _removeSlashOverlay();
              },
            ),
          ),
        ),
      ),
    );
    overlay.insert(_slashOverlay!);
  }

  void _refreshFormatOverlay() {
    _removeFormatOverlay();
    final int? index = _activeSelectionBlockIndex;
    if (index == null || index < 0 || index >= _blocks.length) return;
    final _EditableBlock block = _blocks[index];
    final OverlayState overlay = Overlay.of(context);
    _formatOverlay = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: CompositedTransformFollower(
          link: block.layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(34, -6),
          child: Align(
            alignment: Alignment.topLeft,
            child: FormattingToolbar(
              activeFormats: TextFormattingHelper.detectActiveFormats(
                block.controller.value,
              ),
              onFormat: (format, {url}) =>
                  _applyFormatting(index, format, url: url),
              onClose: () {
                _activeSelectionBlockIndex = null;
                _removeFormatOverlay();
              },
            ),
          ),
        ),
      ),
    );
    overlay.insert(_formatOverlay!);
  }

  void _scheduleSave() {
    if (_loading) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 550), _persist);
    if (mounted && !_saving) setState(() {});
  }

  NoteDocument _document() => NoteDocument(
        version: NoteDocument.currentVersion,
        blocks: _blocks.map((item) => item.toBlock()).toList(growable: false),
      );

  Future<void> _persist({bool showState = true}) async {
    if (_loading) return;
    _saveTimer?.cancel();
    if (showState && mounted) setState(() => _saving = true);
    try {
      final repo = ref.read(notesRepositoryProvider);
      await repo.updateTitle(widget.noteId, _title.text);
      await repo.saveDocument(widget.noteId, _document());
      if (mounted) {
        setState(() {
          _saving = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final bool next = !_favorite;
    setState(() => _favorite = next);
    try {
      await ref.read(notesRepositoryProvider).setFavorite(widget.noteId, next);
    } catch (_) {
      if (mounted) setState(() => _favorite = !next);
    }
  }

  Future<void> _addAttachment({int? afterIndex}) async {
    final source = await ref.read(filePickerServiceProvider).pickSingleFile();
    if (source == null) return;
    final AttachmentEntity attachment = await ref
        .read(attachmentsRepositoryProvider)
        .addFromFile(
          parentType: 'note',
          parentId: widget.noteId,
          source: source,
        );
    final bool image = attachment.mimeType?.startsWith('image/') == true;
    final _EditableBlock newBlock = _EditableBlock.from(
      NoteBlock(
        id: attachment.id,
        type: image ? NoteBlockType.image : NoteBlockType.file,
        text: attachment.fileName,
        attachmentId: attachment.id,
      ),
    );
    _attachBlockListeners(newBlock);
    setState(() {
      final int insertion = afterIndex == null
          ? _blocks.length
          : (afterIndex + 1).clamp(0, _blocks.length);
      _blocks.insert(insertion, newBlock);
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

  Future<void> _showReminders() => showAppSheet<void>(
        context: context,
        builder: (sheetContext) => Column(
          children: <Widget>[
            const AppSheetHeader(title: 'Hatırlatıcılar'),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _addReminder();
                    },
                    icon: const Icon(Icons.add_alert_outlined, size: 18),
                    label: const Text('Hatırlatıcı ekle'),
                  ),
                  const SizedBox(height: 16),
                  ReminderList(parentType: 'note', parentId: widget.noteId),
                ],
              ),
            ),
          ],
        ),
      );

  Future<void> _trashNote() async {
    await _persist(showState: false);
    final repository = ref.read(notesRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repository.trash(widget.noteId);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Not çöp kutusuna taşındı.'),
        action: SnackBarAction(
          label: 'Geri al',
          onPressed: () => repository.restore(widget.noteId),
        ),
      ),
    );
  }

  void _insertBlockAfter(int index, NoteBlockType type, {int? level}) {
    final _EditableBlock newBlock = _EditableBlock.from(
      NoteBlock(id: const Uuid().v7(), type: type, level: level),
    );
    _attachBlockListeners(newBlock);
    setState(
      () => _blocks.insert((index + 1).clamp(0, _blocks.length), newBlock),
    );
    _scheduleSave();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) newBlock.focusNode.requestFocus();
    });
  }

  void _applySlashCommand(int index, SlashCommandItem command) {
    if (index < 0 || index >= _blocks.length) return;
    final _EditableBlock block = _blocks[index];
    _activeSlashBlockIndex = null;
    _removeSlashOverlay();
    if (command.id == SlashCommandId.attachment) {
      block.controller.clear();
      unawaited(_addAttachment(afterIndex: index));
      return;
    }
    setState(() {
      block.type = command.blockType ?? NoteBlockType.paragraph;
      block.level = command.level;
      block.checked = false;
      block.controller.clear();
    });
    _scheduleSave();
    block.focusNode.requestFocus();
  }

  void _applyFormatting(int index, TextFormatType format, {String? url}) {
    if (index < 0 || index >= _blocks.length) return;
    final _EditableBlock block = _blocks[index];
    block.controller.value = TextFormattingHelper.applyFormat(
      value: block.controller.value,
      format: format,
      linkUrl: url,
    );
    _scheduleSave();
    _scheduleOverlayRefresh();
  }

  void _focusPreviousBlock(int index) {
    if (index <= 0) return;
    final _EditableBlock previous = _blocks[index - 1];
    if (!previous.isTextBlock) return;
    previous.focusNode.requestFocus();
    previous.controller.selection = TextSelection.collapsed(
      offset: previous.controller.text.length,
    );
  }

  void _focusNextBlock(int index) {
    if (index < 0 || index >= _blocks.length - 1) return;
    final _EditableBlock next = _blocks[index + 1];
    if (!next.isTextBlock) return;
    next.focusNode.requestFocus();
    next.controller.selection = const TextSelection.collapsed(offset: 0);
  }

  KeyEventResult _handleBlockKeyEvent(_EditableBlock block, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final int index = _blocks.indexOf(block);
    if (index < 0) return KeyEventResult.ignored;

    if (_activeSlashBlockIndex == index) {
      final List<SlashCommandItem> filtered = filterSlashCommands(_slashQuery);
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (filtered.isNotEmpty) {
          setState(() {
            _slashSelectedIndex = (_slashSelectedIndex + 1) % filtered.length;
          });
          _refreshSlashOverlay();
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (filtered.isNotEmpty) {
          setState(() {
            _slashSelectedIndex =
                (_slashSelectedIndex - 1 + filtered.length) % filtered.length;
          });
          _refreshSlashOverlay();
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (filtered.isNotEmpty) {
          _applySlashCommand(index, filtered[_slashSelectedIndex]);
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _activeSlashBlockIndex = null;
        _removeSlashOverlay();
        return KeyEventResult.handled;
      }
    }

    final bool modifier = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (modifier) {
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

    if ((event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        !HardwareKeyboard.instance.isShiftPressed &&
        block.type != NoteBlockType.code) {
      final bool listType = block.type == NoteBlockType.bulletList ||
          block.type == NoteBlockType.numberedList ||
          block.type == NoteBlockType.checkbox;
      if (listType && block.controller.text.trim().isEmpty) {
        setState(() {
          block.type = NoteBlockType.paragraph;
          block.level = null;
          block.checked = false;
        });
        _scheduleSave();
        return KeyEventResult.handled;
      }

      final TextSelection selection = block.controller.selection;
      final int cursor = selection.isValid
          ? selection.baseOffset.clamp(0, block.controller.text.length)
          : block.controller.text.length;
      final String before = block.controller.text.substring(0, cursor);
      final String after = block.controller.text.substring(cursor);
      block.controller.value = TextEditingValue(
        text: before,
        selection: TextSelection.collapsed(offset: before.length),
      );
      final NoteBlockType nextType = switch (block.type) {
        NoteBlockType.bulletList => NoteBlockType.bulletList,
        NoteBlockType.numberedList => NoteBlockType.numberedList,
        NoteBlockType.checkbox => NoteBlockType.checkbox,
        _ => NoteBlockType.paragraph,
      };
      final _EditableBlock next = _EditableBlock.from(
        NoteBlock(
          id: const Uuid().v7(),
          type: nextType,
          text: after,
          checked: nextType == NoteBlockType.checkbox ? false : null,
        ),
      );
      _attachBlockListeners(next);
      setState(() => _blocks.insert(index + 1, next));
      _scheduleSave();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) next.focusNode.requestFocus();
      });
      return KeyEventResult.handled;
    }

    if ((event.logicalKey == LogicalKeyboardKey.backspace ||
            event.logicalKey == LogicalKeyboardKey.delete) &&
        block.controller.selection.isCollapsed &&
        block.controller.selection.baseOffset == 0) {
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
        final _EditableBlock previous = _blocks[index - 1];
        if (previous.isTextBlock) {
          final int offset = previous.controller.text.length;
          previous.controller.text += block.controller.text;
          setState(() {
            _blocks.removeAt(index).dispose();
          });
          previous.focusNode.requestFocus();
          previous.controller.selection = TextSelection.collapsed(offset: offset);
          _scheduleSave();
          return KeyEventResult.handled;
        }
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final TextSelection selection = block.controller.selection;
      if (selection.isCollapsed && selection.baseOffset <= 0 && index > 0) {
        _focusPreviousBlock(index);
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final TextSelection selection = block.controller.selection;
      if (selection.isCollapsed &&
          selection.baseOffset >= block.controller.text.length &&
          index < _blocks.length - 1) {
        _focusNextBlock(index);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Future<void> _deleteBlock(_EditableBlock block) async {
    if (block.attachmentId != null) {
      try {
        await ref.read(attachmentsRepositoryProvider).remove(block.attachmentId!);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
        return;
      }
    }
    final int index = _blocks.indexOf(block);
    if (index < 0) return;
    setState(() {
      _blocks.removeAt(index).dispose();
      if (_blocks.isEmpty) {
        final _EditableBlock next = _EditableBlock.from(NoteBlock.paragraph());
        _attachBlockListeners(next);
        _blocks.add(next);
      }
    });
    _scheduleSave();
  }

  void _moveBlock(_EditableBlock block, int delta) {
    final int index = _blocks.indexOf(block);
    final int destination = index + delta;
    if (index < 0 || destination < 0 || destination >= _blocks.length) return;
    setState(() {
      _blocks.removeAt(index);
      _blocks.insert(destination, block);
    });
    _scheduleSave();
  }

  void _reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex || oldIndex < 0 || oldIndex >= _blocks.length) {
      return;
    }
    setState(() {
      final _EditableBlock block = _blocks.removeAt(oldIndex);
      _blocks.insert(newIndex.clamp(0, _blocks.length), block);
    });
    _scheduleSave();
  }

  String get _saveLabel {
    if (_saving) return 'Kaydediliyor…';
    if (_error != null) return 'Kaydetme sorunu';
    return 'Bu cihazda kaydedildi';
  }

  IconData get _saveIcon {
    if (_saving) return Icons.sync_rounded;
    if (_error != null) return Icons.error_outline_rounded;
    return Icons.check_circle_outline_rounded;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeSlashOverlay();
    _removeFormatOverlay();
    _saveTimer?.cancel();
    if (!_loading) unawaited(_persist(showState: false));
    _title.dispose();
    _scrollController.dispose();
    for (final _EditableBlock block in _blocks) {
      block.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          AppToolbar(
            title: 'Not',
            breadcrumb: 'Notlar',
            leading: IconButton(
              tooltip: 'Geri',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            status: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(_saveIcon, size: 14),
                const SizedBox(width: 5),
                Text(
                  _saveLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: <Widget>[
              AppIconButton(
                icon: _favorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                tooltip: _favorite ? 'Favoriden çıkar' : 'Favoriye ekle',
                selected: _favorite,
                onPressed: _toggleFavorite,
              ),
              AppIconButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Hatırlatıcılar',
                onPressed: _showReminders,
              ),
              PopupMenuButton<String>(
                tooltip: 'Not işlemleri',
                onSelected: (value) {
                  if (value == 'attachment') {
                    unawaited(_addAttachment());
                  } else if (value == 'reminder') {
                    unawaited(_addReminder());
                  } else if (value == 'trash') {
                    unawaited(_trashNote());
                  }
                },
                itemBuilder: (_) => const <PopupMenuEntry<String>>[
                  PopupMenuItem(
                    value: 'attachment',
                    child: Text('Dosya veya görsel ekle'),
                  ),
                  PopupMenuItem(
                    value: 'reminder',
                    child: Text('Hatırlatıcı ekle'),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'trash', child: Text('Çöpe taşı')),
                ],
              ),
            ],
          ),
          Expanded(
            child: _loading
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
                            for (final item in attachmentSnapshot.data ??
                                const <AttachmentEntity>[])
                              item.id: item,
                          };
                          return Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: ListView(
                                controller: _scrollController,
                                padding: EdgeInsets.fromLTRB(
                                  MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                                  34,
                                  MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                                  100,
                                ),
                                children: <Widget>[
                                  TextField(
                                    controller: _title,
                                    maxLines: null,
                                    style:
                                        Theme.of(context).textTheme.headlineLarge,
                                    decoration: const InputDecoration(
                                      hintText: 'Başlıksız',
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      filled: false,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  ReorderableListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    buildDefaultDragHandles: false,
                                    itemCount: _blocks.length,
                                    onReorder: _reorder,
                                    itemBuilder: (context, index) {
                                      final _EditableBlock block = _blocks[index];
                                      return _EditorBlockRow(
                                        key: ValueKey<String>(block.id),
                                        block: block,
                                        index: index,
                                        attachment: block.attachmentId == null
                                            ? null
                                            : attachments[block.attachmentId],
                                        onKeyEvent: (event) =>
                                            _handleBlockKeyEvent(block, event),
                                        onDelete: () => _deleteBlock(block),
                                        onInsert: () => _insertBlockAfter(
                                          index,
                                          NoteBlockType.paragraph,
                                        ),
                                        onMoveUp: index > 0
                                            ? () => _moveBlock(block, -1)
                                            : null,
                                        onMoveDown: index < _blocks.length - 1
                                            ? () => _moveBlock(block, 1)
                                            : null,
                                        onChangeType: (type, level) {
                                          setState(() {
                                            block.type = type;
                                            block.level = level;
                                          });
                                          _scheduleSave();
                                        },
                                        onChecked: (value) {
                                          setState(() => block.checked = value);
                                          _scheduleSave();
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () => _insertBlockAfter(
                                        _blocks.length - 1,
                                        NoteBlockType.paragraph,
                                      ),
                                      icon: const Icon(
                                        Icons.add_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Blok ekle'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
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

  factory _EditableBlock.from(NoteBlock block) => _EditableBlock(
        id: block.id,
        type: block.type,
        level: block.level,
        controller: FormattedTextEditingController(text: block.text),
        focusNode: FocusNode(debugLabel: 'NoteBlock:${block.id}'),
        urlController: TextEditingController(text: block.url ?? ''),
        checked: block.checked ?? false,
        attachmentId: block.attachmentId,
      );

  final String id;
  NoteBlockType type;
  int? level;
  final FormattedTextEditingController controller;
  final FocusNode focusNode;
  final TextEditingController urlController;
  final LayerLink layerLink = LayerLink();
  bool checked;
  final String? attachmentId;

  bool get isTextBlock =>
      type != NoteBlockType.divider &&
      type != NoteBlockType.image &&
      type != NoteBlockType.file;

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

class _EditorBlockRow extends StatefulWidget {
  const _EditorBlockRow({
    super.key,
    required this.block,
    required this.index,
    required this.attachment,
    required this.onKeyEvent,
    required this.onDelete,
    required this.onInsert,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onChangeType,
    required this.onChecked,
  });

  final _EditableBlock block;
  final int index;
  final AttachmentEntity? attachment;
  final KeyEventResult Function(KeyEvent event) onKeyEvent;
  final Future<void> Function() onDelete;
  final VoidCallback onInsert;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final void Function(NoteBlockType type, int? level) onChangeType;
  final ValueChanged<bool> onChecked;

  @override
  State<_EditorBlockRow> createState() => _EditorBlockRowState();
}

class _EditorBlockRowState extends State<_EditorBlockRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final _EditableBlock block = widget.block;
    return CompositedTransformTarget(
      link: block.layerLink,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 34,
                child: AnimatedOpacity(
                  opacity: _hovered || block.focusNode.hasFocus ? 1 : 0.18,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 110),
                  child: Column(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Altına blok ekle',
                        onPressed: widget.onInsert,
                        icon: const Icon(Icons.add_rounded, size: 17),
                      ),
                      ReorderableDragStartListener(
                        index: widget.index,
                        child: PopupMenuButton<String>(
                          tooltip: 'Bloğu taşı veya düzenle',
                          onSelected: (value) {
                            if (value == 'up') widget.onMoveUp?.call();
                            if (value == 'down') widget.onMoveDown?.call();
                            if (value == 'delete') {
                              unawaited(widget.onDelete());
                            }
                          },
                          itemBuilder: (_) => <PopupMenuEntry<String>>[
                            PopupMenuItem(
                              value: 'up',
                              enabled: widget.onMoveUp != null,
                              child: const Text('Yukarı taşı'),
                            ),
                            PopupMenuItem(
                              value: 'down',
                              enabled: widget.onMoveDown != null,
                              child: const Text('Aşağı taşı'),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Bloğu sil'),
                            ),
                          ],
                          icon: const Icon(
                            Icons.drag_indicator_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: _blockContent(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blockContent(BuildContext context) {
    final _EditableBlock block = widget.block;
    if (block.type == NoteBlockType.divider) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Divider(color: Theme.of(context).dividerColor),
      );
    }
    if (block.type == NoteBlockType.image || block.type == NoteBlockType.file) {
      return _AttachmentBlock(
        attachment: widget.attachment,
        fallbackName: block.controller.text,
        image: block.type == NoteBlockType.image,
        onDelete: widget.onDelete,
      );
    }

    final TextStyle? style = switch (block.type) {
      NoteBlockType.heading => switch (block.level ?? 1) {
          1 => Theme.of(context).textTheme.headlineMedium,
          2 => Theme.of(context).textTheme.headlineSmall,
          _ => Theme.of(context).textTheme.titleLarge,
        },
      NoteBlockType.code => Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
          ),
      NoteBlockType.quote => Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontStyle: FontStyle.italic,
          ),
      _ => Theme.of(context).textTheme.bodyLarge,
    };

    final Widget prefix = switch (block.type) {
      NoteBlockType.checkbox => Checkbox(
          value: block.checked,
          onChanged: (value) => widget.onChecked(value ?? false),
        ),
      NoteBlockType.bulletList => const SizedBox(
          width: 26,
          child: Padding(
            padding: EdgeInsets.only(top: 7),
            child: Text('•', textAlign: TextAlign.center),
          ),
        ),
      NoteBlockType.numberedList => SizedBox(
          width: 30,
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text('${widget.index + 1}.', textAlign: TextAlign.center),
          ),
        ),
      NoteBlockType.quote => Container(
          width: 3,
          height: 34,
          margin: const EdgeInsets.only(right: 10, top: 4),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      _ => const SizedBox.shrink(),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        prefix,
        Expanded(
          child: Column(
            children: <Widget>[
              Focus(
                onKeyEvent: (_, event) => widget.onKeyEvent(event),
                child: TextField(
                  controller: block.controller,
                  focusNode: block.focusNode,
                  maxLines: null,
                  style: style,
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: block.type == NoteBlockType.code,
                    fillColor: block.type == NoteBlockType.code
                        ? Theme.of(context)
                            .colorScheme
                            .surfaceContainer
                            .withValues(alpha: 0.72)
                        : Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 7,
                    ),
                  ),
                ),
              ),
              if (block.type == NoteBlockType.link)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextField(
                    controller: block.urlController,
                    decoration: const InputDecoration(
                      hintText: 'https://…',
                      prefixIcon: Icon(Icons.link_rounded, size: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Blok türü',
          onSelected: (value) {
            final List<String> parts = value.split(':');
            final String typeName = parts.first;
            final int? level = parts.length > 1 ? int.tryParse(parts[1]) : null;
            for (final NoteBlockType type in NoteBlockType.values) {
              if (type.name == typeName) {
                widget.onChangeType(type, level);
                return;
              }
            }
          },
          itemBuilder: (_) => const <PopupMenuEntry<String>>[
            PopupMenuItem(value: 'paragraph', child: Text('Paragraf')),
            PopupMenuItem(value: 'heading:1', child: Text('Başlık 1')),
            PopupMenuItem(value: 'heading:2', child: Text('Başlık 2')),
            PopupMenuItem(value: 'heading:3', child: Text('Başlık 3')),
            PopupMenuItem(value: 'bulletList', child: Text('Madde listesi')),
            PopupMenuItem(value: 'numberedList', child: Text('Numaralı liste')),
            PopupMenuItem(value: 'checkbox', child: Text('Yapılacak')),
            PopupMenuItem(value: 'quote', child: Text('Alıntı')),
            PopupMenuItem(value: 'code', child: Text('Kod')),
            PopupMenuItem(value: 'link', child: Text('Bağlantı')),
            PopupMenuItem(value: 'divider', child: Text('Ayraç')),
          ],
          icon: const Icon(Icons.more_horiz_rounded, size: 18),
        ),
      ],
    );
  }
}

class _AttachmentBlock extends StatelessWidget {
  const _AttachmentBlock({
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
  Widget build(BuildContext context) {
    final String name = attachment?.fileName ?? fallbackName;
    if (image && attachment?.hasLocalCopy == true) {
      final File file = File(attachment!.localPath);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Stack(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => openLocalAttachment(
                  context,
                  file: file,
                  mimeType: attachment!.mimeType,
                  title: name,
                ),
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => _fileTile(context, name),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton.filledTonal(
                tooltip: 'Eki kaldır',
                onPressed: onDelete,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ),
          ],
        ),
      );
    }
    return _fileTile(context, name);
  }

  Widget _fileTile(BuildContext context, String name) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: attachment?.hasLocalCopy == true
                ? () => openLocalAttachment(
                      context,
                      file: File(attachment!.localPath),
                      mimeType: attachment!.mimeType,
                      title: name,
                    )
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: <Widget>[
                  Icon(
                    image
                        ? Icons.image_outlined
                        : Icons.insert_drive_file_outlined,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (attachment != null)
                          Text(
                            attachment!.transferStatusLabel(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Eki kaldır',
                    onPressed: onDelete,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
