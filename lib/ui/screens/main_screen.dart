import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/haptic_helper.dart';
import 'home_screen.dart';
import 'analysis_screen.dart';
import 'settings_screen.dart';
import 'quick_focus_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;
  bool _isInLandscapeFocus = false; // Track if we navigated to landscape focus
  
  final List<Widget> _screens = [
    const HomeScreen(), // 0
    const AnalysisScreen(), // 1
    const SettingsScreen(), // 2
  ];

  void _onTabTapped(int index) {
    HapticHelper(ref).lightImpact();
    setState(() {
      _currentIndex = index;
    });
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
    
    // If landscape and not already in focus mode, navigate to Quick Focus
    // Only trigger this once per landscape rotation
    if (orientation == Orientation.landscape && !_isInLandscapeFocus) {
      // Use post-frame callback to avoid building during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && MediaQuery.of(context).orientation == Orientation.landscape) {
          _navigateToQuickFocus();
        }
      });
    }

    // Portrait: Standard Tabbed View
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
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
