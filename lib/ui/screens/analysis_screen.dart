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
import '../../data/models/gamification_state.dart';
import '../../data/services/gamification_service.dart';

// Extracted Widgets
import '../widgets/analysis/stat_card.dart';
import '../widgets/analysis/task_list_item.dart';
import '../widgets/analysis/task_timeline_item.dart';
import '../widgets/analysis/timeline_item_with_line.dart';
import '../widgets/analysis/search_result_card.dart';
import '../widgets/analysis/time_info_chip.dart';
import '../widgets/glass_container.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

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
  
  // Search functionality
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dailySummaryProvider.notifier).loadAll();
      ref.read(dailySummaryServiceProvider).checkAndGenerate(ref);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  // Search tasks by title or note
  List<Task> _searchTasks(String query, List<Task> allTasks) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return allTasks.where((task) {
      final titleMatch = task.title.toLowerCase().contains(lowerQuery);
      final noteMatch = task.journalNote?.toLowerCase().contains(lowerQuery) ?? false;
      return titleMatch || noteMatch;
    }).toList()
      ..sort((a, b) => (b.completedAt ?? b.scheduledStart).compareTo(a.completedAt ?? a.scheduledStart));
  }


  List<Task> _getTasksForDay(DateTime day, List<Task> allTasks) {
    // Only show completed tasks in timeline, not abandoned ones
    return allTasks.where((task) {
      return task.isCompleted && task.completedAt != null && isSameDay(task.completedAt, day);
    }).toList()
      ..sort((a, b) => a.completedAt!.compareTo(b.completedAt!)); // Sort by completion time ascending
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

    // Search results
    final searchResults = _searchTasks(_searchQuery, allTasks);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: _isSearching 
          ? _buildSearchView(searchResults, t, isDark, locale)
          : SingleChildScrollView(
        child: Column(
          children: [
            // Header Title with Search Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 24),
              child: Row(
                children: [
                  Expanded(
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
                  // Search Button
                  IconButton(
                    icon: Icon(
                      Icons.search,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    tooltip: t('search'),
                    onPressed: () {
                      setState(() {
                        _isSearching = true;
                      });
                      // Focus the search field
                      Future.delayed(const Duration(milliseconds: 100), () {
                        _searchFocusNode.requestFocus();
                      });
                    },
                  ),
                ],
              ),
            ),

            // Gamification Card Removed

            
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
                        child: StatCard(
                          icon: Icons.check_circle_outline,
                          label: t('completed'),
                          value: '${completedTasks.length}',
                          isDark: isDark,
                          iconColor: Colors.green,
                          onTap: () => _showTaskList(t('completed'), completedTasks, isDark),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
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
                        child: StatCard(
                          icon: Icons.pie_chart_outline,
                          label: t('completion_rate'),
                          value: '$completionRate%',
                          isDark: isDark,
                          iconColor: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
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

  // _buildGamificationCard removed


  // _showAchievementsList removed

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
              EmptyStateWidget(
                icon: Icons.event_busy_outlined,
                title: t('no_activity'),
                subtitle: locale == 'zh' ? "这天没有任何专注记录" : "No focus activity recorded for this day",
              )
            else
              // Timeline items with left connecting line
              ...List.generate(tasks.length, (index) {
                final task = tasks[index];
                final isLast = index == tasks.length - 1;
                return TimelineItemWithLine(
                  task: task,
                  isDark: isDark,
                  isLast: isLast,
                  onLongPress: (!task.isDecision && !task.isQuickFocus && task.subTasks.isNotEmpty)
                      ? () => _showSubTasks(task, isDark)
                      : null,
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
                          return TaskListItem(
                            task: task,
                            isDark: isDark,
                            onLongPress: (!task.isDecision && !task.isQuickFocus && task.subTasks.isNotEmpty)
                                ? () => _showSubTasks(task, isDark)
                                : null,
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
  
  // Build search view
  Widget _buildSearchView(List<Task> searchResults, String Function(String) t, bool isDark, String locale) {
    return Column(
      children: [
        // Search Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              // Back button
              IconButton(
                icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              ),
              // Search TextField
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: t('search_hint'),
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                      prefixIcon: Icon(Icons.search, color: isDark ? Colors.white38 : Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: isDark ? Colors.white38 : Colors.grey, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                    textInputAction: TextInputAction.search,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Results count
        if (_searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                locale == 'zh' 
                    ? '找到 ${searchResults.length} 个结果' 
                    : '${searchResults.length} result${searchResults.length == 1 ? '' : 's'} found',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ),
          ),
        
        // Search Results or Empty State
        Expanded(
          child: _searchQuery.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.search_outlined,
                  title: locale == 'zh' ? '搜索任务' : 'Search Tasks',
                  subtitle: locale == 'zh' ? '输入关键词搜索过往的任务' : 'Enter keywords to search past tasks',
                )
              : searchResults.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.search_off_outlined,
                      title: locale == 'zh' ? '没有结果' : 'No Results',
                      subtitle: locale == 'zh' ? '换个搜索词试试吧' : 'Try different keywords',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final task = searchResults[index];
                        return SearchResultCard(
                          task: task,
                          isDark: isDark,
                          searchQuery: _searchQuery,
                          onTap: () => _showTaskDetailCard(task, isDark),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

