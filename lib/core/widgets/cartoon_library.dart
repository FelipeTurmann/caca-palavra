import 'package:flutter/material.dart';
import '../theme/game_theme.dart';

/// Approved scenery stays behind live UI and outside pointer/semantics trees.
class CartoonLibraryBackdrop extends StatelessWidget {
  const CartoonLibraryBackdrop({
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
              'assets/themes/biblioteca_encantada/scenery-cartoon.png',
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
                      Color(0xA8FFF9EE),
                      Color(0x00FFF9EE),
                    ],
                    stops: [0, .40, .68],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class CartoonLibrarySeal extends StatelessWidget {
  const CartoonLibrarySeal({super.key});

  // The seal is above the midpoint of the PNG because the book extends below
  // it. Map its measured center and axes, rather than the canvas, to the wheel.
  static const _sourceSize = 1254.0;
  static const _sealCenter = Offset(626.5, 534.5);
  static const _roundingScale = 823 / 803;

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
                      artWidth * _sealCenter.dx / _sourceSize,
                  top:
                      constraints.maxHeight / 2 -
                      artHeight * _sealCenter.dy / _sourceSize,
                  width: artWidth,
                  height: artHeight,
                  child: Image.asset(
                    'assets/themes/biblioteca_encantada/book-seal-cartoon.png',
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => const Align(
                      alignment: Alignment(-.0027, -.4654),
                      child: FractionallySizedBox(
                        widthFactor: .7,
                        heightFactor: .7 / _roundingScale,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: GameTheme.teal,
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
