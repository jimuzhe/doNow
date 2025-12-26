import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../../data/providers/ai_providers.dart';
import '../../data/services/voice_ai_service.dart';
import '../../utils/haptic_helper.dart';
import '../theme/app_theme.dart';
import '../../data/models/task.dart';
import '../../data/providers/task_providers.dart';
import '../../core/utils/audio_util.dart';
import '../../data/services/focus_audio_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../data/localization.dart';
import '../../ui/widgets/responsive_center.dart';

enum VentingMode { 
  realtime,  // 实时通话模式 - AI陪伴
  voiceInput // 语音输入模式 - 录音转文字
}

class VentingScreen extends ConsumerStatefulWidget {
  final VentingMode initialMode;
  
  const VentingScreen({super.key, this.initialMode = VentingMode.voiceInput});

  @override
  ConsumerState<VentingScreen> createState() => _VentingScreenState();
}

class _VentingScreenState extends ConsumerState<VentingScreen> with TickerProviderStateMixin {
  // Mode
  late VentingMode _currentMode;
  
  // AI & Audio
  AudioRecorder? _audioRecorder;
  late AudioPlayer _audioPlayer;
  late VoiceAIService _voiceService;

  // Subscriptions & Connections
  StreamSubscription? _micStreamSub;
  StreamSubscription? _voiceStateSub;
  StreamSubscription? _textSub;
  StreamSubscription? _audioSub;
  StreamSubscription? _sttSub;
  StreamSubscription? _activationSub;
  StreamSubscription? _ttsSub;
  StreamSubscription? _eventSub;
  
  // Reconnection state
  int _reconnectAttempts = 0;
  bool _isReconnecting = false; // TTS state subscription
  
  // State
  bool _isConnected = false;
  bool _isMicOn = false;
  bool _isRecording = false;
  bool _listeningStarted = false; // Track if startListening has been called
  bool _showTranscript = false;
  String _aiResponseText = "";
  String _userTranscript = "";
  Duration _recordDuration = Duration.zero;
  Timer? _timer;
  double _smoothedAmplitude = 0.0;
  bool _isAnalyzing = false;
  String _aphorisms = "";

  // Realtime TTS playback (streaming)
  LiveStreamAudioSource? _liveTtsSource;
  bool _isTtsSpeaking = false;

  // Background audio ducking while TTS speaks
  double? _focusVolumeBeforeTts;
  static const double _focusDuckRatio = 0.3;

