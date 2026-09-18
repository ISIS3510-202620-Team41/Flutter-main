import 'package:flutter/material.dart';

class AppColors {
  static const blue = Color(0xFF89CFE0);
  static const rosewood = Color(0xFFC90956);
  static const yellow = Color(0xFFFDCA64);
  static const green = Color(0xFF01A74C);
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.rosewood,
      onPrimary: AppColors.white,
      secondary: AppColors.blue,
      onSecondary: AppColors.black,
      surface: AppColors.white,
      onSurface: AppColors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.white,
      fontFamily: 'ABeeZee',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.rosewood.withOpacity(0.10),
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontSize: 11),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.rosewood);
          }
          return const IconThemeData(color: AppColors.black);
        }),
      ),
    );
  }
}
