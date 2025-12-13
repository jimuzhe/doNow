import 'subtask.dart';

class Routine {
  final String id;
  final String title;
  final Duration totalDuration;
  final List<SubTask> subTasks;
  final String? emoji; // Visual flair
  final DateTime createdAt;

  Routine({
    required this.id,
    required this.title,
    required this.totalDuration,
    required this.subTasks,
    this.emoji,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Routine copyWith({
    String? id,
    String? title,
    Duration? totalDuration,
    List<SubTask>? subTasks,
    String? emoji,
  }) {
    return Routine(
      id: id ?? this.id,
      title: title ?? this.title,
      totalDuration: totalDuration ?? this.totalDuration,
      subTasks: subTasks ?? this.subTasks,
      emoji: emoji ?? this.emoji,
      createdAt: this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'totalDurationSeconds': totalDuration.inSeconds,
      'subTasks': subTasks.map((s) => s.toJson()).toList(),
      'emoji': emoji,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id'] as String,
      title: json['title'] as String,
      totalDuration: Duration(seconds: json['totalDurationSeconds'] as int),
      subTasks: (json['subTasks'] as List<dynamic>)
          .map((s) => SubTask.fromJson(s as Map<String, dynamic>))
          .toList(),
      emoji: json['emoji'] as String?,
      createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'] as String) 
        : null,
    );
  }
}
