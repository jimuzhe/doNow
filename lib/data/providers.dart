import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/task.dart';
import 'services/ai_service.dart';
import 'services/zhipu_ai_service.dart';
import 'repositories/task_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/task.dart';
import 'services/ai_service.dart';
import 'services/zhipu_ai_service.dart';
import 'repositories/task_repository.dart';
import 'package:flutter/material.dart'; // Added for ThemeMode
import 'models/api_settings.dart';
import 'api_config.dart';

// API Settings Provider (In-memory, non-persistent for this demo)
final apiSettingsProvider = StateProvider<ApiSettings>((ref) {
  return const ApiSettings(
    apiKey: ApiConfig.apiKey,
    baseUrl: ApiConfig.baseUrl,
    model: ApiConfig.model,
  );
});

// Service Provider - Refreshes when settings change
final aiServiceProvider = Provider<AIService>((ref) {
  final settings = ref.watch(apiSettingsProvider);
  return ZhipuAIService(settings);
});

// Task List State Provider
final taskListProvider = StateProvider<List<Task>>((ref) => []);

// Theme Provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// Repository Provider
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  return TaskRepository(ref, aiService);
});

// Active Task Provider - tracks which task is currently being executed
// Used to prevent duplicate navigation from scheduler
final activeTaskIdProvider = StateProvider<String?>((ref) => null);
