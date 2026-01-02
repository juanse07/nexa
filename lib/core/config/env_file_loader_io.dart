import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import 'package:nexa/core/config/env_parser.dart';

/// List of env files that are bundled as Flutter assets
const _bundledAssets = {'.env.defaults'};

Future<Map<String, String>> loadEnvFileImpl(String path) async {
  // First try to read as a local file (works in dev when running from project dir)
  final file = File(path);
  if (await file.exists()) {
    final lines = await file.readAsLines();
    return parseEnvLines(lines);
  }

  // If local file doesn't exist and this is a bundled asset, try rootBundle
  if (_bundledAssets.contains(path)) {
    try {
      final content = await rootBundle.loadString(path);
      final lines = content.split('\n');
      return parseEnvLines(lines);
    } catch (e) {
      // Asset not found or failed to load
      return <String, String>{};
    }
  }

  return <String, String>{};
}
