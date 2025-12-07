import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/task.dart';
import '../providers.dart';

/// Service that monitors scheduled tasks and triggers notifications
/// when it's time to execute them
class TaskSchedulerService {
  final Ref _ref;
  Timer? _checkTimer;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  // Stream controller for navigation events
  final StreamController<Task> _navigationController = StreamController<Task>.broadcast();
  Stream<Task> get onTaskDue => _navigationController.stream;
  
  // Track which tasks have already been notified (to avoid duplicate notifications)
  final Set<String> _notifiedTaskIds = {};

  TaskSchedulerService(this._ref);

  /// Initialize the scheduler - should be called once at app startup
  Future<void> init() async {
    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle notification tap - could navigate to task
        print('Notification tapped: ${response.payload}');
      },
    );
    
    // Start periodic check every 10 seconds
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkScheduledTasks();
    });
    
    // Also check immediately
    _checkScheduledTasks();
  }

  /// Check all scheduled tasks and trigger notifications for due tasks
  void _checkScheduledTasks() {
    final tasks = _ref.read(taskListProvider);
    final now = DateTime.now();
    
    for (final task in tasks) {
      // Skip if already completed, abandoned, or still generating
      if (task.isCompleted || task.isAbandoned || task.isGenerating) continue;
      
      // Skip if already notified
      if (_notifiedTaskIds.contains(task.id)) continue;
      
      // Check if it's time to execute this task (within 1 minute window)
      final scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        task.scheduledStart.hour,
        task.scheduledStart.minute,
      );
      
      // For repeating tasks, check if today is one of the repeat days
      if (task.repeatDays.isNotEmpty) {
        final todayWeekday = now.weekday; // 1 = Monday, 7 = Sunday
        if (!task.repeatDays.contains(todayWeekday)) continue;
      }
      
      // Check if the task is due (within 1 minute before or after scheduled time)
      final diff = now.difference(scheduledTime).inSeconds.abs();
      if (diff <= 60) {
        // Task is due! Mark as notified and trigger
        _notifiedTaskIds.add(task.id);
        _triggerTaskDue(task);
      }
    }
  }

  /// Trigger notification and navigation for a due task
  Future<void> _triggerTaskDue(Task task) async {
    print('Task due: ${task.title}');
    
    // Send system notification
    await _sendNotification(task);
    
    // Emit navigation event (UI will handle actual navigation)
    _navigationController.add(task);
  }

  /// Send a local notification for the task
  Future<void> _sendNotification(Task task) async {
    const androidDetails = AndroidNotificationDetails(
      'task_due_channel',
      'Task Due Notifications',
      channelDescription: 'Notifications when a task is due to start',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    try {
      await _notifications.show(
        task.id.hashCode,
        '🚀 任务开始时间到！',
        task.title,
        details,
        payload: task.id,
      );
    } catch (e) {
      print('Failed to show notification: $e');
    }
  }

  /// Reset notification state for a task (e.g., when rescheduled)
  void resetTaskNotification(String taskId) {
    _notifiedTaskIds.remove(taskId);
  }

  /// Clear all notification states (e.g., at midnight for repeating tasks)
  void clearAllNotificationStates() {
    _notifiedTaskIds.clear();
  }

  /// Dispose resources
  void dispose() {
    _checkTimer?.cancel();
    _navigationController.close();
  }
}

// Provider
final taskSchedulerServiceProvider = Provider<TaskSchedulerService>((ref) {
  final service = TaskSchedulerService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
