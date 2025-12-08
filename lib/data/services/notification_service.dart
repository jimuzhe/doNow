import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';

// Action types from Dynamic Island / Android Notification
enum IslandAction { complete, cancel }

// Simple model for state updates to Simulation Overlay
class ActivityState {
  final String taskTitle;
  final String currentStep;
  final double progress; // 0.0 to 1.0
  final bool isActive;
  final DateTime? startTime;
  final DateTime? endTime;

  ActivityState({
    this.taskTitle = '', 
    this.currentStep = '', 
    this.progress = 0.0, 
    this.isActive = false,
    this.startTime,
    this.endTime,
  });
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // MethodChannel for iOS Live Activities
  static const MethodChannel _liveActivityChannel = MethodChannel('com.donow.app/live_activity');
  
  // MethodChannel for Android Foreground Notification
  static const MethodChannel _androidNotificationChannel = MethodChannel('com.donow.app/android_notification');
  
  // Stream for In-App Simulation
  final StreamController<ActivityState> _activityStreamController = StreamController<ActivityState>.broadcast();
  Stream<ActivityState> get activityStream => _activityStreamController.stream;

  // Stream for action callbacks (complete/cancel from Dynamic Island / Android Notification)
  final StreamController<IslandAction> _actionStreamController = StreamController<IslandAction>.broadcast();
  Stream<IslandAction> get actionStream => _actionStreamController.stream;

  Task? _currentTask;
  bool _isLiveActivitySupported = false;
  bool _isLiveActivityActive = false;
  bool _isAndroidNotificationActive = false;
  
  // Cached step schedule for iOS auto-advance
  List<Map<String, dynamic>>? _cachedStepSchedule;

  Future<void> init() async {
    // 1. Local Notifications Init
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();
        
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(initializationSettings);

    // 2. Check iOS Live Activity support
    await _checkLiveActivitySupport();
    
    // 3. Setup Android notification action handler
    _setupAndroidActionHandler();
  }

  /// Setup handler for Android notification actions
  void _setupAndroidActionHandler() {
    if (_isAndroid()) {
      _androidNotificationChannel.setMethodCallHandler((call) async {
        if (call.method == 'onNotificationAction') {
          final String action = call.arguments as String;
          debugPrint('📲 Android notification action: $action');
          
          if (action == 'complete') {
            triggerComplete();
          } else if (action == 'cancel') {
            triggerCancel();
          }
        }
        return null;
      });
    }
  }

  /// Check if iOS Live Activities are supported
  Future<void> _checkLiveActivitySupport() async {
    if (_isIOS()) {
      try {
        final bool isSupported = await _liveActivityChannel.invokeMethod('isSupported');
        _isLiveActivitySupported = isSupported;
        debugPrint('📱 Live Activity supported: $_isLiveActivitySupported');
      } catch (e) {
        debugPrint('❌ Error checking Live Activity support: $e');
        _isLiveActivitySupported = false;
      }
    }
  }

  /// Check if running on iOS
  bool _isIOS() {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }
  
