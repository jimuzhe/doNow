
import 'dart:convert';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon; // E.g. "🏆" or "🔥"
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final AchievementType type;
  final int targetValue; // E.g. 10 hours, 5 tasks
  final int currentValue;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isUnlocked = false,
    this.unlockedAt,
    required this.type,
    required this.targetValue,
    this.currentValue = 0,
  });

  Achievement copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
    int? currentValue,
  }) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      icon: icon,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      type: type,
      targetValue: targetValue,
      currentValue: currentValue ?? this.currentValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
      'type': type.index,
      'targetValue': targetValue,
      'currentValue': currentValue,
    };
  }

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      icon: json['icon'],
      isUnlocked: json['isUnlocked'] ?? false,
      unlockedAt: json['unlockedAt'] != null ? DateTime.parse(json['unlockedAt']) : null,
      type: AchievementType.values[json['type'] ?? 0],
      targetValue: json['targetValue'] ?? 0,
      currentValue: json['currentValue'] ?? 0,
    );
  }
}

enum AchievementType {
  totalFocusMinutes,
  totalTasksCompleted,
  streakDays,
  earlyBird, // Task completed before 8 AM
  nightOwl, // Task completed after 10 PM
  firstStep, // First task ever
  weekendWarrior, // Task on weekend
  lunchTime, // Task during lunch (11:00 - 13:00)
}

class GamificationState {
  final int currentXp;
  final int level;
  final int totalXpEarned;
  final List<Achievement> achievements;

  const GamificationState({
    this.currentXp = 0,
    this.level = 1,
    this.totalXpEarned = 0,
    this.achievements = const [],
  });

  // Level Logic: Level N requires N * 1000 XP
  int get xpToNextLevel => level * 1000;
  double get progressToNextLevel => currentXp / xpToNextLevel;

  GamificationState copyWith({
    int? currentXp,
    int? level,
    int? totalXpEarned,
    List<Achievement>? achievements,
  }) {
    return GamificationState(
      currentXp: currentXp ?? this.currentXp,
      level: level ?? this.level,
      totalXpEarned: totalXpEarned ?? this.totalXpEarned,
      achievements: achievements ?? this.achievements,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentXp': currentXp,
      'level': level,
      'totalXpEarned': totalXpEarned,
      'achievements': achievements.map((a) => a.toJson()).toList(),
    };
  }

  factory GamificationState.fromJson(Map<String, dynamic> json) {
    return GamificationState(
      currentXp: json['currentXp'] ?? 0,
      level: json['level'] ?? 1,
      totalXpEarned: json['totalXpEarned'] ?? 0,
      achievements: (json['achievements'] as List?)
              ?.map((e) => Achievement.fromJson(e))
              .toList() ??
          [],
    );
  }

  /// Returns total XP needed to reach this level from 0
  static int totalXpForLevel(int level) {
    int total = 0;
    for (int i = 1; i < level; i++) {
        total += i * 1000;
    }
    return total;
  }
  
  String get levelTitle {
     if (level < 5) return "初心 (Beginner)";
     if (level < 10) return "探索者 (Explorer)";
     if (level < 20) return "实干家 (Achiever)";
     if (level < 50) return "大师 (Master)";
     return "传奇 (Legend)";
  }
}
