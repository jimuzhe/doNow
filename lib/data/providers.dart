import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'models/task.dart';
import 'models/api_settings.dart';
import 'models/ai_persona.dart';
import 'services/ai_service.dart';
import 'services/zhipu_ai_service.dart';
import 'services/storage_service.dart';
import 'package:uuid/uuid.dart';
import 'models/subtask.dart';
import 'services/home_widget_service.dart';
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

// Home Widget Service Provider
final homeWidgetServiceProvider = Provider<HomeWidgetService>((ref) {
  return HomeWidgetService();
});

// Task List Provider - Now with persistence and Home Widget sync
final taskListProvider = StateNotifierProvider<TaskListNotifier, List<Task>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final homeWidgetService = ref.watch(homeWidgetServiceProvider);
  return TaskListNotifier(storage, homeWidgetService);
});

class TaskListNotifier extends StateNotifier<List<Task>> {
  final StorageService _storage;
  final HomeWidgetService _homeWidgetService;

  TaskListNotifier(this._storage, this._homeWidgetService) : super([]) {
    // Auto-load from storage on init
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      state = _storage.loadTasks();
      
      // Onboarding Logic: If first launch and no tasks, create a demo task
      if (_storage.loadIsFirstLaunch() && state.isEmpty) {
         _createOnboardingTask();
         _storage.setFirstLaunchCompleted();
      }

      // Also update widget on load to ensure consistency
      _updateWidget();
    } catch (_) {
      // Storage not initialized yet, use defaults
    }
  }

  void _createOnboardingTask() {
    try {
      final now = DateTime.now();
      // Check locale roughly (active locale might not be set yet, default to Chinese given region)
      // Or just use English if unsure. Let's use English for broad compatibility or Chinese if requested.
      // Since user speaks Chinese, let's create a Chinese task.
      
      final demoTask = Task(
        id: const Uuid().v4(),
        title: "DoNow 快速上手指南 🚀",
        // originalInput removed as it does not exist in Task model
        scheduledStart: now.add(const Duration(minutes: 2)), 
        totalDuration: const Duration(minutes: 20),
        subTasks: [
          SubTask(id: const Uuid().v4(), title: "试着长按这个任务卡片 (预览子任务) 👆", estimatedDuration: const Duration(minutes: 5)),
          SubTask(id: const Uuid().v4(), title: "点击卡片进入，然后点击底部的 ▶️ 开始专注", estimatedDuration: const Duration(minutes: 5)),
          SubTask(id: const Uuid().v4(), title: "在任务进行中，点击右上角🎧打开背景白噪音", estimatedDuration: const Duration(minutes: 5)),
          SubTask(id: const Uuid().v4(), title: "回到桌面查看灵动岛/锁屏进度 🏝️", estimatedDuration: const Duration(minutes: 5)),
        ],
        // tags removed as it does not exist in Task model
        createdAt: now,
      );
      
      state = [demoTask];
      _storage.saveTasks(state);
    } catch (e) {
      debugPrint("Error creating onboarding task: $e");
    }
  }

  Future<void> _updateWidget() async {
    // Fire and forget widget update
    try {
      await _homeWidgetService.updateWidget(state);
    } catch (e) {
      debugPrint('Error updating home widget: $e');
    }
  }

  void setTasks(List<Task> tasks) {
    state = tasks;
    _storage.saveTasks(tasks);
    _updateWidget();
  }

  void addTask(Task task) {
    state = [...state, task];
    _storage.saveTasks(state);
    _updateWidget();
  }

  void updateTask(Task task) {
    state = state.map((t) => t.id == task.id ? task : t).toList();
    _storage.saveTasks(state);
    _updateWidget();
  }

  void removeTask(String id) {
    state = state.where((t) => t.id != id).toList();
    _storage.saveTasks(state);
    _updateWidget();
  }

  void clear() {
    state = [];
    _storage.saveTasks(state);
    _updateWidget();
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

// Debug Log Provider - for showing debug logs on screen (not persisted)
final debugLogEnabledProvider = StateProvider<bool>((ref) => false);

