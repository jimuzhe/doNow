import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'ui/screens/main_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/email_verification_screen.dart';
import 'ui/screens/task_detail_screen.dart';
import 'data/providers.dart';
import 'data/localization.dart';
import 'data/models/task.dart';
import 'data/services/notification_service.dart';
import 'data/services/task_scheduler_service.dart';
import 'data/services/storage_service.dart';
import 'data/services/sound_effect_service.dart';
import 'data/services/auth_service.dart';
import 'ui/widgets/dynamic_island_simulation.dart';

// Global navigator key for navigation from services
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global scaffold messenger key for showing SnackBars on top of everything
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// Global route observer
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Storage Service before running app
  final storageService = StorageService();
  await storageService.init();
  
  runApp(
    ProviderScope(
      overrides: [
        // Override the storage service provider with initialized instance
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const AtomicApp(),
    ),
  );
}

class AtomicApp extends ConsumerStatefulWidget {
  const AtomicApp({super.key});

  @override
  ConsumerState<AtomicApp> createState() => _AtomicAppState();
}

class _AtomicAppState extends ConsumerState<AtomicApp> {
  StreamSubscription<Task>? _taskDueSubscription;
  StreamSubscription<Task>? _taskUpcomingSubscription;
  final List<String> _deferredTaskQueue = []; // Queue of tasks waiting for user to become free

  @override
  void initState() {
    super.initState();
    
    // Initialize Notifications
    ref.read(notificationServiceProvider).init();
    
    // Initialize Sound Effects
    ref.read(soundEffectServiceProvider).init();
    
    // Initialize Task Scheduler
    final scheduler = ref.read(taskSchedulerServiceProvider);
    scheduler.init();
    
    // Listen for due tasks and navigate automatically
    _taskDueSubscription = scheduler.onTaskDue.listen((task) {
      _navigateToTaskDetail(task);
    });
    
    // Listen for upcoming task warnings
    _taskUpcomingSubscription = scheduler.onTaskUpcoming.listen((task) {
      // Only show blocking dialog if user is "busy" 
      // (Running a task, or in Quick Focus / Decision screen)
      if (_isBusy()) {
        _showUpcomingDialog(task);
      } else {
        // If not busy (Home, Settings, Analysis), do nothing here.
        // The system notification will still show (via scheduler), 
        // and when time is up, it will direct jump.
      }
    });
  }

  @override
  void dispose() {
    _taskDueSubscription?.cancel();
    _taskUpcomingSubscription?.cancel();
    super.dispose();
  }

  /// Check if user is currently in a "blocking" activity or screen
  bool _isBusy() {
    final context = navigatorKey.currentContext;
    if (context == null) return false;

    // 1. Check if a task is actively running
    final activeTaskId = ref.read(activeTaskIdProvider);
    if (activeTaskId != null) return true;
    
    // 2. Check explicit busy UI state (Decision / Quick Focus)
    return ref.read(isBusyUIProvider);
  }

