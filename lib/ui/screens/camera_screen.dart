
import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:do_now/utils/haptic_helper.dart'; // Ensure correct import path
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  
  // For file result
  String? _capturedPath;
  bool _isVideo = false;

  // Animation for record button
  late AnimationController _recordBtnController;
  late Animation<double> _recordBtnAnimation;
  
  // Timer for video duration
  Timer? _videoTimer;
  int _recordSeconds = 0;
  final int _maxRecordSeconds = 15; // WeChat style limit

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
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) Navigator.pop(context);
        return;
      }
      
      // Default to back camera
      _selectedCameraIdx = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_selectedCameraIdx == -1) _selectedCameraIdx = 0;

      await _startCamera(_cameras[_selectedCameraIdx]);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _startCamera(CameraDescription cameraDescription) async {
    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
    );

    _controller = controller;

    try {
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
      if (mounted) {
        setState(() => _isInit = true);
      }
    } catch (e) {
      debugPrint('Camera start error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _startCamera(cameraController.description);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _recordBtnController.dispose();
    _videoTimer?.cancel();
    super.dispose();
  }

  // Actions
  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    HapticFeedback.lightImpact();
    
    _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras.length;
    
    await _controller?.dispose();
    setState(() => _isInit = false);
    await _startCamera(_cameras[_selectedCameraIdx]);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    HapticFeedback.lightImpact();

    FlashMode newMode;
    if (_flashMode == FlashMode.off) {
      newMode = FlashMode.torch; // For video/preview
    } else {
      newMode = FlashMode.off;
    }
    
    try {
      await _controller!.setFlashMode(newMode);
      setState(() => _flashMode = newMode);
    } catch (_) {}
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isRecording) return;
    HapticFeedback.mediumImpact();

    try {
      final XFile image = await _controller!.takePicture();
      setState(() {
        _capturedPath = image.path;
        _isVideo = false;
      });
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized || _isRecording) return;
    HapticFeedback.mediumImpact();

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
      setState(() {
        _isRecording = false;
        _capturedPath = video.path;
        _isVideo = true;
      });
    } catch (e) {
      debugPrint('Error stopping video: $e');
      setState(() => _isRecording = false);
    }
  }

  void _retake() {
    // Delete temp file maybe?
    setState(() {
      _capturedPath = null;
      _isVideo = false;
    });
    // Restart camera preview if needed (it usually stays running)
  }

  void _confirm() {
    if (_capturedPath != null) {
      Navigator.pop(context, {'path': _capturedPath, 'type': _isVideo ? 'video' : 'photo'});
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

    // Camera Preview UI
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Preview (Full Screen)
          SizedBox.expand(
             child: CameraPreview(_controller!),
          ),

          // 2. Controls Overlay
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
                      // Spacer / Gallery (Future)
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
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      "Tap to capture • Hold to record",
                      style: TextStyle(color: Colors.white54, fontSize: 12, shadows: [
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
             _isVideo 
               ? Center(child: Icon(Icons.videocam, size: 100, color: Colors.white24)) // Simple placeholder for video preview
               : Image.file(File(_capturedPath!), fit: BoxFit.contain),

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
