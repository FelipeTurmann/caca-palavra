import 'package:flutter/material.dart';

abstract final class GameTheme {
  static const cream = Color(0xFFFFF9EE);
  static const creamEnd = Color(0xFFFFF1D5);
  static const ink = Color(0xFF123B49);
  static const teal = Color(0xFF0B5660);
  static const lightTeal = Color(0xFF187481);
  static const coral = Color(0xFFFF735D);
  static const gold = Color(0xFFF4BD4F);
  static const slotBorder = Color(0xFFCDBB9C);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: cream,
    colorScheme: ColorScheme.fromSeed(seedColor: teal).copyWith(
      primary: teal,
      onPrimary: Colors.white,
      surface: cream,
      onSurface: ink,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 23,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyMedium: TextStyle(fontSize: 15, color: ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
  );
}
