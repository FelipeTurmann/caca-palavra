import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/game_theme.dart';
import '../../../../core/theme/visual_theme_catalog.dart';
import '../../domain/game_engine.dart';
import '../game_controller.dart';

class WordSlots extends StatelessWidget {
  const WordSlots({
    super.key,
    required this.word,
    required this.found,
    required this.pulse,
    this.revealed = const {},
    this.celebrate = false,
  });
  final WordEntry word;
  final bool found;
  final bool celebrate;
  final int pulse;
  final Set<int> revealed;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final bees = VisualThemeScope.of(context).isBees;
    return Semantics(
      label: found
          ? 'Palavra encontrada: ${word.display}'
          : 'Palavra de ${word.letters.length} letras${revealed.isEmpty ? '' : '. Letras reveladas: ${[for (var index = 0; index < word.letters.length; index++)
                    if (revealed.contains(index)) '${index + 1}: ${word.letters[index]}'].join(', ')}'}',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          key: ValueKey('${word.key}-$pulse'),
          tween: Tween(begin: 0, end: 1),
          duration: reduced
              ? Duration.zero
              : celebrate
              ? GameTiming.wordCelebration
              : GameTiming.pulse,
          builder: (context, value, child) => Transform.scale(
            scale: (found || revealed.isNotEmpty) && pulse > 0
                ? 1 + math.sin(math.pi * value) * 0.045
                : 1,
            child: celebrate && found && !reduced && value < 1
                ? ShaderMask(
                    key: ValueKey('word-shine-${word.key}'),
                    blendMode: BlendMode.srcATop,
                    shaderCallback: (bounds) {
                      final width = bounds.width * .45;
                      final left = -width + (bounds.width + width) * value;
                      return const LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0x88FFFFFF),
                          Color(0x55F4BD4F),
                          Colors.transparent,
                        ],
                        stops: [0, .45, .55, 1],
                      ).createShader(
                        Rect.fromLTWH(left, 0, width, bounds.height),
                      );
                    },
                    child: child,
                  )
                : child,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final count = word.letters.length;
                final scale = MediaQuery.textScalerOf(
                  context,
                ).scale(1).clamp(1.0, 2.0);
                final horizontalScroll =
                    scale > 1.3 &&
                    count * 44 * scale + (count - 1) * 7 > constraints.maxWidth;
                final side = horizontalScroll
                    ? 44.0 * scale
                    : math.min(
                        44.0 * scale,
                        (constraints.maxWidth - (count - 1) * 7) / count,
                      );
                final row = Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var index = 0; index < count; index++) ...[
                      if (index != 0) const SizedBox(width: 7),
                      Container(
                        key: ValueKey('slot-${word.key}-$index'),
                        width: side,
                        height: side + 2,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: found
                              ? GameTheme.teal
                              : revealed.contains(index)
                              ? const Color(0xFFFFEDB7)
                              : const Color(0xF2FFF9EE),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: found
                                ? GameTheme.lightTeal
                                : revealed.contains(index)
                                ? GameTheme.gold
                                : bees
                                ? const Color(0xFFD7A249)
                                : GameTheme.slotBorder,
                            width: 1.5,
                          ),
                          boxShadow: found
                              ? const [
                                  BoxShadow(
                                    color: Color(0x180B5660),
                                    offset: Offset(0, 2),
                                    blurRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: found || revealed.contains(index)
                            ? SizedBox.expand(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    FittedBox(
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Text(
                                          word.letters[index],
                                          style: TextStyle(
                                            color: found
                                                ? Colors.white
                                                : const Color(0xFF795100),
                                            fontSize: 27,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (!found)
                                      const Positioned(
                                        right: 3,
                                        top: 3,
                                        child: Icon(
                                          Icons.star_rounded,
                                          size: 10,
                                          color: Color(0xFF795100),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : null,
                      ),
                    ],
                  ],
                );
                return horizontalScroll
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: row,
                      )
                    : row;
              },
            ),
          ),
        ),
      ),
    );
  }
}
