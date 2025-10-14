import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class PendingEventsService {
  static const _fileName = 'pending_events.json';
  static const _uuid = Uuid();
  static const _prefsKey = 'pending_events_store_v1';

  Future<File> _file() async {
    if (kIsWeb) {
      throw UnsupportedError('File storage not available on web');
    }
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<Map<String, dynamic>>> list() async {
    try {
      final raw = await _readRaw();
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
      return <Map<String, dynamic>>[];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<String> _readRaw() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefsKey) ?? '[]';
    }
    final f = await _file();
    if (!await f.exists()) return '[]';
    return await f.readAsString();
  }

  Future<void> _write(List<Map<String, dynamic>> items) async {
    final encoded = const JsonEncoder.withIndent('  ').convert(items);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, encoded);
      return;
    }
    final f = await _file();
    await f.writeAsString(encoded);
  }

  Future<String> saveDraft(Map<String, dynamic> draft) async {
    final items = await list();
    final id = (draft['id']?.toString().isNotEmpty ?? false)
        ? draft['id'].toString()
        : _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final toSave = {
      'id': id,
      'updatedAt': now,
      'createdAt': draft['createdAt'] ?? now,
      'data': draft,
      'audienceKeys': draft['audienceKeys'] ?? <String>[],
    };
    final idx = items.indexWhere((e) => (e['id'] ?? '') == id);
    if (idx >= 0) {
      items[idx] = toSave;
    } else {
      items.insert(0, toSave);
    }
    await _write(items);
    return id;
  }

  Future<void> deleteDraft(String id) async {
    final items = await list();
    items.removeWhere((e) => (e['id'] ?? '') == id);
    await _write(items);
  }

  Future<Map<String, dynamic>?> getDraft(String id) async {
    final items = await list();
    return items
        .firstWhere((e) => (e['id'] ?? '') == id, orElse: () => {})
        .cast<String, dynamic>();
  }
}
