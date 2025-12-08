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
import '../../data/localization.dart';
import '../../utils/haptic_helper.dart';


class TaskDetailScreen extends ConsumerStatefulWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late Timer _timer;
  late Duration _remainingTime;
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
    _remainingTime = widget.task.totalDuration;
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
  }

  void _initCurrentStepTimer() {
    if (_forceActiveStepIndex >= 0 && _forceActiveStepIndex < widget.task.subTasks.length) {
      _currentStepRemaining = widget.task.subTasks[_forceActiveStepIndex].estimatedDuration;
    } else {
      _currentStepRemaining = Duration.zero;
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
      HapticFeedback.mediumImpact();
      
      setState(() {
        _completedSteps[activeIdx] = true;
        
        // Move to next step
        if (_forceActiveStepIndex < widget.task.subTasks.length - 1) {
          _forceActiveStepIndex++;
        }
        _initCurrentStepTimer();
        
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
     await ref.read(notificationServiceProvider).startTaskActivity(widget.task);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // 1. Global Timer
          if (_remainingTime.inSeconds > 0) {
            _remainingTime = _remainingTime - const Duration(seconds: 1);
          } else {
            _timer.cancel();
            _showTimeoutDialog();
            return;
          }

          // 2. Step Timer
          final activeIdx = _activeStepIndex;
          if (activeIdx != -1) {
             if (_currentStepRemaining.inSeconds > 0) {
               _currentStepRemaining -= const Duration(seconds: 1);
             }
             
             // AUTO-ADVANCE: When step timer reaches 0, move to next step WITHOUT marking as complete
             // The user must manually check the step to mark it complete
             if (_currentStepRemaining.inSeconds <= 0) {
               // Move to next step if there is one
               if (_forceActiveStepIndex < widget.task.subTasks.length - 1) {
                 _forceActiveStepIndex++;
                 _initCurrentStepTimer(); // Initialize timer for next step
               }
               // If this is the last step and its timer ended, just wait for total timer
               // Don't auto-complete - let the total timer handle it via _showTimeoutDialog
             }
             
             // Update Live Activity
             if (_forceActiveStepIndex >= 0 && _forceActiveStepIndex < widget.task.subTasks.length) {
               final stepTotal = widget.task.subTasks[_forceActiveStepIndex].estimatedDuration.inSeconds;
               final progress = stepTotal > 0 
                   ? 1.0 - (_currentStepRemaining.inSeconds / stepTotal)
                   : 1.0;
                   
               ref.read(notificationServiceProvider).updateTaskProgress(
                 widget.task.subTasks[_forceActiveStepIndex].title, 
                 progress
               );
             }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    if (_timer.isActive) _timer.cancel();
    _actionSubscription?.cancel();
    
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
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
    
    // 1. Mark as completed in repo
    final repo = ref.read(taskRepositoryProvider);
    final completedTask = widget.task.copyWith(isCompleted: true);
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
      builder: (_) => const _SuccessOverlay(),
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
    final minutes = _remainingTime.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remainingTime.inSeconds % 60).toString().padLeft(2, '0');
    final formattedTime = "$minutes:$seconds";

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
            color: _remainingTime.inMinutes < 5 ? Colors.red : (isDark ? Colors.white : Colors.black),
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier', // Monospaced for timer
            fontSize: 24,
          ),
        ),
      ),
      body: Column(
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
                    HapticFeedback.selectionClick();
                    
                    setState(() {
                      bool wasChecked = _completedSteps[index];
                      _completedSteps[index] = !wasChecked;
                      
                      // Extra haptic for completing a step
                      if (!wasChecked) {
                        HapticFeedback.mediumImpact();
                        
                        // If user manually checked a step, move force index to next unchecked
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
                      
                      // Update timer for the current active step
                      _initCurrentStepTimer();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isChecked ? Colors.grey[50] : (isActive ? Colors.white : Colors.white.withOpacity(0.6)),
                      border: Border.all(
                        color: isActive ? Colors.black : (isChecked ? Colors.transparent : Colors.black12),
                        width: isActive ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isActive ? [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
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
                                 color: isChecked ? Colors.black : Colors.transparent,
                                 border: Border.all(color: Colors.black, width: 2),
                                 shape: BoxShape.circle,
                               ),
                               child: isChecked 
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
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
                                   color: isChecked ? Colors.grey : Colors.black,
                                 ),
                               ),
                             ),
                             // Show Timer if Active
                             if (isActive)
                               Text(
                                 "${_currentStepRemaining.inMinutes}:${(_currentStepRemaining.inSeconds % 60).toString().padLeft(2, '0')}",
                                 style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Courier'),
                               ),
                          ],
                        ),
                        if (isActive) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: stepProgress,
                              backgroundColor: Colors.grey[100],
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
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
                     HapticFeedback.selectionClick();
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
  const _SuccessOverlay();

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
        vsync: this, duration: const Duration(milliseconds: 800));
        
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5)));

    _controller.forward();
    
    // Auto close after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified, color: Colors.white, size: 80),
                  const SizedBox(height: 24),
                  Text(
                    t('mission_accomplished'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      height: 1.2
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('great_work'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 18,
                    ),
                  ),
                ],
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
