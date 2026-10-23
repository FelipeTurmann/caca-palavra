import 'package:flutter/material.dart';
import '../theme/game_theme.dart';

/// The approved scenery is decoration, never a control or a semantics node.
class CartoonOceanBackdrop extends StatelessWidget {
  const CartoonOceanBackdrop({
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
              'assets/themes/fundo_mar/scenery-cartoon.png',
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
                      Color(0x90FFF9EE),
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

class CartoonOceanShell extends StatelessWidget {
  const CartoonOceanShell({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        // Compensate the transparent margin, keeping the shell cavity centered
        // on the existing wheel. Letter positions and hit testing do not move.
        child: Transform.scale(
          scale: 1.04,
          child: Image.asset(
            'assets/themes/fundo_mar/shell-cartoon.png',
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GameTheme.cream,
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0xFFE5B9A3), width: 3),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
