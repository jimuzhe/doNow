import 'package:flutter/material.dart';
import '../../main.dart';

/// A helper class to show toast/snackbar messages at the TOP of the screen.
/// This ensures messages are always visible above any modals, dialogs, or bottom sheets.
class SnackBarHelper {
  SnackBarHelper._();

  static OverlayEntry? _currentOverlay;

  /// Show a toast message at the TOP of the screen using Overlay.
  /// This ensures it's visible above all other UI elements including modals.
  static void showGlobal({
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Get the overlay from navigator
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) return;

    final overlay = navigatorState.overlay;
    if (overlay == null) return;

    // Remove any existing overlay
    _currentOverlay?.remove();
    _currentOverlay = null;

    // Create new overlay entry
    _currentOverlay = OverlayEntry(
      builder: (context) => _TopToast(
        message: message,
        backgroundColor: backgroundColor ?? Colors.black87,
        duration: duration,
        onDismiss: () {
          _currentOverlay?.remove();
          _currentOverlay = null;
        },
      ),
    );

    overlay.insert(_currentOverlay!);
  }

  /// Show a success toast (green background) at the top.
  static void showSuccess(String message, {Duration? duration}) {
    showGlobal(
      message: message,
      backgroundColor: Colors.green,
      duration: duration ?? const Duration(seconds: 2),
    );
  }

  /// Show an error toast (red background) at the top.
  static void showError(String message, {Duration? duration}) {
    showGlobal(
      message: message,
      backgroundColor: Colors.red,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Show a warning toast (orange background) at the top.
  static void showWarning(String message, {Duration? duration}) {
    showGlobal(
      message: message,
      backgroundColor: Colors.orange,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// Show an info toast (default theme background) at the top.
  static void showInfo(String message, {Duration? duration}) {
    showGlobal(
      message: message,
      duration: duration ?? const Duration(seconds: 3),
    );
  }
}

/// Internal widget for top toast display with animation
class _TopToast extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopToast({
    required this.message,
    required this.backgroundColor,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Start animation
    _controller.forward();

    // Schedule dismiss
    Future.delayed(widget.duration - const Duration(milliseconds: 300), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {
                    _controller.reverse().then((_) {
                      widget.onDismiss();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Icon based on color
                        Icon(
                          _getIcon(),
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    if (widget.backgroundColor == Colors.green) {
      return Icons.check_circle;
    } else if (widget.backgroundColor == Colors.red) {
      return Icons.error;
    } else if (widget.backgroundColor == Colors.orange) {
      return Icons.warning;
    }
    return Icons.info;
  }
}
