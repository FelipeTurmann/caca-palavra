import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/game_theme.dart';
import '../../domain/game_engine.dart';
import '../../application/campaign_models.dart';
import '../game_controller.dart';

const explorerGoldInk = Color(0xFF795100);
const explorerGoldSurface = Color(0xFFFFEDB7);

class ExtrasButton extends StatelessWidget {
  const ExtrasButton({
    super.key,
    required this.controller,
    required this.onPressed,
  });
  final GameController controller;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(
        'collection-pulse-${state.session}-${controller.collectedSerial}',
      ),
      tween: Tween(begin: 0, end: 1),
      duration: reduced ? Duration.zero : GameTiming.pulse,
      builder: (context, value, child) => Transform.scale(
        scale: controller.collectedSerial > 0
            ? 1 + math.sin(math.pi * value) * 0.07
            : 1,
        child: child,
      ),
      child: TextButton.icon(
        key: const ValueKey('extras'),
        onPressed: controller.dragging ? null : onPressed,
        icon: Icon(
          state.explorerUnlocked
              ? Icons.workspace_premium_rounded
              : Icons.star_rounded,
          color: explorerGoldInk,
          size: 23,
        ),
        label: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Extras: ${state.extras.length}'),
            Text(
              'Meta ${state.explorerProgress}/${state.level.extraGoal}',
              style: const TextStyle(fontSize: 11, color: explorerGoldInk),
            ),
          ],
        ),
      ),
    );
  }
}

class ExplorerBadge extends StatelessWidget {
  const ExplorerBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('explorer-badge'),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      color: explorerGoldSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: GameTheme.gold),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.workspace_premium_rounded, color: explorerGoldInk, size: 30),
        SizedBox(width: 10),
        Flexible(
          child: Text(
            'Explorador conquistado',
            style: TextStyle(
              color: explorerGoldInk,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class ExplorerProgress extends StatelessWidget {
  const ExplorerProgress({super.key, required this.state});
  final GameState state;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: explorerGoldSurface,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: explorerGoldInk),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Explorador · ${state.explorerProgress}/${state.level.extraGoal}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: explorerGoldInk,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(
          label:
              'Meta opcional: ${state.explorerProgress} de ${state.level.extraGoal} extras',
          child: LinearProgressIndicator(
            value: state.explorerProgress / state.level.extraGoal,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: Colors.white,
            color: explorerGoldInk,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          state.explorerUnlocked
              ? 'Selo conquistado! Novas descobertas continuam contando.'
              : 'Encontre ${state.level.extraGoal} ${state.level.extraGoal == 1 ? 'palavra extra' : 'palavras extras'} neste nível para conquistar o selo Explorador.',
          style: const TextStyle(color: GameTheme.ink),
        ),
        const SizedBox(height: 8),
        const Text(
          'Meta opcional. Você pode avançar sem completar o selo.',
          style: TextStyle(fontSize: 13),
        ),
      ],
    ),
  );
}

class ExtrasSheet extends StatelessWidget {
  const ExtrasSheet({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: math.min(MediaQuery.sizeOf(context).height * 0.78, 620),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final state = controller.state;
            final words = state.extras.values.toList().reversed.toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      Text(
                        'Palavras extras',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ExplorerProgress(state: state),
                      if (controller.explorerRewardGranted ||
                          !state.explorerUnlocked) ...[
                        const SizedBox(height: 12),
                        Text(
                          controller.explorerRewardGranted
                              ? '+${Economy.explorerReward} moedas recebidas pelo selo.'
                              : 'Conquiste o selo e ganhe ${Economy.explorerReward} moedas neste nível.',
                          style: const TextStyle(
                            color: explorerGoldInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'Cada extra inédita revela um quadrado de uma resposta. Pelo menos uma letra de cada palavra permanece escondida para você formar a resposta.',
                      ),
                      const SizedBox(height: 16),
                      if (state.explorerUnlocked) ...[
                        const ExplorerBadge(),
                        const SizedBox(height: 16),
                      ],
                      if (words.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Você ainda não encontrou palavras extras.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (var i = 0; i < words.length; i++)
                        Card(
                          color: i == 0
                              ? explorerGoldSurface
                              : Colors.white.withValues(alpha: 0.6),
                          elevation: 0,
                          child: ListTile(
                            leading: const Icon(
                              Icons.star_rounded,
                              color: explorerGoldInk,
                            ),
                            title: Text(
                              words[i].display,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: i == 0
                                ? const Text('Mais recente')
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class ExtraDiscoveriesSummary extends StatelessWidget {
  const ExtraDiscoveriesSummary({super.key, required this.state});
  final GameState state;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (state.extras.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(
          'Suas descobertas',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final word in state.extras.values)
              Chip(
                avatar: const Icon(
                  Icons.star_rounded,
                  color: explorerGoldInk,
                  size: 18,
                ),
                label: Text(word.display),
                backgroundColor: explorerGoldSurface,
                side: BorderSide.none,
              ),
          ],
        ),
      ],
      if (state.explorerUnlocked) ...[
        const SizedBox(height: 20),
        const ExplorerBadge(),
      ],
    ],
  );
}
