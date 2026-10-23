import 'package:flutter/material.dart';
import '../../../../core/theme/game_theme.dart';
import '../../../../core/theme/visual_theme_catalog.dart';
import '../../../../core/widgets/lagoon.dart';
import '../../../../core/widgets/cartoon_garden.dart';
import '../../../../core/widgets/cartoon_library.dart';
import '../../../../core/widgets/cartoon_ocean.dart';
import '../../../../core/widgets/cartoon_bees.dart';
import '../../../../core/widgets/cartoon_magic.dart';
import '../../../../core/widgets/cartoon_snow.dart';
import '../game_controller.dart';
import '../wheel_gesture.dart';

class LetterWheel extends StatelessWidget {
  const LetterWheel({super.key, required this.controller, required this.size});
  final GameController controller;
  final double size;
  @override
  Widget build(BuildContext context) {
    final geometry = WheelGeometry(size, controller.state.order);
    if (controller.configureGeometry(geometry)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.refresh());
    }
    final reduced = MediaQuery.disableAnimationsOf(context);
    final selected = controller.gesture.selected;
    final lagoon = VisualThemeScope.of(context).isLagoon;
    final library = VisualThemeScope.of(context).isLibrary;
    final ocean = VisualThemeScope.of(context).isOcean;
    final bees = VisualThemeScope.of(context).isBees;
    final magic = VisualThemeScope.of(context).isMagic;
    final snow = VisualThemeScope.of(context).isSnow;
    final tealTokens = bees || magic;
    return SizedBox(
      key: const ValueKey('letter-wheel'),
      width: size,
      height: size,
      // Claim pans within the wheel so an outer accessibility/landscape scroll
      // view cannot move the geometry underneath an active letter gesture.
      child: GestureDetector(
        onPanStart: (_) {},
        onPanUpdate: (_) {},
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) =>
              controller.down(event.pointer, event.localPosition),
          onPointerMove: (event) =>
              controller.move(event.pointer, event.localPosition),
          onPointerUp: (event) =>
              controller.up(event.pointer, event.localPosition),
          onPointerCancel: (event) => controller.cancelPointer(event.pointer),
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: lagoon
                      ? const LagoonIsland()
                      : library
                      ? const CartoonLibrarySeal()
                      : ocean
                      ? const CartoonOceanShell()
                      : bees
                      ? const CartoonBeesFlower()
                      : magic
                      ? const CartoonMagicCauldron()
                      : snow
                      ? const CartoonSnowDisc()
                      : const CartoonGardenBed(),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: ConnectionPainter(
                        centers: geometry.centers,
                        selected: selected,
                        pointer: controller.gesture.position,
                      ),
                    ),
                  ),
                ),
                for (final tile in controller.state.level.tiles)
                  AnimatedPositioned(
                    key: ValueKey('position-${tile.id}'),
                    duration: reduced ? Duration.zero : GameTiming.shuffle,
                    curve: Curves.easeOutCubic,
                    left: geometry.centers[tile.id]!.dx - geometry.tileRadius,
                    top: geometry.centers[tile.id]!.dy - geometry.tileRadius,
                    width: geometry.tileRadius * 2,
                    height: geometry.tileRadius * 2,
                    child: Semantics(
                      label:
                          'Letra ${tile.letter}, ficha ${controller.state.level.tiles.indexOf(tile) + 1}',
                      selected: selected.contains(tile.id),
                      child: AnimatedScale(
                        scale: !reduced && selected.contains(tile.id)
                            ? 1.07
                            : 1,
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 100),
                        child: Container(
                          key: ValueKey(tile.id),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: selected.contains(tile.id)
                                  ? [GameTheme.teal, GameTheme.ink]
                                  : tealTokens
                                  ? [const Color(0xFF23848B), GameTheme.teal]
                                  : snow
                                  ? [
                                      const Color(0xFFF1FCFF),
                                      const Color(0xFFBDEAF7),
                                    ]
                                  : [GameTheme.cream, GameTheme.creamEnd],
                            ),
                            border: Border.all(
                              color: selected.contains(tile.id) || magic
                                  ? GameTheme.gold
                                  : bees
                                  ? GameTheme.cream
                                  : snow
                                  ? const Color(0xFF8DCEDD)
                                  : const Color(0xFFD6AA7B),
                              width: selected.contains(tile.id) ? 3 : 1.5,
                            ),
                            boxShadow: [
                              const BoxShadow(
                                color: Color(0x200B5660),
                                blurRadius: 4,
                                offset: Offset(0, 3),
                              ),
                              BoxShadow(
                                color: snow
                                    ? const Color(0x658DCEDD)
                                    : const Color(0x65CDA36B),
                                offset: const Offset(0, 3),
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: FittedBox(
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Text(
                                tile.letter,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      !tealTokens && !selected.contains(tile.id)
                                      ? GameTheme.ink
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: IconButton.filledTonal(
                      key: const ValueKey('shuffle'),
                      tooltip: 'Embaralhar letras',
                      onPressed: controller.interactive && !controller.dragging
                          ? () => controller.shuffle(reduceMotion: reduced)
                          : null,
                      style: IconButton.styleFrom(
                        backgroundColor: snow
                            ? const Color(0xFFD3F7E8)
                            : library || ocean || bees || magic
                            ? GameTheme.teal
                            : const Color(0xCC6F7F42),
                        foregroundColor: snow ? GameTheme.ink : GameTheme.cream,
                        side: BorderSide(
                          color: snow
                              ? const Color(0xFF8DCEDD)
                              : GameTheme.cream,
                          width: 1.5,
                        ),
                      ),
                      icon: const Icon(Icons.shuffle_rounded, size: 27),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ConnectionPainter extends CustomPainter {
  ConnectionPainter({
    required this.centers,
    required this.selected,
    this.pointer,
  });
  final Map<String, Offset> centers;
  final List<String> selected;
  final Offset? pointer;
  @override
  void paint(Canvas canvas, Size size) {
    if (selected.isEmpty) return;
    final path = Path()
      ..moveTo(centers[selected.first]!.dx, centers[selected.first]!.dy);
    for (final id in selected.skip(1)) {
      path.lineTo(centers[id]!.dx, centers[id]!.dy);
    }
    if (pointer != null) path.lineTo(pointer!.dx, pointer!.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = GameTheme.coral
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant ConnectionPainter oldDelegate) => true;
}
