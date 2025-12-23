import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/task.dart';
import '../../data/providers.dart';
import '../../utils/haptic_helper.dart';
import '../../utils/snackbar_helper.dart';
import '../theme/app_theme.dart';

class VentingScreen extends ConsumerStatefulWidget {
  const VentingScreen({super.key});

  @override
  ConsumerState<VentingScreen> createState() => _VentingScreenState();
}

class _VentingScreenState extends ConsumerState<VentingScreen> with TickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  
  // Audio
  late AudioRecorder _audioRecorder;
  late AudioPlayer _audioPlayer;
  StreamSubscription<Amplitude>? _amplitudeSub;
  
  // Basic State
  bool _isRecording = false;
  bool _isPreviewMode = false;
  bool _isPlaying = false;
  String? _tempPath;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;
  double _amplitude = 0.0;
  double _smoothedAmplitude = 0.0;
  
  // Gesture & Positioning
  Offset _startPos = Offset.zero;
  double _dragUpOffset = 0.0;
  bool _isCancelled = false;
  
  // Animations
  late AnimationController _liquidController;
  late AnimationController _previewController;
  late AnimationController _introController;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    
    _liquidController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _previewController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _liquidController.dispose();
    _previewController.dispose();
    _introController.dispose();
    _amplitudeSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  // --- Core Logic ---

  Future<void> _startRecording() async {
    if (_isPreviewMode) return; // Ignore if in preview
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        _tempPath = '${directory.path}/venting_temp_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: _tempPath!);
        
        _amplitudeSub = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 40)).listen((amp) {
           if (mounted) {
             setState(() {
               _amplitude = (amp.current + 45).clamp(0, 45) / 45;
               _smoothedAmplitude = _smoothedAmplitude * 0.7 + _amplitude * 0.3;
             });
           }
        });

        _recordDuration = Duration.zero;
        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          setState(() => _recordDuration += const Duration(seconds: 1));
        });
        
        setState(() {
          _isRecording = true;
          _isCancelled = false;
        });
        HapticHelper(ref).mediumImpact();
      }
    } catch (e) {
      debugPrint("Start error: $e");
    }
  }

  Future<void> _stopRecording({required bool triggeredCancel}) async {
    if (!_isRecording) return;
    
    _timer?.cancel();
    _amplitudeSub?.cancel();

    try {
      final path = await _audioRecorder.stop();
      if (triggeredCancel) {
        if (path != null) File(path).delete().ignore();
        HapticHelper(ref).heavyImpact();
      } else {
        // Enter Preview Mode
        setState(() {
          _isPreviewMode = true;
          _dragUpOffset = 0;
        });
        if (mounted) _previewController.forward();
        if (path != null) {
          await _audioPlayer.setFilePath(path);
        }
        HapticHelper(ref).success();
      }
    } catch (e) {
      debugPrint("Stop error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isCancelled = false; // CRITICAL: Reset cancel state
          _dragUpOffset = 0;
          _recordDuration = Duration.zero;
          _smoothedAmplitude = 0;
        });
      }
    }
  }

  Future<void> _saveVenting() async {
    if (_tempPath == null) return;
    
    final title = _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : "大声倾诉";
    final docDir = await getApplicationDocumentsDirectory();
    final permanentPath = '${docDir.path}/venting_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await File(_tempPath!).copy(permanentPath);
    
    final task = Task(
      id: const Uuid().v4(),
      title: title,
      totalDuration: Duration.zero,
      scheduledStart: DateTime.now(),
      subTasks: [],
      isCompleted: true,
      isVenting: true,
      journalAudioPath: permanentPath,
      completedAt: DateTime.now(),
    );

    ref.read(taskListProvider.notifier).addTask(task);
    if (mounted) Navigator.pop(context);
  }

  void _discard() {
    setState(() {
      _isPreviewMode = false;
      _tempPath = null;
      _recordDuration = Duration.zero;
      _smoothedAmplitude = 0;
      _titleController.clear();
    });
    _previewController.reverse();
    _audioPlayer.stop();
  }

  String _formatDuration(Duration d) {
    return "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryBlue;
    final accent = AppTheme.accentPurple;
    final cancelColor = const Color(0xFFFB7185).withOpacity(0.8);
    
    // Adaptive Colors
    final bgColor = isDark ? Colors.black : const Color(0xFFFBFBFF);
    final mainTextColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF64748B);
    final glassColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);
    final glassBorder = isDark ? Colors.white10 : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Visuals
          _buildLiquidBackground(primary, accent, cancelColor, isDark),
          
          SafeArea(
            child: Column(
              children: [
                _buildHeader(mainTextColor),
                const Spacer(),
                
                // Central Liquid Orb
                _buildLiquidOrb(primary, accent, cancelColor, isDark),
                
                const Spacer(),
                
                // Content area switching between Recording and Preview
                if (_isPreviewMode) _buildPreviewPlayer(isDark, primary)
                else if (_isRecording) _buildRecordingStatus(mainTextColor, secondaryTextColor)
                else _buildIdleStatus(secondaryTextColor),
                
                const SizedBox(height: 180),
              ],
            ),
          ),
          
          // 2. Control Layout
          _buildControls(primary, accent, isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: textColor.withOpacity(0.3), size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _titleController,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.w300, 
                  color: textColor,
                  letterSpacing: 0.5,
                ),
                decoration: InputDecoration(
                  hintText: "TITLE (OPTIONAL)",
                  hintStyle: TextStyle(color: textColor.withOpacity(0.12), fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.bold),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48), // Balance for the close button
        ],
      ),
    );
  }

  Widget _buildLiquidBackground(Color primary, Color accent, Color cancel, bool isDark) {
    return AnimatedBuilder(
      animation: _liquidController,
      builder: (context, child) {
        final t = _liquidController.value * 2 * pi;
        final opacity = isDark ? 0.12 : 0.08;
        return Stack(
          children: [
            Positioned(top: -100 + (sin(t) * 40), left: -100 + (cos(t) * 40), child: _buildGlow(primary.withOpacity(opacity), 450)),
            Positioned(bottom: -150 + (cos(t * 0.8) * 50), right: -100 + (sin(t * 1.2) * 30), child: _buildGlow(accent.withOpacity(opacity - 0.02), 500)),
            if (_isRecording || _isPreviewMode)
               Center(child: _buildGlow((_isCancelled ? cancel : primary).withOpacity(isDark ? 0.08 : 0.05), 350 + (_isPreviewMode ? 0 : _smoothedAmplitude * 200))),
          ],
        );
      },
    );
  }

  Widget _buildGlow(Color color, double size) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, Colors.transparent])));
  }


  Widget _buildLiquidOrb(Color primary, Color accent, Color cancel, bool isDark) {
    final double baseSize = 255.0; // Slightly larger for better filler
    // Slow drift when previewing, reactive when recording
    final double scale = _isPreviewMode ? 1.05 : (_isRecording ? (1.0 + _smoothedAmplitude * 0.45) : 1.0);
    
    return Center(
      child: AnimatedBuilder(
        animation: _liquidController,
        builder: (context, child) {
          final t = _liquidController.value * 2 * pi;
          return Stack(
            alignment: Alignment.center,
            children: [
              _buildBlob(primary.withOpacity(isDark ? 0.5 : 0.35), baseSize * 0.8 * scale, t, 0),
              _buildBlob(accent.withOpacity(isDark ? 0.4 : 0.3), baseSize * 0.9 * scale, t, 1),
              _buildBlob((_isCancelled ? cancel : primary).withOpacity(isDark ? 0.2 : 0.15), baseSize * 1.1 * scale, t, 2),
              
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: isDark ? 50 : 40, sigmaY: isDark ? 50 : 40),
                  child: Container(width: baseSize * 1.5, height: baseSize * 1.5, color: Colors.transparent),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBlob(Color color, double size, double time, int seed) {
    final double offset = 25 * sin(time + seed);
    final double sX = 1.0 + 0.12 * cos(time * 0.9 + seed);
    final double sY = 1.0 + 0.12 * sin(time * 1.1 + seed);
    return Transform.translate(
      offset: Offset(offset, offset * (seed.isEven ? 1 : -1)),
      child: Transform.scale(scaleX: sX, scaleY: sY, child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color))),
    );
  }

  Widget _buildRecordingStatus(Color mainTextColor, Color secondaryTextColor) {
    return Column(
      children: [
        Text(_formatDuration(_recordDuration), style: TextStyle(fontSize: 54, fontWeight: FontWeight.w200, color: mainTextColor, letterSpacing: -2)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Icon(Icons.keyboard_arrow_up_rounded, color: _isCancelled ? const Color(0xFFFB7185) : secondaryTextColor.withOpacity(0.5), size: 20),
             const SizedBox(width: 4),
             Text(_isCancelled ? "DROP TO DELETE" : "SLIDE UP TO CANCEL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: _isCancelled ? const Color(0xFFFB7185) : secondaryTextColor.withOpacity(0.5))),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewPlayer(bool isDark, Color primary) {
    final bgColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04);
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final iconColor = isDark ? Colors.white : Colors.black54;

    return FadeTransition(
      opacity: _previewController,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 50),
        child: Column(
          children: [
             Text("PREVIEWING VOICE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 3, color: primary.withOpacity(0.7))),
             const SizedBox(height: 15),
             ClipRRect(
               borderRadius: BorderRadius.circular(30),
               child: BackdropFilter(
                 filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                   decoration: BoxDecoration(
                     color: bgColor, 
                     borderRadius: BorderRadius.circular(30), 
                     border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                   ),
                   child: Row(
                     children: [
                        IconButton(
                          icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: iconColor),
                          onPressed: () {
                             if (_isPlaying) _audioPlayer.pause(); else _audioPlayer.play();
                          },
                        ),
                        Expanded(child: Text("Voice Note - ${_formatDuration(_recordDuration)}", style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                        const SizedBox(width: 40),
                     ],
                   ),
                 ),
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdleStatus(Color textColor) {
    return FadeTransition(opacity: _introController, child: Text("HOLD TO START VENTING", style: TextStyle(letterSpacing: 3, fontSize: 10, fontWeight: FontWeight.w900, color: textColor.withOpacity(0.2))));
  }

  Widget _buildControls(Color primary, Color accent, bool isDark) {
    return Positioned(
      bottom: 80, left: 0, right: 0,
      child: Center(
        child: _isPreviewMode ? _buildPreviewActions(primary, isDark) : _buildMicButtonListener(primary, isDark),
      ),
    );
  }

  Widget _buildMicButtonListener(Color primary, bool isDark) {
    final double size = _isRecording ? 105 : 85;
    final micColor = isDark ? Colors.white : Colors.black87;
    final buttonBg = isDark 
        ? Colors.white.withOpacity(_isRecording ? 0.2 : 0.05) 
        : Colors.black.withOpacity(_isRecording ? 0.08 : 0.03);

    return Listener(
      onPointerDown: (e) { _startPos = e.position; _startRecording(); },
      onPointerMove: (e) {
        if (!_isRecording) return;
        setState(() {
          _dragUpOffset = (e.position.dy - _startPos.dy).clamp(-200.0, 0.0);
          _isCancelled = _dragUpOffset < -110;
        });
      },
      onPointerUp: (e) => _stopRecording(triggeredCancel: _isCancelled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: buttonBg,
          border: Border.all(color: _isCancelled ? const Color(0xFFFB7185).withOpacity(0.5) : (isDark ? Colors.white10 : Colors.black.withOpacity(0.1)), width: 2),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic_rounded, color: _isRecording ? micColor : micColor.withOpacity(0.35), size: 36),
              if (_isRecording) Container(margin: const EdgeInsets.only(top: 2), width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFFFB7185), shape: BoxShape.circle)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewActions(Color primary, bool isDark) {
    final secondaryColor = isDark ? Colors.white24 : Colors.black.withOpacity(0.12);
    final secondaryTextColor = isDark ? Colors.white24 : Colors.black38;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(Icons.delete_outline_rounded, "Discard", secondaryColor, secondaryTextColor, _discard),
        const SizedBox(width: 30),
        _buildActionButton(Icons.check_rounded, "Save", primary, primary, _saveVenting, isPrimary: true, isDark: isDark),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, Color textColor, VoidCallback onTap, {bool isPrimary = false, bool isDark = true}) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle, 
              color: isPrimary ? color : Colors.transparent, 
              border: isPrimary ? null : Border.all(color: color, width: 2)
            ),
            child: Icon(icon, color: isPrimary ? (isDark ? Colors.black : Colors.white) : color, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: textColor)),
      ],
    );
  }
}

extension on HapticHelper {
  void success() { try { selectionClick(); mediumImpact(); } catch(_) {} }
}
