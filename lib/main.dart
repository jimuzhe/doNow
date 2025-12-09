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
  }

  @override
  void dispose() {
    _taskDueSubscription?.cancel();
    super.dispose();
  }

  /// Navigate to task detail screen when a task is due
  void _navigateToTaskDetail(Task task) {
    // Check if this task (or any task) is already being executed
    final activeTaskId = ref.read(activeTaskIdProvider);
    if (activeTaskId != null) {
      // A task is already being executed, don't navigate again
      print('Task ${task.title} is due but another task is already active');
      return;
    }
    
    // Use the global navigator key to navigate
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (context) => TaskDetailScreen(task: task),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
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
          
          return const MainScreen();
        },
        loading: () => const _SplashScreen(),
        error: (_, __) => const LoginScreen(),
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

