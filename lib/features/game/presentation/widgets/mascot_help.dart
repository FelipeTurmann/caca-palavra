import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/theme/game_theme.dart';
import '../../../../core/theme/visual_theme_catalog.dart';
import '../../application/campaign_models.dart';
import '../../domain/game_engine.dart';
import '../game_controller.dart';

const mascotInvitation =
    'Quer uma dica? Escolha uma palavra para eu te ajudar.';

/// Speech overlays the round without changing its layout or touch coordinates.
class MascotRoundLayout extends StatelessWidget {
  const MascotRoundLayout({
    super.key,
    required this.controller,
    required this.child,
  });
  final GameController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (controller.coordinator == null) return child;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final landscape = box.maxWidth > box.maxHeight;
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final compact = box.maxHeight < 740 || landscape || largeText;
        final width = landscape
            ? math.min(box.maxWidth * .45, 520.0)
            : math.min(box.maxWidth - 16, 560.0);
        final height = math.min(
          box.maxHeight,
          landscape ? (largeText ? 178.0 : 160.0) : 260.0,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (!controller.mascotOpen)
              Positioned(
                right: 4,
                bottom: 2,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: SizedBox(
                      key: const ValueKey('mascot-decoration'),
                      width: compact ? 48 : 80,
                      height: compact ? 56 : 88,
                      child: const ThemeMascot(height: 88, width: 80),
                    ),
                  ),
                ),
              ),
            Positioned(
              key: const ValueKey('mascot-overlay-layer'),
              right: 8,
              bottom: 8,
              width: width,
              child: AnimatedSwitcher(
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                reverseDuration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, .18),
                      end: Offset.zero,
                    ).animate(animation),
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: .9,
                        end: 1,
                      ).animate(animation),
                      alignment: Alignment.bottomRight,
                      child: child,
                    ),
                  ),
                ),
                child: controller.mascotOpen
                    ? TapRegion(
                        key: const ValueKey('mascot-presentation'),
                        groupId: controller,
                        onTapOutside: (_) {
                          if (!controller.busy) controller.closeMascot();
                        },
                        child: SizedBox(
                          height: height,
                          child: MascotHelp(controller: controller),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The character is decoration; all help actions live in the speech or toolbar.
class MascotHelp extends StatelessWidget {
  const MascotHelp({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final characterSize = math.min(
        180.0,
        math.min(box.maxWidth * .38, box.maxHeight - 12),
      );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 6),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _MascotSpeech(controller: controller),
                  Positioned(
                    right: -10,
                    bottom: characterSize * .55,
                    child: const CustomPaint(
                      size: Size(11, 18),
                      painter: _SpeechTail(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IgnorePointer(
            child: ExcludeSemantics(
              child: SizedBox(
                key: const ValueKey('mascot-character'),
                width: characterSize,
                height: characterSize,
                child: ThemeMascot(height: characterSize, width: characterSize),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _MascotSpeech extends StatelessWidget {
  const _MascotSpeech({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final text = controller.busy
        ? 'Liberando dica…'
        : controller.mascotNotice ??
              controller.mascotHint?.clue ??
              mascotInvitation;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: GameTheme.cream,
        border: Border.all(color: const Color(0xFFD6AA7B)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x250B5660),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
        child: LayoutBuilder(
          builder: (context, box) {
            final iconActions =
                box.maxWidth < 190 ||
                box.maxHeight < 210 &&
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
            final canChoose =
                !controller.mascotChoosing && controller.mascotHint != null;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        text,
                        key: const ValueKey('mascot-speech'),
                        style: const TextStyle(
                          fontSize: 16,
                          color: GameTheme.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
                    if (controller.saveError != null)
                      iconActions
                          ? IconButton(
                              tooltip: 'Tentar novamente',
                              onPressed: controller.busy
                                  ? null
                                  : controller.retrySave,
                              icon: const Icon(Icons.refresh_rounded),
                            )
                          : TextButton(
                              onPressed: controller.busy
                                  ? null
                                  : controller.retrySave,
                              child: const Text('Tentar novamente'),
                            ),
                    if (canChoose)
                      iconActions
                          ? IconButton(
                              tooltip: 'Escolher outra palavra',
                              onPressed: controller.interactive
                                  ? controller.chooseMascotWord
                                  : null,
                              icon: const Icon(Icons.touch_app_outlined),
                            )
                          : TextButton(
                              onPressed: controller.interactive
                                  ? controller.chooseMascotWord
                                  : null,
                              child: const Text('Escolher outra palavra'),
                            ),
                    iconActions
                        ? IconButton(
                            tooltip: 'Fechar',
                            onPressed: controller.busy
                                ? null
                                : controller.closeMascot,
                            icon: const Icon(Icons.close_rounded),
                          )
                        : TextButton(
                            onPressed: controller.busy
                                ? null
                                : controller.closeMascot,
                            child: const Text('Fechar'),
                          ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SpeechTail extends CustomPainter {
  const _SpeechTail();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height);
    canvas.drawPath(path, Paint()..color = GameTheme.cream);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFD6AA7B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SpeechTail oldDelegate) => false;
}

class MascotWordLine extends StatelessWidget {
  const MascotWordLine({
    super.key,
    required this.controller,
    required this.word,
    required this.onSelect,
    required this.child,
  });
  final GameController controller;
  final WordEntry word;
  final VoidCallback onSelect;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final bought = controller.coordinator?.mascotHintFor(word.key) != null;
    final eligible = bought || !controller.state.targets.contains(word.key);
    final choosing = controller.mascotOpen && controller.mascotChoosing;
    final selected =
        controller.mascotTargetKey == word.key && controller.mascotOpen;
    final index = controller.state.level.words.indexOf(word) + 1;
    return Row(
      children: [
        const SizedBox(width: 40),
        Expanded(
          child: TapRegion(
            groupId: controller,
            enabled: choosing && eligible,
            child: Semantics(
              button: choosing && eligible,
              selected: selected,
              excludeSemantics: choosing,
              label: choosing
                  ? '$indexª palavra, ${word.letters.length} letras, ${bought
                        ? 'consultar dica liberada'
                        : eligible
                        ? 'comprar dica por ${Economy.mascotHintPrice} moedas'
                        : 'palavra já encontrada'}'
                  : null,
              onTap: choosing && eligible && controller.interactive
                  ? onSelect
                  : null,
              child: GestureDetector(
                key: ValueKey('mascot-line-${word.key}'),
                behavior: HitTestBehavior.opaque,
                onTap: choosing && eligible && controller.interactive
                    ? onSelect
                    : null,
                child: _WordChoicePulse(
                  wordKey: word.key,
                  active:
                      choosing && eligible && !bought && controller.interactive,
                  child: child,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: bought
              ? TapRegion(
                  groupId: controller,
                  child: IconButton(
                    key: ValueKey('mascot-clue-${word.key}'),
                    tooltip: 'Rever dica da $indexª palavra',
                    onPressed: controller.interactive && !controller.dragging
                        ? onSelect
                        : null,
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                      color: GameTheme.teal,
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

/// Only the letter fields breathe; their layout and touch bounds stay fixed.
class _WordChoicePulse extends StatefulWidget {
  const _WordChoicePulse({
    required this.wordKey,
    required this.active,
    required this.child,
  });
  final String wordKey;
  final bool active;
  final Widget child;

  @override
  State<_WordChoicePulse> createState() => _WordChoicePulseState();
}

class _WordChoicePulseState extends State<_WordChoicePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: 1.10,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: .50,
  ).animate(_pulse);

  void _sync() {
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _WordChoicePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    key: ValueKey('mascot-pulse-${widget.wordKey}'),
    scale: _scale,
    child: FadeTransition(opacity: _opacity, child: widget.child),
  );
}
