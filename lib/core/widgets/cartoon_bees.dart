import 'package:flutter/material.dart';
import '../theme/game_theme.dart';

/// Approved art only; live text, controls and pointer geometry stay separate.
class CartoonBeesBackdrop extends StatelessWidget {
  const CartoonBeesBackdrop({
    super.key,
    this.quiet = false,
    this.gameplay = false,
  });
  final bool quiet, gameplay;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/themes/jardim_abelhas/scenery-cartoon.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: GameTheme.cream),
            ),
            if (quiet)
              const ColoredBox(color: Color(0xE6FFF9EE))
            else if (gameplay)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x70FFF9EE),
                      Color(0x50FFF9EE),
                      Color(0x00FFF9EE),
                    ],
                    stops: [0, .4, .65],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class CartoonBeesFlower extends StatelessWidget {
  const CartoonBeesFlower({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        // The circular flower center is centered in the approved square PNG.
        // It uses the same box as the wheel without moving the live tokens.
        child: Image.asset(
          'assets/themes/jardim_abelhas/flower-cartoon.png',
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => const Padding(
            padding: EdgeInsets.all(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GameTheme.gold,
                border: Border.fromBorderSide(
                  BorderSide(color: GameTheme.cream, width: 8),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
