import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/game_theme.dart';
import '../../domain/game_engine.dart';
import '../game_controller.dart';

/// Only presents credits already committed. Finishing a flight never pays coins.
class CoinCollectionLayer extends StatelessWidget {
  const CoinCollectionLayer({
    super.key,
    required this.controller,
    required this.layerKey,
    required this.explorerSourceKey,
    required this.completionSourceKey,
    required this.walletKey,
  });
  final GameController controller;
  final GlobalKey layerKey, explorerSourceKey, completionSourceKey, walletKey;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Stack(
        children: [
          for (final reward in controller.coinRewards)
            if (reward.origin != CoinRewardOrigin.completion ||
                controller.state.phase == RoundPhase.completed)
              _CoinFlight(
                key: ValueKey('coin-flight-${reward.id}'),
                reward: reward,
                layerKey: layerKey,
                walletKey: walletKey,
                sourceKey: reward.origin == CoinRewardOrigin.explorer
                    ? explorerSourceKey
                    : completionSourceKey,
                onFinished: () => controller.finishCoinReward(reward),
              ),
        ],
      ),
    ),
  );
}

class _CoinFlight extends StatefulWidget {
  const _CoinFlight({
    super.key,
    required this.reward,
    required this.layerKey,
    required this.sourceKey,
    required this.walletKey,
    required this.onFinished,
  });
  final CoinReward reward;
  final GlobalKey layerKey, sourceKey, walletKey;
  final VoidCallback onFinished;
  @override
  State<_CoinFlight> createState() => _CoinFlightState();
}

class _CoinFlightState extends State<_CoinFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;
  Offset? start, end;
  bool finished = false;
  void finish() {
    if (finished || !mounted) return;
    finished = true;
    widget.onFinished();
  }

  @override
  void initState() {
    super.initState();
    animation =
        AnimationController(vsync: this, duration: GameTiming.coinCollect)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) finish();
          });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final layer = widget.layerKey.currentContext?.findRenderObject();
      final wallet = widget.walletKey.currentContext?.findRenderObject();
      final source = widget.sourceKey.currentContext?.findRenderObject();
      if (MediaQuery.disableAnimationsOf(context) ||
          layer is! RenderBox ||
          wallet is! RenderBox ||
          !layer.hasSize ||
          !wallet.hasSize) {
        finish();
        return;
      }
      final bounds = Offset.zero & layer.size;
      final target = layer.globalToLocal(
        wallet.localToGlobal(wallet.size.center(Offset.zero)),
      );
      if (!bounds.contains(target)) {
        finish();
        return;
      }
      final origin = source is RenderBox && source.hasSize
          ? layer.globalToLocal(
              source.localToGlobal(source.size.center(Offset.zero)),
            )
          : bounds.center;
      setState(() {
        start = bounds.contains(origin)
            ? origin
            : Offset(layer.size.width * .5, layer.size.height * .6);
        end = target;
      });
      animation.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) && animation.isAnimating) {
      animation.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) => finish());
    }
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => start == null
      ? const SizedBox.shrink()
      : AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final progress = animation.value;
            return Stack(
              children: [
                if (progress < .55)
                  Positioned(
                    left: start!.dx - 32,
                    top: start!.dy - 38 - progress * 24,
                    child: Opacity(
                      opacity: (1 - progress / .55).clamp(0, 1),
                      child: Text(
                        '+${widget.reward.amount}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF795100),
                        ),
                      ),
                    ),
                  ),
                for (var index = 0; index < 3; index++) _coin(index, progress),
              ],
            );
          },
        );
  Widget _coin(int index, double progress) {
    final time = ((progress - index * .08) / (1 - index * .08)).clamp(0.0, 1.0);
    final value = Curves.easeInOutCubic.transform(time);
    final origin = start! + Offset((index - 1) * 12, index * 5.0);
    final middle = Offset(
      (origin.dx + end!.dx) / 2 - 42,
      math.min(origin.dy, end!.dy) - 32,
    );
    final point =
        origin * ((1 - value) * (1 - value)) +
        middle * (2 * (1 - value) * value) +
        end! * (value * value);
    return Positioned(
      left: point.dx - 16,
      top: point.dy - 16,
      child: Opacity(
        opacity: progress < index * .08
            ? 0
            : (1 - math.max(0.0, value - .9) / .1).clamp(0, 1),
        child: Transform.rotate(
          angle: value * math.pi * .65,
          child: Container(
            key: ValueKey('flying-coin-${widget.reward.id}-$index'),
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFE39A), GameTheme.gold, Color(0xFFD49825)],
              ),
              border: Border.all(color: const Color(0xFFFFF1BA), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33795100),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.monetization_on_rounded,
              size: 25,
              color: Color(0xFF94600B),
            ),
          ),
        ),
      ),
    );
  }
}
