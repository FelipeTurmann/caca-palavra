import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/game_theme.dart';
import '../../domain/game_engine.dart';
import '../game_controller.dart';

class WordSlots extends StatelessWidget {
  const WordSlots({
    super.key,
    required this.word,
    required this.found,
    required this.pulse,
  });
  final WordEntry word;
  final bool found;
  final int pulse;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: found
          ? 'Palavra encontrada: ${word.display}'
          : 'Palavra de ${word.letters.length} letras',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          key: ValueKey('${word.key}-$pulse'),
          tween: Tween(begin: 0, end: 1),
          duration: reduced ? Duration.zero : GameTiming.pulse,
          builder: (context, value, child) => Transform.scale(
            scale: found && pulse > 0
                ? 1 + math.sin(math.pi * value) * 0.045
                : 1,
            child: child,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final count = word.letters.length;
                final scale = MediaQuery.textScalerOf(
                  context,
                ).scale(1).clamp(1.0, 2.0);
                final side = math.min(
                  44.0 * scale,
                  (constraints.maxWidth - (count - 1) * 7) / count,
                );
                return Row(
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
                              : Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: found
                                ? GameTheme.lightTeal
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
                        child: found
                            ? FittedBox(
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Text(
                                    word.letters[index],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 27,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
