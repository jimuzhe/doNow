import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../services/ai_service.dart';
import '../providers.dart';

class TaskRepository {
  final Ref _ref;
  final AIService _aiService;

  TaskRepository(this._ref, this._aiService);

  // Helper to get current tasks if needed (but UI should watch provider)
  List<Task> get tasks => _ref.read(taskListProvider);

  void addTask(Task task) {
    _ref.read(taskListProvider.notifier).addTask(task);
  }

  void updateTask(Task task) {
    _ref.read(taskListProvider.notifier).updateTask(task);
  }

  void deleteTask(String taskId) {
    _ref.read(taskListProvider.notifier).removeTask(taskId);
  }

  // Mark task as abandoned (keeps in history for analysis)
  void abandonTask(Task task) {
    final abandonedTask = task.copyWith(isAbandoned: true);
    updateTask(abandonedTask);
  }

  Future<Task> createTask(String title, Duration duration, DateTime start) async {
    // 1. Call AI to split the task
    final subTasks = await _aiService.decomposeTask(title, duration);

    // 2. Create the Task object
    final newTask = Task(
      id: DateTime.now().toIso8601String(), 
      title: title,
      totalDuration: duration,
      scheduledStart: start,
      subTasks: subTasks,
    );

    // 3. Update state via Provider
    _ref.read(taskListProvider.notifier).addTask(newTask);
    
    return newTask;
  }
}
