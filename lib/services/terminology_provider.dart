import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing work terminology preferences (Jobs, Shifts, Events)
/// Terminology choice is stored as English ('Jobs', 'Shifts', 'Events').
/// Display strings are locale-aware, auto-detected from the system language.
class TerminologyProvider with ChangeNotifier {
  static const String _key = 'work_terminology';
  String _terminology = 'Jobs'; // Stored key (always English)
  String _language = 'en'; // Auto-detected from system locale

  TerminologyProvider() {
    _loadPreference();
  }

  String get terminology => _terminology;

  /// Update system language from current BuildContext locale.
  /// Call this at the top of build() in any widget that displays terminology.
  void updateSystemLanguage(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final newLanguage = (locale?.languageCode == 'es') ? 'es' : 'en';
    if (_language != newLanguage) {
      _language = newLanguage;
      notifyListeners();
    }
  }

  /// Get singular form (Job/Trabajo, Shift/Turno, Event/Evento)
  String get singular {
    if (_language == 'es') {
      switch (_terminology) {
        case 'Shifts':
          return 'Turno';
        case 'Events':
          return 'Evento';
        default:
          return 'Trabajo';
      }
    }
    switch (_terminology) {
      case 'Shifts':
        return 'Shift';
      case 'Events':
        return 'Event';
      default:
        return 'Job';
    }
  }

  /// Get plural form (Jobs/Trabajos, Shifts/Turnos, Events/Eventos)
  String get plural {
    if (_language == 'es') {
      switch (_terminology) {
        case 'Shifts':
          return 'Turnos';
        case 'Events':
          return 'Eventos';
        default:
          return 'Trabajos';
      }
    }
    return _terminology;
  }

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