  /// Check if running on Android
  bool _isAndroid() {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Check if Live Activity is currently active
  bool get isLiveActivityActive => _isLiveActivityActive;

  /// Check if Live Activity is supported
  bool get isLiveActivitySupported => _isLiveActivitySupported;
  
  /// Check if Android notification is active
  bool get isAndroidNotificationActive => _isAndroidNotificationActive;

  // Trigger complete action from Dynamic Island / Android Notification / In-App Simulation
  void triggerComplete() {
    _actionStreamController.add(IslandAction.complete);
  }

  // Trigger cancel action from Dynamic Island / Android Notification / In-App Simulation
  void triggerCancel() {
    _actionStreamController.add(IslandAction.cancel);
  }
  
  /// Build step schedule for iOS auto-advance
  /// Each step has: title, durationSeconds, endTime (timestamp)
  List<Map<String, dynamic>> _buildStepSchedule(Task task, DateTime taskStartTime) {
    final List<Map<String, dynamic>> steps = [];
    DateTime currentEndTime = taskStartTime;
    
    for (final subTask in task.subTasks) {
      currentEndTime = currentEndTime.add(subTask.estimatedDuration);
      steps.add({
        'title': subTask.title,
        'durationSeconds': subTask.estimatedDuration.inSeconds,
        'endTime': currentEndTime.millisecondsSinceEpoch / 1000.0,
      });
    }
    
    return steps;
  }

  // Start a new Activity (In-App Simulation + Native iOS/Android if available)
  Future<void> startTaskActivity(Task task, {DateTime? startTime, DateTime? endTime}) async {
    _currentTask = task;
    
    final currentStep = task.subTasks.isNotEmpty ? task.subTasks.first.title : "Starting...";
    final taskStartTime = startTime ?? DateTime.now();
    
    // Build step schedule for iOS
    _cachedStepSchedule = _buildStepSchedule(task, taskStartTime);
    
    // 1. In-App Simulation (works on all platforms including web)
    _activityStreamController.add(ActivityState(
      taskTitle: task.title,
      currentStep: currentStep,
      progress: 0.0,
      isActive: true,
      startTime: startTime,
      endTime: endTime,
    ));

    // 2. Start iOS Live Activity if supported
    if (_isIOS() && _isLiveActivitySupported) {
      try {
        final Map<String, dynamic> args = {
          'taskTitle': task.title,
          'currentStep': currentStep,
          'progress': 0.0,
          'totalDuration': task.totalDuration.inMinutes,
          'currentStepIndex': 0,
          'steps': _cachedStepSchedule,
        };
        
        if (startTime != null) {
           args['startTime'] = startTime.millisecondsSinceEpoch / 1000.0;
        }
        if (endTime != null) {
           args['endTime'] = endTime.millisecondsSinceEpoch / 1000.0;
        }
        
        // For first step, set its specific start/end times
        if (task.subTasks.isNotEmpty) {
          final firstStepEnd = taskStartTime.add(task.subTasks.first.estimatedDuration);
          args['startTime'] = taskStartTime.millisecondsSinceEpoch / 1000.0;
          args['endTime'] = firstStepEnd.millisecondsSinceEpoch / 1000.0;
        }

        final result = await _liveActivityChannel.invokeMethod('startActivity', args);
        
        _isLiveActivityActive = result != null;
        debugPrint('🏝️ Live Activity started with ${_cachedStepSchedule?.length ?? 0} steps');
      } catch (e) {
        debugPrint('❌ Error starting Live Activity: $e');
        _isLiveActivityActive = false;
      }
    }
    
    // 3. Start Android Foreground Notification
    if (_isAndroid()) {
      try {
        await _androidNotificationChannel.invokeMethod('startTaskNotification', {
          'taskTitle': task.title,
          'currentStep': currentStep,
          'progress': 0.0,
          'endTime': endTime != null ? endTime.millisecondsSinceEpoch / 1000.0 : 0.0,
        });
        _isAndroidNotificationActive = true;
        debugPrint('🤖 Android notification started');
      } catch (e) {
        debugPrint('❌ Error starting Android notification: $e');
        _isAndroidNotificationActive = false;
      }
    }
  }

  /// Check for any pending actions triggered from Dynamic Island (iOS 17+) or Android notification
  Future<void> checkPendingAction() async {
    // iOS
    if (_isIOS()) {
      try {
        final String? action = await _liveActivityChannel.invokeMethod('checkPendingAction');
        if (action != null) {
          debugPrint('📲 iOS Pending Action found: $action');
          if (action == 'complete') {
            triggerComplete();
          } else if (action == 'cancel') {
            triggerCancel();
          }
        }
      } catch (e) {
        debugPrint('❌ Error checking iOS pending action: $e');
      }
    }
    
    // Android
    if (_isAndroid()) {
      try {
        final String? action = await _androidNotificationChannel.invokeMethod('checkPendingAction');
        if (action != null) {
          debugPrint('📲 Android Pending Action found: $action');
          if (action == 'complete') {
            triggerComplete();
          } else if (action == 'cancel') {
            triggerCancel();
          }
        }
      } catch (e) {
        debugPrint('❌ Error checking Android pending action: $e');
      }
    }
  }

  Future<void> updateTaskProgress(
    String stepName, 
    double progress, 
    {DateTime? startTime, DateTime? endTime, int currentStepIndex = 0}
  ) async {
    // 1. In-App Simulation
    _activityStreamController.add(ActivityState(
      taskTitle: _currentTask?.title ?? "Current Task",
      currentStep: stepName,
      progress: progress,
      isActive: true,
      startTime: startTime,
      endTime: endTime,
    ));

    // 2. Update iOS Live Activity if active
    if (_isIOS() && _isLiveActivityActive) {
      try {
        final Map<String, dynamic> args = {
          'currentStep': stepName,
          'progress': progress,
          'currentStepIndex': currentStepIndex,
          'steps': _cachedStepSchedule, // Pass full schedule for auto-advance
        };
        
        if (startTime != null) {
           args['startTime'] = startTime.millisecondsSinceEpoch / 1000.0;
        }
        if (endTime != null) {
           args['endTime'] = endTime.millisecondsSinceEpoch / 1000.0;
        }

        await _liveActivityChannel.invokeMethod('updateActivity', args);
      } catch (e) {
        debugPrint('❌ Error updating Live Activity: $e');
      }
    }
    
    // 3. Update Android Foreground Notification if active
    if (_isAndroid() && _isAndroidNotificationActive) {
      try {
        await _androidNotificationChannel.invokeMethod('updateTaskNotification', {
          'currentStep': stepName,
          'progress': progress,
          'endTime': endTime != null ? endTime.millisecondsSinceEpoch / 1000.0 : 0.0,
        });
      } catch (e) {
        debugPrint('❌ Error updating Android notification: $e');
      }
    }
  }

  Future<void> endActivity() async {
    _currentTask = null;
    _cachedStepSchedule = null;
    
    // 1. In-App Simulation
    _activityStreamController.add(ActivityState(isActive: false));
    
    // 2. End iOS Live Activity if active
    if (_isIOS() && _isLiveActivityActive) {
      try {
        await _liveActivityChannel.invokeMethod('endActivity');
        _isLiveActivityActive = false;
        debugPrint('🏁 Live Activity ended');
      } catch (e) {
        debugPrint('❌ Error ending Live Activity: $e');
      }
    }
    
    // 3. Stop Android Foreground Notification if active
    if (_isAndroid() && _isAndroidNotificationActive) {
      try {
        await _androidNotificationChannel.invokeMethod('stopTaskNotification');
        _isAndroidNotificationActive = false;
        debugPrint('🏁 Android notification ended');
      } catch (e) {
        debugPrint('❌ Error ending Android notification: $e');
      }
    }
    
    // 4. Cancel any fallback local notification
    if (!kIsWeb) {
      try {
        await _localNotifications.cancel(888);
      } catch (_) {}
    }
  }

  void dispose() {
    _activityStreamController.close();
    _actionStreamController.close();
  }
}

// Provider
final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());
