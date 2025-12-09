
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:do_now/utils/haptic_helper.dart';
import 'package:do_now/data/services/camera_service.dart';
import 'package:do_now/data/localization.dart';
import 'package:do_now/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import '../widgets/video_player_dialog.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInit = false;
  bool _isRecording = false;
  int _selectedCameraIdx = 0;
  FlashMode _flashMode = FlashMode.off;
  bool _isFrontCamera = false;
  bool _usedPrewarmedController = false; // Track if we used prewarmed controller
  
  // Zoom & Focus
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoomLevel = 1.0;
  double _baseScale = 1.0;
  
  Offset? _focusPoint;
  bool _showFocusRect = false;
  Timer? _focusTimer;

  String? _capturedPath;
  bool _isVideo = false;
  String? _videoThumbnailPath; // Video thumbnail for preview
  bool _isVideoMirrored = false; // Track if video was recorded with front camera

  // Animation for record button
  late AnimationController _recordBtnController;
  late Animation<double> _recordBtnAnimation;
  
  // Timer for video duration
  Timer? _videoTimer;
  int _recordSeconds = 0;
  final int _maxRecordSeconds = 15;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    
    _recordBtnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _recordBtnAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _recordBtnController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initCamera() async {
    final cameraService = CameraService();
    
    // Try to use prewarmed controller first
    if (cameraService.isPrewarmed) {
      final prewarmedController = cameraService.takeController();
      if (prewarmedController != null && prewarmedController.value.isInitialized) {
        _controller = prewarmedController;
        _cameras = cameraService.cameras ?? [];
        
        // Find the camera index that matches the prewarmed controller
        _selectedCameraIdx = _cameras.indexWhere(
          (c) => c.name == prewarmedController.description.name
        );
        if (_selectedCameraIdx == -1) _selectedCameraIdx = 0;
        
        _isFrontCamera = prewarmedController.description.lensDirection == CameraLensDirection.front;
        _usedPrewarmedController = true;
        
        // Get zoom capabilities
        _maxAvailableZoom = await prewarmedController.getMaxZoomLevel();
        _minAvailableZoom = await prewarmedController.getMinZoomLevel();
        
        if (mounted) {
          setState(() => _isInit = true);
        }
        debugPrint('Using prewarmed camera controller');
        return;
      }
    }
    
    // Fallback: Initialize camera normally
    try {
      _cameras = cameraService.cameras ?? await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) Navigator.pop(context);
        return;
      }
      
      // Default to back camera
      _selectedCameraIdx = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_selectedCameraIdx == -1) _selectedCameraIdx = 0;
      
      _isFrontCamera = _cameras[_selectedCameraIdx].lensDirection == CameraLensDirection.front;

      await _startCamera(_cameras[_selectedCameraIdx]);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _startCamera(CameraDescription cameraDescription) async {
    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.high, // Use high quality
      enableAudio: true,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
    );

    _controller = controller;

    try {
      await controller.initialize();
      
      // Get zoom capabilities
      _maxAvailableZoom = await controller.getMaxZoomLevel();
      _minAvailableZoom = await controller.getMinZoomLevel();
      
      await controller.setFlashMode(_flashMode);
      
      // Pre-warm video recording to reduce long-press delay
      try {
        await controller.prepareForVideoRecording();
      } catch (_) {
        // Some devices may not support this
      }
      
      if (mounted) {
        setState(() => _isInit = true);
      }
    } catch (e) {
      debugPrint('Camera start error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Basic lifecycle handling
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _startCamera(_controller!.description);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _recordBtnController.dispose();
    _videoTimer?.cancel();
    _focusTimer?.cancel();
    super.dispose();
  }

  // Actions
  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    HapticHelper(ref).lightImpact();
    
    _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras.length;
    _isFrontCamera = _cameras[_selectedCameraIdx].lensDirection == CameraLensDirection.front;
    
    await _controller?.dispose();
    setState(() => _isInit = false);
    await _startCamera(_cameras[_selectedCameraIdx]);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    HapticHelper(ref).lightImpact();

    FlashMode newMode;
    if (_flashMode == FlashMode.off) {
      newMode = FlashMode.torch; 
    } else {
      newMode = FlashMode.off;
    }
    
    try {
      await _controller!.setFlashMode(newMode);
      setState(() => _flashMode = newMode);
    } catch (_) {}
  }
  
  // Focus logic
  void _onTapToFocus(TapUpDetails details, BoxConstraints constraints) {
    if (_controller == null || !_isInit) return;
    
    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    
    setState(() {
      _focusPoint = details.localPosition;
      _showFocusRect = true;
    });
    
    try {
      _controller!.setFocusPoint(offset);
      _controller!.setExposurePoint(offset);
    } catch (e) {
      debugPrint('Focus error: $e');
    }
    
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showFocusRect = false);
    });
  }
  
  // Zoom logic
  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _currentZoomLevel;
  }

  Future<void> _onScaleUpdate(ScaleUpdateDetails details) async {
    if (_controller == null || !_isInit) return;
    
    double scale = _baseScale * details.scale;
    if (scale < _minAvailableZoom) scale = _minAvailableZoom;
    if (scale > _maxAvailableZoom) scale = _maxAvailableZoom;
    
    if (scale != _currentZoomLevel) {
      setState(() => _currentZoomLevel = scale);
      try {
        await _controller!.setZoomLevel(scale);
      } catch (_) {}
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isRecording) return;
    HapticHelper(ref).mediumImpact();

    try {
      final XFile image = await _controller!.takePicture();
      
      setState(() {
        _capturedPath = image.path;
        _isVideo = false;
        _isVideoMirrored = _isFrontCamera; // Reuse this flag for photos too
      });
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized || _isRecording) return;
    HapticHelper(ref).mediumImpact();

    try {
      await _controller!.startVideoRecording();
      _recordBtnController.forward();
      
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
      
      _videoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _recordSeconds++);
        if (_recordSeconds >= _maxRecordSeconds) {
          _stopRecording();
        }
      });
    } catch (e) {
      debugPrint('Error starting video: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    
    _videoTimer?.cancel();
    _recordBtnController.reverse();

    try {
      final XFile video = await _controller!.stopVideoRecording();
      
      // Generate video thumbnail
      String? thumbnailPath;
      try {
        thumbnailPath = await vt.VideoThumbnail.thumbnailFile(
          video: video.path,
          thumbnailPath: (await getTemporaryDirectory()).path,
          imageFormat: vt.ImageFormat.JPEG,
          maxWidth: 1080,  // Ensure width is large enough
          maxHeight: 1920, // Full HD height
          quality: 85,
        );
      } catch (e) {
        debugPrint('Thumbnail generation error: $e');
      }
      
      setState(() {
        _isRecording = false;
        _capturedPath = video.path;
        _isVideo = true;
        _videoThumbnailPath = thumbnailPath;
        _isVideoMirrored = _isFrontCamera; // Track if video needs mirroring on playback
      });
    } catch (e) {
      debugPrint('Error stopping video: $e');
      setState(() => _isRecording = false);
    }
  }

  void _retake() {
    setState(() {
      _capturedPath = null;
      _isVideo = false;
      _videoThumbnailPath = null;
      _isVideoMirrored = false;
    });
  }

  void _confirm() {
    if (_capturedPath != null) {
      Navigator.pop(context, {
        'path': _capturedPath, 
        'type': _isVideo ? 'video' : 'photo',
        'mirrored': _isVideoMirrored,
        'thumbnail': _videoThumbnailPath, // Pass thumbnail for videos
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_capturedPath != null) {
      return _buildPreviewUI();
    }
    
    // Fix Aspect Ratio for Full Screen
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    
    // Camera aspect ratio is typically width/height (e.g. 4/3 or 16/9)
    // But since it's rotated 90deg on phones, we might need to invert logic or use the controller.value.aspectRatio.
    // Flutter's CameraPreview handles rotation. 
    // Usually controller.value.aspectRatio is ~0.75 (3/4) in portrait or ~1.33 (4/3) in landscape.
    // To cover the screen, we scale.
    
    // Use the standard "Cover" logic
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    // ensure scale is correct to cover
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Preview (Zoomable, Focusable, Full Screen)
          GestureDetector(
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onTapUp: (details) => _onTapToFocus(details, BoxConstraints(maxWidth: size.width, maxHeight: size.height)),
            child: SizedBox.expand(
               child: Transform.scale(
                 scale: scale,
                 child: Center(
                   // Mirror front camera preview to match final captured image
                   child: Transform.flip(
                     flipX: _isFrontCamera,
                     child: CameraPreview(_controller!),
                   ),
                 ),
               ),
            ),
          ),
          
          // 2. Focus Indicator
          if (_showFocusRect && _focusPoint != null)
             Positioned(
               left: _focusPoint!.dx - 30,
               top: _focusPoint!.dy - 30,
               child: IgnorePointer(
                 child: Container(
                   width: 60,
                   height: 60,
                   decoration: BoxDecoration(
                     border: Border.all(color: Colors.yellow, width: 2),
                   ),
                 ),
               ),
             ),

          // 3. Controls Overlay
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Close
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 28),
                        ),
                      ),
                      const Spacer(),
                      // Flash
                      GestureDetector(
                        onTap: _toggleFlash,
                        child: Container(
                           padding: const EdgeInsets.all(8),
                           decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                           child: Icon(
                             _flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
                             color: Colors.white, size: 28
                           ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Bottom Controls
                Padding(
                  padding: const EdgeInsets.only(bottom: 40, left: 30, right: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 40), 

                      // Shutter Button
                      GestureDetector(
                        onTap: () {
                           if (!_isRecording) _takePicture();
                        },
                        onLongPress: () {
                           if (!_isRecording) _startRecording();
                        },
                        onLongPressEnd: (_) {
                           if (_isRecording) _stopRecording();
                        },
                        child: AnimatedBuilder(
                          animation: _recordBtnAnimation,
                          builder: (context, child) {
                            final scale = _recordBtnAnimation.value;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer Ring
                                Container(
                                  width: 80 * scale,
                                  height: 80 * scale,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isRecording ? Colors.green.withOpacity(0.5) : Colors.white24,
                                  ),
                                ),
                                // Inner Circle
                                Container(
                                  width: _isRecording ? 30 : 60,
                                  height: _isRecording ? 30 : 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isRecording ? Colors.red : Colors.white,
                                  ),
                                ),
                                // Progress Indicator if recording
                                if (_isRecording)
                                  SizedBox(
                                    width: 80 * scale,
                                    height: 80 * scale,
                                    child: CircularProgressIndicator(
                                      value: _recordSeconds / _maxRecordSeconds,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                      strokeWidth: 4,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),

                      // Flip Camera
                      GestureDetector(
                        onTap: _switchCamera,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                          child: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Recording Hint
                if (!_isRecording)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      AppStrings.get('camera_hint', ref.watch(localeProvider)),
                      style: const TextStyle(color: Colors.white54, fontSize: 12, shadows: [
                        Shadow(blurRadius: 2, color: Colors.black, offset: Offset(0, 1))
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_capturedPath != null)
            Transform.flip(
              flipX: _isVideoMirrored, // Mirror for front camera content
              child: _isVideo 
                ? (_videoThumbnailPath != null
                    ? Image.file(File(_videoThumbnailPath!), fit: BoxFit.cover)
                    : const Center(child: Icon(Icons.videocam, size: 100, color: Colors.white24)))
                : Image.file(File(_capturedPath!), fit: BoxFit.cover),
            ),
          
          // Video indicator overlay - tap to play
          if (_isVideo && _capturedPath != null)
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => VideoPlayerDialog(videoPath: _capturedPath!),
                );
              },
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, size: 48, color: Colors.white),
                ),
              ),
            ),

          // Actions
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       // Retake
                       IconButton(
                         onPressed: _retake,
                         icon: const Icon(Icons.refresh, color: Colors.white, size: 36),
                       ),
                       // Confirm
                       IconButton(
                         onPressed: _confirm,
                         icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 64),
                       ),
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
