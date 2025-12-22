import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'models/task.dart';
import 'models/habit.dart';
import 'models/routine.dart';
import 'models/api_settings.dart';
import 'models/ai_persona.dart';
import 'services/ai_service.dart';
import 'services/zhipu_ai_service.dart';
import 'services/storage_service.dart';
import 'package:uuid/uuid.dart';
import 'models/subtask.dart';
import 'services/home_widget_service.dart';
import 'services/home_widget_service.dart';
import 'services/gamification_service.dart';
import 'services/morning_report_service.dart';
import '../data/models/morning_report.dart';
import 'models/gamification_state.dart';
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
      
      // NOTE: Onboarding task is now created via checkAndCreateOnboardingTask() 
      // which is called after user login in main.dart

      // Also update widget on load to ensure consistency
      _updateWidget();
    } catch (_) {
      // Storage not initialized yet, use defaults
    }
  }

  /// Create onboarding task if first launch and no tasks exist.
  /// Should be called AFTER user has logged in.
  void checkAndCreateOnboardingTask() {
    if (_storage.loadIsFirstLaunch() && state.isEmpty) {
      _createOnboardingTask();
      _storage.setFirstLaunchCompleted();
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
          SubTask(id: const Uuid().v4(), title: "长按事务卡片可以预览子任务 👆", estimatedDuration: const Duration(minutes: 5)),
          SubTask(id: const Uuid().v4(), title: "左右滑动事务卡片可以进行修改操作，长按右上角➕号使用更多功能", estimatedDuration: const Duration(minutes: 5)),
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

// Auxiliary provider to track if user is in a "Busy" screen (Decision/QuickFocus)
// that isn't running a task yet.
final isBusyUIProvider = StateProvider<bool>((ref) => false);

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


// Habit List Provider
final habitListProvider = StateNotifierProvider<HabitListNotifier, List<Habit>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return HabitListNotifier(storage);
});

class HabitListNotifier extends StateNotifier<List<Habit>> {
  final StorageService _storage;

  HabitListNotifier(this._storage) : super([]) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      state = _storage.loadHabits();
    } catch (_) { }
  }

  void addHabit(Habit habit) {
    state = [...state, habit];
    _storage.saveHabits(state);
  }

  void updateHabit(Habit habit) {
    state = state.map((h) => h.id == habit.id ? habit : h).toList();
    _storage.saveHabits(state);
  }

  void deleteHabit(String id) {
    state = state.where((h) => h.id != id).toList();
    _storage.saveHabits(state);
  }

  void toggleToday(String id) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    state = state.map((h) {
      if (h.id != id) return h;
      
      final isCompleted = h.isCompletedToday();
      List<DateTime> newDates;
      
      if (isCompleted) {
        // Remove today
        newDates = h.completedDates.where((d) => 
          !(d.year == today.year && d.month == today.month && d.day == today.day)
        ).toList();
      } else {
        // Add today
        newDates = [...h.completedDates, today];
      }
      
      return h.copyWith(completedDates: newDates);
    }).toList();
    
    _storage.saveHabits(state);
  }
}

// Routine List Provider
final routineListProvider = StateNotifierProvider<RoutineListNotifier, List<Routine>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return RoutineListNotifier(storage);
});

class RoutineListNotifier extends StateNotifier<List<Routine>> {
  final StorageService _storage;

  RoutineListNotifier(this._storage) : super([]) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      state = _storage.loadRoutines();
    } catch (_) { }
  }

  void addRoutine(Routine routine) {
    state = [...state, routine];
    _storage.saveRoutines(state);
  }

  // Renamed to update for consistency
  void updateRoutine(Routine routine) {
    state = state.map((r) => r.id == routine.id ? routine : r).toList();
    _storage.saveRoutines(state);
  }

  void deleteRoutine(String id) {
    state = state.where((r) => r.id != id).toList();
    _storage.saveRoutines(state);
  }
}

// Gamification Service Provider
final gamificationServiceProvider = StateNotifierProvider<GamificationService, GamificationState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return GamificationService(storage, ref);
});

// Morning Report Enabled Provider - Persisted
final morningReportEnabledProvider = StateNotifierProvider<MorningReportEnabledNotifier, bool>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return MorningReportEnabledNotifier(storage);
});

class MorningReportEnabledNotifier extends StateNotifier<bool> {
  final StorageService _storage;
  
  // Key for shared preferences
  static const _key = 'morning_report_enabled';

  MorningReportEnabledNotifier(this._storage) : super(false) {
    _load();
  }

  Future<void> _load() async {
    // We need to access shared preferences directly or add a method to StorageService.
    // For now, let's assume we can add a simple method to StorageService or access SharedPreferences
    // Since StorageService wraps SharedPreferences, let's add a generic method there or just assume
    // we can add a specific load method. Ideally we should update StorageService.
    // However, to avoid editing StorageService extensively, we can try to use a generic approach 
    // or just default to false if not supported.
    // Actually, let's just add the methods to StorageService in the same step ideally.
    // But since I can't edit 2 files at once with this tool properly in one go for logic dependency,
    // I will assume the methods exist or I will add them.
    // Wait, I can't assume. I should edit StorageService first?
    // User wants "Beta features". 
    // Let's implement StorageService update below.
    try {
       // Since I cannot change StorageService in this call, I will rely on "loadBool" if it existed,
       // but StorageService likely uses specific keys.
       // I'll make this Notifier work by hacking/accessing SharedPreferences if possible?
       // No, `_storage` is a wrapper.
       // I will assume I will add `loadMorningReportEnabled` and `saveMorningReportEnabled` to StorageService.
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

