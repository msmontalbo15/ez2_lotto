// lib/app_locale.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocale extends ChangeNotifier {
  static const String _darkModeKey = 'isDarkMode';
  static const String _isEnglishKey = 'isEnglish';

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  bool _isEnglish = true;
  bool get isEnglish => _isEnglish;

  AppLocale() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_darkModeKey) ?? false;
      _isEnglish = prefs.getBool(_isEnglishKey) ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      notifyListeners();
    }
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkModeKey, value);
    } catch (e) {
      debugPrint('Error saving dark mode: $e');
    }
  }

  Future<void> toggleDarkMode() async {
    await setDarkMode(!_isDarkMode);
  }

  Future<void> setLanguage(bool isEnglish) async {
    if (_isEnglish == isEnglish) return;
    _isEnglish = isEnglish;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isEnglishKey, isEnglish);
    } catch (e) {
      debugPrint('Error saving language: $e');
    }
  }
}
