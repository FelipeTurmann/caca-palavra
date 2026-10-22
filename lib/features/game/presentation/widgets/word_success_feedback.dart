import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/game_theme.dart';
import '../game_controller.dart' show GameTiming;

/// An inline acknowledgement, independent of rewards and pointer handling.
class WordSuccessFeedback extends StatelessWidget {
  const WordSuccessFeedback({super.key, required this.word});
  final String word;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: reduced ? Duration.zero : GameTiming.wordCelebration,
      builder: (context, value, child) {
        final entrance = Curves.easeOutBack.transform(value);
        return Opacity(
          opacity: (value / .22).clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 5),
            child: Transform.scale(
              scale: .88 + entrance * .12,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  child!,
                  if (!reduced && value < 1)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ExcludeSemantics(
                          child: CustomPaint(
                            key: const ValueKey('word-celebration-burst'),
                            painter: _SuccessSparkles(value),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF1F7DE), Color(0xFFDCEFE4)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFB7D5B6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140B5660),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.check_circle_rounded,
                color: GameTheme.teal,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Muito bem!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: GameTheme.teal,
                    ),
                  ),
                  Text(
                    word,
                    textAlign: TextAlign.center,
                    semanticsLabel: 'Palavra encontrada: $word',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: GameTheme.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const ExcludeSemantics(
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 19,
                color: Color(0xFFAE7412),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessSparkles extends CustomPainter {
  _SuccessSparkles(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final expansion = Curves.easeOut.transform(progress);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8;
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 - math.pi / 6;
      final center =
          size.center(Offset.zero) +
          Offset(
            math.cos(angle) * (size.width / 2 + 3 + expansion * 9),
            math.sin(angle) * (size.height / 2 + expansion * 7),
          );
      final ray =
          (2.5 + math.sin(progress * math.pi) * 2) * (1 - progress * .4);
      paint.color = (i.isEven ? GameTheme.gold : GameTheme.coral).withValues(
        alpha: 1 - progress,
      );
      canvas.drawLine(center - Offset(ray, 0), center + Offset(ray, 0), paint);
      canvas.drawLine(center - Offset(0, ray), center + Offset(0, ray), paint);
    }
  }

  @override
  bool shouldRepaint(_SuccessSparkles oldDelegate) =>
      progress != oldDelegate.progress;
}
