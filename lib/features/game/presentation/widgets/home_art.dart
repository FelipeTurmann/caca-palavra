import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/visual_theme_catalog.dart';
import '../../../../core/widgets/lagoon.dart';
import '../../../../core/widgets/cartoon_garden.dart';
import '../../../../core/widgets/cartoon_library.dart';
import '../../../../core/widgets/cartoon_ocean.dart';
import '../../../../core/widgets/cartoon_bees.dart';
import '../../../../core/widgets/cartoon_magic.dart';
import '../../../../core/widgets/cartoon_snow.dart';

/// Static, noninteractive decoration; all controls remain real Flutter widgets.
class HomeWordGarden extends StatelessWidget {
  const HomeWordGarden({
    super.key,
    required this.height,
    this.fullBleed = false,
  });
  final double height;
  final bool fullBleed;
  @override
  Widget build(BuildContext context) => VisualThemeScope.of(context).isLagoon
      ? LagoonHero(height: height)
      : ExcludeSemantics(
          child: IgnorePointer(
            child: SizedBox(
              height: height,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final theme = VisualThemeScope.of(context);
                  final creamTokens =
                      theme.isLibrary ||
                      theme.isOcean ||
                      theme.isBees ||
                      theme.isMagic ||
                      theme.isSnow;
                  final diameter = math.min(66.0, width * .18);
                  final centers = [
                    Offset(width * .20, height * .39),
                    Offset(width * .47, height * .17),
                    Offset(width * .71, height * .42),
                    Offset(width * .43, height * .67),
                  ];
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _WordGardenPainter(
                              centers,
                              fullBleed
                                  ? math.max(
                                      0.0,
                                      (MediaQuery.sizeOf(context).width -
                                              width) /
                                          2,
                                    )
                                  : 0,
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < centers.length; i++)
                        Positioned(
                          left: centers[i].dx - diameter / 2,
                          top: centers[i].dy - diameter / 2,
                          child: Container(
                            width: diameter,
                            height: diameter,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: creamTokens
                                    ? const [
                                        Color(0xFFFFF9EE),
                                        Color(0xFFFFF1D5),
                                      ]
                                    : const [
                                        Color(0xFF2B8B91),
                                        Color(0xFF0B5660),
                                        Color(0xFF074650),
                                      ],
                              ),
                              border: Border.all(
                                color: creamTokens
                                    ? const Color(0xFFFF9372)
                                    : const Color(0xFF419B9F),
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x2A0B5660),
                                  offset: Offset(0, 4),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              ['G', 'A', 'O', 'T'][i],
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                fontSize: diameter * .58,
                                fontWeight: FontWeight.w900,
                                color: creamTokens
                                    ? const Color(0xFF123B49)
                                    : Colors.white,
                                shadows: creamTokens
                                    ? null
                                    : const [
                                        Shadow(
                                          color: Color(0x4404373D),
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        bottom: theme.isMagic ? -23 : -5,
                        child: ThemeMascot(
                          height: height * .59,
                          width: width * .35,
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

class HomeLandscape extends StatelessWidget {
  const HomeLandscape({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: VisualThemeScope.of(context).isLagoon
                  ? const LagoonBackdrop()
                  : VisualThemeScope.of(context).isLibrary
                  ? const CartoonLibraryBackdrop()
                  : VisualThemeScope.of(context).isOcean
                  ? const CartoonOceanBackdrop()
                  : VisualThemeScope.of(context).isBees
                  ? const CartoonBeesBackdrop()
                  : VisualThemeScope.of(context).isMagic
                  ? const CartoonMagicBackdrop()
                  : VisualThemeScope.of(context).isSnow
                  ? const CartoonSnowBackdrop()
                  : CartoonGardenBackdrop(
                      fallback: CustomPaint(painter: _HomeLandscapePainter()),
                    ),
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

/// Layout wrapper retained while the illustrated scenery spans the full page.
class HomeSky extends StatelessWidget {
  const HomeSky({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

class _WordGardenPainter extends CustomPainter {
  _WordGardenPainter(this.centers, this.horizontalBleed);
  final double horizontalBleed;
  final List<Offset> centers;
  @override
  void paint(Canvas canvas, Size size) {
    final g = centers[0], a = centers[1], o = centers[2], t = centers[3];
    final path = Path()
      ..moveTo(g.dx, g.dy)
      ..cubicTo(g.dx, a.dy - 20, a.dx - 32, a.dy - 12, a.dx, a.dy)
      ..cubicTo(a.dx + 33, a.dy + 2, o.dx + 12, o.dy - 25, o.dx, o.dy)
      ..cubicTo(o.dx - 10, t.dy + 5, t.dx + 45, t.dy + 14, t.dx, t.dy)
      ..cubicTo(t.dx - 32, t.dy + 8, g.dx - 12, g.dy + 25, g.dx, g.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFA566),
    );
    canvas.drawPath(
      path.shift(const Offset(0, -1)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFFFD09C),
    );
  }

  @override
  bool shouldRepaint(_WordGardenPainter oldDelegate) =>
      horizontalBleed != oldDelegate.horizontalBleed ||
      !listEqualsOffsets(centers, oldDelegate.centers);
  bool listEqualsOffsets(List<Offset> a, List<Offset> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);
}

class _HomeLandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFCF4), Color(0xFFFFF0D0), Color(0xFFFFEBC4)],
          stops: [0, .2, 1],
        ).createShader(Offset.zero & size),
    );
    final radius = math.min(29.0, size.width * .07);
    final sun = Offset(size.width * .66, size.height - 26);
    final glow = Rect.fromCircle(center: sun, radius: radius * 2.5);
    canvas.drawCircle(
      sun,
      radius * 2.5,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x50FFD064), Color(0x00FFD064)],
        ).createShader(glow),
    );
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      canvas.drawLine(
        sun + Offset(math.cos(angle), math.sin(angle)) * (radius + 7),
        sun + Offset(math.cos(angle), math.sin(angle)) * (radius + 14),
        Paint()
          ..color = const Color(0xFFF6C154)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(
      sun,
      radius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD354), Color(0xFFFFB53E)],
        ).createShader(Rect.fromCircle(center: sun, radius: radius)),
    );
    _hill(canvas, size, size.height - 17, const Color(0xFFC3D5AF), 31);
    _hill(canvas, size, size.height - 5, const Color(0xFF9EC4A0), 14);
    for (final right in [false, true]) {
      canvas.save();
      if (right) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      _plant(
        canvas,
        Offset(9, size.height + 8),
        107,
        60,
        const Color(0xFF6AAB8F),
      );
      _plant(
        canvas,
        Offset(-5, size.height + 10),
        76,
        72,
        const Color(0xFF267B70),
      );
      _plant(
        canvas,
        Offset(57, size.height + 14),
        51,
        49,
        const Color(0xFF468E78),
      );
      canvas.restore();
    }
    final foreground = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(
        size.width * .51,
        size.height - 23,
        size.width,
        size.height,
      )
      ..close();
    canvas.drawPath(foreground, Paint()..color = const Color(0xFFF6BA8A));
  }

  @override
  bool shouldRepaint(_HomeLandscapePainter oldDelegate) => false;
}

void _hill(Canvas canvas, Size size, double y, Color color, double wave) {
  final path = Path()
    ..moveTo(0, y)
    ..cubicTo(
      size.width * .2,
      y - wave * 1.7,
      size.width * .34,
      y + wave,
      size.width * .51,
      y - wave * .1,
    )
    ..quadraticBezierTo(
      size.width * .8,
      y - wave * 1.6,
      size.width,
      y - wave * .3,
    )
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

void _plant(
  Canvas canvas,
  Offset base,
  double height,
  double width,
  Color color,
) {
  canvas.save();
  canvas.translate(base.dx, base.dy);
  final stem = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(-width * .2, -height * .45, width * .06, -height);
  canvas.drawPath(
    stem,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  for (var i = 0; i < 7; i++) {
    final t = (i + 1) / 8;
    final start = Offset(-width * .1 * math.sin(t * math.pi), -height * t);
    final tip =
        start +
        Offset((i.isEven ? 1 : -1) * width * (.57 - t * .2), -height * .29);
    final leaf = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(
        tip.dx + width * .18,
        start.dy - height * .07,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        start.dx - width * .22,
        tip.dy + height * .06,
        start.dx,
        start.dy,
      )
      ..close();
    canvas.drawPath(
      leaf,
      Paint()
        ..color = Color.lerp(
          color,
          const Color(0xFFBCD5AA),
          i.isEven ? .13 : .30,
        )!,
    );
  }
  canvas.restore();
}
