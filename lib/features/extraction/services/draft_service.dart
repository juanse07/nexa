import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DraftService {
  static const _prefsKey = 'event_draft_store_v1';

  Future<File> _draftFile() async {
    if (kIsWeb) {
      throw UnsupportedError('File storage not available on web');
    }
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/event_draft.json');
  }

  Future<void> saveDraft(Map<String, dynamic> data) async {
    final encoded = const JsonEncoder.withIndent('  ').convert(data);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, encoded);
      return;
    }
    final file = await _draftFile();
    await file.writeAsString(encoded);
  }

  Future<Map<String, dynamic>?> loadDraft() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_prefsKey);
        if (raw == null || raw.isEmpty) return null;
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        return null;
      }
      final file = await _draftFile();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearDraft() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      return;
    }
    final file = await _draftFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
