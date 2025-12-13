import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../data/models/task.dart';
import '../../data/models/subtask.dart';
import '../../data/models/routine.dart';
import '../../data/localization.dart';
import '../../data/providers.dart';
import '../screens/task_detail_screen.dart';
import '../screens/decision_screen.dart';
import '../screens/create_task_modal.dart';
import 'subtask_editor_sheet.dart';
import 'responsive_center.dart';

class TaskActionSheet extends ConsumerWidget {
  final Task task;

  const TaskActionSheet({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = ref.watch(localeProvider);
    String t(String key) => AppStrings.get(key, locale);

    // Modern Gradient Colors based on Theme
    final gradientColors = isDark 
      ? [const Color(0xFF2C3E50), const Color(0xFF000000)]
      : [const Color(0xFFFFFFFF), const Color(0xFFF0F2F5)];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40, 
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Task Title & Info
              Text(
                task.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              if (!task.isDecision && !task.isQuickFocus)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.access_time_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('HH:mm').format(task.scheduledStart),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      '${task.totalDuration.inMinutes} min',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 32),

              // Main Actions Grid
              Row(
                children: [
                  // Quick Focus Card
                  Expanded(
                    child: _ActionCard(
                      title: t('quick_focus'),
                      icon: Icons.play_arrow_rounded,
                      color: isDark ? Colors.white : Colors.black,
                      textColor: isDark ? Colors.black : Colors.white,
                      onTap: () {
                         Navigator.pop(context); // Close sheet
                         Navigator.push(context, MaterialPageRoute(
                           builder: (_) => TaskDetailScreen(task: task)
                         ));
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Decision Card
                  Expanded(
                    child: _ActionCard(
                      title: t('make_decision'),
                      icon: Icons.casino_outlined, // or switch_access_shortcut
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[100]!,
                      textColor: isDark ? Colors.white : Colors.black,
                      onTap: () {
                         Navigator.pop(context); // Close sheet
                         Navigator.push(context, MaterialPageRoute(
                           builder: (_) => DecisionScreen(initialText: task.title)
                         ));
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Secondary Actions
              Row(
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: [
                   TextButton.icon(
                     onPressed: () async {
                        // Close Action Sheet first
                        Navigator.pop(context);
                        
                        // Show CreateTaskModal for editing
                        final result = await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => CreateTaskModal(taskToEdit: task),
                        );

                        // Handle 'Start Now' result from Modal
                        if (result != null && result is Map && result['action'] == 'confirm_subtasks') {
                          if (!context.mounted) return;
                          
                          final taskId = result['taskId'];
                          final title = result['title'];
                          final subTasks = result['subTasks'] as List<SubTask>;
                          
                          // Calculate total duration
                          final totalDuration = Duration(minutes: subTasks.fold(0, (sum, st) => sum + st.estimatedDuration.inMinutes));
                          
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => SubTaskEditorSheet(
                              initialSubTasks: subTasks,
                              totalDuration: totalDuration,
                              showStartButton: true,
                              onSave: (editedSubTasks) {
                                 // Create and start task
                                 final newTask = Task(
                                   id: taskId,
                                   title: title,
                                   totalDuration: totalDuration,
                                   scheduledStart: DateTime.now(),
                                   subTasks: editedSubTasks,
                                   isGenerating: false,
                                   repeatDays: task.repeatDays, // Preserve repeat settings if logical
                                 );
                                 
                                 // Save to repo
                                 ref.read(taskRepositoryProvider).updateTask(newTask);
                                 
                                 // Navigate to detail
                                 Navigator.of(context).push(
                                    MaterialPageRoute(builder: (c) => TaskDetailScreen(task: newTask)),
                                 );
                              },
                            ),
                          );
                        }
                     }, 
                     icon: const Icon(Icons.edit_outlined, size: 18),
                     label: Text(t('edit')),
                     style: TextButton.styleFrom(foregroundColor: Colors.grey),
                   ),
                   Container(width: 1, height: 24, color: Colors.grey[300]),
                   TextButton.icon(
                     onPressed: () {
                        // Delete
                        ref.read(taskListProvider.notifier).removeTask(task.id);
                        Navigator.pop(context);
                     }, 
                     icon: const Icon(Icons.delete_outline, size: 18),
                     label: Text(t('delete')),
                     style: TextButton.styleFrom(foregroundColor: Colors.red),
                   ),
                   Container(width: 1, height: 24, color: Colors.grey[300]),
                   TextButton.icon(
                     onPressed: () {
                        // Save as Routine
                        final routine = Routine(
                          id: const Uuid().v4(),
                          title: task.title,
                          totalDuration: task.totalDuration,
                          subTasks: task.subTasks,
                        );
                        ref.read(routineListProvider.notifier).addRoutine(routine); // Using addRoutine
                        
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t('save_routine_success'))),
                        );
                     }, 
                     icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                     label: Text(t('save_as_routine')), // Localized string
                     style: TextButton.styleFrom(foregroundColor: Colors.blue),
                   ),
                 ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: textColor),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
