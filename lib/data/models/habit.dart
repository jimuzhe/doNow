
import 'dart:convert';
import 'package:flutter/material.dart';

class Habit {
  final String id;
  final String title;
  final int iconCode; // Store IconData.codePoint
  final int colorValue; // Store Color.value
  final List<DateTime> completedDates;

  Habit({
    required this.id,
    required this.title,
    required this.iconCode,
    required this.colorValue,
    required this.completedDates,
  });

  bool isCompletedToday() {
    final now = DateTime.now();
    return completedDates.any((date) => 
      date.year == now.year && 
      date.month == now.month && 
      date.day == now.day
    );
  }

  int get currentStreak {
    if (completedDates.isEmpty) return 0;
    
    // Sort dates descending
    final sorted = List<DateTime>.from(completedDates)
      ..sort((a, b) => b.compareTo(a));
      
    int streak = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Check if completed today
    bool completedToday = sorted.any((d) => 
      d.year == today.year && d.month == today.month && d.day == today.day);
      
    // If not completed today, check if completed yesterday to maintain streak
    final yesterday = today.subtract(const Duration(days: 1));
    bool completedYesterday = sorted.any((d) => 
      d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day);
      
    if (!completedToday && !completedYesterday) {
      return 0;
    }

    if (completedToday) streak++;

    // Check backwards from yesterday
    DateTime checkDate = yesterday;
    while (true) {
      bool found = sorted.any((d) => 
        d.year == checkDate.year && d.month == checkDate.month && d.day == checkDate.day);
      
      if (found) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    
    return streak;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'iconCode': iconCode,
      'colorValue': colorValue,
      'completedDates': completedDates.map((e) => e.toIso8601String()).toList(),
    };
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'],
      title: json['title'],
      iconCode: json['iconCode'],
      colorValue: json['colorValue'],
      completedDates: (json['completedDates'] as List).map((e) => DateTime.parse(e)).toList(),
    );
  }

  Habit copyWith({
    String? id,
    String? title,
    int? iconCode,
    int? colorValue,
    List<DateTime>? completedDates,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      completedDates: completedDates ?? this.completedDates,
    );
  }
}
