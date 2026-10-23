import 'package:flutter/material.dart';
import '../theme/game_theme.dart';

/// Approved snowy scenery, separate from live controls and semantics.
class CartoonSnowBackdrop extends StatelessWidget {
  const CartoonSnowBackdrop({
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
              'assets/themes/refugio_neve/scenery-cartoon.png',
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

class CartoonSnowDisc extends StatelessWidget {
  const CartoonSnowDisc({super.key});

  // The measured rim is centered at (626.5, 626.5) in the 1254px PNG.
  // Remove transparent margins and round its 1157 x 1137px axes using only
  // the art transform. Tokens, connections and hit testing do not move.
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: Transform.scale(
          scaleX: 1.08,
          scaleY: 1.08 * 1157 / 1137,
          child: Image.asset(
            'assets/themes/refugio_neve/ice-disc-cartoon.png',
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFD9F5FC),
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0xFF8DCEDD), width: 3),
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
