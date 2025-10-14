import 'dart:async';
import 'dart:io';

import 'env_parser.dart';

Future<Map<String, String>> loadEnvFileImpl(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    return <String, String>{};
  }
  final lines = await file.readAsLines();
  return parseEnvLines(lines);
}
