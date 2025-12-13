import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'; // Haptics
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/subtask.dart';
import '../../data/models/task.dart';
import '../../data/providers.dart';
import '../../data/localization.dart';
import '../../data/services/ai_service.dart'; // For AIEstimateResult
import '../../utils/haptic_helper.dart';
import '../../utils/snackbar_helper.dart';
import '../widgets/custom_loading_overlay.dart';
import '../widgets/subtask_editor_sheet.dart';
import '../widgets/routine_selector_sheet.dart';
import '../../data/models/routine.dart';
import 'task_detail_screen.dart';

class CreateTaskModal extends ConsumerStatefulWidget {
  final Task? taskToEdit;
  const CreateTaskModal({super.key, this.taskToEdit});

  @override
  ConsumerState<CreateTaskModal> createState() => _CreateTaskModalState();
}

class _CreateTaskModalState extends ConsumerState<CreateTaskModal> {
  int _currentStep = 0;
  
  // State
  final TextEditingController _titleController = TextEditingController();
  Duration _selectedDuration = const Duration(minutes: 60);
  DateTime _selectedTime = DateTime.now();
  final Set<int> _selectedDays = {}; // 1-7
  
  // Future for background AI
  Future<List<SubTask>>? _aiFuture; 
  
  // AI Estimation Cache
  AIEstimateResult? _cachedAIResult; // Cached result from "AI Estimate" button
  String? _lastAITitle; // Title when AI estimate was called (for cache invalidation)
  Duration? _lastAIDuration; // Duration when AI estimate was called
  bool _isAIEstimating = false; // Loading state for AI estimate button 

