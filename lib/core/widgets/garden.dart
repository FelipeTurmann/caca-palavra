import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/game_theme.dart';
import '../theme/visual_theme_catalog.dart';
import 'lagoon.dart';
import 'cartoon_garden.dart';
import 'cartoon_library.dart';
import 'cartoon_ocean.dart';
import 'cartoon_bees.dart';
import 'cartoon_magic.dart';
import 'cartoon_snow.dart';

/// Pure decoration. Coordinates stay independent of the wheel's hit geometry.
class Garden extends StatelessWidget {
  const Garden({
    super.key,
    required this.child,
    this.quiet = false,
    this.immersive = false,
  });
  final Widget child;
  final bool quiet;
  final bool immersive;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: VisualThemeScope.of(context).isLagoon
                  ? LagoonBackdrop(
                      quiet: quiet && !immersive,
                      gameplay: immersive,
                    )
                  : VisualThemeScope.of(context).isLibrary
                  ? CartoonLibraryBackdrop(
                      quiet: quiet && !immersive,
                      gameplay: immersive,
                    )
                  : VisualThemeScope.of(context).isOcean
                  ? CartoonOceanBackdrop(
                      quiet: quiet && !immersive,
                      gameplay: immersive,
                    )
                  : VisualThemeScope.of(context).isBees
                  ? CartoonBeesBackdrop(
                      quiet: quiet && !immersive,
                      gameplay: immersive,
                    )
                  : VisualThemeScope.of(context).isMagic
                  ? CartoonMagicBackdrop(
                      quiet: quiet && !immersive,
                      gameplay: immersive,
                    )
                  : VisualThemeScope.of(context).isSnow
                  ? CartoonSnowBackdrop(
                      quiet: quiet && !immersive,
                      gameplay: immersive,
                    )
                  : CartoonGardenBackdrop(
                      quiet: quiet && !immersive,
                      gameplay: immersive,
                      fallback: CustomPaint(
                        painter: _GardenPainter(quiet: quiet),
                      ),
                    ),
            ),
          ),
        ),
      ),
      if (immersive &&
          MediaQuery.sizeOf(context).height >= 740 &&
          MediaQuery.sizeOf(context).width >= 360 &&
          MediaQuery.orientationOf(context) == Orientation.portrait &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.3)
        Positioned(
          right: 4,
          bottom:
              VisualThemeScope.of(context).isLibrary ||
                  VisualThemeScope.of(context).isOcean ||
                  VisualThemeScope.of(context).isBees ||
                  VisualThemeScope.of(context).isMagic ||
                  VisualThemeScope.of(context).isSnow
              ? 0
              : 28,
          child: VisualThemeScope.of(context).isLagoon
              ? const LagoonPondMascot()
              : VisualThemeScope.of(context).isLibrary
              ? const ThemeMascot(
                  theme: VisualTheme.library,
                  height: 94,
                  width: 94,
                )
              : VisualThemeScope.of(context).isOcean
              ? const ThemeMascot(
                  theme: VisualTheme.ocean,
                  height: 94,
                  width: 94,
                )
              : VisualThemeScope.of(context).isBees
              ? const ThemeMascot(
                  theme: VisualTheme.bees,
                  height: 86,
                  width: 86,
                )
              : VisualThemeScope.of(context).isMagic
              ? const ThemeMascot(
                  theme: VisualTheme.magic,
                  height: 86,
                  width: 86,
                )
              : VisualThemeScope.of(context).isSnow
              ? const ThemeMascot(
                  theme: VisualTheme.snow,
                  height: 86,
                  width: 86,
                )
              : const CartoonGardenCornerMascot(),
        ),
      child,
    ],
  );
}

