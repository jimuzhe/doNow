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

  // JSON Serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'totalDurationSeconds': totalDuration.inSeconds,
      'scheduledStart': scheduledStart.toIso8601String(),
      'subTasks': subTasks.map((s) => s.toJson()).toList(),
      'isGenerating': isGenerating,
      'isCompleted': isCompleted,
      'isAbandoned': isAbandoned,
      'repeatDays': repeatDays,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      totalDuration: Duration(seconds: json['totalDurationSeconds'] as int),
      scheduledStart: DateTime.parse(json['scheduledStart'] as String),
      subTasks: (json['subTasks'] as List<dynamic>)
          .map((s) => SubTask.fromJson(s as Map<String, dynamic>))
          .toList(),
      isGenerating: json['isGenerating'] as bool? ?? false,
      isCompleted: json['isCompleted'] as bool? ?? false,
      isAbandoned: json['isAbandoned'] as bool? ?? false,
      repeatDays: (json['repeatDays'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList() ?? [],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }
}

