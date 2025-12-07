import 'subtask.dart';

class Task {
  final String id;
  final String title;
  final Duration totalDuration;
  final DateTime scheduledStart;
  final List<SubTask> subTasks;
  final bool isGenerating;
  final bool isCompleted;
  final bool isAbandoned; // New: Track abandoned tasks
  final List<int> repeatDays; // 1 = Monday, 7 = Sunday. Empty = No repeat.
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    required this.totalDuration,
    required this.scheduledStart,
    required this.subTasks,
    this.isGenerating = false,
    this.isCompleted = false,
    this.isAbandoned = false,
    this.repeatDays = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Task copyWith({
    String? id,
    String? title,
    Duration? totalDuration,
    DateTime? scheduledStart,
    List<SubTask>? subTasks,
    bool? isGenerating,
    bool? isCompleted,
    bool? isAbandoned,
    List<int>? repeatDays,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      totalDuration: totalDuration ?? this.totalDuration,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      subTasks: subTasks ?? this.subTasks,
      isGenerating: isGenerating ?? this.isGenerating,
      isCompleted: isCompleted ?? this.isCompleted,
      isAbandoned: isAbandoned ?? this.isAbandoned,
      repeatDays: repeatDays ?? this.repeatDays,
      createdAt: this.createdAt,
    );
  }
}

