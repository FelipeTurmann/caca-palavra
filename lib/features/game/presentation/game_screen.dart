import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/game_theme.dart';
import '../domain/game_engine.dart';
import 'game_controller.dart';
import 'home_screen.dart';
import 'shop_screen.dart';
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
  BuildContext? _hintContext;
  void _checkExpiry() {
    if (controller.dailyInvalid && _hintContext != null) {
      final dialog = _hintContext!;
      _hintContext = null;
      Navigator.of(dialog).pop(0);
    }
  }

  final _effectsKey = GlobalKey();
  final _extraSourceKey = GlobalKey();
  final _extraTargetKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_checkExpiry);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) controller.refreshCalendar();
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
    controller.removeListener(_checkExpiry);
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

  Future<void> showHint({bool superHint = false}) async {
    final c = controller;
    if (!c.interactive || c.dragging) return;
    c.cancelGesture();
    final expected = c.coordinator!.context;
    final balance = c.balance,
        price = superHint ? Economy.superHintPrice : Economy.hintPrice;
    final available = superHint
        ? c.state.targets.length < c.state.level.words.length
        : c.engine.canReveal;
    final enough = balance >= price, id = c.coordinator!.createHintId();
    final choice = await showDialog<int>(
      context: context,
      builder: (context) {
        _hintContext = context;
        return AlertDialog(
          scrollable: true,
          title: Text(
            !available
                ? superHint
                      ? 'Todas as palavras já foram resolvidas.'
                      : 'Nenhuma letra disponível'
                : !enough
                ? 'Moedas insuficientes'
                : superHint
                ? 'Resolver uma palavra por 100 moedas?'
                : 'Revelar uma letra?',
          ),
          content: Text(
            !available
                ? 'Todas as dicas disponíveis já foram reveladas. Forme as palavras no círculo para continuar.'
                : !enough
                ? 'Você tem $balance moedas. Faltam ${price - balance} ${superHint ? 'para usar a Super Dica.' : 'para esta dica.'}'
                : superHint
                ? 'Resolve a palavra com mais letras escondidas. Se houver empate, uma delas será sorteada. Você tem $balance moedas.'
                : 'Uma letra de uma palavra será revelada por 30 moedas. Você tem $balance moedas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 0),
              child: Text(
                !available
                    ? 'Voltar ao jogo'
                    : !enough || superHint
                    ? 'Agora não'
                    : 'Cancelar',
              ),
            ),
            if (available && !enough)
              FilledButton(
                onPressed: () => Navigator.pop(context, 2),
                child: const Text('Ir à loja'),
              ),
            if (available && enough)
              FilledButton(
                key: ValueKey(
                  superHint ? 'confirm-super-hint' : 'confirm-hint',
                ),
                onPressed: () => Navigator.pop(context, 1),
                child: Text(
                  superHint ? 'Usar 100 moedas' : 'Revelar · 30 moedas',
                ),
              ),
          ],
        );
      },
    );
    _hintContext = null;
    if (!mounted) return;
    if (choice == 2) {
      await openShop(context, c);
      return;
    }
    if (choice != 1) return;
    if (superHint) {
      await c.buySuperHint(id, expected);
    } else {
      final outcome = await c.buyHint(id, expected: expected);
      if (mounted && outcome?.status == 'purchased') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Uma letra revelada!')));
      }
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
                child: controller.dailyInvalid
                    ? Center(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  controller.coordinator!.clockReversed
                                      ? 'Ajuste a data do aparelho para acessar o desafio diário.'
                                      : 'Um novo desafio diário está disponível.',
                                  textAlign: TextAlign.center,
                                ),
                                if (!controller.coordinator!.clockReversed)
                                  FilledButton(
                                    onPressed:
                                        controller.busy ||
                                            controller.saveError != null
                                        ? null
                                        : () async {
                                            if (controller.busy) return;
                                            await controller.run(
                                              () => controller.coordinator!
                                                  .startDaily(),
                                            );
                                            controller.resetView();
                                          },
                                    child: const Text('Jogar novo desafio'),
                                  ),
                                TextButton(
                                  onPressed: controller.leaveToHome,
                                  child: const Text('Voltar ao início'),
                                ),
                                SaveStatus(controller: controller),
                              ],
                            ),
                          ),
                        ),
                      )
                    : controller.state.phase == RoundPhase.completed
                    ? _Completion(controller: controller)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final scale = MediaQuery.textScalerOf(
                            context,
                          ).scale(1);
                          final minimumHeight =
                              (controller.coordinator == null ? 480.0 : 660.0) +
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
                          final progressText =
                              '${controller.state.targets.length} de ${controller.state.level.words.length} palavras';
                          final feedbackHeight =
                              64 * math.max(1, 1 + (scale - 1) * 2);
                          Widget playArea(
                            double size, {
                            required bool bounded,
                          }) {
                            return Column(
                              mainAxisSize: bounded
                                  ? MainAxisSize.max
                                  : MainAxisSize.min,
                              children: [
                                if (bounded)
                                  Expanded(child: answers)
                                else
                                  SizedBox(height: 220 * scale, child: answers),
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    progressText,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                Stack(
                                  children: [
                                    Column(
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.only(
                                            right:
                                                controller.coordinator == null
                                                ? 0
                                                : 56,
                                          ),
                                          child: SelectionFeedback(
                                            controller: controller,
                                            extraIconKey: _extraSourceKey,
                                          ),
                                        ),
                                        LetterWheel(
                                          controller: controller,
                                          size: size,
                                        ),
                                      ],
                                    ),
                                    if (controller.coordinator != null)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Column(
                                          children: [
                                            IconButton.filledTonal(
                                              key: const ValueKey('hint'),
                                              tooltip: 'Dica · 30 moedas',
                                              constraints: const BoxConstraints(
                                                minWidth: 48,
                                                minHeight: 48,
                                              ),
                                              style: IconButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFFD9EBE6,
                                                ),
                                                foregroundColor: GameTheme.teal,
                                              ),
                                              onPressed:
                                                  controller.interactive &&
                                                      !controller.dragging
                                                  ? showHint
                                                  : null,
                                              icon: const Icon(
                                                Icons.lightbulb_outline_rounded,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            IconButton.filledTonal(
                                              key: const ValueKey('super-hint'),
                                              tooltip:
                                                  'Super Dica · 100 moedas',
                                              constraints: const BoxConstraints(
                                                minWidth: 48,
                                                minHeight: 48,
                                              ),
                                              style: IconButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFFFFEDB7,
                                                ),
                                                foregroundColor: const Color(
                                                  0xFF795100,
                                                ),
                                              ),
                                              onPressed:
                                                  controller.interactive &&
                                                      !controller.dragging
                                                  ? () => showHint(
                                                      superHint: true,
                                                    )
                                                  : null,
                                              icon: const Icon(
                                                Icons.auto_fix_high_rounded,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Arraste para ligar as letras',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            );
                          }

                          final levelLabel = Text(
                            controller.isDaily
                                ? 'Desafio diário'
                                : 'Nível ${controller.state.level.id}',
                            style: Theme.of(context).textTheme.titleMedium,
                          );
                          final extrasButton = ExtrasButton(
                            key: _extraTargetKey,
                            controller: controller,
                            onPressed: showExtras,
                          );
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
                                                onPressed: () => openShop(
                                                  context,
                                                  controller,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      SaveStatus(controller: controller),
                                      if (largeText)
                                        SizedBox(
                                          width: double.infinity,
                                          child: Wrap(
                                            alignment:
                                                WrapAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            spacing: 16,
                                            children: [
                                              levelLabel,
                                              extrasButton,
                                            ],
                                          ),
                                        )
                                      else
                                        Row(
                                          children: [
                                            Expanded(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: levelLabel,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            extrasButton,
                                          ],
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 3,
                                          bottom: 8,
                                        ),
                                        child: largeText
                                            ? Text(
                                                'Encontre ${controller.state.level.words.length} palavras',
                                                textAlign: TextAlign.center,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleLarge,
                                              )
                                            : FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  'Encontre ${controller.state.level.words.length} palavras',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.titleLarge,
                                                ),
                                              ),
                                      ),
                                      if (largeText)
                                        playArea(wheelSize, bounded: false)
                                      else
                                        Expanded(
                                          child: LayoutBuilder(
                                            builder: (context, space) {
                                              final style = DefaultTextStyle.of(
                                                context,
                                              ).style.copyWith(fontSize: 14);
                                              double textHeight(String text) {
                                                final painter =
                                                    TextPainter(
                                                      text: TextSpan(
                                                        text: text,
                                                        style: style,
                                                      ),
                                                      textDirection:
                                                          Directionality.of(
                                                            context,
                                                          ),
                                                      textScaler:
                                                          MediaQuery.textScalerOf(
                                                            context,
                                                          ),
                                                    )..layout(
                                                      maxWidth: space.maxWidth,
                                                    );
                                                final result = painter.height;
                                                painter.dispose();
                                                return result;
                                              }

                                              // Reserve every answer row before growing the wheel.
                                              // Short screens can still scroll the answer list.
                                              final answerHeight =
                                                  controller
                                                          .state
                                                          .level
                                                          .words
                                                          .length *
                                                      (44 * math.max(1, scale) +
                                                          12) +
                                                  8;
                                              final available =
                                                  space.maxHeight -
                                                  answerHeight -
                                                  feedbackHeight -
                                                  11 -
                                                  textHeight(progressText) -
                                                  textHeight(
                                                    'Arraste para ligar as letras',
                                                  );
                                              final size = math.min(
                                                wheelSize,
                                                math.max(224.0, available),
                                              );
                                              return playArea(
                                                size,
                                                bounded: true,
                                              );
                                            },
                                          ),
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
    final last = controller.isDaily || controller.lastLevel;
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
                      controller.isDaily
                          ? 'Desafio diário concluído'
                          : 'Nível ${state.level.id} concluído.',
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
                            ? '+${controller.completionReward} moedas!'
                            : 'Recompensa de ${controller.completionReward} moedas já recebida',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      WalletBadge(
                        balance: controller.balance,
                        onPressed: () => openShop(context, controller),
                      ),
                      SaveStatus(controller: controller),
                    ],
                    if (last && !controller.isDaily) ...[
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
