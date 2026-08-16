import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const MethodChannel _androidFileOpener = MethodChannel(
  'io.planora/file_opener',
);

Future<void> openLocalAttachment(
  BuildContext context, {
  required File file,
  String? mimeType,
  String? title,
}) async {
  if (_isImage(file, mimeType)) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ImageAttachmentPreview(
          file: file,
          title: title ?? file.uri.pathSegments.last,
        ),
      ),
    );
    return;
  }

  bool opened = false;
  if (Platform.isAndroid) {
    opened =
        await _androidFileOpener.invokeMethod<bool>('openFile', <String, Object?>{
          'path': file.path,
          'mimeType': mimeType,
        }) ??
        false;
  } else {
    opened = await launchUrl(Uri.file(file.path));
  }

  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dosya bu cihazda açılamadı.')),
    );
  }
}

bool _isImage(File file, String? mimeType) {
  if (mimeType?.startsWith('image/') == true) return true;
  final String path = file.path.toLowerCase();
  return const <String>[
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
    '.heic',
    '.heif',
  ].any(path.endsWith);
}

class _ImageAttachmentPreview extends StatelessWidget {
  const _ImageAttachmentPreview({required this.file, required this.title});

  final File file;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 64,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
