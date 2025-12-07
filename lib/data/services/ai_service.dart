
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/subtask.dart';

abstract class AIService {
  Future<List<SubTask>> decomposeTask(String taskTitle, Duration totalDuration);
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
}
