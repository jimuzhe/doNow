import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/providers.dart';
import '../../data/models/task.dart';
import '../../data/localization.dart';
import '../../data/services/daily_summary_service.dart';
import '../theme/app_theme.dart';

class DailySummaryScreen extends ConsumerStatefulWidget {
  final DateTime date;
  
  const DailySummaryScreen({super.key, required this.date});

  @override
  ConsumerState<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends ConsumerState<DailySummaryScreen> {
  bool _isLoading = false;
  String? _summary;
  String? _encouragement;
  String? _suggestion;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrGenerateSummary();
  }

  Future<void> _loadOrGenerateSummary() async {
    final summaries = ref.read(dailySummaryProvider);
    final key = DateUtils.dateOnly(widget.date).toIso8601String();
    final existing = summaries[key];

    if (existing != null) {
      setState(() {
        _summary = existing.summary;
        _encouragement = existing.encouragement;
        _suggestion = existing.improvement;
      });
      return;
    }

    // Generate new summary
    await _generateSummary();
  }

  Future<void> _generateSummary() async {
    final allTasks = ref.read(taskListProvider);
    final dayTasks = allTasks.where((task) {
      if (task.completedAt != null) {
        return DateUtils.isSameDay(task.completedAt, widget.date);
      }
      if (task.isAbandoned) {
        return DateUtils.isSameDay(task.scheduledStart, widget.date);
      }
      return false;
    }).toList();

    if (dayTasks.isEmpty) {
      setState(() {
        _error = 'no_tasks_to_summarize';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final aiService = ref.read(aiServiceProvider);
      final locale = ref.read(localeProvider);
      
      // Use generateDailySummary method with locale
      final result = await aiService.generateDailySummary(allTasks, widget.date, locale: locale);
      
      setState(() {
        _summary = result.summary;
        _encouragement = result.encouragement;
        _suggestion = result.improvement;
        _isLoading = false;
      });

      // Save to provider
      ref.read(dailySummaryProvider.notifier).addSummary(result);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = ref.watch(localeProvider);
    String t(String key) => AppStrings.get(key, locale);
    
    final dateStr = locale == 'zh' 
        ? DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(widget.date)
        : DateFormat('EEEE, MMM d, yyyy', 'en_US').format(widget.date);
    
    // Get tasks for this day
    final allTasks = ref.watch(taskListProvider);
    final dayTasks = allTasks.where((task) {
      if (task.completedAt != null) {
        return DateUtils.isSameDay(task.completedAt, widget.date);
      }
      if (task.isAbandoned) {
        return DateUtils.isSameDay(task.scheduledStart, widget.date);
      }
      return false;
    }).toList();
    
    final completedCount = dayTasks.where((t) => t.isCompleted).length;
    final abandonedCount = dayTasks.where((t) => t.isAbandoned).length;
    final totalMinutes = dayTasks
        .where((t) => t.isCompleted && t.actualDuration != null)
        .fold(0, (sum, t) => sum + t.actualDuration!.inMinutes);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          t('daily_summary'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Quick Stats Row
            Row(
              children: [
                _QuickStat(
                  label: t('completed'),
                  value: '$completedCount',
                  icon: Icons.check_circle,
                  color: isDark ? Colors.teal[300]! : Colors.teal[600]!,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _QuickStat(
                  label: t('abandoned'),
                  value: '$abandonedCount',
                  icon: Icons.cancel,
                  color: isDark ? Colors.pink[300]! : Colors.pink[600]!,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _QuickStat(
                  label: t('focus_time'),
                  value: '${totalMinutes}${t('minutes')}',
                  icon: Icons.timer,
                  color: isDark ? Colors.indigo[300]! : Colors.indigo[600]!,
                  isDark: isDark,
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Focus Breakdown Pie Chart
            if (completedCount > 0) ...[
              Text(
                t('focus_breakdown'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              _FocusBreakdownChart(dayTasks: dayTasks, isDark: isDark, locale: locale),
              const SizedBox(height: 32),
            ],
            
            // AI Summary Section
            _buildAISummarySection(isDark, t),

            const SizedBox(height: 32),

            // Task List Section
            if (dayTasks.isNotEmpty) ...[
               Row(
                 children: [
                   Icon(Icons.list_alt, color: isDark ? Colors.white38 : Colors.black38, size: 20),
                   const SizedBox(width: 8),
                   Text(
                    locale == 'zh' ? '事项清单' : 'Tasks',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                 ],
               ),
              const SizedBox(height: 16),
              ...dayTasks.map((task) => _TaskSummaryCard(
                task: task,
                isDark: isDark,
                locale: locale,
              )),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAISummarySection(bool isDark, String Function(String) t) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 16),
            Text(
              t('generating_summary'),
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 32,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              t(_error!),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _generateSummary,
              icon: const Icon(Icons.refresh),
              label: Text(t('retry')),
            ),
          ],
        ),
      );
    }

    if (_summary == null) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                t('ai_insight'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Summary
          Text(
            _summary!,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Encouragement
          if (_encouragement != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.favorite, size: 16, color: Colors.pink[300]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _encouragement!,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 12),
          
          // Suggestion
          if (_suggestion != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb, size: 16, color: Colors.amber[400]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _suggestion!,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FocusBreakdownChart extends StatelessWidget {
  final List<Task> dayTasks;
  final bool isDark;
  final String locale;

  const _FocusBreakdownChart({required this.dayTasks, required this.isDark, required this.locale});

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppStrings.get(key, locale);
    final completedTasks = dayTasks.where((t) => t.isCompleted && t.actualDuration != null).toList();
    if (completedTasks.isEmpty) return const SizedBox();

    // Grouping tasks by title to avoid tiny slices for repetitive tasks
    final Map<String, int> groupedMinutes = {};
    for (var task in completedTasks) {
      final mins = task.actualDuration!.inMinutes;
      if (mins > 0) {
        groupedMinutes[task.title] = (groupedMinutes[task.title] ?? 0) + mins;
      }
    }

    if (groupedMinutes.isEmpty) return const SizedBox();

    // Sort by duration descending
    final sortedEntries = groupedMinutes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    // List of premium, ultra-muted colors
    final colors = isDark ? [
      const Color(0xFF94A3B8), // Slate
      const Color(0xFF818CF8), // Indigo
      const Color(0xFF2DD4BF), // Teal
      const Color(0xFFF472B6), // Pink
      const Color(0xFFFB923C), // Orange
      const Color(0xFFA78BFA), // Purple
    ].map((c) => c.withOpacity(0.4)).toList() : [
      const Color(0xFF64748B),
      const Color(0xFF6366F1),
      const Color(0xFF14B8A6),
      const Color(0xFFEC4899),
      const Color(0xFFF97316),
      const Color(0xFF8B5CF6),
    ];

    final totalMinutes = groupedMinutes.values.fold(0, (sum, m) => sum + m);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.3,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: List.generate(
                  sortedEntries.length > 5 ? 6 : sortedEntries.length,
                  (index) {
                    if (index == 5 && sortedEntries.length > 6) {
                      // Others slice
                      final otherMins = sortedEntries.skip(5).fold(0, (sum, e) => sum + e.value);
                      return PieChartSectionData(
                        color: Colors.grey,
                        value: otherMins.toDouble(),
                        title: '${(otherMins / totalMinutes * 100).toInt()}%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }
                    
                    final entry = sortedEntries[index];
                    return PieChartSectionData(
                      color: colors[index % colors.length],
                      value: entry.value.toDouble(),
                      title: '${(entry.value / totalMinutes * 100).toInt()}%',
                      radius: 55,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Custom Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: List.generate(
              sortedEntries.length > 5 ? 6 : sortedEntries.length,
              (index) {
                final isOthers = index == 5 && sortedEntries.length > 6;
                final label = isOthers 
                    ? (Localizations.maybeLocaleOf(context)?.languageCode == 'zh' ? '其他' : "Others") 
                    : sortedEntries[index].key;
                final color = isOthers ? Colors.grey : colors[index % colors.length];
                final mins = isOthers 
                  ? sortedEntries.skip(5).fold(0, (sum, e) => sum + e.value)
                  : sortedEntries[index].value;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "$label (${mins}${t('minutes')})",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _QuickStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.06),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskSummaryCard extends StatelessWidget {
  final Task task;
  final bool isDark;
  final String locale;

  const _TaskSummaryCard({required this.task, required this.isDark, required this.locale});

  @override
  Widget build(BuildContext context) {
    final statusColor = task.isCompleted ? Colors.green : Colors.red;
    final statusText = task.isCompleted 
        ? AppStrings.get('completed', locale) 
        : AppStrings.get('abandoned', locale);
    
    // Time difference
    String? timeDiff;
    if (task.isCompleted && task.actualDuration != null) {
      final diff = task.actualDuration!.inMinutes - task.totalDuration.inMinutes;
      if (diff > 0) {
        timeDiff = '+$diff min';
      } else if (diff < 0) {
        timeDiff = '${diff} min';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black,
                    decoration: task.isAbandoned ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${task.totalDuration.inMinutes}m ${locale == 'zh' ? '计划' : 'planned'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                    if (timeDiff != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        timeDiff,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: timeDiff.startsWith('+') ? Colors.orange : Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
