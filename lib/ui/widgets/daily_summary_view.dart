import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/providers.dart';
import '../../data/localization.dart';
import '../../data/services/daily_summary_service.dart';

class DailySummaryView extends ConsumerStatefulWidget {
  final DateTime date;
  final VoidCallback onClose;

  const DailySummaryView({
    super.key, 
    required this.date,
    required this.onClose,
  });

  @override
  ConsumerState<DailySummaryView> createState() => _DailySummaryViewState();
}

class _DailySummaryViewState extends ConsumerState<DailySummaryView> {
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
      final result = await aiService.generateDailySummary(allTasks, widget.date);
      
      if (mounted) {
        setState(() {
          _summary = result.summary;
          _encouragement = result.encouragement;
          _suggestion = result.improvement;
          _isLoading = false;
        });
        ref.read(dailySummaryProvider.notifier).addSummary(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = ref.watch(localeProvider);
    String t(String key) => AppStrings.get(key, locale);
    
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(widget.date);

    final allTasks = ref.watch(taskListProvider);
    final dayTasks = allTasks.where((task) {
      if (task.completedAt != null) return DateUtils.isSameDay(task.completedAt, widget.date);
      if (task.isAbandoned) return DateUtils.isSameDay(task.scheduledStart, widget.date);
      return false;
    }).toList();
    
    final completedCount = dayTasks.where((t) => t.isCompleted).length;
    final abandonedCount = dayTasks.where((t) => t.isAbandoned).length;
    final totalMinutes = dayTasks
        .where((t) => t.isCompleted && t.actualDuration != null)
        .fold(0, (sum, t) => sum + t.actualDuration!.inMinutes);

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('daily_summary'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black54),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            
            Text(
               dateStr,
               style: TextStyle(
                 fontSize: 14, 
                 color: isDark ? Colors.white54 : Colors.grey[600]
               ),
            ),
            
            const SizedBox(height: 24),
            
            // Stats
            Row(
              children: [
                _QuickStat(t('completed'), '$completedCount', Icons.check_circle, Colors.green, isDark),
                const SizedBox(width: 12),
                _QuickStat(t('abandoned'), '$abandonedCount', Icons.cancel, Colors.red, isDark),
                const SizedBox(width: 12),
                _QuickStat(t('focus_time'), '${totalMinutes}m', Icons.timer, Colors.blue, isDark),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // AI Content
            if (_isLoading)
               Align(
                 alignment: Alignment.center,
                 child: Padding(
                   padding: const EdgeInsets.all(32),
                   child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black),
                 ),
               )
            else if (_error != null)
               Text(t(_error == 'no_tasks_to_summarize' ? 'no_activity' : 'error_ai_generic'), 
                    style: const TextStyle(color: Colors.red))
            else ...[
               // Summary
               if (_summary != null)
                 Container(
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: isDark ? Colors.grey[900] : Colors.white,
                     borderRadius: BorderRadius.circular(16),
                     border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                   ),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Row(children: [
                          const Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
                          const SizedBox(width: 8),
                          Text(t('ai_summary'), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                       ]),
                       const SizedBox(height: 12),
                       Text(_summary!, style: TextStyle(
                         fontSize: 15, 
                         height: 1.5,
                         color: isDark ? Colors.white70 : Colors.black87
                       )),
                     ],
                   ),
                 ),
                 
               const SizedBox(height: 16),
               
               // Encouragement
               if (_encouragement != null)
                  Container(
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: Colors.orange.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(16),
                     border: Border.all(color: Colors.orange.withOpacity(0.3)),
                   ),
                   child: Row(children: [
                      const Icon(Icons.format_quote, color: Colors.orange, size: 24),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_encouragement!, style: TextStyle(
                         fontStyle: FontStyle.italic,
                         color: isDark ? Colors.orange[200] : Colors.orange[900],
                         fontWeight: FontWeight.w500
                      ))),
                   ]),
                  ),
                  
               const SizedBox(height: 16),
               
               // Suggestion
               if (_suggestion != null)
                  Container(
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: Colors.blue.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(16),
                     border: Border.all(color: Colors.blue.withOpacity(0.3)),
                   ),
                   child: Row(children: [
                      const Icon(Icons.lightbulb, color: Colors.blue, size: 24),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_suggestion!, style: TextStyle(
                         color: isDark ? Colors.blue[200] : Colors.blue[900]
                      ))),
                   ]),
                  ),
            ]
          ],
        ),
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

  const _QuickStat(this.label, this.value, this.icon, this.color, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
            Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey[600]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
