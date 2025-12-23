import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';

/// Service to handle iOS/Android app icon quick actions (3D Touch / Long Press)
class QuickActionsService {
  static final QuickActionsService _instance = QuickActionsService._internal();
  factory QuickActionsService() => _instance;
  QuickActionsService._internal();

  final _actionController = StreamController<String>.broadcast();
  
  /// Stream of quick action types
  Stream<String> get onAction => _actionController.stream;
  
  bool _initialized = false;

  /// Initialize quick actions
  void init() {
    if (_initialized) return;
    _initialized = true;

    // Only initialize on iOS and Android
    if (!Platform.isIOS && !Platform.isAndroid) return;

    final quickActions = QuickActions();
    
    // Set the shortcut items (for dynamic shortcuts - optional, since we have static ones in Info.plist)
    quickActions.setShortcutItems([
      ShortcutItem(
        type: 'quick_focus',
        localizedTitle: 'Quick Focus',
        icon: Platform.isIOS ? 'time' : 'ic_quick_focus',
      ),
      ShortcutItem(
        type: 'decision',
        localizedTitle: 'Make a Decision',
        icon: Platform.isIOS ? 'shuffle' : 'ic_decision',
      ),
      ShortcutItem(
        type: 'create_task',
        localizedTitle: 'Create Task',
        icon: Platform.isIOS ? 'add' : 'ic_add_task',
      ),
    ]);

    // Handle when user taps a quick action
    quickActions.initialize((String shortcutType) {
      debugPrint('[QuickActions] Shortcut tapped: $shortcutType');
      _actionController.add(shortcutType);
    });
  }

  void dispose() {
    _actionController.close();
  }
}
