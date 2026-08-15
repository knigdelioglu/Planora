import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<NativeDatabase> openNativeConnection() async {
  final Directory directory = await getApplicationSupportDirectory();
  final Directory dbDirectory = Directory(p.join(directory.path, 'database'));
  await dbDirectory.create(recursive: true);
  final File file = File(p.join(dbDirectory.path, 'not.sqlite'));
  return NativeDatabase.createInBackground(file);
}
