import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/task.dart';
import '../../data/models/subtask.dart';
import '../../data/providers.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/task_scheduler_service.dart';
import '../../data/services/sound_effect_service.dart';
import '../../data/localization.dart';
import '../../utils/haptic_helper.dart';
import '../../data/services/focus_audio_service.dart';
import '../widgets/responsive_center.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> with WidgetsBindingObserver {
  late Timer _timer;
  late Duration _remainingTime;
  late DateTime _taskStartTime;
  bool _hasShownTimeout = false;
  StreamSubscription<IslandAction>? _actionSubscription;
  
  // Local state for checkboxes
  late List<bool> _completedSteps;
  
  // Per-step timer
  late Duration _currentStepRemaining;
  
  // Track current step index even if previous steps are not checked
  int _forceActiveStepIndex = 0;
  
  // Get the active step: either the first unchecked step, or the forced active step
  int get _activeStepIndex {
    // Find first unchecked step
    final firstUnchecked = _completedSteps.indexOf(false);
    if (firstUnchecked == -1) return -1; // All done
    
    // Use the maximum between first unchecked and forced index
    // This allows auto-advance without marking steps as complete
    return _forceActiveStepIndex.clamp(0, widget.task.subTasks.length - 1);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize background audio for persistent timer logic
    ref.read(focusAudioServiceProvider).init().then((_) {
       ref.read(focusAudioServiceProvider).startFocusSound();
    });
    
    _taskStartTime = DateTime.now();
    // Calculate target end time based on initial duration
    _remainingTime = widget.task.totalDuration;
    _endTime = _taskStartTime.add(_remainingTime);
    
    _completedSteps = List.generate(widget.task.subTasks.length, (_) => false);
    
    // Mark this task as active (to prevent duplicate navigation from scheduler)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeTaskIdProvider.notifier).state = widget.task.id;
    });
    
    // Initialize current step timer
    _initCurrentStepTimer();
    
    _startNotifications(); 
    _startTimer();
    _listenToIslandActions();
    
    // Check if we were opened via Dynamic Island action
    WidgetsBinding.instance.addPostFrameCallback((_) {
       ref.read(notificationServiceProvider).checkPendingAction();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check for pending actions from Dynamic Island
      ref.read(notificationServiceProvider).checkPendingAction();
      
      // Refresh timer immediately when app comes to foreground
      if (mounted) {
        setState(() {
           // Force update will happen in next timer tick, 
           // but we can also manually check if we want immediate feedback
           _updateTimers();
        });
      }
    }
  }

  // Target end time for the whole task
  late DateTime _endTime;
  // Target end time for the current step
  DateTime? _stepEndTime;

  void _initCurrentStepTimer() {
    if (_forceActiveStepIndex >= 0 && _forceActiveStepIndex < widget.task.subTasks.length) {
      final stepDuration = widget.task.subTasks[_forceActiveStepIndex].estimatedDuration;
      _currentStepRemaining = stepDuration;
      _stepEndTime = DateTime.now().add(stepDuration);
    } else {
      _currentStepRemaining = Duration.zero;
      _stepEndTime = null;
    }
  }

  // Listen to Dynamic Island action buttons
  void _listenToIslandActions() {
    final service = ref.read(notificationServiceProvider);
    _actionSubscription = service.actionStream.listen((action) {
      if (!mounted) return;
      
      switch (action) {
        case IslandAction.complete:
          _handleIslandComplete();
          break;
        case IslandAction.cancel:
          _handleIslandCancel();
          break;
      }
    });
  }

  // Handle "Complete" button from Dynamic Island - complete current step
  void _handleIslandComplete() {
    final activeIdx = _activeStepIndex;
    if (activeIdx != -1) {
      // Haptic feedback for step completion
      HapticHelper(ref).mediumImpact();
      
      setState(() {
        _completedSteps[activeIdx] = true;
        
        // Move to next step
        if (_forceActiveStepIndex < widget.task.subTasks.length - 1) {
          _forceActiveStepIndex++;
          _initCurrentStepTimer();
          
          // Update Live Activity with new step info
          ref.read(notificationServiceProvider).updateTaskProgress(
            widget.task.subTasks[_forceActiveStepIndex].title, 
            0.0,
            startTime: DateTime.now(),
            endTime: _stepEndTime,
            currentStepIndex: _forceActiveStepIndex,
          );
        }
        
        // Check if all steps are done
        if (!_completedSteps.contains(false)) {
          _timer.cancel();
          Future.microtask(() => _completeMission());
        }
      });
    }
  }

  // Handle "Cancel" button from Dynamic Island - abandon task
  void _handleIslandCancel() {
    _timer.cancel();
    ref.read(taskRepositoryProvider).abandonTask(widget.task);
    ref.read(notificationServiceProvider).endActivity();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // Start Live Activity
  void _startNotifications() async {
     final now = DateTime.now();
     // If we have a current step timer
     DateTime? stepEnd = _stepEndTime;
     
     await ref.read(notificationServiceProvider).startTaskActivity(
       widget.task, 
       startTime: now,
       endTime: stepEnd,
     );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateTimers();
      }
    });
  }

  void _updateTimers() {
     setState(() {
        final now = DateTime.now();

        // 1. Global Timer calculation
        final remaining = _endTime.difference(now);
        _remainingTime = remaining;
        
        if (remaining.inSeconds <= 0 && !_hasShownTimeout) {
           _hasShownTimeout = true;
           _showTimeoutDialog();
           // Do not cancel timer, allow overtime
        }

        // 2. Step Timer
        final activeIdx = _activeStepIndex;
        if (activeIdx != -1 && _stepEndTime != null) {
           final stepRemaining = _stepEndTime!.difference(now);
           
           if (stepRemaining.inSeconds > 0) {
             _currentStepRemaining = stepRemaining;
           } else {
             _currentStepRemaining = Duration.zero; // Clamp to zero
             
             // AUTO-ADVANCE logic
             if (_forceActiveStepIndex < widget.task.subTasks.length - 1) {
                // Move to next step
                _forceActiveStepIndex++;
                _initCurrentStepTimer(); // Initialize timer (sets new _stepEndTime)
                
                // Update Live Activity immediately for new step
                if (_forceActiveStepIndex < widget.task.subTasks.length) {
                   ref.read(notificationServiceProvider).updateTaskProgress(
                     widget.task.subTasks[_forceActiveStepIndex].title, 
                     0.0, // starts at 0 progress (or 1.0 depending on view, new step)
                     startTime: DateTime.now(),
                     endTime: _stepEndTime,
                     currentStepIndex: _forceActiveStepIndex,
                   );
                }
             }
             // else: Last step ended
           }
           
           // Update Live Activity (Periodic)
           // We still send updates to keep 'progress' variable sync if needed, 
           // but native now relies on timestamps mostly.
           if (_forceActiveStepIndex >= 0 && _forceActiveStepIndex < widget.task.subTasks.length) {
             final stepTotal = widget.task.subTasks[_forceActiveStepIndex].estimatedDuration.inSeconds;
             final progress = stepTotal > 0 
                 ? 1.0 - (_currentStepRemaining.inSeconds / stepTotal)
                 : 1.0;
                 
             ref.read(notificationServiceProvider).updateTaskProgress(
               widget.task.subTasks[_forceActiveStepIndex].title, 
               progress,
               startTime: _stepEndTime?.subtract(widget.task.subTasks[_forceActiveStepIndex].estimatedDuration),
               endTime: _stepEndTime,
               currentStepIndex: _forceActiveStepIndex,
             );
           }
        }
     });
  }

  @override
  void dispose() {
    if (_timer.isActive) _timer.cancel();
    _actionSubscription?.cancel();
    
    WidgetsBinding.instance.removeObserver(this);
    
    // Stop background sound
    ref.read(focusAudioServiceProvider).stopFocusSound();
    
    // Clear active task ID when leaving (unless we completed early)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(activeTaskIdProvider.notifier).state = null;
      } catch (_) {}
    });
    
    super.dispose();
  }

  Future<void> _completeMission() async {
    // Strong haptic feedback for mission completion!
    HapticHelper(ref).heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticHelper(ref).heavyImpact();
    
    // Play success sound effect
    ref.read(soundEffectServiceProvider).playSuccess();
    
    // Calculate actual duration
    final actualDuration = DateTime.now().difference(_taskStartTime);
    final diff = actualDuration - widget.task.totalDuration;

    // 1. Mark as completed in repo
    final repo = ref.read(taskRepositoryProvider);
    final completedTask = widget.task.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
      actualDuration: actualDuration, 
    );
    repo.updateTask(completedTask);
    
    // 2. Stop timer & Activity
    _timer.cancel();
    ref.read(notificationServiceProvider).endActivity();
    
    // 3. Clear active task ID
    ref.read(activeTaskIdProvider.notifier).state = null;

    // 4. Show Success Overlay
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false, // Full screen immersive
      builder: (_) => _SuccessOverlay(
        actualDuration: actualDuration,
        diff: diff,
      ),
    );

    if (mounted) {
      Navigator.of(context).pop(); // Back to Home
    }
  }

  void _showTimeoutDialog() {
    final locale = ref.read(localeProvider);
    String t(String key) => AppStrings.get(key, locale);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(t('times_up')),
        content: Text(t('times_up_content')),
        actions: [
          // Continue option (Overtime)
          TextButton(
            onPressed: () {
               Navigator.pop(context); // Close Dialog and keep running
            },
            child: Text(t('ok_cool'), style: const TextStyle(color: Colors.grey)), 
          ),
          TextButton(
            onPressed: () {
               ref.read(notificationServiceProvider).endActivity(); 
               Navigator.pop(context); // Close Dialog
               _showEncouragementOverlay();
            },
            child: Text(t('btn_no')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _completeMission();
            },
            child: Text(t('btn_yes')),
          ),
        ],
      ),
    );
  }

  void _handleCancel() {
    final locale = ref.read(localeProvider);
    String t(String key) => AppStrings.get(key, locale);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('abort_title')),
        content: Text(t('abort_content')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('cancel')),
          ),
          // Reschedule
          TextButton(
             onPressed: () {
               Navigator.pop(context);
               _rescheduleTask();
             },
             child: Text(t('reschedule')),
          ),
           TextButton(
            onPressed: () {
               // 1. Cancel timer
               _timer.cancel();
               
               // 2. Mark task as abandoned (for analysis tracking)
               ref.read(taskRepositoryProvider).abandonTask(widget.task);
               
               // 3. End Live Activity / Dynamic Island
               ref.read(notificationServiceProvider).endActivity();
               
               // 4. Close dialogs and return to home
               Navigator.pop(context);
               Navigator.pop(context);
            },
            child: Text(t('btn_quit'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Format timer
    final bool isOvertime = _remainingTime.isNegative;
    final absDuration = _remainingTime.abs();
    final minutes = absDuration.inMinutes.toString().padLeft(2, '0');
    final seconds = (absDuration.inSeconds % 60).toString().padLeft(2, '0');
    final formattedTime = isOvertime ? "+ $minutes:$seconds" : "$minutes:$seconds";

    final allChecked = !_completedSteps.contains(false);

    // Dark Mode Support for Timer
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Use Theme
      appBar: AppBar(
        leading: const SizedBox(), // Hide back button
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Use Theme
        title: Text(
          formattedTime,
          style: TextStyle(
            color: isOvertime ? Colors.red : (_remainingTime.inMinutes < 5 ? Colors.orange : (isDark ? Colors.white : Colors.black)),
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier', // Monospaced for timer
            fontSize: 24,
          ),
        ),
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Text(
                widget.task.title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: widget.task.subTasks.length,
                itemBuilder: (context, index) {
                  final subTask = widget.task.subTasks[index];
                  final isChecked = _completedSteps[index];
                  final isActive = index == _forceActiveStepIndex && !_completedSteps.every((c) => c);
                  final stepDuration = subTask.estimatedDuration;
                  
                  // Calculate progress for this specific step
                  double stepProgress = 0.0;
                  // If checked, it's done (full progress? or just greyed out). Usually done = 1.0.
                  if (isChecked) {
                    stepProgress = 1.0;
                  } else if (isActive) {
                     final totalSec = stepDuration.inSeconds;
                     if (totalSec > 0) {
                       stepProgress = 1.0 - (_currentStepRemaining.inSeconds / totalSec);
                     }
                  }

                  return InkWell(
                      onTap: () {
                      // Haptic feedback for step toggle
                      HapticHelper(ref).selectionClick();
                      
                      setState(() {
                        final oldActiveIndex = _forceActiveStepIndex;
                        bool wasChecked = _completedSteps[index];
                        _completedSteps[index] = !wasChecked;
                        
                        // Extra haptic for completing a step
                        if (!wasChecked) {
                          HapticHelper(ref).mediumImpact();
                          
                          // If user manually checked a step, move force index to next unchecked
                          // ONLY if we are checking the currently active step or a future one.
                          // If we check a past step, we probably just forgot to check it, so don't move focus.
                          if (index >= _forceActiveStepIndex) {
                            // Find next unchecked step
                            int nextUnchecked = -1;
                            for (int i = 0; i < _completedSteps.length; i++) {
                              if (!_completedSteps[i]) {
                                nextUnchecked = i;
                                break;
                              }
                            }
                            if (nextUnchecked != -1) {
                              _forceActiveStepIndex = nextUnchecked;
                            }
                          }
                        }
                        
                        // Update timer and Live Activity when step changes
                        if (oldActiveIndex != _forceActiveStepIndex) {
                          _initCurrentStepTimer();
                        }
                        
                        // Always update Live Activity when a step is completed
                        // to ensure Dynamic Island shows the latest state
                        if (!wasChecked && _forceActiveStepIndex < widget.task.subTasks.length) {
                           ref.read(notificationServiceProvider).updateTaskProgress(
                             widget.task.subTasks[_forceActiveStepIndex].title, 
                             0.0,
                             startTime: DateTime.now(),
                             endTime: _stepEndTime,
                             currentStepIndex: _forceActiveStepIndex,
                           );
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        // Dark mode: use dark greys instead of white
                        color: isDark 
                            ? (isChecked ? Colors.grey[900] : (isActive ? const Color(0xFF1C1C1E) : Colors.grey[900]!.withOpacity(0.6)))
                            : (isChecked ? Colors.grey[50] : (isActive ? Colors.white : Colors.white.withOpacity(0.6))),
                        border: Border.all(
                          color: isDark 
                              ? (isActive ? Colors.white : (isChecked ? Colors.transparent : Colors.white24))
                              : (isActive ? Colors.black : (isChecked ? Colors.transparent : Colors.black12)),
                          width: isActive ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isActive ? [
                          BoxShadow(
                            color: isDark 
                                ? Colors.white.withOpacity(0.05) 
                                : Colors.black.withOpacity(0.1), 
                            blurRadius: 8, 
                            offset: const Offset(0, 4)
                          )
                        ] : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                               Container(
                                 width: 24,
                                 height: 24,
                                 decoration: BoxDecoration(
                                   color: isChecked 
                                       ? (isDark ? Colors.white : Colors.black) 
                                       : Colors.transparent,
                                   border: Border.all(
                                     color: isDark ? Colors.white : Colors.black, 
                                     width: 2
                                   ),
                                   shape: BoxShape.circle,
                                 ),
                                 child: isChecked 
                                    ? Icon(Icons.check, size: 16, color: isDark ? Colors.black : Colors.white)
                                    : null,
                               ),
                               const SizedBox(width: 16),
                               Expanded(
                                 child: Text(
                                   subTask.title,
                                   style: TextStyle(
                                     fontSize: 16,
                                     fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                     decoration: isChecked ? TextDecoration.lineThrough : null,
                                     color: isChecked 
                                         ? Colors.grey 
                                         : (isDark ? Colors.white : Colors.black),
                                   ),
                                 ),
                               ),
                               // Show Timer if Active
                               if (isActive)
                                 Text(
                                   "${_currentStepRemaining.inMinutes}:${(_currentStepRemaining.inSeconds % 60).toString().padLeft(2, '0')}",
                                   style: TextStyle(
                                     fontWeight: FontWeight.bold, 
                                     fontFamily: 'Courier',
                                     color: isDark ? Colors.white : Colors.black,
                                   ),
                                 ),
                            ],
                          ),
                          if (isActive) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: stepProgress,
                                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                                valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : Colors.black),
                                minHeight: 6,
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Actions
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Finish Button
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: allChecked ? _completeMission : null, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : Colors.black,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(AppStrings.get('complete_mission', ref.watch(localeProvider)), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Small Cancel
                    TextButton(
                      onPressed: _handleCancel,
                      child: Text(
                        AppStrings.get('abort_mission', ref.watch(localeProvider)),
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rescheduleTask() async {
     final locale = ref.read(localeProvider);
     final isDark = Theme.of(context).brightness == Brightness.dark;
     
     // Show Time Picker
     final now = DateTime.now();
     // If current start is in future, use that, else now
     final initial = widget.task.scheduledStart.isAfter(now) ? widget.task.scheduledStart : now;
     DateTime selectedTime = initial.add(const Duration(minutes: 30)); 
     
     await showModalBottomSheet(
       context: context,
       backgroundColor: Theme.of(context).cardColor,
       builder: (bottomSheetContext) => Container(
         height: 300,
         padding: const EdgeInsets.all(16),
         child: Column(
           children: [
             Text(
               AppStrings.get('reschedule', locale), 
               style: TextStyle(
                 fontWeight: FontWeight.bold, 
                 fontSize: 18,
                 color: isDark ? Colors.white : Colors.black,
               ),
             ),
             const SizedBox(height: 16),
             Expanded(
               child: CupertinoTheme(
                 data: CupertinoThemeData(
                   brightness: isDark ? Brightness.dark : Brightness.light,
                   textTheme: CupertinoTextThemeData(
                     dateTimePickerTextStyle: TextStyle(
                       color: isDark ? Colors.white : Colors.black,
                       fontSize: 20,
                       
                     ),
                   ),
                 ),
                 child: CupertinoDatePicker(
                   mode: CupertinoDatePickerMode.dateAndTime,
                   initialDateTime: selectedTime,
                   minimumDate: now,
                   use24hFormat: true,
                   onDateTimeChanged: (val) {
                     // Haptic feedback on scroll
                     HapticHelper(ref).selectionClick();
                     selectedTime = val;
                   },
                 ),
               ),
             ),
             const SizedBox(height: 16),
             SizedBox(
               width: double.infinity,
               child: ElevatedButton(
                 onPressed: () => Navigator.pop(bottomSheetContext),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: isDark ? Colors.white : Colors.black,
                   foregroundColor: isDark ? Colors.black : Colors.white,
                 ),
                 child: Text(AppStrings.get('save', locale)),
               ),
             )
           ],
         ),
       ),
     );
     
     // Update Task
     final updatedTask = widget.task.copyWith(scheduledStart: selectedTime);
     ref.read(taskRepositoryProvider).updateTask(updatedTask);
     
     // Reset notification state so scheduler can trigger again at new time
     ref.read(taskSchedulerServiceProvider).resetTaskNotification(widget.task.id);
     
     // End Activity
     ref.read(notificationServiceProvider).endActivity();

     if (mounted) Navigator.pop(context); // Exit Screen
  }

  Future<void> _showEncouragementOverlay() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false, // Full screen immersive
      builder: (_) => const _EncouragementOverlay(),
    );
     // After overlay closes, we stay on screen? Or popping?
     // User request: "If click not complete give animation and quote"
     // Then probably allow them to "Try again" (stay) or "Leave".
     // My previous code: pop context. 
     // Let's pop the screen after encouragement to be consistent with "Times up -> No".
     if (mounted) Navigator.of(context).pop(); 
  }
}

class _SuccessOverlay extends ConsumerStatefulWidget {
  final Duration actualDuration;
  final Duration diff;

  const _SuccessOverlay({
    required this.actualDuration,
    required this.diff,
  });

  @override
  ConsumerState<_SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends ConsumerState<_SuccessOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
        
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));

    _controller.forward();
    
    // Auto close slightly faster for minimalism
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    String t(String key) => AppStrings.get(key, locale);
    
    // Theme context
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final txtColor = isDark ? Colors.white : Colors.black;
    
    final screenSize = MediaQuery.of(context).size;
    final isEarly = widget.diff.isNegative;
    final absDiff = widget.diff.abs();
    
    final formattedActual = "${widget.actualDuration.inMinutes}m ${widget.actualDuration.inSeconds % 60}s";
    final formattedDiff = "${absDiff.inMinutes}m ${absDiff.inSeconds % 60}s";

    return Material(
      color: Colors.transparent,
      child: Container(
        width: screenSize.width,
        height: screenSize.height,
        color: bgColor.withOpacity(0.95), // Minimalist high opacity background
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Minimal Icon Circle
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: txtColor, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isEarly ? Icons.bolt_outlined : Icons.hourglass_empty,
                        color: txtColor,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Main Status
                    Text(
                      (isEarly ? t('feedback_early') : t('feedback_late')).toUpperCase(),
                      style: TextStyle(
                        color: txtColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4.0, // Airy letter spacing
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                       isEarly ? t('feedback_early_desc') : t('feedback_late_desc'),
                       style: TextStyle(
                         color: txtColor.withOpacity(0.6),
                         fontSize: 14,
                       ),
                       textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 60),

                    // Clean Stat Display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formattedDiff,
                          style: TextStyle(
                            color: txtColor,
                            fontSize: 48,
                            fontWeight: FontWeight.w300, // Light weight for elegance
                            fontFamily: 'Courier',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10, left: 8),
                          child: Text(
                             isEarly ? "SAVED" : "EXTRA", // Ideally localized
                             style: TextStyle(
                               color: txtColor.withOpacity(0.5),
                               fontSize: 12,
                               fontWeight: FontWeight.bold,
                               letterSpacing: 1.0,
                             ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Detailed Small Stats
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      decoration: BoxDecoration(
                        border: Border.all(color: txtColor.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: 14, color: txtColor.withOpacity(0.5)),
                          const SizedBox(width: 8),
                          Text(
                            "${t('total_time')}: $formattedActual",
                            style: TextStyle(
                               color: txtColor.withOpacity(0.7),
                               fontSize: 14,
                               fontFamily: 'Courier',
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
        ),
      ),
    );
  }
}


class _EncouragementOverlay extends ConsumerStatefulWidget {
  const _EncouragementOverlay();

  @override
  ConsumerState<_EncouragementOverlay> createState() => _EncouragementOverlayState();
}

class _EncouragementOverlayState extends ConsumerState<_EncouragementOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
        
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5)));

    _controller.forward();
    
    // Auto close after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    String t(String key) => AppStrings.get(key, locale);
    
    // Get full screen size including status bar and navigation bar
    final screenSize = MediaQuery.of(context).size;

    // Full-screen overlay covering status bar and navigation bar
    return Material(
      color: Colors.transparent,
      child: Container(
        width: screenSize.width,
        height: screenSize.height,
        color: Colors.black.withOpacity(0.95),
        child: Center(
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     const Icon(Icons.favorite, color: Colors.pinkAccent, size: 80),
                     const SizedBox(height: 24),
                     Text(
                       t('encourage_title'),
                       textAlign: TextAlign.center,
                       style: const TextStyle(
                         color: Colors.white,
                         fontSize: 32,
                         fontWeight: FontWeight.w900,
                         letterSpacing: 1.0,
                         height: 1.2
                       ),
                     ),
                     const SizedBox(height: 16),
                     Text(
                       t('encourage_content'),
                       textAlign: TextAlign.center,
                       style: TextStyle(
                         color: Colors.white.withOpacity(0.8),
                         fontSize: 18,
                       ),
                     ),
                     const SizedBox(height: 32),
                     TextButton(
                       onPressed: () => Navigator.of(context).pop(),
                       child: Text(t('ok_cool'), style: const TextStyle(color: Colors.white70)),
                     )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
