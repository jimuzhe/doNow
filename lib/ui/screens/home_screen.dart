import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../data/models/task.dart';
import '../../data/models/subtask.dart';
import '../../data/models/routine.dart';
import '../../data/localization.dart';
import '../../data/providers.dart';
import '../../utils/haptic_helper.dart';
import 'task_detail_screen.dart';
import 'create_task_modal.dart';
import 'decision_screen.dart';
import 'quick_focus_screen.dart';
import 'venting_screen.dart';
import '../widgets/responsive_center.dart';
import '../widgets/subtask_editor_sheet.dart';
import '../widgets/habit_list.dart';
import '../widgets/task_action_sheet.dart';
import 'morning_report_screen.dart';
import '../widgets/glass_container.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  // Slogans to rotate or pick randomly
  final String _slogan = "Action beats anxiety.";
  
  // Animation for the add button
  late AnimationController _addButtonController;
  OverlayEntry? _menuOverlay;
  bool _isPlanningMode = false;
  
  @override
  void initState() {
    super.initState();
    _addButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }
  
  @override
  void dispose() {
    _addButtonController.dispose();
    _menuOverlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the list of tasks directly from the StateProvider
    final allTasks = ref.watch(taskListProvider);
    final now = DateTime.now();

    // Start of today
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    final filteredTasks = allTasks.where((t) {
      if (t.isCompleted || t.isAbandoned) return false;

      if (_isPlanningMode) {
        // Planning Mode: Show all future one-time tasks AND all recurring tasks
        final isFutureOneTime = t.repeatDays.isEmpty && t.scheduledStart.isAfter(todayStart);
        final isRecurring = t.repeatDays.isNotEmpty;
        return isFutureOneTime || isRecurring;
      } else {
        // Execution Mode (Today): 
        // 1. One-time tasks scheduled for today
        final isOneTimeToday = t.repeatDays.isEmpty && 
            t.scheduledStart.year == now.year && 
            t.scheduledStart.month == now.month && 
            t.scheduledStart.day == now.day;
            
        // 2. Recurring tasks that fall on today's weekday
        final isRecurringToday = t.repeatDays.isNotEmpty && t.repeatDays.contains(now.weekday);
        
        // 3. Keep showing if it started today but didn't finish (already handled by idCompleted check above)
        
        return isOneTimeToday || isRecurringToday;
      }
    }).toList()
    ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

    final locale = ref.watch(localeProvider);
    String t(String key) => AppStrings.get(key, locale);
    final slogan = locale == 'zh' ? AppStrings.get('slogan', locale) : _slogan;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Aesthetic Elements
          
          SafeArea(
            child: ResponsiveCenter(
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
                       // Animated Add Button with Expanding Menu
                       _AnimatedAddButton(
                         controller: _addButtonController,
                         isDark: isDark,
                         onTap: () => _showTaskModal(context),
                         onCreateTask: () => _showTaskModal(context),
                         onQuickFocus: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickFocusScreen())),
                         onDecision: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DecisionScreen())),
                         onVenting: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VentingScreen())),
                         ref: ref,
                       ),
                    ],
                  ),
                ),
            
            // Mode Toggle (Today vs Plan)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  _buildModeChip(
                    label: t('today'),
                    isActive: !_isPlanningMode,
                    icon: Icons.today,
                    onTap: () => setState(() => _isPlanningMode = false),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _buildModeChip(
                    label: t('planning'),
                    isActive: _isPlanningMode,
                    icon: Icons.event_repeat,
                    onTap: () => setState(() => _isPlanningMode = true),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            
            // Morning Report Banner (Conditional)
            Consumer(
              builder: (context, ref, _) {
                final enabled = ref.watch(morningReportEnabledProvider);
                if (!enabled) return const SizedBox.shrink();
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MorningReportScreen()));
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.newspaper, color: isDark ? Colors.white38 : Colors.black45),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "每日早报",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                "查看今天发生了什么",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.white24 : Colors.black26),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // 2. Task List with Slides
            Expanded(
              child: filteredTasks.isEmpty
                  ? _buildEmptyState(t, locale)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];
                        return _SlidableTaskCard(task: task, isPlanningMode: _isPlanningMode);
                      },
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

  Widget _buildEmptyState(String Function(String) t, String locale) {
    if (_isPlanningMode) {
      return EmptyStateWidget(
        icon: Icons.calendar_month_outlined,
        title: locale == 'zh' ? '暂无计划' : 'No Plans',
        subtitle: locale == 'zh' ? '点击下方按钮规划你的周期性任务' : "Tap the button to plan your recurring cycles",
        onAction: () => _showTaskModal(context),
        actionLabel: t('create_task'),
      );
    }
    return EmptyStateWidget(
      icon: Icons.add_task_outlined,
      title: t('tap_to_start'),
      subtitle: t('no_tasks_today_hint') != 'no_tasks_today_hint' ? t('no_tasks_today_hint') : "今天还没有任务，点击下方按钮开始规划吧",
      onAction: () => _showTaskModal(context),
      actionLabel: t('create_task'),
    );
  }

  Widget _buildModeChip({
    required String label,
    required bool isActive,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticHelper(ref).lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive 
              ? (isDark ? Colors.white : Colors.black) 
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive 
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              size: 16, 
              color: isActive 
                  ? (isDark ? Colors.black : Colors.white) 
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive 
                    ? (isDark ? Colors.black : Colors.white) 
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTaskModal(BuildContext context, {Task? task}) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTaskModal(taskToEdit: task),
    );

    if (result != null && result is Map && result['action'] == 'confirm_subtasks') {
      if (!context.mounted) return;
      
      final taskId = result['taskId'];
      final title = result['title'];
      final subTasks = result['subTasks'] as List<SubTask>;
      
      // Calculate total duration from subtasks or selected duration? 
      // SubTasks have their own durations.
      final totalDuration = Duration(minutes: subTasks.fold(0, (sum, st) => sum + st.estimatedDuration.inMinutes));
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => SubTaskEditorSheet(
          initialSubTasks: subTasks,
          totalDuration: totalDuration,
          showStartButton: true, // Allow starting directly
          onSave: (editedSubTasks) {
             // Create and start task
             final newTask = Task(
               id: taskId,
               title: title,
               totalDuration: totalDuration, // Or update based on edited
               scheduledStart: DateTime.now(),
               subTasks: editedSubTasks,
               isGenerating: false,
               repeatDays: [],
             );
             
             // Save to repo
             ref.read(taskRepositoryProvider).addTask(newTask);
             
             // Navigate to detail
             Navigator.of(context).push(
                MaterialPageRoute(builder: (c) => TaskDetailScreen(task: newTask)),
             );
          },
          onStart: () {
             // onSave handles everything including start, but maybe we need clear separation?
             // SubTaskEditorSheet calls onSave then onStart. 
             // We can just handle logic in onSave.
          },
        ),
      );
    }
  }
}

