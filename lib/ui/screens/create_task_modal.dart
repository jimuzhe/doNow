import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'; // Haptics
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/subtask.dart';
import '../../data/models/task.dart';
import '../../data/providers.dart';
import '../../data/localization.dart';
import '../widgets/custom_loading_overlay.dart';
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
          ),
          
          const SizedBox(height: 24),
          
          Text(t('how_long'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
           SizedBox(
            height: 100,
            child: CupertinoTimerPicker(
              mode: CupertinoTimerPickerMode.hm,
              initialTimerDuration: _selectedDuration,
              onTimerDurationChanged: (val) {
                 if (val.inMinutes >= 1) {
                   // Debounce haptic to avoid buzzing on scroll
                   // HapticFeedback.selectionClick(); 
                   setState(() => _selectedDuration = val);
                 }
              },
            ),
          ),

          const SizedBox(height: 32),

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
    
    // Always regenerate AI if title or duration changed (for both new and edit)
    final needsRegeneration = widget.taskToEdit == null || 
        widget.taskToEdit!.title != title ||
        widget.taskToEdit!.totalDuration != _selectedDuration;
    
    if (needsRegeneration) {
        final aiService = ref.read(aiServiceProvider);
        setState(() {
          _aiFuture = aiService.decomposeTask(title, _selectedDuration);
        });
    }
    
    // Haptic
    HapticFeedback.lightImpact();

    setState(() {
      _currentStep = 1;
    });
  }

  Future<void> _finish({required bool now}) async {
    HapticFeedback.mediumImpact();
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

        final newTask = Task(
          id: taskId,
          title: title,
          totalDuration: _selectedDuration,
          scheduledStart: DateTime.now(), // Override to now
          subTasks: subTasks,
          isGenerating: false,
          repeatDays: _selectedDays.toList(),
        );
        
        final repo = ref.read(taskRepositoryProvider);
        if (widget.taskToEdit != null) {
          repo.updateTask(newTask);
        } else {
          repo.addTask(newTask);
        }
        
        if (mounted) {
           Navigator.pop(context); // Close Modal
           Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(task: newTask)));
        }
      } catch (e) {
        if (mounted) {
           Navigator.pop(context); 
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('error_ai_generic')), backgroundColor: Colors.red));
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('error_ai_generic')), backgroundColor: Colors.red));
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
             // Handle error
          });
      }
    }
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
