import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/haptic_helper.dart';
import 'home_screen.dart';
import 'analysis_screen.dart';
import 'settings_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;
  
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

  @override
  Widget build(BuildContext context) {
    // We don't really need locale here for icons-only nav
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
          backgroundColor: Colors.white,
          elevation: 0, // Flat
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey[400],
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
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
