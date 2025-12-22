import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/morning_report_service.dart';
import '../models/morning_report.dart';
import 'base_providers.dart';

// Theme Provider - Now with persistence
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ThemeModeNotifier(storage);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final _storage;

  ThemeModeNotifier(this._storage) : super(ThemeMode.light) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      state = _storage.loadThemeMode();
    } catch (_) {}
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    _storage.saveThemeMode(mode);
  }
}

// Vibration Intensity Provider - Now with persistence
final vibrationIntensityProvider = StateNotifierProvider<VibrationIntensityNotifier, double>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return VibrationIntensityNotifier(storage);
});

class VibrationIntensityNotifier extends StateNotifier<double> {
  final _storage;

  VibrationIntensityNotifier(this._storage) : super(1.0) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      state = _storage.loadVibrationIntensity();
    } catch (_) {}
  }

  void setIntensity(double intensity) {
    state = intensity;
    _storage.saveVibrationIntensity(intensity);
  }
}

// Debug Log Provider
final debugLogEnabledProvider = StateProvider<bool>((ref) => false);

// Morning Report Enabled Provider - Persisted
final morningReportEnabledProvider = StateNotifierProvider<MorningReportEnabledNotifier, bool>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return MorningReportEnabledNotifier(storage);
});

class MorningReportEnabledNotifier extends StateNotifier<bool> {
  final _storage;

  MorningReportEnabledNotifier(this._storage) : super(false) {
    _load();
  }

  Future<void> _load() async {
    try {
       state = _storage.loadMorningReportEnabled();
    } catch (_) {
       state = false;
    }
  }

  void toggle() {
    state = !state;
    _storage.saveMorningReportEnabled(state);
  }
}

// Morning Report Data Provider
final morningReportProvider = FutureProvider<MorningReport>((ref) async {
  final service = MorningReportService();
  return service.fetchReport();
});
