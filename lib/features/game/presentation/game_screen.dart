import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/game_theme.dart';
import '../domain/game_engine.dart';
import 'game_controller.dart';
import 'home_screen.dart';
import '../application/campaign_models.dart';
import 'widgets/letter_wheel.dart';
import 'widgets/selection_feedback.dart';
import 'widgets/word_slots.dart';
import 'widgets/explorer_progress.dart';
import 'widgets/extra_collection_layer.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});
  final GameController controller;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  GameController get controller => widget.controller;
  final _effectsKey = GlobalKey();
  final _extraSourceKey = GlobalKey();
  final _extraTargetKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      controller.cancelGesture();
      controller.clearCollectionEffects();
    }
  }

  @override
  void didChangeMetrics() {
    controller.cancelGesture();
    controller.clearCollectionEffects();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.detach();
    super.dispose();
  }

  void showExtras() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ExtrasSheet(controller: controller),
    );
  }

  Future<void> showHint() async {
    final c = controller;
    c.cancelGesture();
    final balance = c.balance;
    final available = c.engine.canReveal;
    final enough = balance >= Economy.hintPrice;
    final id = c.coordinator!.createHintId();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          !available
              ? 'Nenhuma letra disponível'
              : !enough
              ? 'Moedas insuficientes'
              : 'Revelar uma letra?',
        ),
        content: Text(
          !available
              ? 'Todas as dicas disponíveis já foram reveladas. Forme as palavras no círculo para continuar.'
              : !enough
              ? 'Você tem $balance moedas. Faltam ${Economy.hintPrice - balance} para esta dica.'
              : 'Uma letra de uma palavra será revelada por 30 moedas. Você tem $balance moedas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(available && enough ? 'Cancelar' : 'Voltar ao jogo'),
          ),
          if (available && enough)
            FilledButton(
              key: const ValueKey('confirm-hint'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Revelar · 30 moedas'),
            ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final outcome = await c.buyHint(id);
    if (!mounted || outcome == null) return;
    if (outcome.status == 'purchased') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Uma letra revelada!')));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => PopScope<void>(
      canPop: controller.coordinator == null && !controller.dragging,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (controller.coordinator != null) {
            controller.leaveToHome();
          } else {
            controller.cancelGesture();
          }
        }
      },
      child: Scaffold(
        body: Stack(
          key: _effectsKey,
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [GameTheme.cream, GameTheme.creamEnd],
                ),
              ),
              child: SafeArea(
                child: controller.state.phase == RoundPhase.completed
                    ? _Completion(controller: controller)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final scale = MediaQuery.textScalerOf(
                            context,
                          ).scale(1);
                          final minimumHeight =
                              (controller.coordinator == null ? 480.0 : 600.0) +
                              math.max(0, scale - 1) * 520;
                          final height = math.max(
                            constraints.maxHeight,
                            minimumHeight,
                          );
                          final wheelSize = math.min(
                            math.min(math.max(224.0, height * 0.42), 320.0),
                            constraints.maxWidth - 32,
                          );
                          final answers = ListView(
                            key: ValueKey(
                              'answers-${controller.state.session}',
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            children: [
                              for (final word in controller.state.level.words)
                                WordSlots(
                                  word: word,
                                  revealed:
                                      controller.state.revealedLetters[word
                                          .key] ??
                                      const {},
                                  found: controller.state.targets.contains(
                                    word.key,
                                  ),
                                  pulse:
                                      controller.feedback?.kind ==
                                                  SubmissionKind.targetFound &&
                                              controller.feedback?.word?.key ==
                                                  word.key ||
                                          controller
                                                  .feedback
                                                  ?.revealedLetter
                                                  ?.targetKey ==
                                              word.key ||
                                          controller.paidReveal?.targetKey ==
                                              word.key
                                      ? controller.feedbackSerial
                                      : 0,
                                ),
                            ],
                          );
                          final largeText = scale > 1.3;
                          final body = SizedBox(
                            height: largeText ? null : height,
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 540,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    8,
                                  ),
                                  child: Column(
                                    children: [
                                      if (controller.coordinator != null)
                                        SizedBox(
                                          width: double.infinity,
                                          child: Wrap(
                                            alignment:
                                                WrapAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            spacing: 12,
                                            children: [
                                              IconButton(
                                                tooltip: 'Início',
                                                onPressed:
                                                    controller.leaveToHome,
                                                icon: const Icon(
                                                  Icons.arrow_back_rounded,
                                                ),
                                              ),
                                              WalletBadge(
                                                balance: controller.balance,
                                              ),
                                            ],
                                          ),
                                        ),
                                      SaveStatus(controller: controller),
                                      SizedBox(
                                        width: double.infinity,
                                        child: Wrap(
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          spacing: 16,
                                          children: [
                                            Text(
                                              'Nível ${controller.state.level.id}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                            ExtrasButton(
                                              key: _extraTargetKey,
                                              controller: controller,
                                              onPressed: showExtras,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 3,
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          'Encontre ${controller.state.level.words.length} palavras',
                                          textAlign: TextAlign.center,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                      ),
                                      if (largeText)
                                        SizedBox(
                                          height: 220 * scale,
                                          child: answers,
                                        )
                                      else
                                        Expanded(child: answers),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          '${controller.state.targets.length} de ${controller.state.level.words.length} palavras',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      SelectionFeedback(
                                        controller: controller,
                                        extraIconKey: _extraSourceKey,
                                      ),
                                      LetterWheel(
                                        controller: controller,
                                        size: wheelSize,
                                      ),
                                      if (controller.coordinator != null)
                                        TextButton.icon(
                                          key: const ValueKey('hint'),
                                          onPressed:
                                              controller.interactive &&
                                                  !controller.dragging
                                              ? showHint
                                              : null,
                                          icon: const Icon(
                                            Icons.lightbulb_outline_rounded,
                                          ),
                                          label: const Text('Dica · 30 moedas'),
                                        ),
                                      const SizedBox(height: 5),
                                      const Text(
                                        'Arraste para ligar as letras',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                          return largeText ||
                                  constraints.maxHeight < minimumHeight
                              ? SingleChildScrollView(child: body)
                              : body;
                        },
                      ),
              ),
            ),
            if (controller.state.phase != RoundPhase.completed)
              Positioned.fill(
                child: ExtraCollectionLayer(
                  controller: controller,
                  layerKey: _effectsKey,
                  sourceKey: _extraSourceKey,
                  targetKey: _extraTargetKey,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Completion extends StatelessWidget {
  const _Completion({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final last = controller.lastLevel;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: const BoxDecoration(
                        color: GameTheme.teal,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 62,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Muito bem!',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nível ${state.level.id} concluído.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${state.targets.length} palavras obrigatórias\n${state.extras.length} ${state.extras.length == 1 ? 'palavra extra descoberta' : 'palavras extras descobertas'}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17, height: 1.7),
                      ),
                    ),
                    ExtraDiscoveriesSummary(state: state),
                    if (controller.coordinator != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        controller.coordinator!.freshCompletion
                            ? '+20 moedas!'
                            : 'Recompensa de 20 moedas já recebida',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      WalletBadge(balance: controller.balance),
                      SaveStatus(controller: controller),
                    ],
                    if (last) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Você concluiu todos os níveis desta coleção.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('next-level'),
                        onPressed:
                            controller.busy || controller.saveError != null
                            ? null
                            : controller.nextLevel,
                        icon: Icon(
                          last
                              ? Icons.home_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                        label: Text(
                          last ? 'Voltar ao início' : 'Próximo nível',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