class _GardenPainter extends CustomPainter {
  _GardenPainter({required this.quiet});
  final bool quiet;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GameTheme.cream, Color(0xFFFFEDC9)],
        ).createShader(rect),
    );
    final base = size.height;
    for (var i = 0; i < 3; i++) {
      final y = base - (quiet ? 35 : 65) + i * 15;
      final path = Path()
        ..moveTo(0, y)
        ..cubicTo(
          size.width * .25,
          y - 48,
          size.width * .4,
          y + 55,
          size.width * .66,
          y,
        )
        ..quadraticBezierTo(size.width * .88, y - 35, size.width, y + 7)
        ..lineTo(size.width, base)
        ..lineTo(0, base)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = [
            const Color(0xFFB9CEA7),
            const Color(0xFFE3D6A4),
            const Color(0xFFF5D396),
          ][i].withValues(alpha: quiet ? .35 : .7),
      );
    }
    for (final right in [false, true]) {
      canvas.save();
      if (right) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      final height = math.min(size.height * .28, quiet ? 155.0 : 235.0);
      final width = math.min(size.width * .16, 92.0);
      final origin = Offset(-5, base + 12);
      final stalk = Path()
        ..moveTo(origin.dx, origin.dy)
        ..quadraticBezierTo(
          width * .65,
          base - height * .5,
          width * .38,
          base - height,
        );
      canvas.drawPath(
        stalk,
        Paint()
          ..color = const Color(0xFF659C87).withValues(alpha: .6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
      for (var i = 0; i < 7; i++) {
        final t = (i + 1) / 8;
        final center = Offset(width * .36 * t, base - height * t);
        final tip =
            center +
            Offset(i.isEven ? width * .75 : -width * .45, -height * .24);
        final leaf = Path()
          ..moveTo(center.dx, center.dy)
          ..quadraticBezierTo(
            tip.dx + width * .25,
            center.dy - 8,
            tip.dx,
            tip.dy,
          )
          ..quadraticBezierTo(
            center.dx - width * .24,
            tip.dy + 8,
            center.dx,
            center.dy,
          )
          ..close();
        canvas.drawPath(
          leaf,
          Paint()
            ..shader = LinearGradient(
              colors: [
                const Color(0xFF86B49D),
                i.isEven ? const Color(0xFF286E67) : const Color(0xFF5B9D82),
              ],
            ).createShader(Rect.fromPoints(center, tip))
            ..color = Colors.white.withValues(alpha: quiet ? .42 : .8),
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_GardenPainter oldDelegate) => quiet != oldDelegate.quiet;
}

class GardenCard extends StatelessWidget {
  const GardenCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFDF6), Color(0xFFFFF4DC)],
      ),
      borderRadius: BorderRadius.circular(GameTheme.cardRadius),
      border: Border.all(color: const Color(0xFFEED6AE)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x149C7033),
          offset: Offset(0, 4),
          blurRadius: 12,
        ),
      ],
    ),
    child: child,
  );
}

class VolumeButton extends StatefulWidget {
  const VolumeButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.coral = false,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final bool coral;
  @override
  State<VolumeButton> createState() => _VolumeButtonState();
}

class _VolumeButtonState extends State<VolumeButton> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) {
        if (widget.onPressed != null) setState(() => pressed = true);
      },
      onPointerUp: (_) => setState(() => pressed = false),
      onPointerCancel: (_) => setState(() => pressed = false),
      child: AnimatedContainer(
        duration: reduced ? Duration.zero : const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(0, pressed && !reduced ? 2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GameTheme.buttonRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.onPressed == null
                ? [Colors.grey.shade400, Colors.grey.shade500]
                : widget.coral
                ? [const Color(0xFFFF8D71), const Color(0xFFE94F48)]
                : VisualThemeScope.of(context).isLagoon
                ? [
                    const Color(0xFF049D9A),
                    const Color(0xFF00767C),
                    GameTheme.teal,
                  ]
                : [const Color(0xFF21818A), GameTheme.teal],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: .6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: GameTheme.teal.withValues(alpha: .22),
              offset: Offset(0, pressed ? 1 : 4),
              blurRadius: pressed ? 2 : 7,
            ),
          ],
        ),
        child: FilledButton(
          onPressed: widget.onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class VictoryConfetti extends StatefulWidget {
  const VictoryConfetti({super.key, required this.celebrate});
  final bool celebrate;
  @override
  State<VictoryConfetti> createState() => _VictoryConfettiState();
}

class _VictoryConfettiState extends State<VictoryConfetti>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      animation.stop();
      animation.value = 1;
    } else if (!started && widget.celebrate) {
      started = true;
      animation.forward();
    }
  }

  @override
  void didUpdateWidget(VictoryConfetti oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.celebrate) {
      animation.stop();
      animation.value = 1;
    }
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) =>
            widget.celebrate && started && animation.value < 1
            ? CustomPaint(painter: _ConfettiPainter(animation.value))
            : const SizedBox.shrink(),
      ),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.time);
  final double time;
  @override
  void paint(Canvas canvas, Size size) {
    const colors = [GameTheme.coral, GameTheme.teal, GameTheme.gold];
    for (var i = 0; i < 28; i++) {
      final x = size.width * ((i * .618) % 1) + math.sin(time * 5 + i) * 18;
      final y = size.height * (time * .8 - (i % 5) * .06);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(time * 5 + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, -6, 6, 12),
          const Radius.circular(2),
        ),
        Paint()..color = colors[i % 3].withValues(alpha: 1 - time),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => time != oldDelegate.time;
}
