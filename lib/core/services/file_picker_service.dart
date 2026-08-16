import 'dart:io';

import 'package:file_picker/file_picker.dart';

abstract interface class FilePickerService {
  Future<File?> pickSingleFile();
}

final class PlatformFilePickerService implements FilePickerService {
  const PlatformFilePickerService();

  @override
  Future<File?> pickSingleFile() async {
    final PlatformFile? result = await FilePicker.pickFile();
    if (result == null) {
      return null;
    }
    final String? path = result.path;
    return path == null ? null : File(path);
  }
}
