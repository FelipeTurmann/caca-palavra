import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/game_theme.dart';
import '../game_controller.dart';

/// Decorative effects never intercept input or delay the authoritative state.
class ExtraCollectionLayer extends StatelessWidget {
  const ExtraCollectionLayer({
    super.key,
    required this.controller,
    required this.layerKey,
    required this.sourceKey,
    required this.targetKey,
  });
  final GameController controller;
  final GlobalKey layerKey;
  final GlobalKey sourceKey;
  final GlobalKey targetKey;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Stack(
        children: [
          for (final discovery in controller.discoveries)
            _FlyingStar(
              key: ValueKey(
                'extra-flight-${discovery.session}-${discovery.id}',
              ),
              discovery: discovery,
              layerKey: layerKey,
              sourceKey: sourceKey,
              targetKey: targetKey,
              onCollected: () => controller.finishDiscovery(discovery),
            ),
        ],
      ),
    ),
  );
}

class _FlyingStar extends StatefulWidget {
  const _FlyingStar({
    super.key,
    required this.discovery,
    required this.layerKey,
    required this.sourceKey,
    required this.targetKey,
    required this.onCollected,
  });
  final ExtraDiscovery discovery;
  final GlobalKey layerKey;
  final GlobalKey sourceKey;
  final GlobalKey targetKey;
  final VoidCallback onCollected;
  @override
  State<_FlyingStar> createState() => _FlyingStarState();
}

class _FlyingStarState extends State<_FlyingStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  Offset? _start;
  Offset? _end;

  @override
  void initState() {
    super.initState();
    _animation =
        AnimationController(vsync: this, duration: GameTiming.extraCollect)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) widget.onCollected();
          });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final layer = widget.layerKey.currentContext?.findRenderObject();
      final source = widget.sourceKey.currentContext?.findRenderObject();
      final target = widget.targetKey.currentContext?.findRenderObject();
      if (MediaQuery.disableAnimationsOf(context) ||
          layer is! RenderBox ||
          source is! RenderBox ||
          target is! RenderBox ||
          !layer.hasSize ||
          !source.hasSize ||
          !target.hasSize) {
        widget.onCollected();
        return;
      }
      final start = layer.globalToLocal(
        source.localToGlobal(source.size.center(Offset.zero)),
      );
      final end = layer.globalToLocal(
        target.localToGlobal(Offset(24, target.size.height / 2)),
      );
      final bounds = Offset.zero & layer.size;
      if (!bounds.contains(start) || !bounds.contains(end)) {
        widget.onCollected();
        return;
      }
      setState(() {
        _start = start;
        _end = end;
      });
      _animation.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) && _animation.isAnimating) {
      _animation.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCollected();
      });
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _start == null
      ? const SizedBox.shrink()
      : AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final value = Curves.easeInOutCubic.transform(
              ((_animation.value - 0.18) / 0.82).clamp(0.0, 1.0),
            );
            final middle = Offset(
              (_start!.dx + _end!.dx) / 2 - 40,
              math.min(_start!.dy, _end!.dy) - 25,
            );
            final position =
                _start! * math.pow(1 - value, 2).toDouble() +
                middle * (2 * (1 - value) * value) +
                _end! * (value * value);
            return Positioned(
              left: position.dx - 17,
              top: position.dy - 17,
              child: Opacity(
                opacity: (1 - math.max(0.0, value - 0.88) / 0.12).clamp(0, 1),
                child: Transform.rotate(
                  angle: value * math.pi / 3,
                  child: Transform.scale(
                    scale: 1 + math.sin(value * math.pi) * 0.25,
                    child: const Icon(
                      Icons.star_rounded,
                      size: 34,
                      color: GameTheme.gold,
                      shadows: [
                        Shadow(color: Color(0x55795100), blurRadius: 5),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
}
