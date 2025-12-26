import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/subtask.dart';
import '../services/home_widget_service.dart';
import '../repositories/task_repository.dart';
import 'base_providers.dart';
import 'ai_providers.dart';

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
  final _storage;
  final HomeWidgetService _homeWidgetService;

  TaskListNotifier(this._storage, this._homeWidgetService) : super([]) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      state = _storage.loadTasks();
      _updateWidget();
    } catch (_) {}
  }

  void checkAndCreateOnboardingTask() {
    if (_storage.loadIsFirstLaunch() && state.isEmpty) {
      _createOnboardingTask();
      _storage.setFirstLaunchCompleted();
    }
  }

  void _createOnboardingTask() {
    try {
      final now = DateTime.now();
      final demoTask = Task(
        id: const Uuid().v4(),
        title: "DoNow 快速上手指南 🚀",
        scheduledStart: now.add(const Duration(minutes: 2)), 
        totalDuration: const Duration(minutes: 20),
        subTasks: [
          SubTask(id: const Uuid().v4(), title: "长按事务卡片可以预览子任务 👆", estimatedDuration: const Duration(minutes: 5)),
          SubTask(id: const Uuid().v4(), title: "左右滑动事务卡片可以进行修改操作，长按右上角➕号使用更多功能", estimatedDuration: const Duration(minutes: 5)),
          SubTask(id: const Uuid().v4(), title: "在任务进行中，点击右上角🎧打开背景白噪音", estimatedDuration: const Duration(minutes: 5)),
          SubTask(id: const Uuid().v4(), title: "回到桌面查看灵动岛/锁屏进度 🏝️", estimatedDuration: const Duration(minutes: 5)),
        ],
        createdAt: now,
      );
      
      state = [demoTask];
      _storage.saveTasks(state);
    } catch (e) {
      debugPrint("Error creating onboarding task: $e");
    }
  }

  Future<void> _updateWidget() async {
    try {
      // Read locale from storage and pass to widget service
      final locale = _storage.loadLocale() ?? 'en';
      await _homeWidgetService.updateWidget(state, locale: locale);
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

  /// Public method to refresh the home widget (e.g., after locale change)
  void refreshWidget() {
    _updateWidget();
  }
}

// Repository Provider
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  return TaskRepository(ref, aiService);
});

// Active Task Provider
final activeTaskIdProvider = StateProvider<String?>((ref) => null);

// Busy UI Provider
final isBusyUIProvider = StateProvider<bool>((ref) => false);

// Recording State Provider - 用户是否正在录音（按住说话/陪伴模式中）
// 当此状态为 true 时，到期提醒应该静默处理，避免打断用户
final isRecordingProvider = StateProvider<bool>((ref) => false);
