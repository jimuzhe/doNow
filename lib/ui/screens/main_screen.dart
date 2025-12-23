import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/haptic_helper.dart';
import 'home_screen.dart';
import 'analysis_screen.dart';
import 'settings_screen.dart';
import 'quick_focus_screen.dart';
import '../../data/providers.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  bool _isInLandscapeFocus = false; // Track if we navigated to landscape focus
  Orientation? _lastOrientation; // Track previous orientation to detect change
  
  final List<Widget> _screens = [
    const HomeScreen(), // 0
    const AnalysisScreen(), // 1
    const SettingsScreen(), // 2
  ];

  void _onTabTapped(int index) {
    HapticHelper(ref).lightImpact();
    ref.read(mainTabIndexProvider.notifier).state = index;
  }
  
  void _navigateToQuickFocus() {
    if (_isInLandscapeFocus) return; // Already navigated
    _isInLandscapeFocus = true;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const QuickFocusScreen(isAutoLandscape: true),
      ),
    ).then((_) {
      // When user returns from QuickFocusScreen
      _isInLandscapeFocus = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final orientation = MediaQuery.of(context).orientation;
    final autoFocusEnabled = ref.watch(autoLandscapeFocusProvider);
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final isTablet = shortestSide >= 600;
    
    // Auto-Focus Navigation Logic:
    // 1. Must be Landscape
    // 2. Must not already be in focus screen
    // 3. User must have the feature ENABLED
    // 4. We SKIP this for tablets (iPad), as landscape is a primary orientation there
    // 5. We only trigger if orientation actually CHANGED to landscape
    if (orientation == Orientation.landscape && 
        _lastOrientation == Orientation.portrait &&
        !_isInLandscapeFocus && 
        autoFocusEnabled && 
        !isTablet) {
      
      // Use post-frame callback to avoid building during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Double check mounted and still landscape
        if (mounted && MediaQuery.of(context).orientation == Orientation.landscape) {
          _navigateToQuickFocus();
        }
      });
    }
    
    // Update orientation tracker
    _lastOrientation = orientation;

    // Portrait: Standard Tabbed View
    final currentIndex = ref.watch(mainTabIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: _onTabTapped,
          backgroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0, // Flat
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          selectedItemColor: isDark ? Colors.white : Colors.black,
          unselectedItemColor: Colors.grey[500],
          iconSize: 28,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_filled),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined), // More twitter like analysis icon?
              activeIcon: Icon(Icons.bar_chart),
              label: 'Analysis',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Me',
            ),
          ],
        ),
      ),
    );
  }
}
