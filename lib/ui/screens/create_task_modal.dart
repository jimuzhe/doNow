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
import '../widgets/custom_loading_overlay.dart';
import '../widgets/subtask_editor_sheet.dart';
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
    // Dynamic height with keyboard support
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
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
                  ? _buildStep1() 
                  : _buildStep2(),
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

  Widget _buildStep1() {
    return Padding(
      key: const ValueKey<int>(0),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t('step_1'), style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(t('what_to_do'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 20),
            decoration: const InputDecoration(
              hintText: "...",
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.black26),
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
          
          // Duration section with AI button
          Row(
            children: [
              Expanded(
                child: Text(t('how_long'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              // AI Estimate Button
              TextButton.icon(
                onPressed: _isAIEstimating ? null : _onAIEstimate,
                icon: _isAIEstimating 
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
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
            height: 100,
            child: CupertinoTimerPicker(
              key: ValueKey(_selectedDuration), // Force rebuild when duration changes programmatically
              mode: CupertinoTimerPickerMode.hm,
              initialTimerDuration: _selectedDuration,
              onTimerDurationChanged: (val) {
                 if (val.inMinutes >= 1) {
                   setState(() => _selectedDuration = val);
                   // Invalidate cache if duration changed
                   if (_cachedAIResult != null && _lastAIDuration != val) {
                     setState(() {
                       _cachedAIResult = null;
                     });
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
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(t('next'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('enter_title_first')), backgroundColor: Colors.orange),
      );
      return;
    }
    
    setState(() => _isAIEstimating = true);
    HapticHelper(ref).lightImpact();
    
    try {
      final aiService = ref.read(aiServiceProvider);
      final result = await aiService.estimateAndDecompose(title);
      
      if (mounted) {
        setState(() {
          _cachedAIResult = result;
          _lastAITitle = title;
          _lastAIDuration = result.estimatedDuration;
          _selectedDuration = result.estimatedDuration;
          _isAIEstimating = false;
        });
        
        HapticHelper(ref).mediumImpact();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t('estimated')}: ${result.estimatedDuration.inMinutes} ${t('minutes')}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAIEstimating = false);
        
        String errorMsg = t('error_ai_generic');
        if (e.toString().contains('security_audit_fail')) {
          errorMsg = t('security_error');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStep2() {
    return Padding(
      key: const ValueKey<int>(1),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t('step_2'), style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(t('when_to_start'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          
          SizedBox(
            height: 120,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: _selectedTime,
              use24hFormat: true,
              onDateTimeChanged: (val) {
                // HapticFeedback.selectionClick();
                setState(() => _selectedTime = val);
              },
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Repeat Chips (Multi-select 1-7)
          Text(t('repeat'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (index) {
               // 0 -> Mon(1), 6 -> Sun(7)
               final dayNum = index + 1;
               final isSelected = _selectedDays.contains(dayNum);
               return _DayChip(
                 label: t('day_$dayNum'), 
                 selected: isSelected, 
                 onTap: () {
                   setState(() {
                     if (isSelected) {
                       _selectedDays.remove(dayNum);
                     } else {
                       _selectedDays.add(dayNum);
                     }
                   });
                 }
               );
            }),
          ),
          
          if (_selectedDays.isNotEmpty)
             Padding(
               padding: const EdgeInsets.only(top: 8.0),
               child: Text(
                 t('daily'), // Simplify logic
                 style: const TextStyle(color: Colors.grey, fontSize: 12),
               ),
             ),

          const SizedBox(height: 32),
          
          // Action Buttons: "Now" and "Save (Later)"
          Row(
            children: [
               Expanded(
                 child: OutlinedButton(
                   onPressed: () => _finish(now: true),
                   style: OutlinedButton.styleFrom(
                     foregroundColor: Colors.black,
                     side: const BorderSide(color: Colors.black),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                     minimumSize: const Size(0, 50),
                   ),
                   child: Text(t('now'), style: const TextStyle(fontWeight: FontWeight.bold)),
                 ),
               ),
               const SizedBox(width: 12),
               Expanded(
                 flex: 2,
                 child: ElevatedButton(
                   onPressed: () => _finish(now: false),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.black,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                     minimumSize: const Size(0, 50),
                   ),
                   child: Text(t('save'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                 ),
               ),
            ],
          ),
          Center(
            child: TextButton(
               onPressed: () => setState(() => _currentStep = 0),
               child: Text(t('back'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
          setState(() {
            _aiFuture = aiService.decomposeTask(title, _selectedDuration);
          });
      }
    }
    
    // Haptic
    HapticHelper(ref).lightImpact();

    setState(() {
      _currentStep = 1;
    });
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('time_in_past')),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }
    
    // Use existing ID if editing, else new
    final taskId = widget.taskToEdit?.id ?? DateTime.now().toIso8601String();
    
    if (now) {
      try {
        showDialog(
           context: context,
           barrierDismissible: false,
           builder: (_) => CustomLoadingOverlay(message: t('generating'))
        );
        
        // Wait result
        final subTasks = await _aiFuture!;
        
        if (mounted) Navigator.pop(context); // Hide overlay

        if (subTasks.isEmpty) {
           throw Exception("Empty result");
        }

        // Show confirmation/edit sheet before starting
        if (mounted) {
          _showSubTaskConfirmation(
            taskId: taskId,
            title: title,
            subTasks: subTasks,
          );
        }
      } catch (e) {
        if (mounted) {
           Navigator.pop(context); 
           
           String errorMsg = t('error_ai_generic');
           if (e.toString().contains('security_audit_fail')) {
              errorMsg = t('security_error');
           }
           
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
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
            showDialog(
               context: context,
               barrierDismissible: false,
               builder: (_) => CustomLoadingOverlay(message: t('generating'))
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
            
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
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
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, 
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
