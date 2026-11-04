import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/game_theme.dart';
import '../theme/visual_theme_catalog.dart';
import 'garden.dart';

/// An honest indeterminate wait: no simulated percentage or artificial delay.
class _GameLoadingCard extends StatelessWidget {
  const _GameLoadingCard({
    required this.message,
    this.detail = 'Estamos cuidando do seu progresso.',
    this.welcome = false,
  });

  final String message, detail;
  final bool welcome;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: GardenCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (welcome)
                      const ThemeMascot(
                        theme: VisualTheme.garden,
                        width: 80,
                        height: 80,
                      )
                    else
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: GameTheme.teal,
                        foregroundColor: GameTheme.cream,
                        child: Icon(Icons.cloud_rounded, size: 30),
                      ),
                    const SizedBox(width: 12),
                    const Flexible(child: _LoadingIllustration()),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              Text(detail, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );
}

class GameLoadingScreen extends StatelessWidget {
  const GameLoadingScreen({super.key, this.account = false});
  final bool account;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Garden(
      quiet: true,
      child: SafeArea(
        child: _GameLoadingCard(
          welcome: !account,
          message: account
              ? 'Carregando seu progresso…'
              : 'Preparando seu jogo…',
        ),
      ),
    ),
  );
}

/// Covers the current context and blocks touch, accessibility and back navigation.
class GameLoadingOverlay extends StatelessWidget {
  const GameLoadingOverlay({
    super.key,
    required this.child,
    required this.message,
  });
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: message == null,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: message != null,
          child: ExcludeSemantics(
            excluding: message != null,
            child: AbsorbPointer(absorbing: message != null, child: child),
          ),
        ),
        if (message != null) ...[
          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Color(0x660F3028)),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                child: _GameLoadingCard(
                  message: message!,
                  detail: 'Seu jogo estará pronto em instantes.',
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _LoadingIllustration extends StatefulWidget {
  const _LoadingIllustration();

  @override
  State<_LoadingIllustration> createState() => _LoadingIllustrationState();
}

class _LoadingIllustrationState extends State<_LoadingIllustration>
    with SingleTickerProviderStateMixin {
  late final _light = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _light.stop();
    } else if (!_light.isAnimating) {
      _light.repeat();
    }
  }

  @override
  void dispose() {
    _light.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    const letters = ['A', 'B', 'C'];
    final count = letters.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = math.min(5.0, constraints.maxWidth / (count * 4));
        final diameter = math.min(
          44.0,
          (constraints.maxWidth - gap * (count - 1)) / count,
        );
        return AnimatedBuilder(
          animation: _light,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < count; index++) ...[
                if (index > 0) SizedBox(width: gap),
                _tile(
                  letters[index],
                  diameter,
                  reducedMotion ? 0 : _glowAt(index, count),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  double _glowAt(int index, int count) {
    final distance = (_light.value * count - index).abs();
    return math.max(0.0, 1.0 - math.min(distance, count.toDouble() - distance));
  }

  Widget _tile(String letter, double diameter, double glow) {
    const base = GameTheme.teal;
    const highlight = Color(0xFF287C7B);
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(base, highlight, .22 + glow * .78)!, base],
        ),
        border: Border.all(color: Color.lerp(base, highlight, .65)!),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: .14 + glow * .17),
            offset: const Offset(0, 3),
            blurRadius: 3 + glow * 5,
          ),
        ],
      ),
      child: Text(
        letter,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: Colors.white,
          fontSize: diameter * .52,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
