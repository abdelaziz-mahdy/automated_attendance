import 'package:shared_preferences/shared_preferences.dart';

/// Class to manage all application settings
class SettingsService {
  // Singleton instance
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // Cache for settings values
  late SharedPreferences _prefs;
  bool _initialized = false;

  // Setting keys
  static const String keyMaxFaces = 'maxFaces';
  static const String keyAnalyticsUpdateInterval = 'analyticsUpdateInterval';
  static const String keyUseIsolates = 'useIsolates';

  // Default values
  static const int defaultMaxFaces = 10;
  static const int defaultAnalyticsUpdateInterval = 3;
  static const bool defaultUseIsolates = true;

  /// Initialize the settings service
  Future<void> initialize() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// Get max faces setting
  int get maxFaces => _prefs.getInt(keyMaxFaces) ?? defaultMaxFaces;

  /// Set max faces setting
  Future<void> setMaxFaces(int value) async {
    await _prefs.setInt(keyMaxFaces, value);
  }

  /// Get analytics update interval in minutes
  int get analyticsUpdateInterval =>
      _prefs.getInt(keyAnalyticsUpdateInterval) ??
      defaultAnalyticsUpdateInterval;

  /// Set analytics update interval in minutes
  Future<void> setAnalyticsUpdateInterval(int value) async {
    await _prefs.setInt(keyAnalyticsUpdateInterval, value);
  }

  /// Get use isolates setting
  bool get useIsolates => _prefs.getBool(keyUseIsolates) ?? defaultUseIsolates;

  /// Set use isolates setting
  Future<void> setUseIsolates(bool value) async {
    await _prefs.setBool(keyUseIsolates, value);
  }

  /// Reset all settings to default values
  Future<void> resetToDefaults() async {
    await _prefs.setInt(keyMaxFaces, defaultMaxFaces);
    await _prefs.setInt(
        keyAnalyticsUpdateInterval, defaultAnalyticsUpdateInterval);
    await _prefs.setBool(keyUseIsolates, defaultUseIsolates);
  }
}
