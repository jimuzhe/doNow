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
    
    // Clear any existing dynamic shortcuts to avoid duplication with static ones defined in Info.plist
    quickActions.setShortcutItems([]);
    
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
