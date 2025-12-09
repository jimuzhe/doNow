import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'models/task.dart';
import 'models/api_settings.dart';
import 'models/ai_persona.dart';
import 'services/ai_service.dart';
import 'services/zhipu_ai_service.dart';
import 'services/storage_service.dart';
import 'repositories/task_repository.dart';
import 'api_config.dart';

// Storage Service Provider - Singleton
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// API Settings Provider - Now with persistence
final apiSettingsProvider = StateNotifierProvider<ApiSettingsNotifier, ApiSettings>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ApiSettingsNotifier(storage);
});

class ApiSettingsNotifier extends StateNotifier<ApiSettings> {
  final StorageService _storage;

  ApiSettingsNotifier(this._storage) : super(const ApiSettings(
    apiKey: ApiConfig.apiKey,
    baseUrl: ApiConfig.baseUrl,
    model: ApiConfig.model,
  )) {
    // Auto-load from storage on init
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      state = _storage.loadApiSettings();
    } catch (_) {
      // Storage not initialized yet, use defaults
    }
  }

  void update(ApiSettings settings) {
    state = settings;
    _storage.saveApiSettings(settings);
  }
}

// Service Provider - Refreshes when settings or persona change
final aiServiceProvider = Provider<AIService>((ref) {
  final settings = ref.watch(apiSettingsProvider);
  final persona = ref.watch(aiPersonaProvider);
  return ZhipuAIService(settings, persona: persona);
});

// Task List Provider - Now with persistence
final taskListProvider = StateNotifierProvider<TaskListNotifier, List<Task>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return TaskListNotifier(storage);
});

class TaskListNotifier extends StateNotifier<List<Task>> {
  final StorageService _storage;

  TaskListNotifier(this._storage) : super([]) {
    // Auto-load from storage on init
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      state = _storage.loadTasks();
    } catch (_) {
      // Storage not initialized yet, use defaults
    }
  }

  void setTasks(List<Task> tasks) {
    state = tasks;
    _storage.saveTasks(tasks);
  }

  void addTask(Task task) {
    state = [...state, task];
    _storage.saveTasks(state);
  }

  void updateTask(Task task) {
    state = state.map((t) => t.id == task.id ? task : t).toList();
    _storage.saveTasks(state);
  }

  void removeTask(String id) {
    state = state.where((t) => t.id != id).toList();
    _storage.saveTasks(state);
  }

  void clear() {
    state = [];
    _storage.saveTasks(state);
  }
}

// Theme Provider - Now with persistence
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ThemeModeNotifier(storage);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final StorageService _storage;

  ThemeModeNotifier(this._storage) : super(ThemeMode.light) {
    // Auto-load from storage on init
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      state = _storage.loadThemeMode();
    } catch (_) {
      // Storage not initialized yet, use defaults
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    _storage.saveThemeMode(mode);
  }
}

// Repository Provider
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  return TaskRepository(ref, aiService);
});

// Active Task Provider - tracks which task is currently being executed
// Used to prevent duplicate navigation from scheduler
final activeTaskIdProvider = StateProvider<String?>((ref) => null);

// Vibration Intensity Provider - Now with persistence
final vibrationIntensityProvider = StateNotifierProvider<VibrationIntensityNotifier, double>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return VibrationIntensityNotifier(storage);
});

class VibrationIntensityNotifier extends StateNotifier<double> {
  final StorageService _storage;

  VibrationIntensityNotifier(this._storage) : super(1.0) {
    // Auto-load from storage on init
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      state = _storage.loadVibrationIntensity();
    } catch (_) {
      // Storage not initialized yet, use defaults
    }
  }

  void setIntensity(double intensity) {
    state = intensity;
    _storage.saveVibrationIntensity(intensity);
  }
}

// AI Persona Provider - Now with persistence
final aiPersonaProvider = StateNotifierProvider<AIPersonaNotifier, AIPersona>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AIPersonaNotifier(storage);
});

class AIPersonaNotifier extends StateNotifier<AIPersona> {
  final StorageService _storage;

  AIPersonaNotifier(this._storage) : super(AIPersona.balanced) {
    // Auto-load from storage on init
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      final personaName = _storage.loadAIPersona();
      state = AIPersonaExtension.fromStorageString(personaName);
    } catch (_) {
      // Storage not initialized yet, use defaults
    }
  }

  void setPersona(AIPersona persona) {
    state = persona;
    _storage.saveAIPersona(persona.toStorageString());
  }
}

