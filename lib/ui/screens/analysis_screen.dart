import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../data/providers.dart';
import '../../data/models/task.dart';
import '../../data/localization.dart';
import '../../utils/haptic_helper.dart';
import '../../data/services/daily_summary_service.dart';
import '../widgets/subtask_display_sheet.dart';
import 'daily_summary_screen.dart'; // Keep for legacy or remove if unused
import '../widgets/daily_summary_view.dart';
import '../widgets/video_player_dialog.dart';
import '../widgets/custom_dialog.dart';
import '../widgets/task_detail_dialog.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _showDailySummary = false; // Toggle for embedded summary

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dailySummaryProvider.notifier).loadAll();
      ref.read(dailySummaryServiceProvider).checkAndGenerate(ref);
    });
  }


  List<Task> _getTasksForDay(DateTime day, List<Task> allTasks) {
    // Only show completed tasks in timeline, not abandoned ones
    return allTasks.where((task) {
      return task.isCompleted && task.completedAt != null && isSameDay(task.completedAt, day);
    }).toList();
  }

  // Check if a day has any completed tasks (for calendar markers)
  bool _hasCompletedTasks(DateTime day, List<Task> allTasks) {
    return allTasks.any((task) => 
      task.isCompleted && task.completedAt != null && isSameDay(task.completedAt, day)
    );
  }

  // Calculate streak (consecutive days with completed tasks)
  int _calculateStreak(List<Task> allTasks) {
    int streak = 0;
    DateTime checkDate = DateTime.now();
    
    // Check today first
    if (!_hasCompletedTasks(checkDate, allTasks)) {
      // If no tasks today, start from yesterday
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    while (_hasCompletedTasks(checkDate, allTasks)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = ref.watch(localeProvider);
    String t(String key) => AppStrings.get(key, locale);
    
    final allTasks = ref.watch(taskListProvider);
    final tasksForSelectedDay = _getTasksForDay(_selectedDay!, allTasks);
    
    // Stats calculation
    final completedTasks = allTasks.where((t) => t.isCompleted).toList();
    final abandonedTasks = allTasks.where((t) => t.isAbandoned).toList();
    final totalFocusMinutes = completedTasks
        .where((t) => t.actualDuration != null)
        .fold(0, (sum, t) => sum + t.actualDuration!.inMinutes);
    final totalTasks = allTasks.length;
    final completionRate = totalTasks > 0 ? (completedTasks.length / totalTasks * 100).toInt() : 0;
    final streak = _calculateStreak(allTasks);

    // Format total focus time
    final focusHours = totalFocusMinutes ~/ 60;
    final focusMinutes = totalFocusMinutes % 60;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
        child: Column(
          children: [
            // Header Title
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Text(
                  t('analysis_title'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
            
            // 1. Total Focus Time - Big Display
            _buildTotalFocusTime(focusHours, focusMinutes, t, isDark),
            
            const SizedBox(height: 20),

            // 2. Stats Cards Grid (2x2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Row 1: Completed & Abandoned (clickable)
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.check_circle_outline,
                          label: t('completed'),
                          value: '${completedTasks.length}',
                          isDark: isDark,
                          onTap: () => _showTaskList(t('completed'), completedTasks, isDark),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.cancel_outlined,
                          label: t('abandoned'),
                          value: '${abandonedTasks.length}',
                          isDark: isDark,
                          iconColor: Colors.redAccent,
                          onTap: () => _showTaskList(t('abandoned'), abandonedTasks, isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Row 2: Completion Rate & Streak
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.pie_chart_outline,
                          label: t('completion_rate'),
                          value: '$completionRate%',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.local_fire_department_outlined,
                          label: t('streak'),
                          value: '$streak',
                          valueUnit: t('days'),
                          isDark: isDark,
                          iconColor: streak > 0 ? Colors.orange : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // 3. Calendar
            _buildCalendar(allTasks, isDark, theme),
            
            const SizedBox(height: 16),

            // 4. Timeline for Selected Day
            _buildSelectedDayTimeline(tasksForSelectedDay, t, isDark),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTotalFocusTime(int hours, int minutes, String Function(String) t, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left side - Label with icon
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 26,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(width: 12),
              Text(
                t('total_focus_time'),
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Right side - Value
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              children: [
                TextSpan(
                  text: '$hours',
                  style: const TextStyle(fontSize: 32, letterSpacing: -1),
                ),
                TextSpan(
                  text: 'h ',
                  style: TextStyle(fontSize: 16, color: isDark ? Colors.white60 : Colors.black54),
                ),
                TextSpan(
                  text: '$minutes',
                  style: const TextStyle(fontSize: 32, letterSpacing: -1),
                ),
                TextSpan(
                  text: 'm',
                  style: TextStyle(fontSize: 16, color: isDark ? Colors.white60 : Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(List<Task> allTasks, bool isDark, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        currentDay: DateTime.now(),
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          if (!isSameDay(_selectedDay, selectedDay)) {
            HapticHelper(ref).selectionClick();
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
              _showDailySummary = false; // Reset to timeline
            });
          }
        },
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() => _calendarFormat = format);
          }
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        calendarBuilders: CalendarBuilders(
          // Custom marker builder - simple dot for days with completed tasks
          markerBuilder: (context, day, events) {
            if (_hasCompletedTasks(day, allTasks)) {
              return Positioned(
                bottom: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white70 : Colors.black54,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }
            return null;
          },
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
          selectedDecoration: BoxDecoration(
            color: isDark ? Colors.white : Colors.black,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(
            color: isDark ? Colors.black : Colors.white,
            fontWeight: FontWeight.w600,
          ),
          defaultTextStyle: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
          ),
          weekendTextStyle: TextStyle(
            color: isDark ? Colors.white54 : Colors.black54,
          ),
          outsideTextStyle: TextStyle(
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          markersMaxCount: 0, // Disable default markers
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: isDark ? Colors.white54 : Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          weekendStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDayTimeline(List<Task> tasks, String Function(String) t, bool isDark) {
    // Removed conditional _showDailySummary display here as per instruction
    // The DailySummary is now accessed only via the AppBar icon.

    final dateStr = DateFormat('MMM d, yyyy').format(_selectedDay!);
    final isToday = DateUtils.isSameDay(_selectedDay, DateTime.now());
    final locale = ref.watch(localeProvider);
    
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                if (tasks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${tasks.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                const Spacer(),
                // Magic Wand for Daily Summary
                IconButton(
                  icon: Icon(Icons.auto_awesome, size: 20, color: isDark ? Colors.purple[200] : Colors.purple),
                  tooltip: t('daily_summary'),
                  onPressed: () => _openDailySummary(_selectedDay!),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Timeline with left line
            if (tasks.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy_outlined,
                        size: 40,
                        color: isDark ? Colors.white24 : Colors.grey[300],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t('no_activity'),
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Timeline items with left connecting line
              ...List.generate(tasks.length, (index) {
                final task = tasks[index];
                final isLast = index == tasks.length - 1;
                return _TimelineItemWithLine(
                  task: task,
                  isDark: isDark,
                  isLast: isLast,
                  onLongPress: () => _showSubTasks(task, isDark),
                  onTap: () => _showTaskDetailCard(task, isDark),
                );
              }),
          ],
        ),
      );
  }

  void _showTaskList(String title, List<Task> tasks, bool isDark) {
    HapticHelper(ref).lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[600] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${tasks.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // List
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Text(
                          'No tasks',
                          style: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _TaskListItem(
                            task: task,
                            isDark: isDark,
                            onLongPress: () => _showSubTasks(task, isDark),
                            onTap: () => _showTaskDetailCard(task, isDark),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskDetailCard(Task task, bool isDark) {
    HapticHelper(ref).mediumImpact();
    
    showDialog(
      context: context,
      builder: (context) => TaskDetailDialog(
        task: task,
        isDark: isDark,
        locale: ref.read(localeProvider),
      ),
    );
  }

  void _showSubTasks(Task task, bool isDark) {
    HapticHelper(ref).lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SubTaskDisplaySheet(
        task: task,
        isReadOnly: true,
      ),
    );
  }

  void _openDailySummary(DateTime date) {
    HapticHelper(ref).mediumImpact();

    // Check availability logic: Summary for 'date' is generated on 'date + 1' at 8:00 AM.
    final now = DateTime.now();
    final generationThreshold = DateTime(date.year, date.month, date.day + 1, 8, 0);

    // If attempting to view summary before it's ready
    if (now.isBefore(generationThreshold)) {
      final locale = ref.read(localeProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('daily_summary_too_early', locale)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.black87,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailySummaryScreen(date: date),
      ),
    );
  }
}

// Stats Card Widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? valueUnit;
  final bool isDark;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueUnit,
    required this.isDark,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left side: Icon + Label
            Expanded(
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Right side: Value + Arrow (if clickable)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
                if (valueUnit != null) ...[
                  const SizedBox(width: 2),
                  Text(
                    valueUnit!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Task List Item for Modal
class _TaskListItem extends StatelessWidget {
  final Task task;
  final bool isDark;
  final VoidCallback onLongPress;
  final VoidCallback onTap;

  const _TaskListItem({
    required this.task,
    required this.isDark,
    required this.onLongPress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = task.isCompleted ? Colors.green : Colors.red;
    final dateStr = task.completedAt != null 
        ? DateFormat('MMM d, HH:mm').format(task.completedAt!)
        : DateFormat('MMM d, HH:mm').format(task.scheduledStart);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                      decoration: task.isAbandoned ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.touch_app_outlined,
              size: 16,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }
}

// Timeline Item Widget
class _TaskTimelineItem extends StatelessWidget {
  final Task task;
  final bool isDark;
  final VoidCallback onLongPress;
  final VoidCallback onSwipeLeft;

  const _TaskTimelineItem({
    required this.task,
    required this.isDark,
    required this.onLongPress,
    required this.onSwipeLeft,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = task.completedAt != null 
        ? DateFormat('HH:mm').format(task.completedAt!)
        : DateFormat('HH:mm').format(task.scheduledStart);
        
    final statusColor = task.isCompleted ? Colors.green : Colors.red;
    
    // Calculate time difference (planned vs actual)
    String? timeDiffStr;
    Color? timeDiffColor;
    if (task.isCompleted && task.actualDuration != null) {
      final plannedMinutes = task.totalDuration.inMinutes;
      final actualMinutes = task.actualDuration!.inMinutes;
      final diff = actualMinutes - plannedMinutes;
      
      if (diff > 0) {
        timeDiffStr = '+${diff}m slower';
        timeDiffColor = Colors.orange;
      } else if (diff < 0) {
        timeDiffStr = '${diff.abs()}m faster';
        timeDiffColor = Colors.green;
      } else {
        timeDiffStr = 'On time';
        timeDiffColor = Colors.blue;
      }
    }
    
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        onSwipeLeft();
        return false; // Don't actually dismiss
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.purple.withOpacity(0.2) : Colors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: Colors.purple[300], size: 18),
            const SizedBox(width: 6),
            Text(
              'Daily Summary',
              style: TextStyle(
                color: Colors.purple[300],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time & Status Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(width: 16),
              
              // Content Column
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
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: task.isAbandoned ? TextDecoration.lineThrough : null,
                              color: task.isAbandoned 
                                  ? Colors.grey 
                                  : (isDark ? Colors.white : Colors.black),
                            ),
                          ),
                        ),
                        // Image thumbnail (aligned with title)
                        if (task.journalImagePath != null)
                          // Mirror front camera content
                          Transform.flip(
                            flipX: task.journalMediaMirrored,
                            child: Container(
                              height: 48,
                              width: 48,
                              margin: const EdgeInsets.only(left: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                ),
                                image: DecorationImage(
                                  image: kIsWeb 
                                      ? NetworkImage(task.journalImagePath!) 
                                      : FileImage(File(task.journalImagePath!)) as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: task.journalVideoPath != null
                                  ? const Icon(Icons.play_circle_fill, color: Colors.white, size: 20)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Time comparison row
                    Row(
                      children: [
                        // Planned duration
                        _TimeInfoChip(
                          label: 'Planned',
                          value: '${task.totalDuration.inMinutes}m',
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        // Actual duration
                        if (task.actualDuration != null)
                          _TimeInfoChip(
                            label: 'Actual',
                            value: '${task.actualDuration!.inMinutes}m',
                            isDark: isDark,
                          ),
                        if (timeDiffStr != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: timeDiffColor!.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              timeDiffStr,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: timeDiffColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    // Location if available
                    if (task.journalLocation != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              task.journalLocation!,
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
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

// Time Info Chip
class _TimeInfoChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _TimeInfoChip({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

// Timeline Item with Left Line
class _TimelineItemWithLine extends StatelessWidget {
  final Task task;
  final bool isDark;
  final bool isLast;
  final VoidCallback onLongPress;
  final VoidCallback onTap;

  const _TimelineItemWithLine({
    required this.task,
    required this.isDark,
    required this.isLast,
    required this.onLongPress,
    required this.onTap,
  });

  void _showMediaViewer(BuildContext context, Task task) {
    if (task.journalVideoPath != null) {
      // Show video player as full screen page
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => VideoPlayerDialog(
            videoPath: task.journalVideoPath!,
            isMirrored: task.journalMediaMirrored,
          ),
        ),
      );
    } else if (task.journalImagePath != null) {
      // Show image viewer with mirror support
      showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (context) => GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Transform.flip(
                flipX: task.journalMediaMirrored,
                child: kIsWeb
                    ? Image.network(task.journalImagePath!, fit: BoxFit.contain)
                    : Image.file(File(task.journalImagePath!), fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = task.completedAt != null
        ? DateFormat('HH:mm').format(task.completedAt!)
        : DateFormat('HH:mm').format(task.scheduledStart);
    
    final statusColor = task.isCompleted ? Colors.green : Colors.red;
    
    // Calculate time difference
    String? timeDiffStr;
    Color? timeDiffColor;
    if (task.isCompleted && task.actualDuration != null && !task.isDecision) {
      final diff = task.actualDuration!.inMinutes - task.totalDuration.inMinutes;
      if (diff > 0) {
        timeDiffStr = '+${diff}m';
        timeDiffColor = Colors.orange;
      } else if (diff < 0) {
        timeDiffStr = '-${diff.abs()}m';
        timeDiffColor = Colors.green;
      }
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left timeline column with dot and line
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  // Time indicator dot (Different for decision/quick focus)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: task.isDecision 
                          ? Colors.purpleAccent 
                          : (task.isQuickFocus ? Colors.orangeAccent : statusColor),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: task.isDecision 
                        ? const Center(child: Icon(Icons.star, size: 8, color: Colors.white))
                        : (task.isQuickFocus ? const Center(child: Icon(Icons.bolt, size: 8, color: Colors.white)) : null),
                  ),
                  // Connecting line (if not last item)
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Content area
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time + Duration on same line (Hidden for Decision/QuickFocus special handling)
                          if (!task.isDecision && !task.isQuickFocus)
                            Row(
                              children: [
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white70 : Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${task.totalDuration.inMinutes}m',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white54 : Colors.grey[500],
                                  ),
                                ),
                                if (task.actualDuration != null) ...[
                                  Text(
                                    '→${task.actualDuration!.inMinutes}m',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white54 : Colors.grey[500],
                                    ),
                                  ),
                                ],
                                if (timeDiffStr != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: timeDiffColor!.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      timeDiffStr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: timeDiffColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            )
                          else if (task.isQuickFocus)
                             // Quick Focus Row
                             Row(
                               children: [
                                 Text(
                                   timeStr,
                                   style: TextStyle(
                                     fontSize: 12,
                                     fontWeight: FontWeight.w500,
                                     color: isDark ? Colors.white70 : Colors.grey[700],
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                   decoration: BoxDecoration(
                                     color: Colors.orange.withOpacity(0.1),
                                     borderRadius: BorderRadius.circular(4),
                                     border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                   ),
                                   child: Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       Icon(Icons.bolt, size: 10, color: Colors.orange[700]),
                                       const SizedBox(width: 2),
                                       Text(
                                         task.actualDuration != null ? '${task.actualDuration!.inMinutes}m' : 'Focus',
                                         style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[700]),
                                       ),
                                     ],
                                   ),
                                 )
                               ],
                             )
                          else
                            // Special Time display/Tag for Decision
                            Row(
                              children: [
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white70 : Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    "Decision", 
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple[300]),
                                  ),
                                )
                              ],
                            ),

                          const SizedBox(height: 4),
                          // Title
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration: task.isAbandoned ? TextDecoration.lineThrough : null,
                              color: task.isAbandoned
                                  ? Colors.grey
                                  : (isDark ? Colors.white : Colors.black),
                            ),
                          ),
                          // Location if available
                          if (task.journalLocation != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    task.journalLocation!,
                                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // Note if available
                          if (task.journalNote != null && task.journalNote!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: task.isDecision 
                                    ? (isDark ? Colors.purple.withOpacity(0.1) : Colors.purple.withOpacity(0.05))
                                    : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
                                borderRadius: BorderRadius.circular(8),
                                border: task.isDecision ? Border.all(color: Colors.purple.withOpacity(0.2), width: 1) : null,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    task.isDecision ? Icons.psychology : Icons.format_quote, 
                                    size: 14, 
                                    color: task.isDecision ? Colors.purple[300] : Colors.grey[500]
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      task.journalNote!,
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.grey[700],
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: task.isDecision ? FontWeight.w500 : FontWeight.normal,
                                      ),
                                      maxLines: 10, // Show more for decision
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Media on right if available (image or video)
                    if (task.journalImagePath != null || task.journalVideoPath != null)
                      GestureDetector(
                        onTap: () => _showMediaViewer(context, task),
                        // Mirror front camera content
                        child: Transform.flip(
                          flipX: task.journalMediaMirrored,
                          child: Container(
                            height: 50,
                            width: 50,
                            margin: const EdgeInsets.only(left: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                              // Use darker background for video without thumbnail
                              color: task.journalImagePath == null && task.journalVideoPath != null
                                  ? (isDark ? Colors.grey[800] : Colors.grey[600])
                                  : Colors.black12,
                              image: task.journalImagePath != null
                                  ? DecorationImage(
                                      image: kIsWeb
                                          ? NetworkImage(task.journalImagePath!)
                                          : FileImage(File(task.journalImagePath!)) as ImageProvider,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: task.journalVideoPath != null
                                ? Center(
                                    child: Icon(
                                      Icons.play_circle_fill, 
                                      color: Colors.white.withOpacity(0.9), 
                                      size: 24,
                                    ),
                                  )
                                : null,
                          ),
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
}

// Helper for Detail Card
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const _DetailRow({required this.icon, required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.white54 : Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _DetailStat({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600])),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
      ],
    );
  }
}

