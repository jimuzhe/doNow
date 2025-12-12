import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class HomeWidgetService {
  // MUST MATCH the App Group ID in Xcode
  static const String appGroupId = 'group.com.atomictask.donow'; // User needs to verify this later
  static const String iOSWidgetName = 'DoNowHomeWidget';

  /// Update the Home Screen Widget with latest task data
  Future<void> updateWidget(List<Task> tasks) async {
    try {
      final now = DateTime.now();
      
      // Calculate pending tasks for today
      final todayTasks = tasks.where((t) {
        final isToday = t.scheduledStart.year == now.year &&
            t.scheduledStart.month == now.month &&
            t.scheduledStart.day == now.day;
        return isToday && !t.isCompleted && !t.isAbandoned;
      }).toList();
      
      final pendingCount = todayTasks.length;
      
      // Find next task
      todayTasks.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
      final nextTask = todayTasks.firstOrNull; // Requires Dart 3

      // Save data for iOS Widget
      await HomeWidget.saveWidgetData<int>('pending_count', pendingCount);
      
      if (nextTask != null) {
        await HomeWidget.saveWidgetData<String>('next_task_title', nextTask.title);
        final timeStr = DateFormat('HH:mm').format(nextTask.scheduledStart);
        await HomeWidget.saveWidgetData<String>('next_task_time', timeStr);
      } else {
        await HomeWidget.saveWidgetData<String>('next_task_title', 'All Clear');
        await HomeWidget.saveWidgetData<String>('next_task_time', '--:--');
      }
      
      // Force update the widget
      await HomeWidget.updateWidget(
        iOSName: iOSWidgetName,
      );
      
      debugPrint('📱 Home Widget updated: $pendingCount pending');
    } catch (e) {
      debugPrint('❌ Error updating Home Widget: $e');
    }
  }
}
