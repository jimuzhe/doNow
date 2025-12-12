import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/daily_summary.dart';
import '../providers.dart';
import '../localization.dart';

// Provider
final dailySummaryServiceProvider = Provider<DailySummaryService>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  final taskList = ref.watch(taskListProvider);
  return DailySummaryService(aiService, taskList);
});

final dailySummaryProvider = StateNotifierProvider<DailySummaryNotifier, Map<String, DailySummary>>((ref) {
  return DailySummaryNotifier();
});

class DailySummaryNotifier extends StateNotifier<Map<String, DailySummary>> {
  DailySummaryNotifier() : super({});

  void addSummary(DailySummary summary) {
    final key = DateUtils.dateOnly(summary.date).toIso8601String();
    state = {...state, key: summary};
    _saveToStorage(key, summary);
  }

  void loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('summary_'));
    Map<String, DailySummary> loaded = {};
    for (var key in keys) {
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        try {
          final summary = DailySummary.fromJson(jsonDecode(jsonStr));
          final dateKey = DateUtils.dateOnly(summary.date).toIso8601String();
          loaded[dateKey] = summary;
        } catch (_) {}
      }
    }
    state = loaded;
  }

  Future<void> _saveToStorage(String dateKey, DailySummary summary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('summary_$dateKey', jsonEncode(summary.toJson()));
  }
}

class DailySummaryService {
  final dynamic _aiService;
  // ignore: unused_field
  final List<dynamic> _allTasks;
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  DailySummaryService(this._aiService, this._allTasks);

  // Initialize timezone and notifications
  static Future<void> initializeNotifications() async {
    if (_isInitialized) return;
    
    // Initialize timezone
    tz_data.initializeTimeZones();
    
    // Initialize notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(settings);
    _isInitialized = true;
  }

  // Schedule daily reminder notification at 8:00 AM
  Future<void> scheduleDailyReminder({int hour = 8, int minute = 0, String locale = 'en'}) async {
    // Skip on web
    if (kIsWeb) return;
    
    await initializeNotifications();
    
    // Cancel existing scheduled notification
    await _notifications.cancel(100);
    
    // Calculate next 8 AM
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
    
    // If it's already past 8 AM today, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    
    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
    
    // Localized notification text
    final title = locale == 'zh' ? '📊 昨日总结已就绪' : '📊 Yesterday\'s Summary Ready';
    final body = locale == 'zh' ? '查看你的表现，获取AI洞见！' : 'Check out your performance and get AI insights!';
    
    // Android notification details
    final androidDetails = AndroidNotificationDetails(
      'daily_summary_reminder',
      locale == 'zh' ? '每日总结提醒' : 'Daily Summary Reminder',
      channelDescription: locale == 'zh' ? '提醒您查看昨日总结' : 'Reminds you to check yesterday\'s summary',
      importance: Importance.high,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    try {
      await _notifications.zonedSchedule(
        100, // Notification ID
        title,
        body,
        tzScheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at same time
      );
      debugPrint('📅 Daily reminder scheduled for ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}');
    } catch (e) {
      debugPrint('❌ Failed to schedule daily reminder: $e');
    }
  }

  // Cancel daily reminder
  Future<void> cancelDailyReminder() async {
    if (kIsWeb) return;
    await _notifications.cancel(100);
    debugPrint('🔕 Daily reminder cancelled');
  }

  // Save a summary from the daily summary screen
  void saveSummary(
    WidgetRef ref,
    DateTime date,
    String summary,
    String encouragement,
    String improvement,
  ) {
    final dailySummary = DailySummary(
      date: date,
      summary: summary,
      encouragement: encouragement,
      improvement: improvement,
    );
    ref.read(dailySummaryProvider.notifier).addSummary(dailySummary);
  }

  // Check if we need to generate summary for yesterday
  Future<void> checkAndGenerate(WidgetRef ref) async {
    // Get current locale for notification text
    final locale = ref.read(localeProvider);
    
    // Schedule daily reminder (if not already scheduled)
    scheduleDailyReminder(locale: locale);

    final now = DateTime.now();
    // Only generate after 8:00 AM per user request
    if (now.hour < 8) return;

    final prefs = await SharedPreferences.getInstance();
    final lastCheckStr = prefs.getString('last_summary_check');
    final today = DateUtils.dateOnly(now);
    
    // If we haven't checked today
    if (lastCheckStr == null || lastCheckStr != today.toIso8601String()) {
      // Logic: Generate summary for YESTERDAY
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayKey = yesterday.toIso8601String();
      
      // Check if we already have a summary for yesterday
      final existing = ref.read(dailySummaryProvider)[yesterdayKey];
      if (existing == null) {
        // Generate it
        try {
           final tasks = ref.read(taskListProvider); 
           
           final summary = await _aiService.generateDailySummary(tasks, yesterday, locale: locale);
           ref.read(dailySummaryProvider.notifier).addSummary(summary);
           
        } catch (e) {
          debugPrint("Failed to generate daily summary: $e");
        }
      }
      
      // Update check time
      await prefs.setString('last_summary_check', today.toIso8601String());
    }
  }
}

