import 'subtask.dart';

class Task {
  final String id;
  final String title;
  final Duration totalDuration;
  final DateTime scheduledStart;
  final List<SubTask> subTasks;
  final bool isGenerating;
  final bool isCompleted;
  final bool isAbandoned; // Restored
  final List<int> repeatDays; // Restored
  final DateTime createdAt; // Restored
  final DateTime? completedAt; 
  final Duration? actualDuration; 
  final String? journalImagePath;
  final String? journalVideoPath;
  final String? journalLocation;
  final String? journalNote; // Text note 

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
    this.completedAt,
    this.actualDuration,
    this.journalImagePath,
    this.journalVideoPath,
    this.journalLocation,
    this.journalNote,
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
    DateTime? completedAt,
    Duration? actualDuration,
    String? journalImagePath,
    String? journalVideoPath,
    String? journalLocation,
    String? journalNote,
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
      completedAt: completedAt ?? this.completedAt,
      actualDuration: actualDuration ?? this.actualDuration,
      journalImagePath: journalImagePath ?? this.journalImagePath,
      journalVideoPath: journalVideoPath ?? this.journalVideoPath,
      journalLocation: journalLocation ?? this.journalLocation,
      journalNote: journalNote ?? this.journalNote,
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
      'completedAt': completedAt?.toIso8601String(),
      'actualDurationSeconds': actualDuration?.inSeconds,
      'journalImagePath': journalImagePath,
      'journalVideoPath': journalVideoPath,
      'journalLocation': journalLocation,
      'journalNote': journalNote,
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
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      actualDuration: json['actualDurationSeconds'] != null
          ? Duration(seconds: json['actualDurationSeconds'] as int)
          : null,
      journalImagePath: json['journalImagePath'] as String?,
      journalVideoPath: json['journalVideoPath'] as String?,
      journalLocation: json['journalLocation'] as String?,
      journalNote: json['journalNote'] as String?,
    );
  }
}

