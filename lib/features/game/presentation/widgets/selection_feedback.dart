import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/game_theme.dart';
import '../../domain/game_engine.dart';
import '../game_controller.dart';

class SelectionFeedback extends StatelessWidget {
  const SelectionFeedback({super.key, required this.controller});
  final GameController controller;

  static String message(SubmissionResult? result) => switch (result?.kind) {
    SubmissionKind.tooShort => 'Use pelo menos 3 letras.',
    SubmissionKind.targetFound => 'Muito bem!',
    SubmissionKind.targetRepeated => 'Você já encontrou essa palavra.',
    SubmissionKind.extraFound => 'Palavra extra: ${result!.word!.display}',
    SubmissionKind.extraRepeated => 'Essa palavra extra já foi encontrada.',
    SubmissionKind.unknownWord => 'Palavra não reconhecida nesta versão.',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final result = controller.feedback;
    final error =
        result?.kind == SubmissionKind.unknownWord ||
        result?.kind == SubmissionKind.tooShort;
    final success = result?.kind == SubmissionKind.targetFound;
    final extra = result?.kind == SubmissionKind.extraFound;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: 64 * math.max(1, scale * 0.85),
      child: Center(
        child: controller.dragging
            ? Container(
                key: const ValueKey('preview'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: GameTheme.teal,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    controller.preview,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            : Semantics(
                liveRegion: true,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(controller.feedbackSerial),
                  tween: Tween(begin: 0, end: 1),
                  duration: reduced ? Duration.zero : GameTiming.pulse,
                  builder: (context, value, child) => Transform.translate(
                    offset: Offset(
                      error
                          ? math.sin(value * math.pi * 6) * 4 * (1 - value)
                          : 0,
                      0,
                    ),
                    child: child,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (result != null) ...[
                          Icon(
                            error
                                ? Icons.info_outline_rounded
                                : extra
                                ? Icons.star_rounded
                                : success
                                ? Icons.check_circle_rounded
                                : Icons.refresh_rounded,
                            size: 19,
                            color: extra
                                ? const Color(0xFF8A5A00)
                                : GameTheme.teal,
                          ),
                          const SizedBox(width: 7),
                        ],
                        Flexible(
                          child: Text(
                            message(result),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
