import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing work terminology preferences (Jobs, Shifts, Events)
class TerminologyProvider with ChangeNotifier {
  static const String _key = 'work_terminology';
  String _terminology = 'Jobs'; // Default

  TerminologyProvider() {
    _loadPreference();
  }

  String get terminology => _terminology;

  /// Get singular form (Job, Shift, Event)
  String get singular {
    switch (_terminology) {
      case 'Shifts':
        return 'Shift';
      case 'Events':
        return 'Event';
      case 'Jobs':
      default:
        return 'Job';
    }
  }

  /// Get plural form (Jobs, Shifts, Events)
  String get plural => _terminology;

  /// Get lowercase singular form
  String get singularLowercase => singular.toLowerCase();

  /// Get lowercase plural form
  String get pluralLowercase => plural.toLowerCase();

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && (saved == 'Jobs' || saved == 'Shifts' || saved == 'Events')) {
      _terminology = saved;
      notifyListeners();
    }
  }

  Future<void> setTerminology(String value) async {
    if (value != 'Jobs' && value != 'Shifts' && value != 'Events') {
      throw ArgumentError('Invalid terminology: $value');
    }
    _terminology = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value);
  }
}
