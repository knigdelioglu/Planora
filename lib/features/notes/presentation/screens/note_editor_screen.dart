import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_app/app/providers.dart';
import 'package:not_app/features/attachments/domain/entities/attachment.dart';
import 'package:not_app/features/notes/domain/entities/note.dart';
import 'package:not_app/features/notes/domain/entities/note_document.dart';
import 'package:not_app/features/reminders/presentation/reminder_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
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
      for (final NoteBlock block in note.document.blocks) {
        _blocks.add(_EditableBlock.from(block, _scheduleSave));
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
      _blocks.add(
        _EditableBlock.from(
          NoteBlock(
            id: attachment.id,
            type: image ? NoteBlockType.image : NoteBlockType.file,
            text: attachment.fileName,
            attachmentId: attachment.id,
          ),
          _scheduleSave,
        ),
      );
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

  void _addTextBlock(NoteBlockType type) {
    setState(
      () => _blocks.add(
        _EditableBlock.from(
          NoteBlock(id: const Uuid().v7(), type: type),
          _scheduleSave,
        ),
      ),
    );
    _scheduleSave();
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
      if (_blocks.isEmpty) {
        _blocks.add(
          _EditableBlock.from(
            NoteBlock(id: const Uuid().v7(), type: NoteBlockType.paragraph),
            _scheduleSave,
          ),
        );
      }
    });
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
              final NoteBlockType? type = NoteBlockType.values
                  .where((item) => item.name == value)
                  .firstOrNull;
              if (type != null) _addTextBlock(type);
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'paragraph', child: Text('Paragraf')),
              PopupMenuItem(value: 'heading', child: Text('Başlık')),
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
                final Map<String, AttachmentEntity> attachments = <
                  String,
                  AttachmentEntity
                >{
                  for (final item in
                      attachmentSnapshot.data ?? const <AttachmentEntity>[])
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
                          (index) => _BlockEditorRow(
                            key: ValueKey<String>(_blocks[index].id),
                            block: _blocks[index],
                            attachment: _blocks[index].attachmentId == null
                                ? null
                                : attachments[_blocks[index].attachmentId],
                            index: index,
                            onDelete: () => _deleteBlock(index),
                            onChangedType: (type) {
                              setState(() => _blocks[index].type = type);
                              _scheduleSave();
                            },
                            onChecked: (value) {
                              setState(() => _blocks[index].checked = value);
                              _scheduleSave();
                            },
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
    required this.controller,
    required this.urlController,
    required this.checked,
    required this.attachmentId,
  });

  factory _EditableBlock.from(NoteBlock block, VoidCallback onChanged) {
    final TextEditingController controller = TextEditingController(
      text: block.text,
    )..addListener(onChanged);
    final TextEditingController urlController = TextEditingController(
      text: block.url ?? '',
    )..addListener(onChanged);
    return _EditableBlock(
      id: block.id,
      type: block.type,
      controller: controller,
      urlController: urlController,
      checked: block.checked ?? false,
      attachmentId: block.attachmentId,
    );
  }

  final String id;
  NoteBlockType type;
  final TextEditingController controller;
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
    level: type == NoteBlockType.heading ? 2 : null,
  );

  void dispose() {
    controller.dispose();
    urlController.dispose();
  }
}

class _BlockEditorRow extends StatelessWidget {
  const _BlockEditorRow({
    super.key,
    required this.block,
    required this.attachment,
    required this.index,
    required this.onDelete,
    required this.onChangedType,
    required this.onChecked,
  });
  final _EditableBlock block;
  final AttachmentEntity? attachment;
  final int index;
  final Future<void> Function() onDelete;
  final ValueChanged<NoteBlockType> onChangedType;
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
      NoteBlockType.heading => Theme.of(context).textTheme.headlineMedium,
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
        child: Center(child: Text('•')),
      ),
      NoteBlockType.numberedList => SizedBox(
        width: 32,
        child: Center(child: Text('${index + 1}.')),
      ),
      NoteBlockType.quote => const SizedBox(
        width: 24,
        child: Center(child: Text('❝')),
      ),
      _ => const SizedBox(width: 8),
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
                TextField(
                  controller: block.controller,
                  maxLines: null,
                  style: style,
                  decoration: InputDecoration(
                    hintText: block.type == NoteBlockType.heading
                        ? 'Başlık'
                        : block.type == NoteBlockType.code
                        ? 'Kod yazın…'
                        : 'Yazmaya başlayın…',
                    border: InputBorder.none,
                    filled: block.type == NoteBlockType.code,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
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
          PopupMenuButton<NoteBlockType>(
            tooltip: 'Blok türü',
            onSelected: onChangedType,
            itemBuilder: (_) => const <PopupMenuEntry<NoteBlockType>>[
              PopupMenuItem(
                value: NoteBlockType.paragraph,
                child: Text('Paragraf'),
              ),
              PopupMenuItem(
                value: NoteBlockType.heading,
                child: Text('Başlık'),
              ),
              PopupMenuItem(
                value: NoteBlockType.bulletList,
                child: Text('Madde'),
              ),
              PopupMenuItem(
                value: NoteBlockType.numberedList,
                child: Text('Numara'),
              ),
              PopupMenuItem(
                value: NoteBlockType.checkbox,
                child: Text('Yapılacak'),
              ),
              PopupMenuItem(value: NoteBlockType.quote, child: Text('Alıntı')),
              PopupMenuItem(value: NoteBlockType.code, child: Text('Kod')),
              PopupMenuItem(value: NoteBlockType.link, child: Text('Bağlantı')),
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
      _loadingPreview = false;
    }
  }

  Future<void> _open() async {
    try {
      final File? file = await _ensureLocal();
      if (file == null) throw StateError('Ek kaydı bulunamadı.');
      final bool opened = await launchUrl(Uri.file(file.path));
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dosya bu cihazda açılamadı.')),
        );
      }
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
    final AttachmentEntity? attachment = widget.attachment;
    final String name = attachment?.fileName.trim().isNotEmpty == true
        ? attachment!.fileName
        : widget.fallbackName.trim().isEmpty
        ? 'Ek dosya'
        : widget.fallbackName;
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
                            : const Icon(Icons.broken_image_outlined, size: 42),
                      )
                    : Image.file(
                        _preview!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 42),
                        ),
                      ),
              ),
            ),
          ListTile(
            leading: Icon(
              widget.image
                  ? Icons.image_outlined
                  : Icons.insert_drive_file_outlined,
            ),
            title: Text(name),
            subtitle: Text(
              attachment == null
                  ? 'Ek kaydı bulunamadı'
                  : '${(attachment.sizeBytes / 1024).ceil()} KB · ${attachment.transferState}',
            ),
            onTap: _open,
            trailing: IconButton(
              tooltip: 'Eki sil',
              onPressed: widget.onDelete,
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
