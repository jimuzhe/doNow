
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/localization.dart';
import '../../data/providers.dart';
import '../../data/models/task.dart';
import '../../data/services/sound_effect_service.dart';
import '../../data/services/focus_audio_service.dart';
import '../../utils/haptic_helper.dart';
import '../widgets/task_completion_sheet.dart';
import '../widgets/focus_sound_sheet.dart';
import '../widgets/custom_dialog.dart';

class QuickFocusScreen extends ConsumerStatefulWidget {
  final bool isAutoLandscape;
  const QuickFocusScreen({
    super.key, 
    this.isAutoLandscape = false,
  });

  @override
  ConsumerState<QuickFocusScreen> createState() => _QuickFocusScreenState();
}

class _QuickFocusScreenState extends ConsumerState<QuickFocusScreen> with TickerProviderStateMixin {
  final TextEditingController _taskController = TextEditingController();
  
  // Settings
  int _focusInterval = 25; // Minutes before break suggestion
  int _breakDurationSetting = 5; // Minutes for break
  
  // Timer States
  Duration _accumulatedTime = Duration.zero; // Count UP
  Duration _breakTimeRemaining = Duration.zero; // Count DOWN (for break)
  
  bool _isRunning = false;
  bool _isBreak = false; // If true, we are in break mode (countdown)
  
  late Timer _timer;
  late AnimationController _sandAnimation; // For hourglass visual

