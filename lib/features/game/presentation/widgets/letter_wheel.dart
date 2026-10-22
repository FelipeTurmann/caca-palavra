import 'package:flutter/material.dart';
import '../../../../core/theme/game_theme.dart';
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
                  child: Padding(
                    padding: const EdgeInsets.all(17),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.35),
                        border: Border.all(
                          color: GameTheme.slotBorder.withValues(alpha: 0.32),
                        ),
                      ),
                    ),
                  ),
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
                                  : [GameTheme.lightTeal, GameTheme.teal],
                            ),
                            border: Border.all(
                              color: selected.contains(tile.id)
                                  ? GameTheme.gold
                                  : Colors.white.withValues(alpha: 0.65),
                              width: selected.contains(tile.id) ? 3 : 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x200B5660),
                                blurRadius: 4,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: FittedBox(
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Text(
                                tile.letter,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
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
                        backgroundColor: const Color(0xFFD9EBE6),
                        foregroundColor: GameTheme.teal,
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
