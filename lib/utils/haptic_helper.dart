import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/providers.dart';

/// Helper class for haptic feedback with intensity control
class HapticHelper {
  /// Trigger light impact haptic based on intensity setting
  static void lightImpact(WidgetRef ref) {
    final intensity = ref.read(vibrationIntensityProvider);
    if (intensity <= 0) return;
    
    HapticFeedback.lightImpact();
  }

  /// Trigger medium impact haptic based on intensity setting
  static void mediumImpact(WidgetRef ref) {
    final intensity = ref.read(vibrationIntensityProvider);
    if (intensity <= 0) return;
    
    if (intensity < 0.5) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// Trigger heavy impact haptic based on intensity setting
  static void heavyImpact(WidgetRef ref) {
    final intensity = ref.read(vibrationIntensityProvider);
    if (intensity <= 0) return;
    
    if (intensity < 0.4) {
      HapticFeedback.lightImpact();
    } else if (intensity < 0.7) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  /// Trigger selection click haptic based on intensity setting
  static void selectionClick(WidgetRef ref) {
    final intensity = ref.read(vibrationIntensityProvider);
    if (intensity <= 0) return;
    
    HapticFeedback.selectionClick();
  }

  /// Get a human-readable label for current intensity
  static String getIntensityLabel(double intensity, String locale) {
    if (intensity <= 0) {
      return locale == 'zh' ? '关闭' : 'Off';
    } else if (intensity < 0.4) {
      return locale == 'zh' ? '轻微' : 'Light';
    } else if (intensity < 0.7) {
      return locale == 'zh' ? '中等' : 'Medium';
    } else {
      return locale == 'zh' ? '强烈' : 'Strong';
    }
  }
}
