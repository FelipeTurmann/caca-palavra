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
  static const cardRadius = 24.0;
  static const buttonRadius = 22.0;
  static const pagePadding = 20.0;
  static ThemeData get theme => ThemeData(
    fontFamily: 'Nunito',
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _GentleTransitions(),
        TargetPlatform.iOS: _GentleTransitions(),
        TargetPlatform.windows: _GentleTransitions(),
        TargetPlatform.linux: _GentleTransitions(),
        TargetPlatform.macOS: _GentleTransitions(),
      },
    ),
    listTileTheme: const ListTileThemeData(enableFeedback: false),
    appBarTheme: const AppBarTheme(
      backgroundColor: cream,
      foregroundColor: ink,
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFFFFFBF1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFFFFFBF1),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: const BorderSide(color: Color(0xFFEED6AE)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFFFF4DC),
      side: const BorderSide(color: Color(0xFFEED6AE)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        enableFeedback: false,
        minimumSize: const Size(48, 48),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        enableFeedback: false,
        minimumSize: const Size(48, 48),
      ),
    ),
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
        enableFeedback: false,
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
  );
}

class _GentleTransitions extends PageTransitionsBuilder {
  const _GentleTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => MediaQuery.disableAnimationsOf(context)
      ? child
      : FadeTransition(opacity: animation, child: child);
}
