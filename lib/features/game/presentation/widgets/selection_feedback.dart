import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/game_theme.dart';
import '../../domain/game_engine.dart';
import '../../application/campaign_models.dart';
import '../game_controller.dart';
import 'word_success_feedback.dart';

class SelectionFeedback extends StatelessWidget {
  const SelectionFeedback({
    super.key,
    required this.controller,
    this.extraIconKey,
  });
  final GameController controller;
  final GlobalKey? extraIconKey;

  static String message(SubmissionResult? result) => switch (result?.kind) {
    SubmissionKind.tooShort => 'Use pelo menos 3 letras.',
    SubmissionKind.targetFound => 'Muito bem!',
    SubmissionKind.superResolved => 'Palavra resolvida pela Super Dica!',
    SubmissionKind.hintResolved => 'Dica completou ${result!.word!.display}!',
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
    final success =
        result?.kind == SubmissionKind.targetFound ||
        result?.kind == SubmissionKind.superResolved ||
        result?.kind == SubmissionKind.hintResolved;
    final extra = result?.kind == SubmissionKind.extraFound;
    final celebrating = controller.celebratingExplorer;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      // Reserve wrapped feedback and its extra-reveal caption at larger text
      // sizes, keeping the same space for every message within this layout.
      height: 64 * math.max(1, 1 + (scale - 1) * 2),
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
            : result != null &&
                  result.kind == SubmissionKind.targetFound &&
                  !result.completed
            ? Semantics(
                liveRegion: true,
                child: WordSuccessFeedback(
                  key: ValueKey(
                    'word-celebration-${controller.state.session}-${controller.feedbackSerial}',
                  ),
                  word: result.word!.display,
                ),
              )
            : Semantics(
                liveRegion: true,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('${controller.feedbackSerial}-$celebrating'),
                  tween: Tween(begin: 0, end: 1),
                  duration: reduced ? Duration.zero : GameTiming.pulse,
                  builder: (context, value, child) => Transform.scale(
                    scale: celebrating
                        ? 1 + math.sin(value * math.pi) * 0.04
                        : 1,
                    child: Transform.translate(
                      offset: Offset(
                        error
                            ? math.sin(value * math.pi * 6) * 4 * (1 - value)
                            : 0,
                        0,
                      ),
                      child: child,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (result != null || celebrating) ...[
                          Icon(
                            celebrating
                                ? Icons.workspace_premium_rounded
                                : error
                                ? Icons.info_outline_rounded
                                : extra
                                ? Icons.star_rounded
                                : success
                                ? Icons.check_circle_rounded
                                : Icons.refresh_rounded,
                            size: 19,
                            key: extra && !celebrating ? extraIconKey : null,
                            color: extra || celebrating
                                ? const Color(0xFF8A5A00)
                                : GameTheme.teal,
                          ),
                          const SizedBox(width: 7),
                        ],
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                celebrating
                                    ? 'Explorador conquistado!'
                                    : message(result),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (controller.explorerRewardGranted &&
                                  (celebrating ||
                                      result?.explorerUnlocked == true))
                                Text(
                                  '+${Economy.explorerReward} moedas!',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF795100),
                                  ),
                                ),
                              if (extra && !celebrating)
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    result!.resolvedWord != null
                                        ? '${result.resolvedWord!.display} completada!'
                                        : result.revealedLetter != null
                                        ? 'Uma letra revelada!'
                                        : 'Extras continuam contando.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF795100),
                                    ),
                                  ),
                                ),
                            ],
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
