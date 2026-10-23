import 'package:flutter/material.dart';
import '../theme/game_theme.dart';

/// Approved classroom art, separate from live controls and semantics.
class CartoonMagicBackdrop extends StatelessWidget {
  const CartoonMagicBackdrop({
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
              'assets/themes/escola_magia/scenery-cartoon.png',
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

class CartoonMagicCauldron extends StatelessWidget {
  const CartoonMagicCauldron({super.key});

  // The body adds depth below the opening. Map the measured liquid center and
  // axes to the wheel, preserving the existing token and pointer coordinates.
  static const _sourceSize = 1254.0;
  static const _openingCenter = Offset(622.5, 610);
  static const _roundingScale = 919 / 898;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final artWidth = constraints.maxWidth;
            final artHeight = constraints.maxHeight * _roundingScale;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left:
                      constraints.maxWidth / 2 -
                      artWidth * _openingCenter.dx / _sourceSize,
                  top:
                      constraints.maxHeight / 2 -
                      artHeight * _openingCenter.dy / _sourceSize,
                  width: artWidth,
                  height: artHeight,
                  child: Image.asset(
                    'assets/themes/escola_magia/cauldron-cartoon.png',
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => const Align(
                      alignment: Alignment(-.024, -.086),
                      child: FractionallySizedBox(
                        widthFactor: .7,
                        heightFactor: .7 / _roundingScale,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFBEEBD8),
                            border: Border.fromBorderSide(
                              BorderSide(color: GameTheme.gold, width: 4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
