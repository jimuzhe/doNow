import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/providers.dart';

/// Helper class to provide haptic feedback based on user settings
class HapticHelper {
  final WidgetRef ref;

  HapticHelper(this.ref);

  /// Get the current vibration intensity from settings
  double get intensity => ref.read(vibrationIntensityProvider);

  /// Light impact - for selection feedback
  void lightImpact() {
    if (intensity <= 0) return;
    
    if (intensity < 0.4) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  /// Medium impact - for confirmations
  void mediumImpact() {
    if (intensity <= 0) return;
    
    if (intensity < 0.4) {
      HapticFeedback.selectionClick();
    } else if (intensity < 0.7) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// Heavy impact - for important actions
  void heavyImpact() {
    if (intensity <= 0) return;
    
    if (intensity < 0.4) {
      HapticFeedback.lightImpact();
    } else if (intensity < 0.7) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  /// Selection click - for subtle feedback
  void selectionClick() {
    if (intensity <= 0) return;
    HapticFeedback.selectionClick();
  }

  /// Success feedback
  void success() {
    if (intensity <= 0) return;
    if (intensity < 0.4) {
       HapticFeedback.lightImpact();
    } else {
       HapticFeedback.mediumImpact();
    }
  }

  /// Warning feedback
  void warning() {
    if (intensity <= 0) return;
    HapticFeedback.mediumImpact();
  }

  /// Error feedback
  void error() {
    if (intensity <= 0) return;
    HapticFeedback.heavyImpact();
    // Double vibration for error if intensity is high?
    if (intensity > 0.7) {
       Future.delayed(const Duration(milliseconds: 100), () => HapticFeedback.heavyImpact());
    }
  }
}

/// Static helper for places where WidgetRef is not available
/// Uses full intensity since settings can't be accessed
class HapticHelperStatic {
  /// Light impact
  static void lightImpact() {
    HapticFeedback.lightImpact();
  }

  /// Medium impact
  static void mediumImpact() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact
  static void heavyImpact() {
    HapticFeedback.heavyImpact();
  }

  /// Selection click
  static void selectionClick() {
    HapticFeedback.selectionClick();
  }
}
