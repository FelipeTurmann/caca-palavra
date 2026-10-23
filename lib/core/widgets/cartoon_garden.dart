import 'package:flutter/material.dart';
import '../theme/game_theme.dart';
import '../theme/visual_theme_catalog.dart';

/// Approved garden art is decoration only, outside touch and semantics trees.
class CartoonGardenBackdrop extends StatelessWidget {
  const CartoonGardenBackdrop({
    super.key,
    this.quiet = false,
    this.gameplay = false,
    this.fallback,
  });
  final bool quiet, gameplay;
  final Widget? fallback;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/themes/jardim_gatinho/scenery-cartoon.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) =>
                  fallback ?? const ColoredBox(color: GameTheme.cream),
            ),
            if (quiet)
              const ColoredBox(color: Color(0xD9FFF9EE))
            else if (gameplay)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x18FFF9EE),
                      Color(0x70FFF9EE),
                      Color(0x40FFF9EE),
                      Color(0x00FFF9EE),
                    ],
                    stops: [0, .18, .43, .62],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class CartoonGardenBed extends StatelessWidget {
  const CartoonGardenBed({super.key});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: Image.asset(
          'assets/themes/jardim_gatinho/flowerbed-cartoon.png',
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => const Padding(
            padding: EdgeInsets.all(18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFBFD68C),
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFFDFC79E), width: 4),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class CartoonGardenCornerMascot extends StatelessWidget {
  const CartoonGardenCornerMascot({super.key});
  @override
  Widget build(BuildContext context) =>
      const ThemeMascot(theme: VisualTheme.garden, height: 94, width: 84);
}
