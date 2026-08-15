import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<QueryExecutor> openNativeConnection() async {
  final directory = await getApplicationSupportDirectory();
  final databaseDir = Directory(p.join(directory.path, 'app_storage'));
  await databaseDir.create(recursive: true);
  final file = File(p.join(databaseDir.path, 'not.sqlite'));
  return NativeDatabase.createInBackground(file);
}
