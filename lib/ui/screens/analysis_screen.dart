import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/localization.dart';
import '../../data/providers.dart';
import '../../data/models/task.dart';

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
                padding: const EdgeInsets.all(24),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          t('focus_minutes'),
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "$totalMinutes",
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      locale == 'zh' ? '分钟' : 'minutes',
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey,
                        fontSize: 16,
                      ),
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
            color: isDark ? Colors.grey[800] : Colors.grey[100],
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
          color: isDark ? Colors.grey[900] : Colors.grey[50],
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

    return Container(
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