  Future<void> _restartAutoListeningIfNeeded() async {
    if (!mounted) return;
    if (_currentMode != VentingMode.realtime) return;
    if (!_isMicOn) return;

    // Only restart when service is ready; otherwise connect and wait briefly.
    if (_voiceService.state != VoiceState.ready) {
      await _voiceService.connect();
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (_voiceService.state != VoiceState.ready) return;

    _voiceService.clearAudioBuffer();
    await _voiceService.startListening(mode: 'auto');
  }
  
  // Voice input mode: buffer audio locally, send all at once when done
  List<Uint8List> _voiceInputBuffer = [];
  String? _lastAudioPath;  // Store audio path for saving to timeline later
  String _encouragement = "";  // Farewell message shown when user confirms
  
  // Gesture (for voice input mode)
  Offset _startPos = Offset.zero;
  double _dragOffset = 0.0; // Positive = down, Negative = up
  bool _isTextInputMode = false; // Down swipe triggers text input
  
  // Text input mode
  final TextEditingController _textController = TextEditingController();
  bool _showTextInput = false;
  bool _isCancelled = false;
  bool _showEncouragement = false;  // Show farewell encouragement before exit
  bool _showConfirmButton = false;  // Show confirm button after typewriter completes
  
  // Animations
  late AnimationController _liquidController;
  late AnimationController _introController;
  late AnimationController _transcriptController;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    // Initialize recorder only if starting in voice input mode
    if (widget.initialMode == VentingMode.voiceInput) {
      _audioRecorder = AudioRecorder();
    }
    _audioPlayer = AudioPlayer();
    
    // Configure AudioSession for Speaker output
    // NOTE: Don't configure AudioSession here for iOS compatibility.
    // AudioUtil will handle session configuration globally when needed.
    // This prevents conflicting session configurations between VentingScreen and AudioUtil.

    // Audio player will be used to play buffered TTS audio
    // No need for live streaming - we buffer and play when TTS stops
    _voiceService = ref.read(voiceAIServiceProvider);
    
    _liquidController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _transcriptController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Listen to voice AI state changes
    _voiceStateSub = _voiceService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isConnected = state == VoiceState.connecting || 
                        state == VoiceState.ready || 
                        state == VoiceState.listening || 
                        state == VoiceState.processing ||
                        state == VoiceState.speaking;
        });
        
        // Handle connection failure - show error to user
        if (state == VoiceState.idle || state == VoiceState.error) {
          if (_isRecording || (_currentMode == VentingMode.voiceInput && _showTranscript && _userTranscript == "正在识别...")) {
            setState(() {
              _userTranscript = "连接失败，请重试";
              _showTranscript = true;
              _transcriptController.forward();
            });
          }
        }
      }
    });

    // Listen to AI TTS text responses
    _textSub = _voiceService.textStream.listen((text) {
      if (mounted) setState(() => _aiResponseText = text);
    });

    // Listen to STT transcription results (user's speech to text)
    // In sttOnlyMode, XiaozhiService auto-sends abort, but we still call it here for safety
    _sttSub = _voiceService.sttStream.listen((transcript) {
      print('STT result received in UI: $transcript');
      if (mounted && transcript.isNotEmpty) {
        setState(() {
          _userTranscript = transcript;
          // In voice input mode, show transcript after recording finishes
          if (_currentMode == VentingMode.voiceInput) {
            _showTranscript = true;
            _transcriptController.forward();
          }
        });
      }
    });

    // Stream TTS audio data (play as it arrives)
    // Note: audioStream not available in new architecture, handled internally
    // _audioSub = _voiceService.audioStream.listen((pcmData) {
    //   if (!mounted || _currentMode != VentingMode.realtime) return;

      if (!_isTtsSpeaking) {
        _isTtsSpeaking = true;
      }

      // Start streaming playback lazily on first audio chunk
      if (_liveTtsSource == null) {
        unawaited(_startLiveTtsPlayback());
      }

    //   _liveTtsSource?.addAudio(pcmData);

    //   // Visual feedback
    //   setState(() {
    //     _smoothedAmplitude = 0.7;
    //   });
    // });
    
    // Listen for TTS state changes to start/stop live playback
    _ttsSub = _voiceService.ttsStateStream.listen((state) {
      if (mounted && _currentMode == VentingMode.realtime) {
        if (state == 'start') {
          _isTtsSpeaking = true;
          unawaited(_startLiveTtsPlayback());
          print('[TTS] Started');
        } else if (state == 'stop') {
          _isTtsSpeaking = false;
          unawaited(_stopLiveTtsPlayback());

          // In "auto" VAD mode, keep the conversation flowing by re-entering listening
          // after the AI finishes speaking.
          unawaited(Future.delayed(
            const Duration(milliseconds: 200),
            _restartAutoListeningIfNeeded,
          ));
        }
      }
    });

    _activationSub = _voiceService.activationStream.listen((result) {
      if (!result.isActivated && mounted) {
        _showActivationDialog(result.activationCode ?? '', result.message);
      }
    });

    // Listen to low-level events for auto-reconnection
    _eventSub = _voiceService.eventStream.listen((event) async {
      if (!mounted) return;
      
      if (event.type == XiaozhiEventType.connected) {
        // Reset retry count on successful connection
        _reconnectAttempts = 0;
        if (_isReconnecting) {
          setState(() => _isReconnecting = false);
          
          // Silent resume: if in realtime mode, auto-resume mic if needed
          if (_currentMode == VentingMode.realtime && !_isMicOn) {
             _toggleMic();
          }
        }
      } else if (event.type == XiaozhiEventType.disconnected) {
        // Seamless Auto-Reconnect:
        // Try to reconnect silently without disturbing the user.
        // Only show error if max retries reached.
        
        if ((_currentMode == VentingMode.realtime || _isRecording || _isAnalyzing) && _reconnectAttempts < 5) {
           // Set state but don't show visible UI overlay
           if (!_isReconnecting) setState(() => _isReconnecting = true);
           
           _reconnectAttempts++;
           debugPrint("[Silent Reconnect] Attempt $_reconnectAttempts/5...");
           
           // Fast retry
           await Future.delayed(const Duration(milliseconds: 1000));
           if (mounted) {
             _voiceService.connect();
           }
        } else if (_reconnectAttempts >= 5) {
           // Max retries reached -> Only THEN show user feedback
           debugPrint("Max reconnection attempts reached.");
           setState(() => _isReconnecting = false);
           
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
                 content: const Text("网络连接不稳定，请检查重试"),
                 action: SnackBarAction(label: '重试', onPressed: () {
                    _reconnectAttempts = 0;
                    _voiceService.connect();
                 }),
                 duration: const Duration(seconds: 4),
             ),
           );
           
           // Reset state
           if (_isRecording) {
              _stopVoiceInputRecording(cancelled: true);
           }
           _reconnectAttempts = 0;
        }
      }
    });

    // Pre-connect when entering the page for faster response when user starts recording
    _preConnect();
    
    // Mark as Busy UI (prevents auto-navigation to other tasks)
    Future.microtask(() => ref.read(isBusyUIProvider.notifier).state = true);
  }

  /// Pre-connect to voice service for faster response
  Future<void> _preConnect() async {
    print('Pre-connecting to voice service...');
    
    // In voiceInput mode, only use STT (no AI voice response)
    if (_currentMode == VentingMode.voiceInput) {
      _voiceService.setSttOnlyMode(true);
    } else {
      _voiceService.setSttOnlyMode(false);
    }
    
    await _voiceService.connect();
    if (mounted && _voiceService.state == VoiceState.ready) {
      print('Pre-connection successful, ready for recording');
    }
  }
  
  Future<void> _startLiveTtsPlayback() async {
    if (!mounted || _currentMode != VentingMode.realtime) return;

    // If a previous stream is still active, stop it first.
    await _stopLiveTtsPlayback();

    _duckBackgroundAudioForTts();

    try {
      _liveTtsSource = LiveStreamAudioSource();
      await _audioPlayer.setAudioSource(_liveTtsSource!);
      await _audioPlayer.play();
    } catch (e) {
      print('[TTS Live] Start error: $e');
      await _stopLiveTtsPlayback();
    }
  }

  Future<void> _stopLiveTtsPlayback() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.stop();
      }
    } catch (_) {
      // ignore
    }

    _restoreBackgroundAudioAfterTts();

    final src = _liveTtsSource;
    _liveTtsSource = null;
    if (src != null) {
      try {
        await src.dispose();
      } catch (e) {
        print('[TTS Live] Dispose error: $e');
      }
    }
  }

  void _duckBackgroundAudioForTts() {
    if (_focusVolumeBeforeTts != null) return; // already ducked
    try {
      final focusService = ref.read(focusAudioServiceProvider);
      final current = focusService.currentVolume;
      _focusVolumeBeforeTts = current;
      final ducked = (current * _focusDuckRatio).clamp(0.0, 1.0);
      focusService.setVolume(ducked);
    } catch (e) {
      print('[TTS Duck] Failed to duck focus audio: $e');
      _focusVolumeBeforeTts = null;
    }
  }

  void _restoreBackgroundAudioAfterTts() {
    final prev = _focusVolumeBeforeTts;
    _focusVolumeBeforeTts = null;
    if (prev == null) return;
    try {
      ref.read(focusAudioServiceProvider).setVolume(prev);
    } catch (e) {
      print('[TTS Duck] Failed to restore focus audio: $e');
    }
  }

  Future<void> _checkActivation() async {
    final result = await _voiceService.checkOtaActivation();
    if (!result.isActivated && mounted) {
      _showActivationDialog(result.activationCode ?? '', result.message);
    } else if (result.isActivated && mounted) {
      // Successfully activated! Auto-reconnect and start the service
      setState(() => _isConnected = true);
      
      // If in realtime mode, auto-start mic
      if (_currentMode == VentingMode.realtime) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isMicOn) {
            _toggleMic();
          }
        });
      }
      
      // Show success feedback
      HapticHelper(ref).success();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('激活成功！'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _resetAndRecheck() async {
    await _voiceService.resetDevice();
    await _checkActivation();
  }

  @override
  void dispose() {
    try {
      // Reset Busy UI logic
      ref.read(isBusyUIProvider.notifier).state = false;
    } catch (_) {}
    
    _textController.dispose();
    _audioRecorder?.dispose();
    _audioPlayer.dispose();
    _liquidController.dispose();
    _introController.dispose();
    _transcriptController.dispose();
    _micStreamSub?.cancel();
    _voiceStateSub?.cancel();
    _textSub?.cancel();
    _audioSub?.cancel();
    _sttSub?.cancel();
    _activationSub?.cancel();
    _ttsSub?.cancel();
    _eventSub?.cancel();
    _timer?.cancel();
    _voiceService.disconnect();
    // Best-effort stop of any ongoing TTS stream playback.
    unawaited(_stopLiveTtsPlayback());
    super.dispose();
  }

  // ==================== UI BUILD ====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryBlue;
    final accent = AppTheme.accentPurple;
    final cancelColor = const Color(0xFFFB7185);
    
    final locale = ref.watch(localeProvider);
    String t(String key) => AppStrings.get(key, locale);
    
    final bgColor = isDark ? Colors.black : const Color(0xFFFBFBFF);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true, // Allow keyboard to push content up
      body: _showEncouragement 
        ? _buildEncouragementOverlay(isDark, textColor)
        : Stack(
        fit: StackFit.expand,
        children: [
          // Background
          _buildLiquidBackground(primary, accent, cancelColor, isDark),
          
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                ),
                child: ResponsiveCenter(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                    // Top section
                    Column(
                      children: [
                        _buildHeader(textColor, secondaryTextColor, t),
                        const SizedBox(height: 40),
                        // Center content - switches based on mode and state
                        _buildCenterContent(primary, accent, cancelColor, isDark, textColor, t),
                      ],
                    ),
                    
                    // Bottom section
                    Column(
                      children: [
                        // Status text
                        _buildStatusArea(textColor, secondaryTextColor, t),
                        
                        const SizedBox(height: 30),
                        
                        // Controls - different for each mode
                        // 当显示金句时隐藏麦克风按钮，因为金句区域已经有重录选项
                        if (_currentMode == VentingMode.realtime)
                          _buildRealtimeControls(primary, isDark)
                        else if (_showTextInput)
                          // Text input mode (triggered by down swipe)
                          _buildTextInputArea(primary, isDark, textColor)
                        else if (!_showTranscript)
                          // Voice input mode (default) - 隐藏当金句界面显示时
                          _buildVoiceInputControls(primary, isDark),
                        
                        const SizedBox(height: 80), // Bottom padding to avoid phone's one-hand mode
                      ],
                    ),
                  ],
                ),
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color secondaryColor, String Function(String) t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Close button
          IconButton(
            icon: Icon(Icons.close_rounded, color: textColor.withOpacity(0.4), size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          
          const Spacer(),
          
          // Title (only show in voiceInput mode)
          if (_currentMode == VentingMode.voiceInput)
            Text(
              t('venting'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor.withOpacity(0.6),
              ),
            ),
          
          const Spacer(),
          
          // Companion mode button (only in voiceInput mode)
          if (_currentMode == VentingMode.voiceInput)
            GestureDetector(
              onTap: () => _switchMode(VentingMode.realtime),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone_in_talk_rounded, size: 16, color: AppTheme.primaryBlue),
                    const SizedBox(width: 6),
                    Text(
                      t('companion'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // In realtime mode, show back arrow to return to voiceInput
            const SizedBox(width: 48),
        ],
      ),
    );
  }


  Widget _buildCenterContent(Color primary, Color accent, Color cancel, bool isDark, Color textColor, String Function(String) t) {
    // 1. Analyzing state (Thinking) - Priority
    if (_isAnalyzing) {
      return _buildSpinningOrb(primary, accent, isDark, t);
    }

    // 2. STT Processing state
    final identifyingStr = t('identifying');
    if (_currentMode == VentingMode.voiceInput && _userTranscript == identifyingStr) {
      return _buildSpinningOrb(primary, accent, isDark, t);
    }
    
    // 3. Result state - show transcript/aphorisms
    if (_currentMode == VentingMode.voiceInput && _showTranscript && _userTranscript.isNotEmpty) {
      // Logic to hide user's raw transcript (requested by user)
      // Only show result if:
      // A. Aphorisms have been generated (Analysis complete)
      // B. It is an error message (failure/retry)
      // Otherwise (Raw user text), show "Thinking" orb.
      
      bool hasAphorisms = _aphorisms.isNotEmpty;
      // Simple heuristic for error messages based on AppStrings
      bool isError = _userTranscript.contains("失败") || 
                     _userTranscript.contains("Failed") || 
                     _userTranscript.contains("retry") ||
                     _userTranscript.contains("重试");
                     
      if (hasAphorisms || isError) {
        return _buildTranscriptResult(textColor, isDark, t);
      } else {
        // Hide user text -> Show Thinking Orb similar to analyzing state
        return _buildSpinningOrb(primary, accent, isDark, t);
      }
    }
    
    
    // 4. Default - show liquid orb (Recording or Idle)
    return _buildLiquidOrb(primary, accent, cancel, isDark);
  }



  /// Processing state animation - reuses liquid orb with breathing effect
  Widget _buildSpinningOrb(Color primary, Color accent, bool isDark, String Function(String) t) {
    final locale = ref.watch(localeProvider);
    // We just reuse the liquid orb but pass isProcessing=true
    return AnimatedBuilder(
      animation: _liquidController,
      builder: (context, child) {
        final tAnim = _liquidController.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLiquidOrb(primary, accent, Colors.transparent, isDark, isProcessing: true),
            const SizedBox(height: 32),
            // Animated text
            SizedBox(
              width: 200,
              child: Text(
                "${t('thinking')}${'.' * ((tAnim * 3).toInt() % 4)}",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTranscriptResult(Color textColor, bool isDark, String Function(String) t) {
    return FadeTransition(
      opacity: _transcriptController,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Result card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withOpacity(0.06) 
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Column(
              children: [
                // Quote decoration
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryBlue.withOpacity(0),
                            AppTheme.primaryBlue.withOpacity(0.5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.format_quote_rounded,
                      color: AppTheme.primaryBlue.withOpacity(0.4),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 32,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryBlue.withOpacity(0.5),
                            AppTheme.primaryBlue.withOpacity(0),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Content Switch: Transcript OR Aphorisms
                if (_aphorisms.isEmpty)
                  // Show User Transcript
                  Text(
                    _userTranscript,
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.6,
                      color: textColor,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  // Show Aphorisms with Typewriter effect
                  _TypewriterText(
                    text: _aphorisms,
                    style: TextStyle(
                      fontSize: 18,
                      height: 2.0, // Increase line height for cleaner look
                      color: textColor.withOpacity(0.9),
                      fontWeight: FontWeight.w400, // Use normal weight instead of w500
                      // fontStyle: FontStyle.italic, // REMOVED: Italic looks messy for Chinese
                      letterSpacing: 0.5, // Slight spacing for elegance
                    ),
                    textAlign: TextAlign.start, // Left align to avoid jagged edges
                    duration: const Duration(milliseconds: 50),
                    onComplete: () {
                      if (mounted && !_showConfirmButton) {
                        setState(() => _showConfirmButton = true);
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Action buttons - Show with glow effect after typewriter completes
          if (_aphorisms.isNotEmpty && _showConfirmButton)
            // Finish Button - SAVE TO TIMELINE when user confirms
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                onTap: () async {
                  HapticHelper(ref).mediumImpact();
                  final locale = ref.read(localeProvider);
                  
                  // Save to timeline
                  final now = DateTime.now();
                  final task = Task(
                    id: const Uuid().v4(),
                    title: AppStrings.get('venting', locale),
                    totalDuration: Duration.zero,
                    scheduledStart: now,
                    subTasks: [],
                    isVenting: true,
                    isCompleted: true,
                    completedAt: now,
                    journalAudioPath: _lastAudioPath,
                    journalNote: "$_userTranscript\n\n$_aphorisms",
                  );
                  
                  ref.read(taskListProvider.notifier).addTask(task);
                  
                  setState(() => _showEncouragement = true);
                  
                  // Delay to show encouragement, then close automatically (if user hasn't already manually exited)
                  await Future.delayed(const Duration(seconds: 4));
                  if (mounted && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      // Soft white glow
                      BoxShadow(
                        color: Colors.white.withOpacity(0.6),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                      // Outer glow
                      BoxShadow(
                        color: Colors.white.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                      // Soft shadow for depth
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    AppStrings.get('i_know_what_to_do', ref.read(localeProvider)),
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            
          const SizedBox(height: 16),
          
          // Re-record Button (Secondary)
          if (_aphorisms.isEmpty)
             _buildRerecordButton(isDark, textColor, t),
          
          // If aphorisms exist, allow re-record as secondary option below finish
          if (_aphorisms.isNotEmpty)
             Padding(
               padding: const EdgeInsets.only(top: 8),
               child: GestureDetector(
                 onTap: () {
                    HapticHelper(ref).mediumImpact();
                    // 主动发起连接，为下次录音预热
                    _voiceService.connect();
                    setState(() {
                      _showTranscript = false;
                      _userTranscript = "";
                      _aphorisms = "";
                      _showConfirmButton = false;
                      _isConnected = true; 
                    });
                    _transcriptController.reverse();
                 },
                 child: Text(
                   AppStrings.get('rerecord', ref.read(localeProvider)),
                   style: TextStyle(
                     color: isDark ? Colors.white54 : Colors.black45,
                     fontSize: 14,
                   ),
                 ),
               ),
             ),
        ],
      ),
    );
  }

  Widget _buildRerecordButton(bool isDark, Color textColor, String Function(String) t) {
    final locale = ref.watch(localeProvider);
    return GestureDetector(
      onTap: () {
        HapticHelper(ref).selectionClick();
        // 主动发起连接，为下次录音预热
        _voiceService.connect();
        setState(() {
          _showTranscript = false;
          _userTranscript = "";
          _showConfirmButton = false;
          _isConnected = true; // 正在连接或已连接
          _voiceInputBuffer.clear(); // Clear local buffer on re-record
          _aphorisms = ""; // 清除之前的格言
        });
        _transcriptController.reverse();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.refresh_rounded,
              size: 20,
              color: isDark ? Colors.white60 : Colors.black45,
            ),
            const SizedBox(width: 8),
            Text(
              t("rerecord"),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusArea(Color textColor, Color secondaryColor, String Function(String) t) {
    if (_currentMode == VentingMode.realtime) {
      // Realtime mode status
      if (_aiResponseText.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            _aiResponseText,
            style: TextStyle(fontSize: 16, color: textColor, height: 1.5),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }
      return Text(
        _isConnected 
            ? (_isMicOn ? t("listening") : t("tap_mic_to_start_chat")) 
            : t("connecting"),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 2,
          fontWeight: FontWeight.w500,
          color: secondaryColor.withOpacity(0.5),
        ),
      );
    } else {
      // Voice input mode status
      if (_isRecording) {
        // Determine current gesture state
        final bool isUpSwipe = _dragOffset < -80; // Cancel
        final bool isDownSwipe = _dragOffset > 80; // Text input
        
        return Column(
          children: [
            Text(
              _formatDuration(_recordDuration),
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.w200, color: textColor),
            ),
            const SizedBox(height: 8),
            // Show gesture hints
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Up swipe hint (cancel)
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: isUpSwipe ? const Color(0xFFFB7185) : secondaryColor.withOpacity(0.3),
                  size: 18,
                ),
                Text(
                  isUpSwipe ? t("release_to_cancel") : t("swipe_up_to_cancel"),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w500,
                    color: isUpSwipe ? const Color(0xFFFB7185) : secondaryColor.withOpacity(0.3),
                  ),
                ),
                const SizedBox(width: 20),
                // Down swipe hint (text input)
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDownSwipe ? AppTheme.primaryBlue : secondaryColor.withOpacity(0.3),
                  size: 18,
                ),
                Text(
                  isDownSwipe ? t("release_to_input") : t("swipe_down_to_type"),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w500,
                    color: isDownSwipe ? AppTheme.primaryBlue : secondaryColor.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ],
        );
      }
      // Default state - show hint based on mode
      if (_showTextInput) {
        return Text(
          t("input_text_to_send"),
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.w500,
            color: AppTheme.primaryBlue.withOpacity(0.6),
          ),
        );
      }
      
      // 如果正在显示金句结果界面，不显示提示文字
      if (_showTranscript) {
        return const SizedBox.shrink();
      }

      return Text(
        t("hold_to_speak"),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 2,
          fontWeight: FontWeight.w500,
          color: secondaryColor.withOpacity(0.4),
        ),
      );
    }
  }

  // ==================== REALTIME MODE CONTROLS ====================

  Widget _buildRealtimeControls(Color primary, bool isDark) {
    final buttonBg = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04);
    final iconColor = isDark ? Colors.white : Colors.black87;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Mic toggle button
        GestureDetector(
          onTap: _toggleMic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isMicOn ? primary : buttonBg,
              border: Border.all(
                color: _isMicOn ? primary : (isDark ? Colors.white10 : Colors.black12),
                width: 2,
              ),
            ),
            child: Icon(
              _isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded,
              color: _isMicOn ? Colors.white : iconColor.withOpacity(0.5),
              size: 28,
            ),
          ),
        ),
        
        const SizedBox(width: 40),
        
        // Hang up button - returns to voiceInput mode
        GestureDetector(
          onTap: _hangUp,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFB7185),
            ),
            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  // ==================== VOICE INPUT MODE CONTROLS ====================

  Widget _buildVoiceInputControls(Color primary, bool isDark) {
    final double size = _isRecording ? 100 : 80;
    final buttonBg = isDark 
        ? Colors.white.withOpacity(_isRecording ? 0.15 : 0.08)
        : Colors.black.withOpacity(_isRecording ? 0.08 : 0.04);
    final iconColor = isDark ? Colors.white : Colors.black87;

    return Listener(
      onPointerDown: (e) {
        // If coming from a previous result, reset first
        if (_showTranscript) {
          _voiceService.abort(); // Use abort instead of disconnect
          setState(() {
            _showTranscript = false;
            _userTranscript = "";
            // Don't reset _isConnected - connection is still alive
          });
          _transcriptController.reverse();
        }
        
        _startPos = e.position;
        _startVoiceInputRecording();
      },
      onPointerMove: (e) {
        if (!_isRecording) return;
        setState(() {
          // Track both up and down movement
          _dragOffset = (e.position.dy - _startPos.dy).clamp(-200.0, 200.0);
          _isCancelled = _dragOffset < -80; // Up swipe = cancel
          _isTextInputMode = _dragOffset > 80; // Down swipe = text input
        });
      },
      onPointerUp: (e) {
        if (_isTextInputMode) {
          // Down swipe: cancel recording and show text input
          _stopVoiceInputRecording(cancelled: true);
          HapticHelper(ref).mediumImpact();
          setState(() {
            _showTextInput = true;
            _isTextInputMode = false;
            _dragOffset = 0;
          });
        } else {
          // Normal release or up swipe cancel
          _stopVoiceInputRecording(cancelled: _isCancelled);
          setState(() {
            _dragOffset = 0;
            _isTextInputMode = false;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: buttonBg,
          border: Border.all(
            color: _isCancelled 
                ? const Color(0xFFFB7185).withOpacity(0.5) // Red for cancel
                : _isTextInputMode
                    ? AppTheme.primaryBlue.withOpacity(0.5) // Blue for text input
                    : (isDark ? Colors.white10 : Colors.black12),
            width: 2,
          ),
          boxShadow: _isRecording ? [
            BoxShadow(
              color: _isCancelled 
                  ? const Color(0xFFFB7185).withOpacity(0.3)
                  : _isTextInputMode
                      ? AppTheme.primaryBlue.withOpacity(0.3)
                      : primary.withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isTextInputMode 
                  ? Icons.keyboard_rounded  // Show keyboard when swiping down
                  : _isCancelled 
                      ? Icons.close_rounded  // Show X when swiping up to cancel
                      : Icons.mic_rounded,   // Default mic icon
              color: _isRecording 
                  ? (_isTextInputMode 
                      ? AppTheme.primaryBlue 
                      : _isCancelled 
                          ? const Color(0xFFFB7185) 
                          : iconColor)
                  : iconColor.withOpacity(0.4),
              size: 32,
            ),
            if (_isRecording && !_isCancelled && !_isTextInputMode)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFFFB7185),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== TEXT INPUT AREA ====================

  Widget _buildTextInputArea(Color primary, bool isDark, Color textColor) {
    final buttonBg = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04);
    final iconColor = isDark ? Colors.white : Colors.black87;
    
    // Only show when text input mode is active (triggered by down swipe)
    if (!_showTextInput) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedOpacity(
        opacity: _showTextInput ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: buttonBg,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              // Close button (switch back to voice)
              GestureDetector(
                onTap: () {
                  HapticHelper(ref).selectionClick();
                  setState(() => _showTextInput = false);
                  _textController.clear();
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: Icon(Icons.mic_rounded, size: 22, color: iconColor.withOpacity(0.6)),
                ),
              ),
              // Text input
              Expanded(
                child: TextField(
                  controller: _textController,
                  autofocus: true, // Auto focus when shown
                  style: TextStyle(color: textColor, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: "输入文字...",
                    hintStyle: TextStyle(color: iconColor.withOpacity(0.3)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendTextMessage(),
                ),
              ),
              // Send button
              GestureDetector(
                onTap: _sendTextMessage,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Send text message to server
  Future<void> _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    HapticHelper(ref).mediumImpact();
    
    // Clear input immediately for better UX
    _textController.clear();
    setState(() => _showTextInput = false);
    
    // Show processing state
    setState(() {
      _userTranscript = text;
      _showTranscript = true;
      _transcriptController.forward();
    });
    
    // Send to server
    try {
      await _voiceService.sendTextMessage(text);
    } catch (e) {
      print('Error sending text message: $e');
      if (mounted) {
        setState(() => _userTranscript = "发送失败: $e");
      }
    }
  }

  // ==================== LIQUID ORB ====================

  Widget _buildLiquidBackground(Color primary, Color accent, Color cancel, bool isDark) {
    return AnimatedBuilder(
      animation: _liquidController,
      builder: (context, child) {
        final t = _liquidController.value * 2 * pi;
        final opacity = isDark ? 0.12 : 0.08;
        return Stack(
          children: [
            Positioned(
              top: -100 + (sin(t) * 40),
              left: -100 + (cos(t) * 40),
              child: _buildGlow(primary.withOpacity(opacity), 450),
            ),
            Positioned(
              bottom: -150 + (cos(t * 0.8) * 50),
              right: -100 + (sin(t * 1.2) * 30),
              child: _buildGlow(accent.withOpacity(opacity - 0.02), 500),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }

  Widget _buildLiquidOrb(Color primary, Color accent, Color cancel, bool isDark, {bool isProcessing = false}) {
    final double baseSize = 220.0;
    final isActive = _isMicOn || _isRecording;
    
    // Use AnimatedBuilder to animate blobs
    return AnimatedBuilder(
      animation: Listenable.merge([_liquidController, _introController]),
      builder: (context, child) {
        // Base time for animation
        final t = _liquidController.value * 2 * pi;
        // Apply fade-in opacity
        final double opacity = _introController.value;
        
        // Scale breathing based on state
        double breathScale = 1.0;
        if (isActive) {
          breathScale = 1.0 + _smoothedAmplitude * 0.15;
        } else if (isProcessing) {
          breathScale = 1.0 + 0.03 * sin(t * 1.5);
        }
        
        // Colors with good opacity for blending
        Color pColor = primary.withOpacity(isDark ? 0.45 : 0.35);
        Color aColor = accent.withOpacity(isDark ? 0.40 : 0.30);
        Color cColor = (_isCancelled ? cancel : primary.withBlue(180)).withOpacity(isDark ? 0.35 : 0.25);
        Color dColor = accent.withRed(200).withOpacity(isDark ? 0.30 : 0.20);
        
        if (isProcessing) {
          pColor = primary.withOpacity(isDark ? 0.7 : 0.6);
          aColor = accent.withOpacity(isDark ? 0.6 : 0.5);
          cColor = primary.withOpacity(isDark ? 0.5 : 0.4);
          dColor = accent.withOpacity(isDark ? 0.4 : 0.3);
        }

        return Transform.scale(
          scale: breathScale,
          child: Opacity(
            opacity: opacity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Multiple diffuse blobs moving in different patterns
                // Blob 1: Large, slow circular drift
                _buildDiffuseBlob(
                  color: pColor, 
                  size: baseSize * 0.9, 
                  time: t,
                  radiusX: 15, radiusY: 12, 
                  speedX: 0.8, speedY: 1.0, 
                  phaseX: 0, phaseY: pi / 3,
                ),
                // Blob 2: Medium, opposite direction
                _buildDiffuseBlob(
                  color: aColor, 
                  size: baseSize * 0.75, 
                  time: t,
                  radiusX: 18, radiusY: 14, 
                  speedX: 1.1, speedY: 0.7, 
                  phaseX: pi / 2, phaseY: pi,
                ),
                // Blob 3: Smaller, faster diagonal
                _buildDiffuseBlob(
                  color: cColor, 
                  size: baseSize * 0.65, 
                  time: t,
                  radiusX: 20, radiusY: 16, 
                  speedX: 0.9, speedY: 1.2, 
                  phaseX: pi, phaseY: pi / 4,
                ),
                // Blob 4: Tiny accent, wandering
                _buildDiffuseBlob(
                  color: dColor, 
                  size: baseSize * 0.55, 
                  time: t,
                  radiusX: 22, radiusY: 18, 
                  speedX: 1.3, speedY: 0.9, 
                  phaseX: pi * 1.5, phaseY: pi / 2,
                ),
                // Blob 5: Center anchor (subtle movement)
                _buildDiffuseBlob(
                  color: pColor.withOpacity(pColor.opacity * 0.6), 
                  size: baseSize * 1.0, 
                  time: t,
                  radiusX: 6, radiusY: 5, 
                  speedX: 0.5, speedY: 0.6, 
                  phaseX: 0, phaseY: 0,
                ),
                
                // Heavy blur to blend everything together
                ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                    child: Container(
                      width: baseSize * 1.4, 
                      height: baseSize * 1.4, 
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.01),
                            Colors.transparent,
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build a single diffuse blob that moves in an elliptical path
  Widget _buildDiffuseBlob({
    required Color color,
    required double size,
    required double time,
    required double radiusX,
    required double radiusY,
    required double speedX,
    required double speedY,
    required double phaseX,
    required double phaseY,
  }) {
    // Elliptical path with independent X and Y motion
    final double offsetX = radiusX * sin(time * speedX + phaseX);
    final double offsetY = radiusY * cos(time * speedY + phaseY);
    
    // Subtle scale pulsing
    final double pulse = 1.0 + 0.05 * sin(time * 0.7 + phaseX);
    
    return Transform.translate(
      offset: Offset(offsetX, offsetY),
      child: Transform.scale(
        scale: pulse,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color,
                color.withOpacity(color.opacity * 0.3),
              ],
              stops: const [0.3, 1.0],
            ),
          ),
        ),
      ),
    );
  }


  // ==================== LOGIC ====================

  Future<void> _switchMode(VentingMode mode) async {
    if (_currentMode == mode) return;
    
    // Stop any ongoing recording/connection
    if (_isMicOn) _toggleMic();
    if (_isRecording) _stopVoiceInputRecording(cancelled: true);
    
    setState(() {
      _currentMode = mode;
      _showTranscript = false;
      _userTranscript = "";
      _aiResponseText = "";
    });
    
    if (mode == VentingMode.realtime) {
      // Realtime mode needs TTS and AEC
      _voiceService.setSttOnlyMode(false);
      await _voiceService.switchToVoiceCallMode(); // 开启语音通话模式以启用 AEC
      
      // IMPORTANT: Stop and DISPOSE VentingScreen's own _audioRecorder
      // to avoid conflict with AudioUtil's recorder on iOS
      try {
        await _audioRecorder?.stop();
        await _audioRecorder?.dispose();
        _audioRecorder = null;
      } catch (_) {}
      
      // 预先请求麦克风权限（iOS上会显示系统弹窗）
      bool hasPermission = await AudioUtil.checkMicrophonePermission();
      if (!hasPermission) {
        print('Companion mode: Pre-requesting microphone permission...');
        hasPermission = await AudioUtil.requestMicrophonePermission();
        
        if (!hasPermission) {
          // 权限被拒绝，显示提示并返回
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('需要麦克风权限才能使用陪伴模式')),
            );
            // 切换回语音输入模式
            setState(() => _currentMode = VentingMode.voiceInput);
          }
          HapticHelper(ref).selectionClick();
          return;
        }
        
        // 刚刚获得权限，重置录音器状态
        await AudioUtil.resetRecorderState();
      }
      
      _voiceService.connect();
      // Auto-start mic after connection established
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _currentMode == VentingMode.realtime && _isConnected && !_isMicOn) {
          _toggleMic();
        }
      });
    } else {
      // 切换到 VoiceInput 模式
      // 重要：先停止 AudioUtil 的录音，释放麦克风资源
      try {
        await AudioUtil.stopRecording();
        print('Switch to voiceInput: AudioUtil recording stopped');
      } catch (e) {
        print('Switch to voiceInput: Error stopping AudioUtil: $e');
      }
      
      // 给iOS一点时间释放资源
      if (!kIsWeb && Platform.isIOS) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // VoiceInput mode needs local recorder
      if (_audioRecorder == null) {
        _audioRecorder = AudioRecorder();
      }

      // VoiceInput mode only needs STT (don't disconnect, use abort if needed)
      _voiceService.setSttOnlyMode(true);
      await _voiceService.switchToChatMode(); // 退出语音通话模式
      // 主动发起连接预热
      _preConnect();
    }
    
    HapticHelper(ref).selectionClick();
  }

  /// Hang up call and return to voiceInput mode
  Future<void> _hangUp() async {
    if (_isMicOn) {
      _toggleMic();
    }
    _voiceService.disconnect(); // 直接断开连接
    
    // 重要：停止 AudioUtil 的录音，释放麦克风资源
    try {
      await AudioUtil.stopRecording();
      print('Hang up: AudioUtil recording stopped');
    } catch (e) {
      print('Hang up: Error stopping AudioUtil: $e');
    }
    
    // 给iOS一点时间释放资源
    if (!kIsWeb && Platform.isIOS) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // 重新创建本地录音器供倾诉模式使用
    _audioRecorder = AudioRecorder();
    
    setState(() {
      _currentMode = VentingMode.voiceInput;
      _isConnected = false;
      _aiResponseText = "";
    });
    
    HapticHelper(ref).heavyImpact();
    
    // 返回倾诉模式后，立即发起连接预热
    _preConnect();
  }

  void _toggleMic() async {
    if (_isMicOn) {
      // Turn off mic
      _micStreamSub?.cancel();
      _voiceService.stopListening();
      setState(() => _isMicOn = false);
      // 更新全局录音状态
      ref.read(isRecordingProvider.notifier).state = false;
    } else {
      // Turn on mic
      // Use AudioUtil's permission API for consistency and proper state tracking
      bool hasPermission = await AudioUtil.checkMicrophonePermission();
      
      // If permission not granted, try to request it explicitly
      if (!hasPermission) {
        print('Companion mode: Requesting microphone permission...');
        hasPermission = await AudioUtil.requestMicrophonePermission();
        print('Companion mode: Permission result: $hasPermission');
        
        // 如果刚刚获得权限，重置录音器状态以确保正确初始化
        if (hasPermission) {
          await AudioUtil.resetRecorderState();
        }
      }
      
      if (hasPermission) {
        // IMPORTANT: Stop and release VentingScreen's own _audioRecorder
        // to avoid conflict with AudioUtil's recorder on iOS
        try {
           // FORCE CLEANUP: Ensure local recorder is completely dead before starting AI service
           if (_audioRecorder != null) {
             if (await _audioRecorder!.isRecording()) {
               await _audioRecorder!.stop();
             }
             await _audioRecorder!.dispose();
             _audioRecorder = null;
             
             // Give OS a moment to release the mic resource completely
             if (!kIsWeb && Platform.isIOS) {
               await Future.delayed(const Duration(milliseconds: 100));
             }
           }
        } catch (e) {
          print('Companion mode: Error cleaning up local recorder: $e');
        }
        
        // Let XiaozhiService handle the recording internally via AudioUtil
        // NOTE: Server-side VAD "realtime" requires AEC support; prefer "auto" for reliability.
        try {
          await _voiceService.startListening(mode: 'auto');
          setState(() => _isMicOn = true);
          // 更新全局录音状态
          ref.read(isRecordingProvider.notifier).state = true;
        } catch (e) {
          print('Companion mode: Failed to start listening: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('启动录音失败: $e')),
            );
          }
        }
      } else {
        print('Companion mode: Microphone permission denied');
        // Optionally show a snackbar or dialog to inform user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要麦克风权限才能使用陪伴模式')),
          );
        }
      }
    }
    HapticHelper(ref).mediumImpact();
  }

  /// Voice Input Mode: Record locally, send all at once when done
  Future<void> _startVoiceInputRecording() async {
    print('Starting voice input recording...');
    
    // === IMMEDIATE UI RESPONSE ===（先做UI反馈，提高响应速度）
    HapticHelper(ref).mediumImpact();
    
    // Abort any ongoing server response (but keep connection)
    _voiceService.abort(reason: 'wake_word_detected');
    
    // Clear previous buffer
    _voiceInputBuffer.clear();
    
    setState(() {
      _isRecording = true;
      _isCancelled = false;
      _userTranscript = "";
      _showTranscript = false;  // Hide previous transcript
      _aphorisms = "";  // Clear previous aphorisms
      _recordDuration = Duration.zero;
    });
    // 同步更新全局录音状态，让到期提醒系统知道用户正在录音
    ref.read(isRecordingProvider.notifier).state = true;
    _transcriptController.reverse();
    
    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _recordDuration += const Duration(seconds: 1));
    });
    
    // === NOW DO ASYNC OPERATIONS ===
    
    // Ensure recorder is initialized
    if (_audioRecorder == null) {
      _audioRecorder = AudioRecorder();
    }
    
    final hasPermission = await _audioRecorder!.hasPermission();
    print('Microphone permission: $hasPermission');
    
    if (!hasPermission) {
      print('No microphone permission!');
      // 取消录音状态
      _timer?.cancel();
      setState(() => _isRecording = false);
      return;
    }
    
    // === START LOCAL RECORDING ===
    print('Starting audio stream...');
    try {
      final stream = await _audioRecorder!.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
      ));
      print('Audio stream started');
      
      int chunkCount = 0;
      _micStreamSub = stream.listen((data) {
        chunkCount++;
        // Log every 10 chunks
        if (chunkCount % 10 == 0) {
          print('Recording: received chunk #$chunkCount, ${data.length} bytes');
        }
        
        // Update amplitude visualization
        if (data.isNotEmpty && mounted) {
          setState(() {
            final amp = (data[0].abs() / 128.0).clamp(0.0, 1.0);
            _smoothedAmplitude = _smoothedAmplitude * 0.7 + amp * 0.3;
          });
        }
        
        // BUFFER LOCALLY - don't send yet
        _voiceInputBuffer.add(Uint8List.fromList(data));
      }, onError: (e) {
        print('Audio stream error: $e');
      });
      
      print('Started local recording for Voice Input mode');
    } catch (e) {
      print('Failed to start audio stream: $e');
    }
  }

  Future<void> _stopVoiceInputRecording({required bool cancelled}) async {
    _timer?.cancel();
    
    // Wait a bit to ensure all audio data is captured before stopping
    if (!cancelled) {
      await Future.delayed(const Duration(milliseconds: 250));
    }
    
    _micStreamSub?.cancel();
    await _audioRecorder?.stop();
    
    final recordedChunks = List<Uint8List>.from(_voiceInputBuffer);
    _voiceInputBuffer.clear();
    
    print('Stopped recording: ${recordedChunks.length} audio chunks captured');
    
    if (cancelled || recordedChunks.isEmpty) {
      HapticHelper(ref).heavyImpact();
      _userTranscript = "";
      
      setState(() {
        _isRecording = false;
        _isCancelled = false;
        _dragOffset = 0;
        _recordDuration = Duration.zero;
        _smoothedAmplitude = 0;
      });
      // 重置全局录音状态
      ref.read(isRecordingProvider.notifier).state = false;
      return;
    }
    
    HapticHelper(ref).success();
    
    // IMMEDIATE UI UPDATE - show processing state (Analyzing/Thinking)
    // NOTE: We keep _showTranscript = false so that the Orb is shown (in Thinking state)
    // The Orb will show "正在思考..." if _userTranscript == "正在识别..." or _isAnalyzing == true
    final locale = ref.read(localeProvider);
    setState(() {
      _isRecording = false;
      _isCancelled = false;
      _dragOffset = 0;
      _recordDuration = Duration.zero;
      _smoothedAmplitude = 0;
      _userTranscript = AppStrings.get('identifying', locale);
      _showTranscript = true; 
      _transcriptController.forward();
    });
    // 重置全局录音状态
    ref.read(isRecordingProvider.notifier).state = false;
    
    // === NOW SEND ALL AUDIO TO SERVER ===
    try {
      // Connect only if WebSocket is not connected (use isConnected, not state)
      if (!_voiceService.isConnected) {
        print('Connecting to send audio...');
        await _voiceService.connect();
        
        // Wait for connection
        int waitCount = 0;
        while (!_voiceService.isConnected && waitCount < 30) {
          await Future.delayed(const Duration(milliseconds: 100));
          waitCount++;
        }
        
        if (!_voiceService.isConnected) {
          print('Failed to connect for sending audio');
          if (mounted) {
            setState(() {
                _userTranscript = AppStrings.get('connection_failed', locale);
                _showTranscript = true;
            });
          }
          return;
        }
      } else {
        print('Using existing connection');
      }
      
      // Clear any previous buffer
      _voiceService.clearAudioBuffer();
      
      // Start listening (skip recording since we already have buffered audio)
      await _voiceService.startListening(mode: 'manual', skipRecording: true);
      print('Started listening, sending ${recordedChunks.length} audio chunks...');
      
      // Send all buffered audio chunks (encode PCM to Opus first)
      for (final chunk in recordedChunks) {
        final opusData = await AudioUtil.encodeToOpus(chunk);
        if (opusData != null) {
          _voiceService.sendBinaryMessage(opusData);
        }
      }
      
      print('All audio sent, stopping listening...');
      
      // Stop listening but stay connected for STT result
      _voiceService.stopListening();
      
      // Wait for STT result
      int waitCount = 0;
      String identifyingStr = AppStrings.get('identifying', locale);
      while ((_userTranscript.isEmpty || _userTranscript == identifyingStr) && waitCount < 100) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
        if (!mounted) return;
      }
      
      if (mounted) {
        if (_userTranscript.isEmpty || _userTranscript == identifyingStr) {
          setState(() {
            _userTranscript = AppStrings.get('no_voice_detected', locale);
            _showTranscript = true;
          });
        } else {
             // STT Success! Auto proceed to Analysis
             setState(() {
                 _isAnalyzing = true; // Triggers "Thinking" Orb
                 _showTranscript = true; // Keep transcript visible
             });
             await _autoAnalyzeAndFinish(recordedChunks);
        }
      }
    } catch (e) {
      print('Error sending audio: $e');
      if (mounted) {
        setState(() {
           _userTranscript = "${AppStrings.get('send_failed', locale)}: $e";
           _showTranscript = true;
        });
      }
    }
  }

  /// 自动分析用户倾诉内容，生成格言，但不保存到时间线
  /// 只有用户点击"我知道怎么做了"才会保存到时间线
  Future<void> _autoAnalyzeAndFinish(List<Uint8List> recordedChunks) async {
      try {
        debugPrint("Starting auto analysis...");
        // 1. Analyze with AI
        final aiService = ref.read(aiServiceProvider);
        final locale = ref.read(localeProvider);
        
        // Use local variable for analysis to allow UI to show loading status
        final transcriptToAnalyze = _userTranscript;
        
        if (mounted) {
           setState(() {
               _userTranscript = AppStrings.get('analyzing_insight', locale);
           });
        }
        
        final analysisFuture = aiService.analyzeVentingContent(transcriptToAnalyze);
        
        // 2. Save Audio File (for later use when user confirms)
        String? audioPath;
        if (recordedChunks.isNotEmpty) {
            try {
               final dir = await getApplicationDocumentsDirectory();
               final audioDir = Directory('${dir.path}/journal_audio');
               if (!await audioDir.exists()) {
                 await audioDir.create(recursive: true);
               }
               
               final fileName = 'venting_${DateTime.now().millisecondsSinceEpoch}.wav';
               audioPath = '${audioDir.path}/$fileName';
               
               final dataBytesBuilder = BytesBuilder();
               for (var b in recordedChunks) dataBytesBuilder.add(b);
               final dataBytes = dataBytesBuilder.toBytes();
               
               if (dataBytes.isNotEmpty) {
                 final header = AudioUtil.buildWavHeader(dataBytes.length, wavSampleRate: 16000);
                 final file = File(audioPath);
                 
                 final finalBytesBuilder = BytesBuilder();
                 finalBytesBuilder.add(header);
                 finalBytesBuilder.add(dataBytes);
                 
                 await file.writeAsBytes(finalBytesBuilder.toBytes());
                 debugPrint("Audio saved to: $audioPath");
                 // Store audio path for later use when saving to timeline
                 _lastAudioPath = audioPath;
               }
            } catch (e) {
               debugPrint("Audio save failed: $e");
            }
        }

        final result = await analysisFuture;
        if (!mounted) return;
        
        // Parse result: "aphorisms|||encouragement"
        String aphorisms = result;
        String encouragement = "";
        if (result.contains('|||')) {
          final parts = result.split('|||');
          aphorisms = parts[0].trim();
          encouragement = parts.length > 1 ? parts[1].trim() : "";
        }
        
        // 3. Only update UI to show result (不保存到时间线，等用户点击"我知道怎么做了")
        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            _aphorisms = aphorisms;
            _encouragement = encouragement;
            _showTranscript = true; // Show result card with typewriter
            _userTranscript = transcriptToAnalyze; // Restore original text for saving
            _transcriptController.forward();
          });
          HapticHelper(ref).success();
        }
        
      } catch (e) {
         debugPrint("Venting processing error: $e");
         if (mounted) {
           final locale = ref.read(localeProvider);
           setState(() { 
               _isAnalyzing = false;
               _userTranscript = "${AppStrings.get('processing_failed', locale)}: $e"; 
               _showTranscript = true; // Show error
           });
         }
      }
  }

  String _formatDuration(Duration d) {
    return "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  /// Build the encouragement overlay shown before exiting
  Widget _buildEncouragementOverlay(bool isDark, Color textColor) {
    return EncouragementView(
      text: _encouragement,
      isDark: isDark,
    );
  }



  void _showActivationDialog(String code, String? message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.vpn_key_rounded, color: AppTheme.primaryBlue, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              '设备激活',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '请在后台输入以下激活码',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
              ),
              child: SelectableText(
                code,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                  letterSpacing: 6,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message ?? 'xiaozhi.me',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); _resetAndRecheck(); },
            child: Text('重置', style: TextStyle(color: Colors.orange)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: Text('稍后', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _checkActivation(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            child: const Text('已激活', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

extension on HapticHelper {
  void success() { try { selectionClick(); mediumImpact(); } catch(_) {} }
}

class _TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration duration;
  final TextAlign textAlign;
  final VoidCallback? onComplete;

  const _TypewriterText({
    Key? key,
    required this.text,
    required this.style,
    this.duration = const Duration(milliseconds: 30),
    this.textAlign = TextAlign.center,
    this.onComplete,
  }) : super(key: key);

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  String _displayedText = "";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }
  
  @override
  void didUpdateWidget(_TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
        _startTyping();
    }
  }

  void _startTyping() {
    _timer?.cancel();
    _displayedText = "";
    
    // Simple split usually works for Chinese, but characters.toList() is safer
    // Since we don't import characters, we use runestrings or just regular invalid logic
    // But characters package is included in flutter.
    // To be safe without extra imports, use .split('') or runes.
    // However, emoji might break. Characters is best.
    // Assuming 'package:flutter/widgets.dart' exports Characters via 'package:characters/characters.dart'? 
    // Actually no, it might not be exported directly in all versions. 
    // Safest is visual Characters handling. 
    // Let's use characters property on String if available (dart >= 2.12 with flutter).
    // Text(str).data!.characters 
    // Let's use characters.
    
    final chars = widget.text.characters.toList();
    int currentIndex = 0;
    
    _timer = Timer.periodic(widget.duration, (timer) {
      if (currentIndex < chars.length) {
        setState(() {
          _displayedText += chars[currentIndex];
        });
        currentIndex++;
      } else {
        timer.cancel();
        // Trigger onComplete callback when typing finishes
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_displayedText.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Split text by newlines to insert dividers
    final parts = _displayedText.split('\n');
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < parts.length; i++) ...[
          // Only render text if not empty (to avoid empty space, though Text("") is mostly invisible)
          if (parts[i].isNotEmpty)
             Text(parts[i], style: widget.style, textAlign: widget.textAlign),
             
          // Add Divider if we have split parts (meaning newlines occurred)
          // i < parts.length - 1 ensures we don't put divider after the last part
          if (i < parts.length - 1)
            Container(
               margin: const EdgeInsets.symmetric(vertical: 24),
               height: 1,
               // Use a very subtle color derived from the text color
               color: widget.style.color?.withOpacity(0.06) ?? Colors.grey.withOpacity(0.06), 
            ),
        ],
      ],
    );
  }
}

/// A custom AudioSource that streams raw PCM data wrapped in a WAV container.
/// Used for realtime voice playback from the AI.
class LiveStreamAudioSource extends StreamAudioSource {
  final StreamController<List<int>> _controller = StreamController<List<int>>();
  
  LiveStreamAudioSource();

  /// Push raw PCM bytes to the player
  void addAudio(Uint8List bytes) {
    if (!_controller.isClosed) {
      if (bytes.isNotEmpty) {
        // print("[Audio] Pushing ${bytes.length} bytes to player"); 
      }
      _controller.add(bytes.toList());
    }
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    // TTS audio from server is 16000Hz (confirmed from server hello response)
    // We use a very large file size (approx 4GB) to simulate an infinite stream
    // 0xFFFFFFFF = 4294967295 bytes
    final header = AudioUtil.buildWavHeader(
      0xFFFFFFFF, 
      wavSampleRate: 16000,  // Server returns 16kHz audio
      wavChannels: 1
    );
    
    return StreamAudioResponse(
      sourceLength: null,
      contentLength: null,
      offset: 0,
      stream: _createStream(header.toList()),
      contentType: 'audio/wav',
    );
  }

  Stream<List<int>> _createStream(List<int> header) async* {
    yield header;
    yield* _controller.stream;
  }

  // Not overriding close/dispose from super as it may not exist or doesn't need to be called
  // We just need to clean up our own controller.
  Future<void> dispose() async {
    await _controller.close();
  }
}

/// A postcard-style encouragement view designed to feel personal and warm.
class EncouragementView extends ConsumerStatefulWidget {
  final String text;
  final bool isDark;

  const EncouragementView({
    super.key,
    required this.text,
    required this.isDark,
  });

  @override
  ConsumerState<EncouragementView> createState() => _EncouragementViewState();
}

class _EncouragementViewState extends ConsumerState<EncouragementView> with TickerProviderStateMixin {
  late AnimationController _mainController;
  
  // Animations
  late Animation<double> _cardSlide;
  late Animation<double> _contentOpacity;
  late Animation<double> _stampScale;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _cardSlide = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    );

    _contentOpacity = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );
    
    _stampScale = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.7, 1.0, curve: Curves.elasticOut),
    );

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    
    // Postcard colors - Dark Mode Adaptation
    final paperColor = widget.isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFDFBF7); // Dark Grey vs Warm Paper
    final inkColor = widget.isDark ? const Color(0xFFE2E8F0) : const Color(0xFF2D3748);   // Light Grey vs Dark Ink
    final stampColor = widget.isDark ? const Color(0xFFFC8181) : const Color(0xFFE53E3E); // Light Red vs Red
    final bgBase = widget.isDark ? Colors.black : const Color(0xFFF0F2F5);     // Pure Black BG

    return Scaffold(
      backgroundColor: bgBase,
      body: GestureDetector(
        onTap: () {
          HapticHelper(ref).selectionClick();
          Navigator.pop(context);
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
          // Background Texture (Subtle Noise or Gradient)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isDark 
                  ? [Colors.black, const Color(0xFF1C1C1E)]
                  : [const Color(0xFFF0F2F5), const Color(0xFFE2E8F0)],
              ),
            ),
          ),
          
          // The Postcard
          Center(
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                // Slide up from bottom
                final slide = 100 * (1.0 - _cardSlide.value);
                // Slight rotation for natural feel
                
                return Transform.translate(
                  offset: Offset(0, slide),
                  child: Transform.rotate(
                    angle: -0.02, // Permanent slight tilt
                    child: Opacity(
                      opacity: _cardSlide.value.clamp(0.0, 1.0),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.85,
                        constraints: const BoxConstraints(maxWidth: 400, minHeight: 500),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: paperColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(widget.isDark ? 0.3 : 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                            if (!widget.isDark)
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                          ],
                          border: widget.isDark 
                              ? Border.all(color: Colors.white.withOpacity(0.1), width: 1)
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header: Stamp and Postmark
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left: Greeting
                                Padding(
                                  padding: const EdgeInsets.only(top: 20, left: 0),
                                  child: Text(
                                    "TO: YOU",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                      color: inkColor.withOpacity(0.4),
                                    ),
                                  ),
                                ),
                                
                                // Right: Valid Stamp
                                Transform.scale(
                                  scale: _stampScale.value,
                                  child: _buildStamp(stampColor),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 48),
                            
                            // Body: Encouragement Text
                            FadeTransition(
                              opacity: _contentOpacity,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.text,
                                    style: TextStyle(
                                      fontSize: 28,
                                      height: 1.4,
                                      color: inkColor.withOpacity(0.9),
                                      letterSpacing: 0.5,
                                      fontWeight: FontWeight.w400,
                                      fontFamilyFallback: const ['Georgia', 'serif'], // Try serif if available
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  // Divider line
                                  Container(
                                    width: 80,
                                    height: 2,
                                    color: inkColor.withOpacity(0.1),
                                  ),
                                  const SizedBox(height: 16),
                                  // Signature
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Transform.rotate(
                                      angle: -0.05,
                                      child: Text(
                                        AppStrings.get('from_ai', locale),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          fontStyle: FontStyle.italic,
                                          color: inkColor.withOpacity(0.7),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Footer text outside card
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _contentOpacity,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.get('encouragement_footer', locale),
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.isDark ? Colors.white54 : Colors.black45,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.get('encouragement_exit_hint', locale),
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isDark ? Colors.white24 : Colors.black26,
                        letterSpacing: 1,
                      ),
                    ),
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

  Widget _buildStamp(Color color) {
    return Container(
      width: 60,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset:const Offset(1,1))
        ]
      ),
      child: Stack(
        children: [
          // Stamp perforation effect (visual only)
          Positioned(top: 2, left: 2, right: 2, bottom: 2,
             child: Container(
               decoration: BoxDecoration(
                 border: Border.all(color: color.withOpacity(0.2), width: 1, style: BorderStyle.solid),
               ),
             ),
          ),
          Center(
            child: Icon(Icons.favorite, color: color, size: 28),
          ),
          // Postmark overlay
          Positioned(
            bottom: -5,
            right: -5,
            child: Transform.rotate(
              angle: -0.5,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black.withOpacity(0.2), width: 2),
                ),
                child: Center(
                  child: Text(
                    "POST",
                    style: TextStyle(
                       fontSize: 8, 
                       fontWeight: FontWeight.bold, 
                       color: Colors.black.withOpacity(0.2)
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
