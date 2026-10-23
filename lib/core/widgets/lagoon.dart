import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/game_theme.dart';
import '../theme/visual_theme_catalog.dart';

/// Shared scenery is cached by Flutter; no image work is done during gestures.
class LagoonBackdrop extends StatelessWidget {
  const LagoonBackdrop({super.key, this.quiet = false, this.gameplay = false});
  final bool quiet, gameplay;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/themes/capivara_lagoa/scenery-cartoon.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) =>
                  CustomPaint(painter: LagoonPainter(quiet: quiet)),
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
                      Color(0x28FFF9EE),
                      Color(0xA6FFF9EE),
                      Color(0x70FFF9EE),
                      Color(0x00FFF9EE),
                    ],
                    stops: [0, .18, .45, .62],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class LagoonIsland extends StatelessWidget {
  const LagoonIsland({super.key});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: Image.asset(
          'assets/themes/capivara_lagoa/island-cartoon.png',
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) =>
              const CustomPaint(painter: LagoonWheelPainter()),
        ),
      ),
    ),
  );
}

/// Adds the prototype's cream label surface without affecting layout metrics.
class LagoonReadingSurface extends StatelessWidget {
  const LagoonReadingSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xF2FFF9EE),
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x187B523C),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class LagoonPondMascot extends StatelessWidget {
  const LagoonPondMascot({super.key});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: SizedBox(
        width: 94,
        height: 70,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              bottom: 4,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: .62,
                  child: const ThemeMascot(
                    theme: VisualTheme.lagoon,
                    height: 100,
                    width: 90,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 1,
              right: 1,
              bottom: 0,
              child: const SizedBox(
                height: 13,
                child: CustomPaint(painter: _PondRipplePainter()),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PondRipplePainter extends CustomPainter {
  const _PondRipplePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final oval = (Offset.zero & size).deflate(1);
    canvas.drawOval(oval, Paint()..color = const Color(0x50537F75));
    canvas.drawArc(
      oval,
      0,
      math.pi,
      false,
      Paint()
        ..color = const Color(0x9AFFF3CE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }

  @override
  bool shouldRepaint(_PondRipplePainter oldDelegate) => false;
}

/// Decorative layers only: never participates in the wheel's hit geometry.
class LagoonPainter extends CustomPainter {
  const LagoonPainter({this.quiet = false});
  final bool quiet;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: quiet
              ? const [Color(0xFFFFE3CB), GameTheme.cream, Color(0xFFE1E9D5)]
              : const [Color(0xFFF9BC9F), Color(0xFFFFEDD0), Color(0xFFC0D9C4)],
          stops: const [0, .48, 1],
        ).createShader(bounds),
    );
    final horizon = size.height * (quiet ? .76 : .48);
    final sun = Offset(size.width * .58, horizon);
    final radius = math.min(size.width * .12, 65.0);
    canvas.drawCircle(
      sun,
      radius * 2.8,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xAFFFF4CF), Color(0x00FFF4CF)],
        ).createShader(Rect.fromCircle(center: sun, radius: radius * 2.8)),
    );
    canvas.drawCircle(sun, radius, Paint()..color = const Color(0x9FFFF4CC));
    // Distant banks at the edges leave the reading column calm and open.
    for (final right in [false, true]) {
      canvas.save();
      if (right) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      final bank = Path()
        ..moveTo(0, horizon - 34)
        ..quadraticBezierTo(
          size.width * .13,
          horizon - 8,
          size.width * .27,
          horizon + 17,
        )
        ..lineTo(0, horizon + 27)
        ..close();
      canvas.drawPath(bank, Paint()..color = const Color(0x3885A387));
      canvas.restore();
    }
    // Reflections are static and sparse, rather than continuous water animation.
    for (var i = 0; i < 14; i++) {
      final y = horizon + radius * .5 + i * (size.height - horizon) / 15;
      final halfWidth = radius * (.38 + i * .075);
      canvas.drawLine(
        Offset(sun.dx - halfWidth, y),
        Offset(sun.dx + halfWidth, y),
        Paint()
          ..color = const Color(0x70FFF7DB)
          ..strokeWidth = i.isEven ? 3 : 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final right in [false, true]) {
      canvas.save();
      if (right) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      final height = math.min(size.height * .26, quiet ? 125.0 : 205.0);
      for (var i = 0; i < 6; i++) {
        final x = i * 9.0 - 13;
        final leaf = Path()
          ..moveTo(x, size.height + 5)
          ..quadraticBezierTo(
            x + 15,
            size.height - height * .6,
            x + 12 + i * 6,
            size.height - height * (.6 + i * .07),
          )
          ..quadraticBezierTo(
            x + 43,
            size.height - height * .35,
            x + 9,
            size.height + 5,
          )
          ..close();
        canvas.drawPath(
          leaf,
          Paint()
            ..color = [
              const Color(0xFF719C7C),
              const Color(0xFF9BB28A),
              const Color(0xFF527F6C),
            ][i % 3].withValues(alpha: quiet ? .48 : .9),
        );
      }
      for (var i = 0; i < 3; i++) {
        final center = Offset(24 + i * 35.0, size.height - 14 - (i % 2) * 15);
        drawLily(canvas, center, 24 - i * 3.0, flower: i != 1);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(LagoonPainter oldDelegate) => quiet != oldDelegate.quiet;
}

void drawLily(
  Canvas canvas,
  Offset center,
  double radius, {
  bool flower = true,
}) {
  final ripple = Rect.fromCenter(
    center: center + const Offset(0, 4),
    width: radius * 2.8,
    height: radius * .92,
  );
  canvas.drawOval(
    ripple,
    Paint()
      ..color = const Color(0x70FFF9E7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
  final leaf = Rect.fromCenter(
    center: center,
    width: radius * 2,
    height: radius * .85,
  );
  canvas.drawArc(
    leaf,
    .23,
    math.pi * 2 - .45,
    true,
    Paint()..color = const Color(0xFF749C70),
  );
  canvas.drawArc(
    leaf.deflate(3),
    .23,
    math.pi * 2 - .45,
    false,
    Paint()
      ..color = const Color(0xFFAFC391)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  if (!flower) return;
  final bloom = center - Offset(0, radius * .25);
  for (var i = 0; i < 5; i++) {
    canvas.save();
    canvas.translate(bloom.dx, bloom.dy);
    canvas.rotate((i - 2) * .45);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, -radius * .24),
        width: radius * .35,
        height: radius * .85,
      ),
      Paint()
        ..color = i.isEven ? const Color(0xFFFFD3BC) : const Color(0xFFF5B9A9),
    );
    canvas.restore();
  }
  canvas.drawCircle(bloom, radius * .12, Paint()..color = GameTheme.gold);
}

class LagoonWheelPainter extends CustomPainter {
  const LagoonWheelPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 5;
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        center,
        radius - i * 5,
        Paint()
          ..color = const Color(0x99FFFCDF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    final island = Rect.fromCircle(center: center, radius: radius - 20);
    canvas.drawCircle(
      center + const Offset(0, 4),
      radius - 20,
      Paint()..color = const Color(0xFF708867),
    );
    canvas.drawCircle(
      center,
      radius - 20,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFBFCC8C), Color(0xFF8FAC77)],
        ).createShader(island),
    );
    canvas.drawCircle(
      center,
      radius - 21,
      Paint()
        ..color = const Color(0xFFD1DCA2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < 16; i++) {
      final angle = i * math.pi / 8;
      final dot =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - 27);
      canvas.drawCircle(
        dot,
        i % 3 == 0 ? 2.7 : 1.5,
        Paint()
          ..color = i.isEven
              ? const Color(0xFFFFF3CD)
              : const Color(0xFFDFDCA1),
      );
    }
  }

  @override
  bool shouldRepaint(LagoonWheelPainter oldDelegate) => false;
}

