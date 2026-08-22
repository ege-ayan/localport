import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String?> incomingFilePath(String fileName) async {
  final downloads =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(downloads.path, 'LocalPort'));
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }
  return p.join(dir.path, fileName);
}
