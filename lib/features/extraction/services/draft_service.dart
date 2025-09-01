import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class DraftService {
  Future<File> _draftFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/event_draft.json');
  }

  Future<void> saveDraft(Map<String, dynamic> data) async {
    final file = await _draftFile();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<Map<String, dynamic>?> loadDraft() async {
    try {
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
    final file = await _draftFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