  @override
  void initState() {
    super.initState();
    if (widget.taskToEdit != null) {
      final t = widget.taskToEdit!;
      _titleController.text = t.title;
      _selectedDuration = t.totalDuration;
      _selectedTime = t.scheduledStart;
      _selectedDays.addAll(t.repeatDays);
      
      // If editing, we can treat existing subtasks as the "result"
      _aiFuture = Future.value(t.subTasks);
    }
  } 

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Dynamic height with keyboard support
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                 child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40, 
                  height: 4, 
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[600] : Colors.grey[300], 
                    borderRadius: BorderRadius.circular(2),
                  ),
                 ),
              ),
      
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: 0.0,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: _currentStep == 0 
                  ? _buildStep1(isDark) 
                  : _buildStep2(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String t(String key) {
    return AppStrings.get(key, ref.read(localeProvider));
  }

  Widget _buildStep1(bool isDark) {
    return Padding(
      key: const ValueKey<int>(0),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t('step_1'), style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(t('what_to_do'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          TextField(
            controller: _titleController,
            style: TextStyle(fontSize: 20, color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: "...",
              border: InputBorder.none,
              hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.black26),
            ),
            autofocus: true,
            onChanged: (_) {
              // Invalidate cache when title changes
              if (_cachedAIResult != null && _lastAITitle != _titleController.text.trim()) {
                setState(() {
                  _cachedAIResult = null;
                });
              }
            },
          ),
          
          const SizedBox(height: 24),

          // Routines Button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _showRoutineSelector,
              icon: const Icon(Icons.inventory_2_outlined, size: 16),
              label: Text(t('routines')),
              style: TextButton.styleFrom(
                 foregroundColor: Colors.orange,
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                 backgroundColor: Colors.orange.withOpacity(0.1),
              ),
            ),
          ),
          
          // Duration section with AI button
          Row(
            children: [
              Expanded(
                child: Text(t('how_long'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              ),
              // AI Estimate Button
              TextButton.icon(
                onPressed: _isAIEstimating ? null : _onAIEstimate,
                icon: _isAIEstimating 
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white : null))
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(_isAIEstimating ? t('estimating') : t('ai_estimate')),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 150,
            child: CupertinoTimerPicker(
              // Key forces rebuild when AI estimate updates the duration
              key: ValueKey(_selectedDuration.inMinutes),
              mode: CupertinoTimerPickerMode.hm,
              initialTimerDuration: _selectedDuration,
              onTimerDurationChanged: (val) {
                 // Don't call setState during scroll - let native picker handle momentum
                 // Just update the value directly
                 if (val.inMinutes >= 1) {
                   _selectedDuration = val;
                   // Invalidate cache if duration changed significantly
                   if (_cachedAIResult != null && _lastAIDuration != val) {
                     _cachedAIResult = null;
                   }
                 }
              },
            ),
          ),
          
          // Show cache status hint
          if (_cachedAIResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t('ai_ready'),
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _goToStep2,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(t('next'), style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
  
  /// AI Estimate: Get duration + subtasks in one call
  Future<void> _onAIEstimate() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      SnackBarHelper.showWarning(t('enter_title_first'));
      return;
    }
    
    setState(() => _isAIEstimating = true);
    HapticHelper(ref).lightImpact();
    
    try {
      final aiService = ref.read(aiServiceProvider);
      final locale = ref.read(localeProvider);
      final result = await aiService.estimateAndDecompose(title, locale: locale);
      
      if (mounted) {
        setState(() {
          _cachedAIResult = result;
          _lastAITitle = title;
          _lastAIDuration = result.estimatedDuration;
          _selectedDuration = result.estimatedDuration;
          _isAIEstimating = false;
        });
        
        HapticHelper(ref).mediumImpact();
        
        SnackBarHelper.showSuccess('${t('estimated')}: ${result.estimatedDuration.inMinutes} ${t('minutes')}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAIEstimating = false);
        
        String errorMsg = t('error_ai_generic');
        if (e.toString().contains('security_audit_fail')) {
          errorMsg = t('security_error');
        }
        
        SnackBarHelper.showError(errorMsg);
      }
    }
  }

  Widget _buildStep2(bool isDark) {
    return Padding(
      key: const ValueKey<int>(1),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t('step_2'), style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(t('when_to_start'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          
          SizedBox(
            height: 150,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: _selectedTime,
              use24hFormat: true,
              onDateTimeChanged: (val) {
                // Don't call setState during scroll - let native picker handle momentum
                _selectedTime = val;
              },
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Repeat Chips (Multi-select 1-7 with swipe support)
          Text(t('repeat'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 12),
          _SwipeableDaySelector(
            selectedDays: _selectedDays,
            isDark: isDark,
            t: t,
            onDayToggle: (dayNum) {
              setState(() {
                if (_selectedDays.contains(dayNum)) {
                  _selectedDays.remove(dayNum);
                } else {
                  _selectedDays.add(dayNum);
                }
              });
            },
            onDaySwipe: (dayNum) {
              setState(() {
                if (!_selectedDays.contains(dayNum)) {
                  _selectedDays.add(dayNum);
                }
              });
            },
          ),
          
          if (_selectedDays.isNotEmpty)
             Padding(
               padding: const EdgeInsets.only(top: 8.0),
               child: Text(
                 t('daily'), // Simplify logic
                 style: TextStyle(color: Colors.grey[500], fontSize: 12),
               ),
             ),

          const SizedBox(height: 32),
          
          // Single Save Button - smart detection for "now" vs "later"
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                minimumSize: const Size(0, 50),
              ),
              child: Text(
                t('save'), 
                style: TextStyle(
                  color: isDark ? Colors.black : Colors.white, 
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
               onPressed: () => setState(() => _currentStep = 0),
               child: Text(t('back'), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  void _goToStep2() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    
    // Check if we have a valid cached AI result
    final hasCachedResult = _cachedAIResult != null && 
        _cachedAIResult!.subTasks.isNotEmpty &&
        _lastAITitle == title &&
        _lastAIDuration == _selectedDuration;
    
    if (hasCachedResult) {
      // Use cached result - no need to call AI again
      setState(() {
        _aiFuture = Future.value(_cachedAIResult!.subTasks);
      });
    } else {
      // No valid cache - need to regenerate
      // Clear any stale cache
      _cachedAIResult = null;
      
      final needsRegeneration = widget.taskToEdit == null || 
          widget.taskToEdit!.title != title ||
          widget.taskToEdit!.totalDuration != _selectedDuration;
      
      if (needsRegeneration) {
          final aiService = ref.read(aiServiceProvider);
          final locale = ref.read(localeProvider);
          setState(() {
            _aiFuture = aiService.decomposeTask(title, _selectedDuration, locale: locale);
          });
      }
    }
    
    // Haptic
    HapticHelper(ref).lightImpact();

    setState(() {
      _currentStep = 1;
    });
  }

  // Smart save handler - determines if task should start immediately
  void _handleSave() {
    final now = DateTime.now();
    final scheduledDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    
    // Calculate time difference in minutes
    final diffInMinutes = scheduledDateTime.difference(now).inMinutes;
    
    // If scheduled time is within 1 minute of now (or in the past), treat as "start now"
    final isImmediate = diffInMinutes <= 1 && diffInMinutes >= -2;
    
    _finish(now: isImmediate);
  }

  Future<void> _finish({required bool now}) async {
    HapticHelper(ref).mediumImpact();
    final title = _titleController.text.trim();
    
    // Validate: For non-repeating tasks saved for later, time must not be in the past
    if (!now && _selectedDays.isEmpty) {
      final scheduledDateTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      
      if (scheduledDateTime.isBefore(DateTime.now())) {
        SnackBarHelper.showWarning(t('time_in_past'));
        return;
      }
    }
    
    // Use existing ID if editing, else new
    final taskId = widget.taskToEdit?.id ?? DateTime.now().toIso8601String();
    
    if (now) {
      try {
        showGeneralDialog(
           context: context,
           barrierDismissible: false,
           barrierColor: Colors.white,
           pageBuilder: (_, __, ___) => CustomLoadingOverlay(message: t('generating')),
         );
        
        // Wait result
        final subTasks = await _aiFuture!;
        
        if (mounted) Navigator.pop(context); // Hide overlay

        if (subTasks.isEmpty) {
           throw Exception("Empty result");
        }

        // Return to HomeScreen to show confirmation sheet
        if (mounted) {
          Navigator.pop(context, {
            'action': 'confirm_subtasks',
            'taskId': taskId,
            'title': title,
            'subTasks': subTasks,
          });
        }
      } catch (e) {
        if (mounted) {
           Navigator.pop(context); 
           
           String errorMsg = t('error_ai_generic');
           if (e.toString().contains('security_audit_fail')) {
              errorMsg = t('security_error');
           }
           
           SnackBarHelper.showError(errorMsg);
        }
      }
    } else {
      // "Later" / Save
      
      // For editing, wait for new AI result if title/duration changed
      if (widget.taskToEdit != null) {
        try {
          // Show loading if AI is regenerating
          final needsRegeneration = widget.taskToEdit!.title != title ||
              widget.taskToEdit!.totalDuration != _selectedDuration;
          
          List<SubTask> finalSubTasks = widget.taskToEdit!.subTasks;
          
          if (needsRegeneration && _aiFuture != null) {
            showGeneralDialog(
               context: context,
               barrierDismissible: false,
               barrierColor: Colors.white,
               pageBuilder: (_, __, ___) => CustomLoadingOverlay(message: t('generating')),
             );
            
            final newSubTasks = await _aiFuture!;
            if (mounted) Navigator.pop(context);
            
            if (newSubTasks.isNotEmpty) {
              finalSubTasks = newSubTasks;
            }
          }
          
          final updatedTask = widget.taskToEdit!.copyWith(
             title: title,
             totalDuration: _selectedDuration,
             scheduledStart: _selectedTime,
             subTasks: finalSubTasks,
             repeatDays: _selectedDays.toList(),
          );
          ref.read(taskRepositoryProvider).updateTask(updatedTask);
          if (mounted) Navigator.pop(context);
        } catch (e) {
          if (mounted) {
            Navigator.pop(context);
            
            String errorMsg = t('error_ai_generic');
            if (e.toString().contains('security_audit_fail')) {
               errorMsg = t('security_error');
            }
            
            SnackBarHelper.showError(errorMsg);
          }
        }
      } else {
          // New Task Logic
          Navigator.pop(context);
          
          final pendingTask = Task(
              id: taskId,
              title: title,
              totalDuration: _selectedDuration,
              scheduledStart: _selectedTime,
              subTasks: [],
              isGenerating: true,
              repeatDays: _selectedDays.toList(),
          );
          
          final repo = ref.read(taskRepositoryProvider);
          repo.addTask(pendingTask);
          
          _aiFuture!.then((result) {
             if (result.isEmpty) throw Exception("Empty");
             final completedTask = pendingTask.copyWith(
               subTasks: result, 
               isGenerating: false
             );
             repo.updateTask(completedTask);
          }).catchError((e) {
             // Stop spinning on error
             final failedTask = pendingTask.copyWith(isGenerating: false);
             repo.updateTask(failedTask);
          });
      }
    }
  }
  
  /// Show subtask confirmation/edit sheet before starting task
  void _showSubTaskConfirmation({
    required String taskId,
    required String title,
    required List<SubTask> subTasks,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SubTaskEditorSheet(
        initialSubTasks: subTasks,
        totalDuration: _selectedDuration,
        showStartButton: true,
        onSave: (editedSubTasks) {
          // Create and start the task with edited subtasks
          final newTask = Task(
            id: taskId,
            title: title,
            totalDuration: _selectedDuration,
            scheduledStart: DateTime.now(),
            subTasks: editedSubTasks,
            isGenerating: false,
            repeatDays: _selectedDays.toList(),
          );
          
          final repo = ref.read(taskRepositoryProvider);
          if (widget.taskToEdit != null) {
            repo.updateTask(newTask);
          } else {
            repo.addTask(newTask);
          }
          
          // Close modal and navigate to task detail
          Navigator.pop(context); // Close CreateTaskModal
          Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(task: newTask)));
        },
      ),
    );
  }

  void _showRoutineSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RoutineSelectorSheet(
        onSelect: (routine) {
          Navigator.pop(context); // Close sheet
          
          setState(() {
            _titleController.text = routine.title;
            _selectedDuration = routine.totalDuration;
            
            // Treat routine subtasks as cached result
            _cachedAIResult = AIEstimateResult(
              estimatedDuration: routine.totalDuration,
              subTasks: routine.subTasks,
            );
            _lastAITitle = routine.title;
            _lastAIDuration = routine.totalDuration;
          });
          
          HapticHelper(ref).mediumImpact();
        },
      ),
    );
  }
}

// Swipeable Day Selector with multi-select support
class _SwipeableDaySelector extends StatefulWidget {
  final Set<int> selectedDays;
  final bool isDark;
  final String Function(String) t;
  final Function(int) onDayToggle;
  final Function(int) onDaySwipe;

  const _SwipeableDaySelector({
    required this.selectedDays,
    required this.isDark,
    required this.t,
    required this.onDayToggle,
    required this.onDaySwipe,
  });

  @override
  State<_SwipeableDaySelector> createState() => _SwipeableDaySelectorState();
}

class _SwipeableDaySelectorState extends State<_SwipeableDaySelector> {
  final List<GlobalKey> _chipKeys = List.generate(7, (_) => GlobalKey());
  int? _lastSwipedDay;
  bool _isSwiping = false;

  void _handlePanUpdate(DragUpdateDetails details) {
    _isSwiping = true;
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    
    final localPosition = details.localPosition;
    
    for (int i = 0; i < 7; i++) {
      final key = _chipKeys[i];
      final RenderBox? chipBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (chipBox == null) continue;
      
      final chipPosition = chipBox.localToGlobal(Offset.zero, ancestor: box);
      final chipSize = chipBox.size;
      
      final rect = Rect.fromLTWH(
        chipPosition.dx,
        chipPosition.dy,
        chipSize.width,
        chipSize.height,
      );
      
      if (rect.contains(localPosition)) {
        final dayNum = i + 1;
        if (_lastSwipedDay != dayNum) {
          _lastSwipedDay = dayNum;
          widget.onDaySwipe(dayNum);
        }
        break;
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _isSwiping = false;
    _lastSwipedDay = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final dayNum = index + 1;
          final isSelected = widget.selectedDays.contains(dayNum);
          return GestureDetector(
            key: _chipKeys[index],
            onTap: () => widget.onDayToggle(dayNum),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? (widget.isDark ? Colors.white : Colors.black)
                    : (widget.isDark ? Colors.grey[800] : Colors.grey[100]),
                shape: BoxShape.circle,
              ),
              child: Text(
                widget.t('day_$dayNum'),
                style: TextStyle(
                  color: isSelected
                      ? (widget.isDark ? Colors.black : Colors.white)
                      : (widget.isDark ? Colors.white : Colors.black),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