class _SlidableTaskCard extends ConsumerWidget {
  final Task task;
  final bool isPlanningMode;

  const _SlidableTaskCard({required this.task, this.isPlanningMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = ref.watch(localeProvider);
    String t(String key) => AppStrings.get(key, locale);

    if (task.isGenerating) {
       return Container(
         margin: const EdgeInsets.only(bottom: 20),
         padding: const EdgeInsets.all(28),
         decoration: BoxDecoration(
           color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
           borderRadius: BorderRadius.circular(24),
           boxShadow: [
             BoxShadow(
               color: Colors.black.withOpacity(0.04),
               blurRadius: 20,
               offset: const Offset(0, 10),
             ),
           ],
         ),
         child: Row(
           children: [
             SizedBox(
               width: 24, height: 24, 
               child: CircularProgressIndicator(
                 strokeWidth: 3, 
                 valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppTheme.primaryBlue : Colors.black),
               ),
             ),
             const SizedBox(width: 20),
             Expanded(
               child: Text(
                 "AI is crafting '${task.title}'...", 
                 style: TextStyle(
                   color: isDark ? Colors.white54 : Colors.grey[600],
                   fontStyle: FontStyle.italic,
                   fontWeight: FontWeight.w500,
                 )
               ),
             ),
           ],
         ),
       );
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: GlassContainer(
        borderRadius: 24,
        padding: EdgeInsets.zero,
        opacity: isDark ? 0.08 : 0.4,
        blur: isDark ? 20 : 10,
        color: isDark ? Colors.white : Colors.white,
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
              ),
               SlidableAction(
                onPressed: (context) {
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
          // Swipe to left -> Show Delete and Save Routine
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              // Save as Routine (Dynamic State)
              Builder(
                builder: (context) {
                  // Check if routine already exists
                  final routines = ref.watch(routineListProvider);
                  final isSaved = routines.any((r) => r.title == task.title && r.totalDuration == task.totalDuration);
                  
                  return SlidableAction(
                    onPressed: isSaved ? null : (context) {
                        // Save as Routine
                        final routine = Routine(
                          id: Uuid().v4(),
                          title: task.title,
                          totalDuration: task.totalDuration,
                          subTasks: task.subTasks,
                        );
                        ref.read(routineListProvider.notifier).addRoutine(routine); 
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t('save_routine_success'))),
                        );
                    },
                    backgroundColor: isSaved ? Colors.grey : Colors.blue,
                    foregroundColor: Colors.white,
                    icon: isSaved ? Icons.bookmark_added : Icons.bookmark_add_outlined,
                    label: isSaved ? t('saved') : t('save_as_routine'), 
                  );
                }
              ),
              SlidableAction(
                onPressed: (context) {
                  // Delete Logic with Provider
                  ref.read(taskListProvider.notifier).removeTask(task.id);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task deleted')),
                  );
                },
                backgroundColor: isDark ? Colors.red.shade900 : Colors.red[50]!,
                foregroundColor: isDark ? Colors.red.shade300 : Colors.red,
                icon: Icons.delete_outline,
                label: t('slide_drop'),
              ),
            ],
          ),
        child: GestureDetector(
          onLongPress: (!task.isDecision && !task.isQuickFocus && task.subTasks.isNotEmpty) 
              ? () => _showEditSubtasksSheet(context, task, ref) 
              : null,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                // Big Time
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH').format(task.scheduledStart),
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      DateFormat('mm').format(task.scheduledStart),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 28),
                
                // Divider
                Container(
                  width: 4, 
                  height: 48, 
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 28),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Repeat Info
                          if (task.repeatDays.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.repeat, size: 10, color: isDark ? Colors.white38 : Colors.black38),
                                  const SizedBox(width: 4),
                                  Text(
                                    task.repeatDays.length == 7 
                                      ? (locale == 'zh' ? '每天' : 'Daily')
                                      : task.repeatDays.map((d) => AppStrings.get('day_$d', locale)).join(','),
                                    style: TextStyle(
                                      fontSize: 9, 
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Expired Badge
                          if (!isPlanningMode && task.scheduledStart.add(task.totalDuration).isBefore(DateTime.now()) && !task.isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red.withOpacity(0.2)),
                              ),
                              child: Text(
                                locale == 'zh' ? '已过期' : 'EXPIRED',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined, 
                            size: 14, 
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${task.totalDuration.inMinutes} min',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.list_alt_outlined, 
                            size: 14, 
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${task.subTasks.length} steps',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }



  
  /// Show edit subtasks sheet
  void _showEditSubtasksSheet(BuildContext context, Task task, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SubTaskEditorSheet(
        initialSubTasks: task.subTasks,
        totalDuration: task.totalDuration,
        showStartButton: false,
        onSave: (editedSubTasks) {
          // Update task with new subtasks
          final updatedTask = task.copyWith(subTasks: editedSubTasks);
          ref.read(taskRepositoryProvider).updateTask(updatedTask);
          
          // Show success feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.get('save', ref.read(localeProvider))),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }
}

/// Animated Add Button with Rotating Icon and Expanding Menu
class _AnimatedAddButton extends StatefulWidget {
  final AnimationController controller;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onCreateTask;
  final VoidCallback onQuickFocus;
  final VoidCallback onDecision;
  final VoidCallback onVenting;
  final WidgetRef ref;

  const _AnimatedAddButton({
    required this.controller,
    required this.isDark,
    required this.onTap,
    required this.onCreateTask,
    required this.onQuickFocus,
    required this.onDecision,
    required this.onVenting,
    required this.ref,
  });

  @override
  State<_AnimatedAddButton> createState() => _AnimatedAddButtonState();
}

class _AnimatedAddButtonState extends State<_AnimatedAddButton> {
  bool _isExpanded = false;
  OverlayEntry? _overlayEntry;
  final GlobalKey _buttonKey = GlobalKey();
  
  void _toggleMenu() {
    if (_isExpanded) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }
  
  void _openMenu() {
    HapticHelper(widget.ref).mediumImpact();
    widget.controller.forward();
    setState(() => _isExpanded = true);
    
    // Create overlay
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }
  
  void _closeMenu() {
    widget.controller.reverse();
    setState(() => _isExpanded = false);
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
  
  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    
    final locale = widget.ref.read(localeProvider);
    String t(String key) => AppStrings.get(key, locale);
    
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Backdrop to close menu when tapping outside
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeMenu,
              child: AnimatedBuilder(
                animation: widget.controller,
                builder: (context, child) => Container(
                  color: Colors.black.withOpacity(0.3 * widget.controller.value),
                ),
              ),
            ),
          ),
          
          // Menu items with staggered animation
          Positioned(
            right: MediaQuery.of(context).size.width - position.dx - size.width,
            top: position.dy + size.height + 8,
            child: Material(
              color: Colors.transparent,
              child: AnimatedBuilder(
                animation: widget.controller,
                builder: (context, child) {
                  return IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Create Task
                        _buildMenuItem(
                          icon: Icons.flash_on,
                          label: t('create_task'),
                          delay: 0.0,
                          onTap: () {
                            _closeMenu();
                            widget.onCreateTask();
                          },
                        ),
                        const SizedBox(height: 8),
                        // Quick Focus
                        _buildMenuItem(
                          icon: Icons.hourglass_empty,
                          label: t('quick_focus'),
                          delay: 0.1,
                          onTap: () {
                            _closeMenu();
                            widget.onQuickFocus();
                          },
                        ),
                        const SizedBox(height: 8),
                        // Decision
                        _buildMenuItem(
                          icon: Icons.casino,
                          label: t('make_decision'),
                          delay: 0.2,
                          onTap: () {
                            _closeMenu();
                            widget.onDecision();
                          },
                        ),
                        const SizedBox(height: 8),
                        // Venting
                        _buildMenuItem(
                          icon: Icons.favorite_border,
                          label: t('venting'),
                          delay: 0.3,
                          onTap: () {
                            _closeMenu();
                            widget.onVenting();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required double delay,
    required VoidCallback onTap,
  }) {
    // Staggered animation with safe values
    final progress = ((widget.controller.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
    final curvedValue = Curves.easeOutCubic.transform(progress);
    // Ensure scale is never 0 to avoid layout issues
    final scale = curvedValue.clamp(0.01, 1.0);
    final opacity = curvedValue.clamp(0.0, 1.0);
    
    return Transform.scale(
      scale: scale,
      alignment: Alignment.centerRight,
      child: Opacity(
        opacity: opacity,
        child: GestureDetector(
          onTap: () {
            HapticHelper(widget.ref).selectionClick();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: widget.isDark ? Colors.white : Colors.black),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _buttonKey,
      onTap: widget.onTap,
      onLongPress: _toggleMenu,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: widget.controller.value * pi * 0.25, // 45 degree rotation
            child: Icon(
              _isExpanded ? Icons.close : Icons.add_circle,
              size: 36,
              color: widget.isDark ? Colors.white : Colors.black,
            ),
          );
        },
      ),
    );
  }
  
  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }
}
