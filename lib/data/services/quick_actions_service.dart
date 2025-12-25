import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
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

    // Skip on Web platform - quick actions not supported
    if (kIsWeb) return;

    const quickActions = QuickActions();
    
    // 1. Initialize the callback FIRST
    quickActions.initialize((String shortcutType) {
      debugPrint('[QuickActions] Shortcut tapped: $shortcutType');
      _actionController.add(shortcutType);
    });

    // 2. Clear and Set Shortcuts
    // We wrap this in a microtask to ensure the engine is fully ready to handle the channel call
    Future.microtask(() async {
      try {
        await quickActions.clearShortcutItems();
        await quickActions.setShortcutItems(const <ShortcutItem>[
          ShortcutItem(type: 'create_task', localizedTitle: '新建事项', icon: 'add'),
          ShortcutItem(type: 'quick_focus', localizedTitle: '快速专注', icon: 'timer'),
          ShortcutItem(type: 'decision', localizedTitle: '做个决定', icon: 'shuffle'),
          ShortcutItem(type: 'venting', localizedTitle: '大声倾诉', icon: 'mic'),
        ]);
        debugPrint('[QuickActions] Shortcuts registered successfully');
      } catch (e) {
        debugPrint('[QuickActions] Error registering shortcuts: $e');
      }
    });
  }

  void dispose() {
    _actionController.close();
  }
}