class LagoonHero extends StatelessWidget {
  const LagoonHero({super.key, required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final diameter = math.min(62.0, width * .17);
            final centers = [
              Offset(width * .13, height * .26),
              Offset(width * .33, height * .40),
              Offset(width * .53, height * .24),
              Offset(width * .73, height * .26),
            ];
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _HeroTrailPainter(centers)),
                ),
                Positioned(
                  right: -8,
                  bottom: -4,
                  width: width * .47,
                  height: height * .18,
                  child: const LagoonIsland(),
                ),
                Positioned(
                  right: -3,
                  bottom: 0,
                  child: ThemeMascot(height: height * .56, width: width * .39),
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
                        color: GameTheme.cream,
                        border: Border.all(
                          color: const Color(0xFFF4A877),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x257B523C),
                            offset: Offset(0, 3),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: Text(
                        ['G', 'A', 'O', 'T'][i],
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: diameter * .58,
                          fontWeight: FontWeight.w900,
                          color: GameTheme.ink,
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

class _HeroTrailPainter extends CustomPainter {
  const _HeroTrailPainter(this.centers);
  final List<Offset> centers;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (final point in centers.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = GameTheme.coral
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_HeroTrailPainter oldDelegate) =>
      !listEquals(centers, oldDelegate.centers);
}