  /// Navigate to task detail screen when a task is due
  void _navigateToTaskDetail(Task task) {
    if (_isBusy()) {
      // User is busy, show reminder dialog instead of forcing navigation
      _showTaskDueDialog(task);
      return;
    }
    
    // If this task was in the deferred queue, remove it
    _deferredTaskQueue.remove(task.id);
    
    // Navigate
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(task: task),
      ),
    );
  }

  /// Show dialog when task is explicitly DUE (0s) but user is busy
  void _showTaskDueDialog(Task task) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final t = AppStrings.get;
    final locale = ref.read(localeProvider);
    
    // Construct message: "Task <Title> will start immediately after you finish."
    final msg = locale == 'zh'
        ? "在您结束当前工作后，事项 \"${task.title}\" 将会立即开始。"
        : "Task \"${task.title}\" will start immediately after you finish current work.";
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(t('task_starting', locale)),
          content: Text(msg),
          actions: [
             ElevatedButton(
               onPressed: () {
                 Navigator.pop(context);
                 // Add to deferred queue (avoid duplicates)
                 if (!_deferredTaskQueue.contains(task.id)) {
                   _deferredTaskQueue.add(task.id);
                 }
               },
               child: Text(t('ok_cool', locale)), // "I know"
             ),
          ],
        );
      },
    );
  }

  /// Show dialog for upcoming task (3 min warning)
  void _showUpcomingDialog(Task task) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    
    final locale = ref.read(localeProvider);
    final t = AppStrings.get;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: Text(t('upcoming_task', locale)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text(t('upcoming_task_desc', locale)),
            ],
          ),
          actions: [
             // "I Know" - Dismiss and stay
             TextButton(
               onPressed: () => Navigator.pop(context),
               child: Text(t('ok_cool', locale), style: const TextStyle(color: Colors.grey)),
             ),
             
             // "Postpone" - Reschedule
             ElevatedButton(
               onPressed: () {
                 Navigator.pop(context); // Close dialog
                 _showRescheduleSheet(task);
               },
               style: ElevatedButton.styleFrom(
                 backgroundColor: isDark ? Colors.white : Colors.black,
                 foregroundColor: isDark ? Colors.black : Colors.white,
               ),
               child: Text(t('action_delay', locale)), // Use "Delay/Postpone" label
             ),
          ],
        );
      },
    );
  }

  /// Show sheet to reschedule a task
  void _showRescheduleSheet(Task task) async {
     final context = navigatorKey.currentContext;
     if (context == null) return;
     
     final locale = ref.read(localeProvider);
     final isDark = Theme.of(context).brightness == Brightness.dark;
     final t = AppStrings.get;
     
     // Default reschedule: +10 mins or +30 mins?
     // Let's default to next 15 min slot or just +15 mins
     DateTime selectedTime = DateTime.now().add(const Duration(minutes: 15));
     
     await showModalBottomSheet(
       context: context,
       backgroundColor: Theme.of(context).cardColor,
       builder: (ctx) => Container(
         height: 300,
         padding: const EdgeInsets.all(16),
         child: Column(
           children: [
             Text(
               t('reschedule', locale), 
               style: TextStyle(
                 fontWeight: FontWeight.bold, 
                 fontSize: 18,
                 color: isDark ? Colors.white : Colors.black,
               ),
             ),
             const SizedBox(height: 16),
             Expanded(
               child: CupertinoTheme(
                 data: CupertinoThemeData(
                   brightness: isDark ? Brightness.dark : Brightness.light,
                   textTheme: CupertinoTextThemeData(
                     dateTimePickerTextStyle: TextStyle(
                       color: isDark ? Colors.white : Colors.black,
                       fontSize: 20,
                     ),
                   ),
                 ),
                 child: CupertinoDatePicker(
                   mode: CupertinoDatePickerMode.dateAndTime,
                   initialDateTime: selectedTime,
                   minimumDate: DateTime.now(),
                   use24hFormat: true,
                   onDateTimeChanged: (val) {
                      selectedTime = val;
                   },
                 ),
               ),
             ),
             const SizedBox(height: 16),
             SizedBox(
               width: double.infinity,
               child: ElevatedButton(
                 onPressed: () {
                   Navigator.pop(ctx);
                   // Update task
                   final updated = task.copyWith(scheduledStart: selectedTime);
                   ref.read(taskRepositoryProvider).updateTask(updated);
                   
                   // Reset notification state so it triggers again at new time
                   ref.read(taskSchedulerServiceProvider).resetTaskNotification(task.id);
                   ref.read(taskSchedulerServiceProvider).resetTaskNotification('${task.id}_upcoming');
                   ref.read(taskSchedulerServiceProvider).resetTaskNotification('${task.id}_due');
                   
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text("Rescheduled to ${_formatTime(selectedTime)}"))
                   );
                 },
                 style: ElevatedButton.styleFrom(
                   backgroundColor: isDark ? Colors.white : Colors.black,
                   foregroundColor: isDark ? Colors.black : Colors.white,
                 ),
                 child: Text(t('save', locale)),
               ),
             )
           ],
         ),
       ),
     );
  }
  
  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
  }
  
  void _checkDeferredTask() {
    if (_deferredTaskQueue.isEmpty) return;
    
    final context = navigatorKey.currentContext;
    if (context == null) return;
    
    // FAILSAFE: If we're at the navigation root (MainScreen), force reset the busy state.
    // This handles cases where dispose() failed to reset isBusyUIProvider (e.g., ref was invalid).
    if (!Navigator.canPop(context)) {
      // We're at root - definitely not in a sub-screen
      // Force reset to false in case it got stuck
      try {
        if (ref.read(isBusyUIProvider)) {
          ref.read(isBusyUIProvider.notifier).state = false;
        }
      } catch (_) {}
    }
    
    // Now check if still busy (could be in TaskDetailScreen which sets activeTaskIdProvider)
    if (_isBusy()) return;
    
    // Take the FIRST task from the queue (FIFO)
    final deferredTaskId = _deferredTaskQueue.first;
    
    // Retrieve task
    final tasks = ref.read(taskListProvider);
    final task = tasks.firstWhere((t) => t.id == deferredTaskId, orElse: () => Task(id: 'null', title: '', totalDuration: Duration.zero, scheduledStart: DateTime.now(), subTasks: []));
    
    if (task.id != 'null') {
      // Found deferred task.
      // 1. Update its Scheduled Start to NOW (Time also changes as requested)
      final now = DateTime.now();
      final updatedTask = task.copyWith(scheduledStart: now);
      ref.read(taskRepositoryProvider).updateTask(updatedTask);
      
      // NOTE: We don't reset notification markers here anymore.
      // The scheduler now properly skips tasks that are already running (activeTaskId == task.id).
      
      // 3. Remove from queue BEFORE navigation to prevent re-entry
      _deferredTaskQueue.remove(deferredTaskId);
      
      // 4. Navigate directly to task (bypassing _navigateToTaskDetail to avoid re-checking _isBusy)
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => TaskDetailScreen(task: updatedTask),
        ),
      );
      
      // Feedback: Show how many tasks remaining in queue
      final locale = ref.read(localeProvider);
      final remaining = _deferredTaskQueue.length;
      String msg;
      if (remaining > 0) {
        msg = locale == 'zh' 
            ? '开始延后的任务: ${task.title} (还有 $remaining 个待执行)' 
            : 'Resuming: ${task.title} ($remaining more in queue)';
      } else {
        msg = locale == 'zh' ? '开始延后的任务: ${task.title}' : 'Resuming deferred task: ${task.title}';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } else {
      // Task not found (maybe deleted), remove from queue and try next
      _deferredTaskQueue.remove(deferredTaskId);
      if (_deferredTaskQueue.isNotEmpty) {
        // Recursively check for next task
        _checkDeferredTask();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [
         // Custom observer to handle deferred task checks on Pop
         _DeferredTaskObserver(onDidPop: _checkDeferredTask),
      ],
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'Do Now',
      debugShowCheckedModeBanner: false,
      // Localization support for Chinese date/time pickers
      locale: Locale(locale),
      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Colors.black,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
          outline: Colors.black,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        dividerTheme: const DividerThemeData(color: Colors.black12),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.white : Colors.black),
          trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.black : Colors.grey[300]),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          surfaceTintColor: Colors.transparent, 
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.black87,
          contentTextStyle: const TextStyle(color: Colors.white),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black, // Pure black background
        cardColor: const Color(0xFF1C1C1E), // Slightly lighter for cards
        canvasColor: Colors.black,
        dialogBackgroundColor: const Color(0xFF1C1C1E),
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.black,
          secondary: Colors.white,
          onSecondary: Colors.black,
          surface: Color(0xFF1C1C1E),
          onSurface: Colors.white,
          outline: Colors.white54,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        dividerTheme: const DividerThemeData(color: Colors.white12),
        switchTheme: SwitchThemeData(
          // Light Grey/White for active track in dark mode looks clean
          thumbColor: WidgetStateProperty.resolveWith((states) => 
            states.contains(WidgetState.selected) ? Colors.black : Colors.white
          ),
          trackColor: WidgetStateProperty.resolveWith((states) => 
            states.contains(WidgetState.selected) ? Colors.white : Colors.grey[700]
          ),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.black, // Pure black
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black, // Pure black
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF333333),
          contentTextStyle: const TextStyle(color: Colors.white),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      builder: (context, child) {
        // Only show simulated Dynamic Island on desktop/web platforms
        // iOS uses native Live Activity, Android uses Foreground Service Notification
        final platform = Theme.of(context).platform;
        if (platform != TargetPlatform.iOS && platform != TargetPlatform.android) {
          return DynamicIslandSimulation(child: child!);
        }
        return child!;
      },
      // Show appropriate screen based on auth state and email verification
      home: authState.when(
        data: (user) {
          if (user == null) {
            return const LoginScreen();
          }
          
          // Update storage service with current user ID
          final storage = ref.read(storageServiceProvider);
          final previousUserId = storage.userId;
          storage.setUserId(user.uid);
          
          // Refresh task data when user changes
          if (previousUserId != user.uid) {
            // Invalidate both task providers to reload user-specific data
            ref.invalidate(taskListProvider);
            ref.invalidate(taskRepositoryProvider);
            ref.invalidate(apiSettingsProvider);
            ref.invalidate(aiPersonaProvider);
          }
          
          // Check if email needs verification (skip for anonymous users)
          if (!user.isAnonymous) {
            // Watch the verification provider for realtime updates
            final isEmailVerified = ref.watch(emailVerifiedProvider);
            if (!isEmailVerified && !user.emailVerified) {
              return const EmailVerificationScreen();
            }
          }
          
          // Create onboarding task for first-time users (after login)
          ref.read(taskListProvider.notifier).checkAndCreateOnboardingTask();
          
          return const MainScreen();
        },
        loading: () => const _SplashScreen(),
        // When Firebase is blocked (error), go directly to MainScreen (offline mode)
        error: (error, stackTrace) {
          debugPrint('Auth error (possibly Firebase blocked): $error');
          return const MainScreen();
        },
      ),
    );
  }
}

/// Simple splash screen shown while checking auth state
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeferredTaskObserver extends NavigatorObserver {
  final VoidCallback onDidPop;
  
  _DeferredTaskObserver({required this.onDidPop});

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // Use a delay to ensure the popped widget is fully disposed
    // and isBusyUIProvider has been reset. Transition animations
    // typically take 300ms, so 400ms gives margin.
    Future.delayed(const Duration(milliseconds: 400), onDidPop);
  }
}
