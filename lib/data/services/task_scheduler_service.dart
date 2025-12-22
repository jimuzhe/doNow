import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/task.dart';
import '../providers.dart';
import '../localization.dart';

/// Service that monitors scheduled tasks and triggers notifications
/// when it's time to execute them
class TaskSchedulerService {
  final Ref _ref;
  Timer? _checkTimer;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  // Stream controller for navigation events
  final StreamController<Task> _navigationController = StreamController<Task>.broadcast();
  Stream<Task> get onTaskDue => _navigationController.stream;

  // Stream for upcoming task warnings
  final StreamController<Task> _upcomingController = StreamController<Task>.broadcast();
  Stream<Task> get onTaskUpcoming => _upcomingController.stream;

  // Stream for notification taps
  final StreamController<String> _notificationTapController = StreamController<String>.broadcast();
  Stream<String> get onNotificationTap => _notificationTapController.stream;
  
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
        if (response.payload != null) {
          _notificationTapController.add(response.payload!);
        }
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
      // 2. Logic Check
      
      // A. Upcoming Warning (3 minutes before)
      if (diffSeconds >= -190 && diffSeconds <= -5) {
          final isForeground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
          final isBusy = _ref.read(isBusyUIProvider) || _ref.read(activeTaskIdProvider) != null;
          
          if (!_notifiedTaskIds.contains('${task.id}_upcoming')) {
               // Send notification if:
               // 1. App is in background (not foreground)
               // 2. User is in app but BUSY
               if (!isForeground || isBusy) {
                  _notifiedTaskIds.add('${task.id}_upcoming');
                  _sendUpcomingNotification(task);
                  _upcomingController.add(task);
               }
          }
          continue;
      }
      
      // B. Start Time Reached
      if (diffSeconds >= -30 && diffSeconds <= 300) {
         if (!_notifiedTaskIds.contains('${task.id}_due')) {
             _notifiedTaskIds.add('${task.id}_due');

            final isForeground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
            final activeTaskId = _ref.read(activeTaskIdProvider);
            
            if (activeTaskId == task.id) continue;

            if (!isForeground) {
              // App is in background, definitely send system notification
              _sendDueNotification(task);
            } else if (activeTaskId != null) {
               // Conflict! User is in app but doing another task
               _sendConflictNotification(task);
            } else {
               // No conflict, in foreground
               _triggerTaskDue(task);
            }
         }
      }
    }
  }

  /// Send "Upcoming Task" warning (3 mins before)
  Future<void> _sendUpcomingNotification(Task task) async {
    final locale = _ref.read(localeProvider);
    final title = locale == 'zh' ? '即将开始的任务' : 'Upcoming Task';
    final body = locale == 'zh' 
        ? '任务 "${task.title}" 将在3分钟后开始' 
        : '"${task.title}" starts in 3 minutes';

    await _showNotification(
       id: task.id.hashCode + 1, // Different ID from due notification
       title: title,
       body: body,
       taskId: task.id,
    );
  }

  /// Send "Conflict / Due" notification when another task is already active
  Future<void> _sendDueNotification(Task task) async {
    final locale = _ref.read(localeProvider);
    final title = locale == 'zh' ? '🚀 任务开始时间到！' : '🚀 Task Starting Now!';
    final body = task.title;
    
    await _showNotification(
      id: task.id.hashCode,
      title: title,
      body: body,
      taskId: task.id,
    );
    // Also notify internal stream so UI can react if it comes back to foreground
    _navigationController.add(task);
  }

  /// Send "Conflict / Due" notification when another task is already active
  Future<void> _sendConflictNotification(Task task) async {
    final locale = _ref.read(localeProvider);
    final title = locale == 'zh' ? '任务时间已到' : 'Task Time Reached';
    final body = locale == 'zh'
        ? '您正在进行其他事项。是否切换到 "${task.title}"?'
        : 'You are busy. Switch to "${task.title}"?';
    
    // We can add actions here later if we use a more advanced plugin, 
    // for now just a notification that brings them to app.
    await _showNotification(
      id: task.id.hashCode,
      title: title,
      body: body,
      taskId: task.id,
    );
  }

  /// Wrapper for showing notification
  Future<void> _showNotification({required int id, required String title, required String body, required String taskId}) async {
    const androidDetails = AndroidNotificationDetails(
      'task_due_channel',
      'Task Notifications',
      channelDescription: 'Notifications for tasks',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    try {
      await _notifications.show(
        id,
        title,
        body,
        details,
        payload: taskId,
      );
    } catch (e) {
      print('Failed to show notification: $e');
    }
  }

  /// Trigger notification and navigation for a due task
  Future<void> _triggerTaskDue(Task task) async {
    print('Task due: ${task.title}');
    
    // Check if user is busy (in QuickFocus, Decision, or running another task)
    final isBusy = _ref.read(isBusyUIProvider) || _ref.read(activeTaskIdProvider) != null;
    
    // Only send system notification if user is BUSY
    // If not busy, we will navigate directly (no notification needed)
    if (isBusy) {
      await _showNotification(
         id: task.id.hashCode,
         title: '🚀 任务开始时间到！',
         body: task.title,
         taskId: task.id,
      );
    }
    
    // Emit navigation event (UI will handle actual navigation or show dialog)
    _navigationController.add(task);
  }


  /// Reset notification state for a task (e.g., when rescheduled)
  void resetTaskNotification(String taskId) {
    _notifiedTaskIds.remove(taskId);
    _notifiedTaskIds.remove('${taskId}_upcoming');
    _notifiedTaskIds.remove('${taskId}_due');
  }

  /// Clear all notification states (e.g., at midnight for repeating tasks)
  void clearAllNotificationStates() {
    _notifiedTaskIds.clear();
  }

  /// Dispose resources
  void dispose() {
    _checkTimer?.cancel();
    _navigationController.close();
    _upcomingController.close();
    _notificationTapController.close();
  }
}

// Provider
final taskSchedulerServiceProvider = Provider<TaskSchedulerService>((ref) {
  final service = TaskSchedulerService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
