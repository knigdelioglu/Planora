import 'dart:io';

import 'package:file_picker/file_picker.dart';

abstract interface class FilePickerService {
  Future<File?> pickSingleFile();
}

final class PlatformFilePickerService implements FilePickerService {
  const PlatformFilePickerService();

  @override
  Future<File?> pickSingleFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      lockParentWindow: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final String? path = result.files.single.path;
    return path == null ? null : File(path);
  }
}
