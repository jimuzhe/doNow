import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/api_settings.dart';
import '../api_config.dart';

/// Service for persisting app data to local storage
/// Data is stored per-user using userId as a prefix for keys
class StorageService {
  // Base keys (will be prefixed with userId for user-specific data)
  static const String _tasksKey = 'tasks';
  static const String _apiSettingsKey = 'api_settings';
  static const String _aiPersonaKey = 'ai_persona';
  
  // Global keys (shared across all users on this device)
  static const String _localeKey = 'locale';
  static const String _themeModeKey = 'theme_mode';
  static const String _vibrationIntensityKey = 'vibration_intensity';
  static const String _currentUserIdKey = 'current_user_id';

  SharedPreferences? _prefs;
  String? _userId;

  /// Initialize SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Load previously stored userId if any
    _userId = prefs.getString(_currentUserIdKey);
  }

  /// Set the current user ID (call this after login)
  Future<void> setUserId(String? userId) async {
    _userId = userId;
    if (userId != null) {
      await prefs.setString(_currentUserIdKey, userId);
    } else {
      await prefs.remove(_currentUserIdKey);
    }
  }

  /// Get current user ID
  String? get userId => _userId;

  /// Get the user-specific key
  String _userKey(String baseKey) {
    if (_userId == null || _userId!.isEmpty) {
      // Fallback for anonymous/logged out users
      return 'anonymous_$baseKey';
    }
    return '${_userId}_$baseKey';
  }

  /// Ensure prefs is initialized
  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('StorageService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  // ============== TASKS (per-user) ==============

  /// Save tasks list to storage (per-user)
  Future<void> saveTasks(List<Task> tasks) async {
    final jsonList = tasks.map((t) => t.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await prefs.setString(_userKey(_tasksKey), jsonString);
  }

  /// Load tasks list from storage (per-user)
  List<Task> loadTasks() {
    final jsonString = prefs.getString(_userKey(_tasksKey));
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    
    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => Task.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading tasks: $e');
      return [];
    }
  }

  // ============== API SETTINGS (per-user) ==============

  /// Save API settings to storage (per-user)
  Future<void> saveApiSettings(ApiSettings settings) async {
    final jsonString = jsonEncode(settings.toJson());
    await prefs.setString(_userKey(_apiSettingsKey), jsonString);
  }

  /// Load API settings from storage (per-user)
  ApiSettings loadApiSettings() {
    final jsonString = prefs.getString(_userKey(_apiSettingsKey));
    if (jsonString == null || jsonString.isEmpty) {
      // Return default settings
      return const ApiSettings(
        apiKey: ApiConfig.apiKey,
        baseUrl: ApiConfig.baseUrl,
        model: ApiConfig.model,
      );
    }
    
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ApiSettings.fromJson(json);
    } catch (e) {
      print('Error loading API settings: $e');
      return const ApiSettings(
        apiKey: ApiConfig.apiKey,
        baseUrl: ApiConfig.baseUrl,
        model: ApiConfig.model,
      );
    }
  }

  // ============== LOCALE (global) ==============

  /// Save locale to storage (global - shared across users)
  Future<void> saveLocale(String locale) async {
    await prefs.setString(_localeKey, locale);
  }

  /// Load locale from storage (returns null if not set)
  String? loadLocale() {
    return prefs.getString(_localeKey);
  }

  // ============== THEME MODE (global) ==============

  /// Save theme mode to storage (global - shared across users)
  Future<void> saveThemeMode(ThemeMode themeMode) async {
    await prefs.setInt(_themeModeKey, themeMode.index);
  }

  /// Load theme mode from storage (default: light)
  ThemeMode loadThemeMode() {
    final index = prefs.getInt(_themeModeKey);
    if (index == null || index < 0 || index >= ThemeMode.values.length) {
      return ThemeMode.light;
    }
    return ThemeMode.values[index];
  }

  // ============== VIBRATION INTENSITY (global) ==============

  /// Save vibration intensity to storage (global)
  Future<void> saveVibrationIntensity(double intensity) async {
    await prefs.setDouble(_vibrationIntensityKey, intensity);
  }

  /// Load vibration intensity from storage (default: 1.0)
  double loadVibrationIntensity() {
    return prefs.getDouble(_vibrationIntensityKey) ?? 1.0;
  }

  // ============== AI PERSONA (per-user) ==============

  /// Save AI persona to storage (per-user)
  Future<void> saveAIPersona(String personaName) async {
    await prefs.setString(_userKey(_aiPersonaKey), personaName);
  }

  /// Load AI persona from storage (default: 'balanced')
  String loadAIPersona() {
    return prefs.getString(_userKey(_aiPersonaKey)) ?? 'balanced';
  }

  // ============== ONBOARDING (per-user) ==============
  
  static const String _isFirstLaunchKey = 'is_first_launch';

  /// Check if this is the first launch for this user
  /// Returns true if the key doesn't exist yet
  bool loadIsFirstLaunch() {
    return prefs.getBool(_userKey(_isFirstLaunchKey)) ?? true;
  }

  /// Set first launch flag to false
  Future<void> setFirstLaunchCompleted() async {
    await prefs.setBool(_userKey(_isFirstLaunchKey), false);
  }

  // ============== CLEAR ALL ==============

  /// Clear all stored data for current user only
  Future<void> clearUserData() async {
    final keysToRemove = [
      _userKey(_tasksKey),
      _userKey(_apiSettingsKey),
      _userKey(_aiPersonaKey),
    ];
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }

  /// Clear all stored data (use with caution)
  Future<void> clearAll() async {
    await prefs.clear();
  }
}
