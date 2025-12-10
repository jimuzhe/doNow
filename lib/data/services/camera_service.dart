import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Global camera service for pre-warming camera to reduce load time
class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  List<CameraDescription>? _cameras;
  CameraController? _controller;
  bool _isPrewarming = false;
  bool _isPrewarmed = false;
  Future<void>? _initFuture;

  /// Get available cameras (cached)
  List<CameraDescription>? get cameras => _cameras;
  
  /// Get pre-warmed controller (if available)
  CameraController? get prewarmedController => _controller;
  
  /// Check if camera is prewarmed and ready
  bool get isPrewarmed => _isPrewarmed && _controller != null && _controller!.value.isInitialized;

  /// Check if camera is currently prewarming
  bool get isPrewarming => _isPrewarming;

  /// Pre-warm the camera (call this before opening camera screen)
  /// If already warming, returns the ongoing future.
  Future<void> prewarm() async {
    if (kIsWeb) return;
    if (_isPrewarmed && _controller != null) return;
    
    // Return existing future if currently initializing
    if (_initFuture != null) return _initFuture;

    _initFuture = _initializeCamera();
    return _initFuture;
  }

  Future<void> _initializeCamera() async {
    _isPrewarming = true;
    
    try {
      // Get available cameras
      _cameras ??= await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        return;
      }
      
      // Find back camera (preferred default)
      int cameraIdx = _cameras!.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (cameraIdx == -1) cameraIdx = 0;
      
      // Initialize controller with high quality
      _controller = CameraController(
        _cameras![cameraIdx],
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
      );
      
      await _controller!.initialize();
      
      // Pre-warm video recording
      try {
        await _controller!.prepareForVideoRecording();
      } catch (_) {}
      
      _isPrewarmed = true;
      debugPrint('Camera pre-warmed successfully');
    } catch (e) {
      debugPrint('Camera prewarm error: $e');
      await _controller?.dispose();
      _controller = null;
      _isPrewarmed = false;
    } finally {
      _isPrewarming = false;
      _initFuture = null;
    }
  }

  /// Take the prewarmed controller (transfers ownership, caller must dispose)
  CameraController? takeController() {
    if (!_isPrewarmed || _controller == null) return null;
    
    final controller = _controller;
    _controller = null;
    _isPrewarmed = false;
    return controller;
  }

  /// Release and dispose the prewarmed controller
  Future<void> release() async {
    _isPrewarmed = false;
    _isPrewarming = false;
    await _controller?.dispose();
    _controller = null;
  }

  /// Dispose everything
  Future<void> dispose() async {
    await release();
    _cameras = null;
  }
}
