import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../data/models/task.dart';
import '../../data/localization.dart';
import '../../data/providers.dart';
import 'task_detail_screen.dart';
import 'create_task_modal.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Slogans to rotate or pick randomly
  final String _slogan = "Action beats anxiety.";

  @override
  Widget build(BuildContext context) {
    // Watch the list of tasks directly from the StateProvider
    final allTasks = ref.watch(taskListProvider);
    final now = DateTime.now();

    // Filter logic:
    // 1. Not Completed
    // 2. Not Abandoned
    // 3. If Time Passed (e.g. 12h past start) AND Not Repeating -> Hide
    final tasks = allTasks.where((t) {
      if (t.isCompleted) return false;
      if (t.isAbandoned) return false; // Hide abandoned tasks
      
      final endTime = t.scheduledStart.add(t.totalDuration);
      if (endTime.isBefore(now) && t.repeatDays.isEmpty) {
        return false; // Expired and not repeating
      }
      return true;
    }).toList();

    final locale = ref.watch(localeProvider);
    String t(String key) => AppStrings.get(key, locale);
    final slogan = locale == 'zh' ? AppStrings.get('slogan', locale) : _slogan;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header with Slogan (No Clock)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         t('do_now'),
                         style: TextStyle(
                           fontSize: 28,
                           fontWeight: FontWeight.w900,
                           letterSpacing: -1.0,
                           color: isDark ? Colors.white : Colors.black,
                         ),
                       ),
                       const SizedBox(height: 4),
                       Text(
                         slogan.toUpperCase(),
                         style: TextStyle(
                           fontSize: 12,
                           fontWeight: FontWeight.w600,
                           letterSpacing: 2.0,
                           color: isDark ? Colors.white54 : Colors.grey[400],
                         ),
                       ),
                     ],
                   ),
                   IconButton(
                      onPressed: () => _showTaskModal(context),
                      icon: Icon(Icons.add_circle, size: 36, color: isDark ? Colors.white : Colors.black),
                   ),
                ],
              ),
            ),

            // 2. Task List with Slides
            Expanded(
              child: tasks.isEmpty
                  ? _buildEmptyState(t)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return _SlidableTaskCard(task: task);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String Function(String) t) {
    return Center(
      child: GestureDetector(
        onTap: () => _showTaskModal(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 64, color: Colors.grey[200]),
            const SizedBox(height: 16),
            Text(
              t('tap_to_start'),
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskModal(BuildContext context, {Task? task}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTaskModal(taskToEdit: task),
    );
  }
}

class _SlidableTaskCard extends ConsumerWidget {
  final Task task;

  const _SlidableTaskCard({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = ref.watch(localeProvider);
    String t(String key) => AppStrings.get(key, locale);

    if (task.isGenerating) {
       return Container(
         margin: const EdgeInsets.only(bottom: 16),
         padding: const EdgeInsets.all(24),
         decoration: BoxDecoration(
           color: Theme.of(context).cardColor,
           borderRadius: BorderRadius.circular(16),
           border: Border.all(color: isDark ? Colors.transparent : Colors.grey[100]!),
         ),
         child: Row(
           children: [
             SizedBox(
               width: 24, height: 24, 
               child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white : Colors.black),
             ),
             const SizedBox(width: 16),
             Expanded(
               child: Text(
                 "AI is crafting '${task.title}'...", 
                 style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)
               ),
             ),
           ],
         ),
       );
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Slidable(
        key: ValueKey(task.id),
        // Swipe to right -> Shows Execute (Green)
        startActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (context) {
                // Execute Now
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (c) => TaskDetailScreen(task: task)),
                );
              },
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              icon: Icons.play_arrow,
              label: t('slide_do'),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
             SlidableAction(
              onPressed: (context) {
                 // Open Edit Modal
                 // We need to access the parent screen's method or pass a callback, 
                 // but since we are in the same file, we can't easily access _HomeScreenState method from here.
                 // Refactor: Pass onEdit callback or use global key? 
                 // Simplest: Just use showModalBottomSheet again here duplicate logic, OR make this method static/public?
                 // Or better: Just show the modal directly here.
                 
                 showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => CreateTaskModal(taskToEdit: task),
                  );
              },
              backgroundColor: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              foregroundColor: isDark ? Colors.white : Colors.black,
              icon: Icons.edit_calendar,
              label: t('slide_edit'),
            ),
          ],
        ),
        // Swipe to left -> Show Delete
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (context) {
                // Delete Logic with Provider
                ref.read(taskListProvider.notifier).removeTask(task.id);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task deleted')),
                );
              },
              backgroundColor: Colors.red[50]!,
              foregroundColor: Colors.red,
              icon: Icons.delete_outline,
              label: t('slide_drop'),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Big Time
              Text(
                DateFormat('HH:mm').format(task.scheduledStart),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w200,
                  letterSpacing: -1,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(width: 24),
              
              // Divider
              Container(width: 1, height: 40, color: isDark ? Colors.white24 : Colors.grey[200]),
              const SizedBox(width: 24),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${task.totalDuration.inMinutes} min • ${task.subTasks.length} steps',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
