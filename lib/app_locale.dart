// lib/app_locale.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// App State for Language and Theme
class AppLocale extends ChangeNotifier {
  bool _isEnglish = true;
  bool _isDarkMode = false;
  bool _isLoaded = false;

  bool get isEnglish => _isEnglish;
  bool get isDarkMode => _isDarkMode;
  bool get isLoaded => _isLoaded;

  // Static instance for async initialization
  static final AppLocale _instance = AppLocale._internal();
  static AppLocale get instance => _instance;

  AppLocale._internal() {
    _loadSettings();
  }

  // Factory constructor for backwards compatibility
  factory AppLocale() => _instance;

  // Wait for settings to load from cache before app starts
  Future<void> waitForLoad() async {
    while (!_isLoaded) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnglish = prefs.getBool('isEnglish') ?? true;
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    } catch (e) {
      // Fallback to defaults if SharedPreferences fails
      _isEnglish = true;
      _isDarkMode = false;
    }
    _isLoaded = true;
    notifyListeners();
  }

  void setLanguage(bool isEnglish) {
    _isEnglish = isEnglish;
    _saveSettings();
    notifyListeners();
  }

  void setDarkMode(bool isDarkMode) {
    _isDarkMode = isDarkMode;
    _saveSettings();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isEnglish', _isEnglish);
      await prefs.setBool('isDarkMode', _isDarkMode);
    } catch (e) {
      // Silently fail - settings will reset on next app start
    }
  }

  void toggleLanguage() {
    setLanguage(!_isEnglish);
  }

  void toggleDarkMode() {
    setDarkMode(!_isDarkMode);
  }
}

// Localization Strings
class AppStrings {
  // Navigation
  static const Map<String, String> navTab = {
    'en': 'Results',
    'tl': 'Resulta',
  };
  static const Map<String, String> navHistory = {
    'en': 'History',
    'tl': 'Kasaysayan',
  };
  static const Map<String, String> navStats = {
    'en': 'Statistics',
    'tl': 'Istatistika',
  };
  static const Map<String, String> navTicket = {
    'en': 'Ticket',
    'tl': 'Tiket',
  };
  static const Map<String, String> navSettings = {
    'en': 'Settings',
    'tl': 'Mga Setting',
  };

  // Today Screen
  static const Map<String, String> todaysResults = {
    'en': "TODAY'S RESULTS",
    'tl': 'RESULTA NGAYON',
  };
  static const Map<String, String> latestResult = {
    'en': 'LATEST RESULT',
    'tl': 'PINAKABAGONG RESULTA',
  };
  static const Map<String, String> nextDraw = {
    'en': 'Next draw:',
    'tl': 'Susunod na draw:',
  };
  static const Map<String, String> drawSoon = {
    'en': 'Draw starting soon:',
    'tl': 'Magsisimula na ang draw:',
  };
  static const Map<String, String> offline = {
    'en': 'No internet. Showing cached data.',
    'tl': 'Walang internet. Nagpapakita ng nakaimbak na datos.',
  };
  static const Map<String, String> retry = {
    'en': 'TRY AGAIN',
    'tl': 'SUBUKAN ULIT',
  };

  // History Screen
  static const Map<String, String> historyTitle = {
    'en': 'HISTORY',
    'tl': 'KASAYSAYAN',
  };
  static const Map<String, String> historySubtitle = {
    'en': 'Previous EZ2 results',
    'tl': 'Mga nakaraang resulta ng EZ2',
  };
  static const Map<String, String> noData = {
    'en': 'No data available',
    'tl': 'Walang datos',
  };

