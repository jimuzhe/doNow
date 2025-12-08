import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';

// Action types from Dynamic Island
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
  
  // Stream for In-App Simulation
  final StreamController<ActivityState> _activityStreamController = StreamController<ActivityState>.broadcast();
  Stream<ActivityState> get activityStream => _activityStreamController.stream;

  // Stream for action callbacks (complete/cancel from Dynamic Island)
  final StreamController<IslandAction> _actionStreamController = StreamController<IslandAction>.broadcast();
  Stream<IslandAction> get actionStream => _actionStreamController.stream;

  Task? _currentTask;
  bool _isLiveActivitySupported = false;
  bool _isLiveActivityActive = false;

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

  /// Check if Live Activity is currently active
  bool get isLiveActivityActive => _isLiveActivityActive;

  /// Check if Live Activity is supported
  bool get isLiveActivitySupported => _isLiveActivitySupported;

  // Trigger complete action from Dynamic Island / In-App Simulation
  void triggerComplete() {
    _actionStreamController.add(IslandAction.complete);
  }

  // Trigger cancel action from Dynamic Island / In-App Simulation
  void triggerCancel() {
    _actionStreamController.add(IslandAction.cancel);
  }

  // Start a new Activity (In-App Simulation + Native iOS if available)
  Future<void> startTaskActivity(Task task, {DateTime? startTime, DateTime? endTime}) async {
    _currentTask = task;
    
    final currentStep = task.subTasks.isNotEmpty ? task.subTasks.first.title : "Starting...";
    
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
        };
        
        if (startTime != null) {
           args['startTime'] = startTime.millisecondsSinceEpoch / 1000.0;
        }
        if (endTime != null) {
           args['endTime'] = endTime.millisecondsSinceEpoch / 1000.0;
        }

        final result = await _liveActivityChannel.invokeMethod('startActivity', args);
        
        _isLiveActivityActive = result != null;
        debugPrint('🏝️ Live Activity started: $result');
      } catch (e) {
        debugPrint('❌ Error starting Live Activity: $e');
        _isLiveActivityActive = false;
      }
    }
  }

  /// Check for any pending actions triggered from Dynamic Island (iOS 17+)
  Future<void> checkPendingAction() async {
    if (!_isIOS()) return;
    
    try {
      final String? action = await _liveActivityChannel.invokeMethod('checkPendingAction');
      if (action != null) {
        debugPrint('📲 Pending Action found: $action');
        if (action == 'complete') {
          triggerComplete();
        } else if (action == 'cancel') {
          triggerCancel();
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking pending action: $e');
    }
  }

  Future<void> updateTaskProgress(String stepName, double progress, {DateTime? startTime, DateTime? endTime}) async {
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
        };
        
        if (startTime != null) {
           args['startTime'] = startTime.millisecondsSinceEpoch / 1000.0;
        }
        if (endTime != null) {
           args['endTime'] = endTime.millisecondsSinceEpoch / 1000.0;
        }

        await _liveActivityChannel.invokeMethod('updateActivity', args);
        // debugPrint('🔄 Live Activity updated: $stepName'); 
      } catch (e) {
        debugPrint('❌ Error updating Live Activity: $e');
      }
    }
  }

  Future<void> endActivity() async {
    _currentTask = null;
    
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
    
    // 3. Cancel any Android notification
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
