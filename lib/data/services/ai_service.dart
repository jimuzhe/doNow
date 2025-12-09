
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/subtask.dart';
import '../models/daily_summary.dart';

/// Result from AI estimation (time + subtasks in one call)
class AIEstimateResult {
  final Duration estimatedDuration;
  final List<SubTask> subTasks;
  
  AIEstimateResult({required this.estimatedDuration, required this.subTasks});
}

abstract class AIService {
  Future<List<SubTask>> decomposeTask(String taskTitle, Duration totalDuration);
  
  /// Estimate task duration and decompose into subtasks in one AI call
  Future<AIEstimateResult> estimateAndDecompose(String taskTitle);

  /// Generate a daily summary, encouragement, and improvement suggestions specifically for the previous day
  Future<DailySummary> generateDailySummary(List<Task> tasks, DateTime date);
}

class MockAIService implements AIService {
  final Uuid _uuid = const Uuid();

  @override
  Future<List<SubTask>> decomposeTask(String taskTitle, Duration totalDuration) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Simple mock logic: split duration into 4 parts
    final stepDuration = Duration(minutes: totalDuration.inMinutes ~/ 4);

    return [
      SubTask(
        id: _uuid.v4(),
        title: 'Prepare environment for "$taskTitle"',
        estimatedDuration: stepDuration,
      ),
      SubTask(
        id: _uuid.v4(),
        title: 'Start initial phase of "$taskTitle"',
        estimatedDuration: stepDuration,
      ),
      SubTask(
        id: _uuid.v4(),
        title: 'Execute core work of "$taskTitle"',
        estimatedDuration: stepDuration,
      ),
      SubTask(
        id: _uuid.v4(),
        title: 'Review and finalize "$taskTitle"',
        estimatedDuration: stepDuration,
      ),
    ];
  }
  
  @override
  Future<AIEstimateResult> estimateAndDecompose(String taskTitle) async {
    await Future.delayed(const Duration(seconds: 2));
    
    // Mock: estimate 60 minutes and split into 4 parts
    const totalMinutes = 60;
    final stepDuration = const Duration(minutes: 15);
    
    return AIEstimateResult(
      estimatedDuration: const Duration(minutes: totalMinutes),
      subTasks: [
        SubTask(id: _uuid.v4(), title: 'Prepare for "$taskTitle"', estimatedDuration: stepDuration),
        SubTask(id: _uuid.v4(), title: 'Start "$taskTitle"', estimatedDuration: stepDuration),
        SubTask(id: _uuid.v4(), title: 'Execute "$taskTitle"', estimatedDuration: stepDuration),
        SubTask(id: _uuid.v4(), title: 'Finalize "$taskTitle"', estimatedDuration: stepDuration),
      ],
    );
  }


  @override
  Future<DailySummary> generateDailySummary(List<Task> tasks, DateTime date) async {
    await Future.delayed(const Duration(seconds: 2));
    return DailySummary(
      date: date,
      summary: "Yesterday was a productive day! You completed 3 tasks.",
      encouragement: "Great job maintaining focus. Keep it up!",
      improvement: "Try to start your first task earlier in the day.",
    );
  }
}
