import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF3B82F6);
  static const Color backgroundColor = Color(0xFF111827);
  static const Color surfaceColor = Color(0xFF1F2937);
  static const Color cardColor = Color(0xFF374151);
  
  // Role colors
  static const Color superAdminColor = Color(0xFFEF4444);
  static const Color adminColor = Color(0xFFF97316);
  static const Color moderatorColor = Color(0xFFEAB308);
  static const Color userColor = Color(0xFF22C55E);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        background: backgroundColor,
        surface: surfaceColor,
        onBackground: Colors.white,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  static Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return superAdminColor;
      case 'admin':
        return adminColor;
      case 'moderator':
        return moderatorColor;
      case 'user':
        return userColor;
      default:
        return Colors.grey;
    }
  }
}