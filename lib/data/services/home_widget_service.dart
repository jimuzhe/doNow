import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class HomeWidgetService {
  // MUST MATCH the App Group ID in Xcode Entitlements
  static const String appGroupId = 'group.com.donow.app';
  static const String iOSWidgetName = 'DoNowHomeWidget';

  /// Update the Home Screen Widget with latest task data
  /// [locale] - Current app locale ('zh' or 'en')
  Future<void> updateWidget(List<Task> tasks, {String locale = 'en'}) async {
    // Skip on web platform - home_widget only works on iOS/Android
    if (kIsWeb) {
      debugPrint('📱 Home Widget: Skipping on web platform');
      return;
    }
    
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

      // Set the App Group ID globally for iOS
      await HomeWidget.setAppGroupId(appGroupId);

      // Save locale for iOS Widget to use
      await HomeWidget.saveWidgetData<String>('locale', locale);
      
      // Save localized static labels
      final bool isChinese = locale == 'zh';
      await HomeWidget.saveWidgetData<String>('label_pending', isChinese ? '待办' : 'Pending');
      await HomeWidget.saveWidgetData<String>('label_tasks', isChinese ? '任务' : 'Tasks');
      await HomeWidget.saveWidgetData<String>('label_up_next', isChinese ? '下一个' : 'UP NEXT');
      await HomeWidget.saveWidgetData<String>('label_no_tasks', isChinese ? '暂无任务' : 'No Tasks');
      await HomeWidget.saveWidgetData<String>('label_all_clear', isChinese ? '全部完成' : 'All Clear');

      // Save data for iOS Widget
      await HomeWidget.saveWidgetData<int>('pending_count', pendingCount);
      
      if (nextTask != null) {
        await HomeWidget.saveWidgetData<String>('next_task_title', nextTask.title);
        final timeStr = DateFormat('HH:mm').format(nextTask.scheduledStart);
        await HomeWidget.saveWidgetData<String>('next_task_time', timeStr);
      } else {
        await HomeWidget.saveWidgetData<String>('next_task_title', isChinese ? '全部完成' : 'All Clear');
        await HomeWidget.saveWidgetData<String>('next_task_time', '--:--');
      }
      
      // Force update the widget
      await HomeWidget.updateWidget(
        iOSName: iOSWidgetName,
        androidName: iOSWidgetName, // Often helpful to set generic name or specific android name if setup
      );
      
      debugPrint('📱 Home Widget updated: $pendingCount pending (locale: $locale)');
    } catch (e) {
      debugPrint('❌ Error updating Home Widget: $e');
    }
  }
}
