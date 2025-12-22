import 'package:flutter/material.dart';

class AppTheme {
  // Curated Colors
  static const Color primaryBlue = Color(0xFF4A90E2); // Muted Blue
  static const Color accentPurple = Color(0xFF9B51E0); // Muted Purple
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color lightCard = Color(0xFFF2F2F7);
  static const Color glassWhite = Color(0x1FFFFFFF);
  static const Color glassBlack = Color(0x1F000000);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Colors.black,
        onPrimary: Colors.white,
        secondary: Color(0xFF2C2C2E), // Less obvious secondary
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: Colors.black,
        outline: Colors.black12,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
      dividerTheme: const DividerThemeData(color: Colors.black12),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => 
          states.contains(WidgetState.selected) ? Colors.white : Colors.black
        ),
        trackColor: WidgetStateProperty.resolveWith((states) => 
          states.contains(WidgetState.selected) ? Colors.black : Colors.grey[300]
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        elevation: 0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent, 
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.black87,
        contentTextStyle: const TextStyle(color: Colors.white),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      cardColor: darkCard,
      canvasColor: Colors.black,
      dialogBackgroundColor: darkCard,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        onPrimary: Colors.black,
        secondary: Colors.white70,
        onSecondary: Colors.black,
        surface: darkCard,
        onSurface: Colors.white,
        outline: Colors.white10,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
      dividerTheme: const DividerThemeData(color: Colors.white12),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => 
          states.contains(WidgetState.selected) ? Colors.black : Colors.white
        ),
        trackColor: WidgetStateProperty.resolveWith((states) => 
          states.contains(WidgetState.selected) ? Colors.white : Colors.grey[700]
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
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
    );
  }
}


