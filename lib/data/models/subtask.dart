
class SubTask {
  final String id;
  final String title;
  final Duration estimatedDuration;
  final bool isCompleted;

  SubTask({
    required this.id,
    required this.title,
    required this.estimatedDuration,
    this.isCompleted = false,
  });

  SubTask copyWith({
    String? id,
    String? title,
    Duration? estimatedDuration,
    bool? isCompleted,
  }) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  // JSON Serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'estimatedDurationSeconds': estimatedDuration.inSeconds,
      'isCompleted': isCompleted,
    };
  }

  factory SubTask.fromJson(Map<String, dynamic> json) {
    return SubTask(
      id: json['id'] as String,
      title: json['title'] as String,
      estimatedDuration: Duration(seconds: json['estimatedDurationSeconds'] as int),
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}
