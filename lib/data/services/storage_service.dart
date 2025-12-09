import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/api_settings.dart';
import '../api_config.dart';

/// Service for persisting app data to local storage
class StorageService {
  static const String _tasksKey = 'tasks';
  static const String _apiSettingsKey = 'api_settings';
  static const String _localeKey = 'locale';
  static const String _themeModeKey = 'theme_mode';
  static const String _vibrationIntensityKey = 'vibration_intensity';
  static const String _aiPersonaKey = 'ai_persona';

  SharedPreferences? _prefs;

  /// Initialize SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Ensure prefs is initialized
  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('StorageService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  // ============== TASKS ==============

  /// Save tasks list to storage
  Future<void> saveTasks(List<Task> tasks) async {
    final jsonList = tasks.map((t) => t.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await prefs.setString(_tasksKey, jsonString);
  }

  /// Load tasks list from storage
  List<Task> loadTasks() {
    final jsonString = prefs.getString(_tasksKey);
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

  // ============== API SETTINGS ==============

  /// Save API settings to storage
  Future<void> saveApiSettings(ApiSettings settings) async {
    final jsonString = jsonEncode(settings.toJson());
    await prefs.setString(_apiSettingsKey, jsonString);
  }

  /// Load API settings from storage
  ApiSettings loadApiSettings() {
    final jsonString = prefs.getString(_apiSettingsKey);
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

  // ============== LOCALE ==============

  /// Save locale to storage
  Future<void> saveLocale(String locale) async {
    await prefs.setString(_localeKey, locale);
  }

  /// Load locale from storage (default: 'en')
  String loadLocale() {
    return prefs.getString(_localeKey) ?? 'en';
  }

  // ============== THEME MODE ==============

  /// Save theme mode to storage
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

  // ============== VIBRATION INTENSITY ==============

  /// Save vibration intensity to storage
  Future<void> saveVibrationIntensity(double intensity) async {
    await prefs.setDouble(_vibrationIntensityKey, intensity);
  }

  /// Load vibration intensity from storage (default: 1.0)
  double loadVibrationIntensity() {
    return prefs.getDouble(_vibrationIntensityKey) ?? 1.0;
  }

  // ============== AI PERSONA ==============

  /// Save AI persona to storage
  Future<void> saveAIPersona(String personaName) async {
    await prefs.setString(_aiPersonaKey, personaName);
  }

  /// Load AI persona from storage (default: 'balanced')
  String loadAIPersona() {
    return prefs.getString(_aiPersonaKey) ?? 'balanced';
  }

  // ============== CLEAR ALL ==============

  /// Clear all stored data
  Future<void> clearAll() async {
    await prefs.clear();
  }
}