  // Stats Screen
  static const Map<String, String> statsTitle = {
    'en': 'STATISTICS',
    'tl': 'ISTATISTIKA',
  };
  static const Map<String, String> mostDrawn = {
    'en': 'Most Drawn EZ2 Numbers',
    'tl': 'Mga Pinaka-Madaling Lumabas sa EZ2',
  };
  static const Map<String, String> mostDrawnPairs = {
    'en': 'Most Drawn Number Pairs',
    'tl': 'Mga Pinaka-Madaling Pairs ng Numbers',
  };
  static const Map<String, String> winnersChart = {
    'en': '2D Lotto Winners Chart',
    'tl': 'Chart ng Mga Nanalo sa 2D Lotto',
  };
  static const Map<String, String> hotCold = {
    'en': 'PCSO EZ2 Hot & Cold Numbers',
    'tl': 'Mga Hot & Cold Numbers ng EZ2 sa PCSO',
  };

  // Ticket Screen
  static const Map<String, String> checkTicket = {
    'en': 'CHECK TICKET',
    'tl': 'TSEK ANG TIKET',
  };
  static const Map<String, String> youWon = {
    'en': 'YOU WON!',
    'tl': 'NANALO KAYO!',
  };
  static const Map<String, String> notYet = {
    'en': 'Not a winner yet',
    'tl': 'Hindi pa nanalo',
  };

  // Settings Screen
  static const Map<String, String> appSettings = {
    'en': 'APP SETTINGS',
    'tl': 'MGA SETTING NG APP',
  };
  static const Map<String, String> darkMode = {
    'en': 'Dark Mode',
    'tl': 'Madilim na Mode',
  };
  static const Map<String, String> cloudUpdate = {
    'en': 'CLOUD UPDATE',
    'tl': 'CLOUD UPDATE',
  };
  static const Map<String, String> checkUpdates = {
    'en': 'Check for Updates',
    'tl': 'Suriin ang Update',
  };
  static const Map<String, String> shareApp = {
    'en': 'SHARE APP',
    'tl': 'IPAMAHAGI ANG APP',
  };
  static const Map<String, String> dataManagement = {
    'en': 'DATA MANAGEMENT',
    'tl': 'PAMAMAHALA NG DATA',
  };
  static const Map<String, String> clearCache = {
    'en': 'Clear Cache',
    'tl': 'Burahin Cache',
  };
  static const Map<String, String> refreshData = {
    'en': 'Refresh Data',
    'tl': 'I-refresh ang Datos',
  };
  static const Map<String, String> about = {
    'en': 'ABOUT',
    'tl': 'TUNGKOL SA APP',
  };

  // Common
  static const Map<String, String> loading = {
    'en': 'Loading...',
    'tl': 'Kinukuha...',
  };
  static const Map<String, String> offlineBanner = {
    'en': 'You are offline - showing cached data',
    'tl': 'Wala kang internet - nagpapakita ng nakaimbak na datos',
  };
  static const Map<String, String> noInternet = {
    'en': 'No internet connection...',
    'tl': 'Walang internet connection...',
  };

  // Get string based on language
  static String get(String key, bool isEnglish) {
    final map = _strings[key];
    if (map == null) return key;
    return isEnglish ? map['en']! : map['tl']!;
  }

  static final Map<String, Map<String, String>> _strings = {
    'navTab': navTab,
    'navHistory': navHistory,
    'navStats': navStats,
    'navTicket': navTicket,
    'navSettings': navSettings,
    'todaysResults': todaysResults,
    'latestResult': latestResult,
    'nextDraw': nextDraw,
    'drawSoon': drawSoon,
    'offline': offline,
    'retry': retry,
    'historyTitle': historyTitle,
    'historySubtitle': historySubtitle,
    'noData': noData,
    'statsTitle': statsTitle,
    'mostDrawn': mostDrawn,
    'mostDrawnPairs': mostDrawnPairs,
    'winnersChart': winnersChart,
    'hotCold': hotCold,
    'checkTicket': checkTicket,
    'youWon': youWon,
    'notYet': notYet,
    'appSettings': appSettings,
    'darkMode': darkMode,
    'cloudUpdate': cloudUpdate,
    'checkUpdates': checkUpdates,
    'shareApp': shareApp,
    'dataManagement': dataManagement,
    'clearCache': clearCache,
    'refreshData': refreshData,
    'about': about,
    'loading': loading,
    'offlineBanner': offlineBanner,
    'noInternet': noInternet,
  };
}
