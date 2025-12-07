import 'dart:async';
import 'dart:io';
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

  ActivityState({
    this.taskTitle = '', 
    this.currentStep = '', 
    this.progress = 0.0, 
    this.isActive = false
  });
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Stream for In-App Simulation
  final StreamController<ActivityState> _activityStreamController = StreamController<ActivityState>.broadcast();
  Stream<ActivityState> get activityStream => _activityStreamController.stream;

  // Stream for action callbacks (complete/cancel from Dynamic Island)
  final StreamController<IslandAction> _actionStreamController = StreamController<IslandAction>.broadcast();
  Stream<IslandAction> get actionStream => _actionStreamController.stream;

  Task? _currentTask;

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

    // Note: iOS Live Activities are handled natively via Swift code
    // The live_activities Flutter package has limited web support
    // so we use the in-app simulation on all platforms
  }

  // Trigger complete action from Dynamic Island / In-App Simulation
  void triggerComplete() {
    _actionStreamController.add(IslandAction.complete);
  }

  // Trigger cancel action from Dynamic Island / In-App Simulation
  void triggerCancel() {
    _actionStreamController.add(IslandAction.cancel);
  }

  // Start a new Activity (In-App Simulation + Native iOS if available)
  Future<void> startTaskActivity(Task task) async {
    _currentTask = task;
    
    // In-App Simulation (works on all platforms including web)
    _activityStreamController.add(ActivityState(
      taskTitle: task.title,
      currentStep: task.subTasks.isNotEmpty ? task.subTasks.first.title : "Starting...",
      progress: 0.0,
      isActive: true,
    ));

    // Note: Native iOS Live Activity is started via native Swift code
    // when running on real iOS device with TrollStore
  }

  Future<void> updateTaskProgress(String stepName, double progress) async {
    // In-App Simulation
    _activityStreamController.add(ActivityState(
      taskTitle: _currentTask?.title ?? "Current Task",
      currentStep: stepName,
      progress: progress,
      isActive: true,
    ));

    // Note: Native iOS Live Activity update is handled in Swift
  }

  Future<void> endActivity() async {
    _currentTask = null;
    
    // In-App Simulation
    _activityStreamController.add(ActivityState(isActive: false));
    
    // Cancel any Android notification
    if (!_isWeb()) {
      try {
        await _localNotifications.cancel(888);
      } catch (_) {}
    }
  }

  bool _isWeb() {
    try {
      return identical(0, 0.0); // Always false, but catches web
    } catch (_) {
      return true;
    }
  }

  void dispose() {
    _activityStreamController.close();
    _actionStreamController.close();
  }
}

// Provider
final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());
