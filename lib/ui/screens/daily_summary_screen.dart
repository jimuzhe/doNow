import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/providers.dart';
import '../../data/models/task.dart';
import '../../data/localization.dart';
import '../../data/services/daily_summary_service.dart';

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
      
      // Use generateDailySummary method
      final result = await aiService.generateDailySummary(allTasks, widget.date);
      
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
    
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(widget.date);
    
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
                  color: Colors.green,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _QuickStat(
                  label: t('abandoned'),
                  value: '$abandonedCount',
                  icon: Icons.cancel,
                  color: Colors.red,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _QuickStat(
                  label: t('focus_time'),
                  value: '${totalMinutes}m',
                  icon: Icons.timer,
                  color: Colors.blue,
                  isDark: isDark,
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // AI Summary Section
            _buildAISummarySection(isDark, t),
            
            const SizedBox(height: 32),
            
            // Task List
            Text(
              t('tasks'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            
            ...dayTasks.map((task) => _TaskSummaryCard(task: task, isDark: isDark)),
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
          gradient: LinearGradient(
            colors: isDark 
                ? [Colors.purple[900]!, Colors.blue[900]!]
                : [Colors.purple[50]!, Colors.blue[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [Colors.purple[900]!, Colors.blue[900]!]
              : [Colors.purple[50]!, Colors.blue[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.purple.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                t('ai_insight'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purpleAccent,
                  fontSize: 14,
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
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
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

  const _TaskSummaryCard({required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final statusColor = task.isCompleted ? Colors.green : Colors.red;
    final statusText = task.isCompleted ? 'Completed' : 'Abandoned';
    
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
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
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
                      '${task.totalDuration.inMinutes}m planned',
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
