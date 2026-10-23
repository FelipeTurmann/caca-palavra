import 'package:flutter/material.dart';
import '../theme/visual_theme_catalog.dart';

/// Decoration only: answer scrolling keeps its existing constraints and size.
class ThemedReadingPage extends StatelessWidget {
  const ThemedReadingPage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = VisualThemeScope.of(context);
    if (!theme.isLibrary &&
        !theme.isOcean &&
        !theme.isBees &&
        !theme.isMagic &&
        !theme.isSnow) {
      return child;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.isSnow
              ? const Color(0xB38DCEDD)
              : theme.isOcean
              ? const Color(0xB39CCFC7)
              : theme.isBees
              ? const Color(0xB3D7A249)
              : theme.isMagic
              ? const Color(0xB3AA97B8)
              : const Color(0xB3D6AA7B),
        ),
        gradient: const LinearGradient(
          colors: [Color(0xFAFFF1D5), Color(0xF2FFF9EE), Color(0xFAFFF1D5)],
        ),
      ),
      child: child,
    );
  }
}
