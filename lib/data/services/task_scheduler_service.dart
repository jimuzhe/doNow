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

      DateTime? targetTime;
      
      // 1. Determine the target scheduled time for specific types
      if (task.repeatDays.isNotEmpty) {
         // REPEATING TASK: Logic is based on "Today + Time"
         final todayWeekday = now.weekday; // 1 = Monday, 7 = Sunday
         if (!task.repeatDays.contains(todayWeekday)) continue;
         
         targetTime = DateTime(
            now.year,
            now.month,
            now.day,
            task.scheduledStart.hour,
            task.scheduledStart.minute,
          );
      } else {
         // ONE-OFF TASK: Respect the full scheduled date
         // If the date is in the past (e.g. yesterday), we might have missed it.
         // But usually we just compare strictly.
         targetTime = task.scheduledStart;
      }
      
      if (targetTime == null) continue;

      // 2. Check if due
      // Allow triggering if we are slightly past the time (caught up after sleep)
      // or slightly before.
      // E.g. [Target - 30s, Target + 5 min]
      final diffSeconds = now.difference(targetTime).inSeconds;
      
      // If now is 10s before target: diff = -10.
      // If now is 300s after target: diff = 300.
      if (diffSeconds >= -30 && diffSeconds <= 300) {
         // Valid window: 30s before up to 5 minutes after
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
