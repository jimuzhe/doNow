import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/localization.dart';
import '../../data/providers.dart';
import '../../data/models/task.dart';
import '../../utils/haptic_helper.dart';

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Localization
    final locale = ref.watch(localeProvider);
    String t(String key) => AppStrings.get(key, locale);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Data - Use ALL tasks
    final tasks = ref.watch(taskListProvider);
    
    // Categorize tasks
    final completedTasks = tasks.where((t) => t.isCompleted).toList();
    final abandonedTasks = tasks.where((t) => t.isAbandoned && !t.isCompleted).toList();
    
    final completedCount = completedTasks.length;
    final abandonedCount = abandonedTasks.length;
    final totalMinutes = completedTasks.fold(0, (sum, t) => sum + t.totalDuration.inMinutes);
    
    // Calculate additional statistics
    final totalTasks = completedCount + abandonedCount;
    final completionRate = totalTasks > 0 ? (completedCount / totalTasks * 100).toInt() : 0;
    final avgMinutes = completedCount > 0 ? (totalMinutes / completedCount).toInt() : 0;
    
    // Calculate streak (consecutive days with completed tasks)
    int currentStreak = _calculateStreak(completedTasks);
    
    // Find best time slot (hour of day with most completions)
    String bestTimeSlot = _getBestTimeSlot(completedTasks, locale);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('analysis_title'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              
              // Focus Minutes Card (主要统计)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark 
                      ? [Colors.grey[900]!, Colors.grey[850]!]
                      : [Colors.grey[100]!, Colors.grey[50]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left side: Icon and label
                    Row(
                      children: [
                        Icon(Icons.timer, color: Colors.blue, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          t('focus_minutes'),
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // Right side: Time
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          "$totalMinutes",
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          locale == 'zh' ? '分钟' : 'min',
                          style: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Clickable Stats Cards
              Row(
                children: [
                  Expanded(
                    child: _ClickableStatCard(
                      label: t('completed'),
                      value: "$completedCount",
                      icon: Icons.check_circle,
                      color: Colors.green,
                      isDark: isDark,
                      onTap: () => _showTaskListSheet(
                        context, 
                        t('completed_tasks'), 
                        completedTasks, 
                        TaskStatus.completed, 
                        locale, 
                        isDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ClickableStatCard(
                      label: t('abandoned'),
                      value: "$abandonedCount",
                      icon: Icons.cancel,
                      color: Colors.red,
                      isDark: isDark,
                      onTap: () => _showTaskListSheet(
                        context, 
                        t('abandoned_tasks'), 
                        abandonedTasks, 
                        TaskStatus.abandoned, 
                        locale, 
                        isDark,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // New Stats Row: Completion Rate & Average Duration
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: locale == 'zh' ? '完成率' : 'Completion Rate',
                      value: "$completionRate%",
                      icon: Icons.trending_up,
                      color: completionRate >= 70 ? Colors.green : (completionRate >= 40 ? Colors.orange : Colors.red),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: locale == 'zh' ? '平均时长' : 'Avg Duration',
                      value: "$avgMinutes${locale == 'zh' ? '分' : 'm'}",
                      icon: Icons.access_time,
                      color: Colors.purple,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Streak & Best Time Slot
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: locale == 'zh' ? '连续天数' : 'Streak',
                      value: "$currentStreak${locale == 'zh' ? '天' : 'd'}",
                      icon: Icons.local_fire_department,
                      color: currentStreak >= 7 ? Colors.orange : (currentStreak >= 3 ? Colors.amber : Colors.grey),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: locale == 'zh' ? '最佳时段' : 'Best Time',
                      value: bestTimeSlot,
                      icon: Icons.wb_sunny,
                      color: Colors.cyan,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              Text(
                t('weekly_activity'),
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold, 
                  color: isDark ? Colors.grey[400] : Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              
              // Chart
              AspectRatio(
                aspectRatio: 1.7,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final dayIndex = value.toInt();
                            final key = 'day_${dayIndex + 1}';
                            final label = AppStrings.get(key, locale);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(label, style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey, 
                                fontSize: 10,
                              )),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(7, (index) {
                      final dayNum = index + 1;
                      final count = completedTasks.where((t) => t.scheduledStart.weekday == dayNum).length;
                      return _makeGroupData(index, count.toDouble(), isDark);
                    }),
                  ),
                ),
              ),
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
  
  int _calculateStreak(List<Task> completedTasks) {
    if (completedTasks.isEmpty) return 0;
    
    // Sort tasks by completion date (most recent first)
    final sortedTasks = completedTasks.toList()
      ..sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int streak = 0;
    
    // Check if there's a task completed today or yesterday
    final mostRecent = DateTime(
      sortedTasks.first.scheduledStart.year,
      sortedTasks.first.scheduledStart.month,
      sortedTasks.first.scheduledStart.day,
    );
    
    final daysSinceLastTask = today.difference(mostRecent).inDays;
    if (daysSinceLastTask > 1) return 0; // Streak broken
    
    // Count consecutive days
    DateTime currentDay = mostRecent;
    final Set<String> completedDays = {};
    
    for (var task in sortedTasks) {
      final taskDay = DateTime(
        task.scheduledStart.year,
        task.scheduledStart.month,
        task.scheduledStart.day,
      );
      completedDays.add(taskDay.toIso8601String().split('T')[0]);
    }
    
    // Count backwards from most recent day
    while (completedDays.contains(currentDay.toIso8601String().split('T')[0])) {
      streak++;
      currentDay = currentDay.subtract(const Duration(days: 1));
    }
    
    return streak;
  }
  
  String _getBestTimeSlot(List<Task> completedTasks, String locale) {
    if (completedTasks.isEmpty) return locale == 'zh' ? '暂无' : 'N/A';
    
    // Count tasks by hour
    final Map<int, int> hourCounts = {};
    for (var task in completedTasks) {
      final hour = task.scheduledStart.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }
    
    // Find hour with most tasks
    int bestHour = hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    
    // Format time slot
    if (locale == 'zh') {
      if (bestHour >= 5 && bestHour < 12) return '早上';
      if (bestHour >= 12 && bestHour < 18) return '下午';
      if (bestHour >= 18 && bestHour < 22) return '晚上';
      return '深夜';
    } else {
      if (bestHour >= 5 && bestHour < 12) return 'Morning';
      if (bestHour >= 12 && bestHour < 18) return 'Afternoon';
      if (bestHour >= 18 && bestHour < 22) return 'Evening';
      return 'Night';
    }
  }

  void _showTaskListSheet(
    BuildContext context, 
    String title, 
    List<Task> tasks, 
    TaskStatus status,
    String locale,
    bool isDark,
  ) {
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locale == 'zh' ? '暂无任务' : 'No tasks')),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              // List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) => _TaskHistoryItem(
                    task: tasks[index],
                    status: status,
                    locale: locale,
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y, bool isDark) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: isDark ? Colors.white : Colors.black,
          width: 16,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 10,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
        ),
      ],
    );
  }
}

enum TaskStatus { completed, abandoned, pending }

class _ClickableStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ClickableStatCard({
    required this.label, 
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  label, 
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey, 
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value, 
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Non-clickable stat card for display-only statistics
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label, 
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label, 
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey, 
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value, 
            style: TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskHistoryItem extends StatelessWidget {
  final Task task;
  final TaskStatus status;
  final String locale;
  final bool isDark;

  const _TaskHistoryItem({
    required this.task,
    required this.status,
    required this.locale,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (status) {
      TaskStatus.completed => Colors.green,
      TaskStatus.abandoned => Colors.red,
      TaskStatus.pending => Colors.orange,
    };
    
    final statusIcon = switch (status) {
      TaskStatus.completed => Icons.check_circle,
      TaskStatus.abandoned => Icons.cancel,
      TaskStatus.pending => Icons.schedule,
    };
    
    final dateStr = _formatDate(task.createdAt, locale);
    final durationStr = "${task.totalDuration.inMinutes} min";

    return GestureDetector(
      onLongPress: () => _showSubtasksSheet(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Status Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            
            // Task Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                      decoration: status == TaskStatus.abandoned 
                          ? TextDecoration.lineThrough 
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$dateStr • $durationStr",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            
            // Subtasks count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${task.subTasks.length} ${AppStrings.get('steps', locale)}",
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showSubtasksSheet(BuildContext context) {
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${task.totalDuration.inMinutes} ${locale == 'zh' ? '分钟' : 'min'} • ${task.subTasks.length} ${locale == 'zh' ? '个步骤' : 'steps'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // Subtasks List
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: task.subTasks.length,
                itemBuilder: (context, index) {
                  final subtask = task.subTasks[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subtask.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${subtask.estimatedDuration.inMinutes} ${locale == 'zh' ? '分钟' : 'min'}',
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
                  );
                },
              ),
            ),
            
            // Close button padding
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }
  
  String _formatDate(DateTime date, String locale) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return locale == 'zh' ? '今天' : 'Today';
    } else if (diff.inDays == 1) {
      return locale == 'zh' ? '昨天' : 'Yesterday';
    } else if (diff.inDays < 7) {
      return locale == 'zh' ? '${diff.inDays}天前' : '${diff.inDays}d ago';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