  @override
  void initState() {
    super.initState();
    _sandAnimation = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 2), // Loop duration for sand flow
    );
     // If running, we repeat.
  }
  
  @override
  void dispose() {
    _sandAnimation.dispose();
    _taskController.dispose();
    if (_isRunning) _timer.cancel();
    // Ensure audio stops when leaving screen
    ref.read(focusAudioServiceProvider).stopFocusSound();
    super.dispose();
  }

  void _toggleTimer() {
    HapticHelper(ref).mediumImpact();
    
    if (_isRunning) {
      // Pause and show options
      _handlePause();
    } else {
      _startTimer();
    }
  }

  void _handlePause() {
    _stopTimer();
    // Dialog removed as per requirement. User remains on screen in paused state.
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
    });
    
    if (_isBreak && _breakTimeRemaining.inSeconds == 0) {
      // Reset break if starting from 0
       _breakTimeRemaining = Duration(minutes: _breakDurationSetting);
    }

    // Audio Control: Play only during Focus, stop during Break
    if (_isBreak) {
      ref.read(focusAudioServiceProvider).stopFocusSound();
    } else {
      ref.read(focusAudioServiceProvider).startFocusSound();
    }

    _sandAnimation.repeat(); // visual flow

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_isBreak) {
          // Break Mode: Countdown
          if (_breakTimeRemaining.inSeconds > 0) {
            _breakTimeRemaining = _breakTimeRemaining - const Duration(seconds: 1);
          } else {
             // Break Finished
             _stopTimer();
             ref.read(soundEffectServiceProvider).playSuccess();
             HapticHelper(ref).heavyImpact();
             // Switch back to Focus automatically? Or just stop.
             // User prompt: "Timer Completed".
             _isBreak = false; // Ready to focus again
          }
        } else {
          // Focus Mode: Count UP
          _accumulatedTime = _accumulatedTime + const Duration(seconds: 1);
          
          // Check Interval
          if (_accumulatedTime.inSeconds > 0 && 
              _accumulatedTime.inSeconds % (_focusInterval * 60) == 0) {
             // Interval hit! Suggest break? 
             HapticHelper(ref).mediumImpact();
             ref.read(soundEffectServiceProvider).playSuccess(); // subtle ding
             // Maybe show a small toast or just vibrate
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text(AppStrings.get('break_timer', ref.read(localeProvider))),
                 duration: const Duration(seconds: 3),
                 action: SnackBarAction(
                   label: AppStrings.get('start_break', ref.read(localeProvider)), 
                   onPressed: () {
                     _switchToBreak();
                   }
                 ),
               )
             );
          }
        }
      });
    });
  }

  void _stopTimer() {
    if (_timer.isActive) _timer.cancel();
    _sandAnimation.stop();
    ref.read(focusAudioServiceProvider).stopFocusSound();
    setState(() {
      _isRunning = false;
    });
  }
  
  void _switchToBreak() {
    _stopTimer();
    setState(() {
      _isBreak = true;
      _breakTimeRemaining = Duration(minutes: _breakDurationSetting);
    });
    _startTimer();
  }

  void _finishFocus() {
    _stopTimer();
    ref.read(soundEffectServiceProvider).playSuccess(); 
    HapticHelper(ref).heavyImpact();
    _showCompletionSheet();
  }

  Future<void> _showCompletionSheet() async {
     // Create a temporary task record
     final now = DateTime.now();


     final task = Task(
       id: const Uuid().v4(),
       title: _taskController.text.isEmpty 
           ? AppStrings.get('quick_focus_title', ref.read(localeProvider))
           : _taskController.text,
       totalDuration: _accumulatedTime,
       scheduledStart: now.subtract(_accumulatedTime),
       subTasks: [],
       isCompleted: true,
       completedAt: now,
       actualDuration: _accumulatedTime, // Record actual duration for analysis
       isQuickFocus: true, 
     );
     
     // Save to repository so it appears in Analysis
     ref.read(taskListProvider.notifier).addTask(task);

     await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => TaskCompletionSheet(
          task: task,
          actualDuration: _accumulatedTime, 
        ),
     );
     
     if (mounted && !widget.isAutoLandscape) Navigator.pop(context); 
     // If auto-landscape, we reset?
     if (widget.isAutoLandscape) {
       setState(() {
         _accumulatedTime = Duration.zero;
         _isBreak = false;
       });
     }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
         final locale = ref.read(localeProvider);
         String t(String key) => AppStrings.get(key, locale);
         
         return StatefulBuilder(
           builder: (context, setModalState) {
             return Container(
               padding: const EdgeInsets.all(24),
               height: 350,
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(t('focus_setting'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 24),
                   
                   // Focus Interval
                   Text("${t('break_interval')}: $_focusInterval min"),
                   Slider(
                     value: _focusInterval.toDouble(),
                     min: 5,
                     max: 60,
                     divisions: 11,
                     label: "$_focusInterval",
                     onChanged: (val) {
                       setModalState(() => _focusInterval = val.toInt());
                       setState(() {}); // Update main UI if needed
                     },
                   ),
                   
                   const SizedBox(height: 16),
                   
                   // Break Duration
                   Text("${t('break_duration')}: $_breakDurationSetting min"),
                   Slider(
                     value: _breakDurationSetting.toDouble(),
                     min: 1,
                     max: 15,
                     divisions: 14,
                     label: "$_breakDurationSetting",
                     onChanged: (val) {
                       setModalState(() => _breakDurationSetting = val.toInt());
                       setState(() {});
                     },
                   ),
                 ],
               ),
             );
           }
         );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = ref.watch(localeProvider);
    String t(String key) => AppStrings.get(key, locale);
    
    // Display Time
    final displayDuration = _isBreak ? _breakTimeRemaining : _accumulatedTime;
    final minutes = displayDuration.inMinutes.toString().padLeft(2, '0');
    final seconds = (displayDuration.inSeconds % 60).toString().padLeft(2, '0');
    final timeStr = "$minutes:$seconds";
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isBreak ? t('break_timer') : t('quick_focus')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isAutoLandscape 
          ? null // No back button in auto-landscape
          : IconButton(
              icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
        actions: [
          // White Noise Setting
          IconButton(
            icon: Icon(Icons.headphones, color: isDark ? Colors.white : Colors.black),
            onPressed: () {
               showModalBottomSheet(
                 context: context,
                 isScrollControlled: true,
                 backgroundColor: Colors.transparent,
                 builder: (_) => const FocusSoundSheet(),
               );
            },
          ),
          // Timer Settings
          IconButton(
            icon: Icon(Icons.tune, color: isDark ? Colors.white : Colors.black),
            onPressed: _showSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
             // 1. Task Input (Only editable if not running)
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
               child: TextField(
                 controller: _taskController,
                 enabled: !_isRunning,
                 style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark?Colors.white:Colors.black),
                 decoration: InputDecoration(
                   hintText: t('what_to_do'),
                   border: InputBorder.none,
                   hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                 ),
                 textAlign: TextAlign.center,
               ),
             ),
             
             Expanded(
               child: Center(
                 child: Stack(
                   alignment: Alignment.center,
                   children: [
                      // Sandglass Animation Logic
                      // We represent it as a top heavy triangle filling bottom triangle? 
                      // Or just a rotating container.
                      // Let's use a CustomPaint for Hourglass shape
                      AnimatedBuilder(
                        animation: _sandAnimation,
                        builder: (context, child) {
                           // If running, we simulate flowing.
                           // Rotation if running?
                           return Transform.rotate(
                             angle: _isRunning && !_isBreak ? _sandAnimation.value * 2 * pi : 0, // Spin slowly? Or use Lottie? 
                             // Wait, simple rotation isn't an hourglass flow.
                             // Let's just do a nice Circular Progress that is full or indeterminate?
                             // User asked for "sandglass animation showing accumulated time".
                             // Accumulated time is infinite basically. 
                             // So let's show a "filling up" circle based on Interval.
                             child: child,
                           );
                        },
                        child: SizedBox(
                          width: 250,
                          height: 250,
                          child: CircularProgressIndicator(
                            value: _isBreak 
                                ? 1.0 - (_breakTimeRemaining.inSeconds / (_breakDurationSetting * 60)) 
                                : (_accumulatedTime.inSeconds % (_focusInterval * 60)) / (_focusInterval * 60), 
                            strokeWidth: 12,
                            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation(
                                _isBreak ? Colors.green : (isDark ? Colors.white : Colors.black)
                            ),
                          ),
                        ),
                      ),
                      
                      // Hourglass Icon (Rotating) for both Focus and Break
                      AnimatedBuilder(
                        animation: _sandAnimation,
                        builder: (context, child) {
                           // If not running, static empty or bottom?
                           if (!_isRunning) {
                             return Icon(Icons.hourglass_empty, size: 60, color: _isBreak ? Colors.green : Colors.grey);
                           }
                           return Transform.rotate(
                             angle: _sandAnimation.value * pi, 
                             child: Icon(Icons.hourglass_bottom, size: 60, color: _isBreak ? Colors.green : (isDark ? Colors.white : Colors.black)),
                           );
                        }
                      ),
                      
                      // Touch Area
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _toggleTimer,
                            child: const SizedBox(),
                          ),
                        ),
                      ),
                      
                      // Removed Coffee Icon to align with reading: "Break time is also a paused hourglass"


                   ],
                 ),
               ),
             ),
             
             Text(
               timeStr,
               style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
             ),
             if (!_isBreak)
               Text(t('accumulated_time'), style: const TextStyle(color: Colors.grey)),
             if (_isBreak)
               Text(t('break_timer'), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),

             const SizedBox(height: 32),

             // Control Buttons
             Padding(
               padding: const EdgeInsets.all(32),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: [
                  // Start State: Only START
                   if (_accumulatedTime.inSeconds == 0 && !_isBreak)
                     Expanded(
                       child: SizedBox(
                         height: 64,
                         child: ElevatedButton(
                           onPressed: _toggleTimer,
                           style: ElevatedButton.styleFrom(
                             backgroundColor: isDark ? Colors.white : Colors.black,
                             foregroundColor: isDark ? Colors.black : Colors.white,
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                           ),
                           child: Text(t('btn_start')),
                         ),
                       ),
                     )
                   else
                     // Running/Paused: Only FINISH
                     Expanded(
                       child: SizedBox(
                         height: 64,
                         child: OutlinedButton(
                           onPressed: _finishFocus,
                           style: OutlinedButton.styleFrom(
                             side: BorderSide(color: isDark ? Colors.white : Colors.black, width: 2),
                             foregroundColor: isDark ? Colors.white : Colors.black,
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                             backgroundColor: isDark ? Colors.black : Colors.white,
                           ),
                           child: Text(t('record_activity')),
                         ),
                       ),
                     ),
                 ],
               ),
             )
          ],
        ),
      ),
    );
  }
}
