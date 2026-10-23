import 'package:flutter/material.dart';
import '../../../../core/theme/game_theme.dart';
import '../../../../core/theme/visual_theme_catalog.dart';
import '../../application/campaign_models.dart';
import '../../domain/game_engine.dart';
import '../game_controller.dart';

const mascotInvitation =
    'Vou te ajudar! Escolha uma palavra para receber uma dica.';

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
  Widget build(BuildContext context) => controller.coordinator == null
      ? child
      : Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned(
              right: 0,
              bottom: 0,
              left: controller.mascotOpen ? 0 : null,
              width: controller.mascotOpen
                  ? null
                  : MediaQuery.sizeOf(context).height < 740 ||
                        MediaQuery.orientationOf(context) ==
                            Orientation.landscape ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.3
                  ? 64
                  : 96,
              child: TapRegion(
                groupId: controller,
                enabled: controller.mascotOpen,
                onTapOutside: (_) {
                  if (!controller.busy) controller.closeMascot();
                },
                child: MascotHelp(controller: controller),
              ),
            ),
          ],
        );
}

class MascotHelp extends StatelessWidget {
  const MascotHelp({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final compact =
        MediaQuery.sizeOf(context).height < 740 ||
        MediaQuery.orientationOf(context) == Orientation.landscape ||
        scale > 1.3;
    final text = controller.busy
        ? 'Liberando dica…'
        : controller.mascotNotice ??
              controller.mascotHint?.clue ??
              mascotInvitation;
    return SizedBox(
      height: controller.mascotOpen
          ? scale > 1.3
                ? 178
                : MediaQuery.sizeOf(context).width < 400
                ? 164
                : 112
          : compact
          ? 80
          : 112,
      child: Align(
        alignment: Alignment.bottomRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: controller.mascotOpen
                      ? Padding(
                          padding: const EdgeInsets.only(right: 12, bottom: 6),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: GameTheme.cream,
                                  border: Border.all(
                                    color: const Color(0xFFD6AA7B),
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x180B5660),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    6,
                                    8,
                                    3,
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: SingleChildScrollView(
                                          child: Semantics(
                                            liveRegion: true,
                                            child: Text(
                                              text,
                                              key: const ValueKey(
                                                'mascot-speech',
                                              ),
                                              style: const TextStyle(
                                                fontSize: 14,
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
                                            TextButton(
                                              onPressed: controller.busy
                                                  ? null
                                                  : controller.retrySave,
                                              child: const Text(
                                                'Tentar novamente',
                                              ),
                                            ),
                                          if (!controller.mascotChoosing &&
                                              controller.mascotHint != null)
                                            TextButton(
                                              onPressed: controller.interactive
                                                  ? controller.chooseMascotWord
                                                  : null,
                                              child: const Text(
                                                'Escolher outra palavra',
                                              ),
                                            ),
                                          TextButton(
                                            onPressed: controller.busy
                                                ? null
                                                : controller.closeMascot,
                                            child: const Text('Fechar'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Positioned(
                                right: -10,
                                bottom: 23,
                                child: CustomPaint(
                                  size: Size(11, 18),
                                  painter: _SpeechTail(),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Semantics(
                  button: true,
                  label: 'Dica do mascote',
                  excludeSemantics: true,
                  enabled: controller.interactive && !controller.dragging,
                  onTap: controller.interactive && !controller.dragging
                      ? () => controller.mascotOpen
                            ? controller.closeMascot()
                            : controller.chooseMascotWord()
                      : null,
                  child: Tooltip(
                    message: 'Dica do mascote',
                    child: InkResponse(
                      key: const ValueKey('mascot-help'),
                      onTap: controller.interactive && !controller.dragging
                          ? () => controller.mascotOpen
                                ? controller.closeMascot()
                                : controller.chooseMascotWord()
                          : null,
                      radius: 42,
                      child: SizedBox(
                        width: compact ? 48 : 80,
                        height: compact ? 56 : 88,
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: ThemeMascot(height: 80, width: 80),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: GameTheme.cream,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 18,
                                  color: GameTheme.teal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
    duration: const Duration(milliseconds: 850),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: 1.035,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: .65,
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
