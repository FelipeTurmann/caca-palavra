import 'dart:math' as math;
import '../../../core/widgets/garden.dart';
import '../../../core/widgets/lagoon.dart';
import '../../../core/widgets/themed_reading_page.dart';
import 'settings_screen.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/game_theme.dart';
import '../domain/game_engine.dart';
import 'game_controller.dart';
import 'home_screen.dart';
import 'shop_screen.dart';
import '../application/campaign_models.dart';
import 'widgets/letter_wheel.dart';
import 'widgets/ad_free_button.dart';
import 'widgets/selection_feedback.dart';
import 'widgets/word_slots.dart';
import 'widgets/explorer_progress.dart';
import 'widgets/extra_collection_layer.dart';
import 'widgets/coin_collection_layer.dart';
import 'widgets/mascot_help.dart';

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
  final _walletKey = GlobalKey();
  final _completionCoinSourceKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_checkExpiry);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.effects.resume();
      controller.refreshCalendar();
    }
    if (state != AppLifecycleState.resumed) {
      controller.suspendPresentation();
    }
  }

  @override
  void didChangeMetrics() {
    final dialog = _hintContext;
    _hintContext = null;
    if (dialog != null && dialog.mounted) Navigator.of(dialog).pop(0);
    controller.cancelTransientPresentation();
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
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ExtrasSheet(controller: controller),
    );
  }

  Future<void> selectMascotWord(WordEntry word) async {
    final c = controller;
    if (!c.interactive || c.dragging || c.coordinator == null) return;
    final session = c.coordinator!;
    final expected = session.context;
    if (session.mascotHintFor(word.key) != null) {
      c.showMascotWord(word.key);
      return;
    }
    if (c.state.targets.contains(word.key)) return;
    if (session.clueWordFor(word.key)?.clue == null) {
      c.showMascotWord(
        word.key,
        notice: 'Esta palavra está sem dica no momento.',
      );
      return;
    }
    c.showMascotWord(word.key);
    final price = Economy.mascotHintPrice;
    final enough = c.balance >= price;
    final index = c.state.level.words.indexOf(word) + 1;
    final id = session.createHintId();
    final choice = await showDialog<int>(
      context: context,
      animationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (dialogContext) {
        _hintContext = dialogContext;
        return AlertDialog(
          scrollable: true,
          title: Text(enough ? 'Dica do mascote' : 'Moedas insuficientes'),
          content: Text(
            enough
                ? 'Dica para a $indexª palavra · ${word.letters.length} letras. Receba uma frase para ajudar a descobrir esta palavra por $price moedas. Você tem ${c.balance} moedas.'
                : 'Você tem ${c.balance} moedas. Faltam ${price - c.balance} moedas para esta dica.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 0),
              child: Text(enough ? 'Cancelar' : 'Agora não'),
            ),
            FilledButton(
              key: const ValueKey('confirm-mascot-hint'),
              onPressed: () => Navigator.pop(dialogContext, enough ? 1 : 2),
              child: Text(
                enough ? 'Receber dica · $price moedas' : 'Ir à loja',
              ),
            ),
          ],
        );
      },
    );
    _hintContext = null;
    if (!mounted) return;
    if (!c.mascotOpen) return;
    if (expected?.identity != session.context?.identity || c.dailyInvalid) {
      c.closeMascot();
      return;
    }
    if (choice == 2) {
      await openShop(context, c);
      if (mounted &&
          expected?.identity == session.context?.identity &&
          c.interactive) {
        await selectMascotWord(word);
      }
      return;
    }
    if (choice != 1) {
      c.chooseMascotWord();
      return;
    }
    final outcome = await c.buyMascotHint(word.key, id, expected);
    if (!mounted) return;
    if (outcome?.status == 'unavailable') {
      c.showMascotWord(
        word.key,
        notice: 'Esta palavra está sem dica no momento.',
      );
    } else if (outcome?.status == 'insufficient') {
      c.showMascotWord(
        word.key,
        notice: 'Moedas insuficientes para esta dica.',
      );
    } else if (outcome?.status == 'resolved' || outcome?.status == 'inactive') {
      c.closeMascot();
    }
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
      animationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
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
                ? 'Resolver uma palavra por $price moedas?'
                : 'Revelar uma letra?',
          ),
          content: Text(
            !available
                ? 'Todas as dicas disponíveis já foram reveladas. Forme as palavras no círculo para continuar.'
                : !enough
                ? 'Você tem $balance moedas. Faltam ${price - balance} ${superHint ? 'para usar a Super Dica.' : 'para esta dica.'}'
                : superHint
                ? 'Resolve a palavra com mais letras escondidas. Se houver empate, uma delas será sorteada. Você tem $balance moedas.'
                : 'Uma letra de uma palavra será revelada por $price moedas. Se for a última letra, a palavra será completada. Você tem $balance moedas.',
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
                  superHint ? 'Usar $price moedas' : 'Revelar · $price moedas',
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
      await c.buyHint(id, expected: expected);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => PopScope<void>(
      canPop: controller.coordinator == null && !controller.dragging,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (controller.mascotOpen) {
            controller.closeMascot();
          } else if (controller.coordinator != null) {
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
            Garden(
              quiet: true,
              immersive: true,
              showCornerMascot:
                  controller.coordinator == null ||
                  controller.state.phase == RoundPhase.completed,
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
                    ? _Completion(
                        controller: controller,
                        walletKey: _walletKey,
                        rewardSourceKey: _completionCoinSourceKey,
                      )
                    : MascotRoundLayout(
                        controller: controller,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final scale = MediaQuery.textScalerOf(
                              context,
                            ).scale(1);
                            if (controller.coordinator != null &&
                                controller.saveError == null &&
                                scale <= 1.3 &&
                                constraints.maxWidth >= 568 &&
                                constraints.maxWidth > constraints.maxHeight) {
                              return _WideRound(
                                controller: controller,
                                sourceKey: _extraSourceKey,
                                targetKey: _extraTargetKey,
                                walletKey: _walletKey,
                                onExtras: showExtras,
                                onHint: showHint,
                                onSuperHint: () => showHint(superHint: true),
                                onMascotWord: selectMascotWord,
                              );
                            }
                            final minimumHeight =
                                (controller.coordinator == null
                                    ? 480.0
                                    : 660.0) +
                                math.max(0, scale - 1) * 520;
                            final height = math.max(
                              constraints.maxHeight,
                              minimumHeight,
                            );
                            final wheelSize = math.min(
                              math.min(math.max(224.0, height * 0.42), 320.0),
                              constraints.maxWidth - 32,
                            );
                            final answers = ThemedReadingPage(
                              child: ListView(
                                key: ValueKey(
                                  'answers-${controller.state.session}',
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                children: [
                                  for (final word
                                      in controller.state.level.words)
                                    MascotWordLine(
                                      controller: controller,
                                      word: word,
                                      onSelect: () => selectMascotWord(word),
                                      child: WordSlots(
                                        word: word,
                                        celebrate:
                                            controller.feedback?.kind ==
                                                SubmissionKind.targetFound &&
                                            controller.feedback?.completed ==
                                                false &&
                                            controller.feedback?.word?.key ==
                                                word.key,
                                        revealed:
                                            controller
                                                .state
                                                .revealedLetters[word.key] ??
                                            const {},
                                        found: controller.state.targets
                                            .contains(word.key),
                                        pulse:
                                            (controller.feedback?.kind ==
                                                            SubmissionKind
                                                                .targetFound ||
                                                        controller
                                                                .feedback
                                                                ?.kind ==
                                                            SubmissionKind
                                                                .superResolved) &&
                                                    controller
                                                            .feedback
                                                            ?.word
                                                            ?.key ==
                                                        word.key ||
                                                controller
                                                        .feedback
                                                        ?.revealedLetter
                                                        ?.targetKey ==
                                                    word.key ||
                                                controller
                                                        .paidReveal
                                                        ?.targetKey ==
                                                    word.key
                                            ? controller.feedbackSerial
                                            : 0,
                                      ),
                                    ),
                                ],
                              ),
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
                                    SizedBox(
                                      height: 220 * scale,
                                      child: answers,
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      progressText,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  if (controller.coordinator != null &&
                                      largeText)
                                    Row(
                                      children: [
                                        AdFreeButton(controller: controller),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: _HintTools(
                                              controller: controller,
                                              horizontal: true,
                                              onHint: showHint,
                                              onSuperHint: () =>
                                                  showHint(superHint: true),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  Stack(
                                    children: [
                                      Column(
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  controller.coordinator ==
                                                          null ||
                                                      largeText
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
                                      if (controller.coordinator != null &&
                                          !largeText)
                                        Positioned(
                                          left: 0,
                                          top: 0,
                                          child: AdFreeButton(
                                            controller: controller,
                                          ),
                                        ),
                                      if (controller.coordinator != null &&
                                          !largeText)
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: _HintTools(
                                            controller: controller,
                                            onHint: showHint,
                                            onSuperHint: () =>
                                                showHint(superHint: true),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  const LagoonReadingSurface(
                                    child: Text(
                                      'Arraste para ligar as letras',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 14),
                                    ),
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
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      tooltip: 'Início',
                                                      onPressed: controller
                                                          .leaveToHome,
                                                      icon: const Icon(
                                                        Icons
                                                            .arrow_back_rounded,
                                                      ),
                                                    ),
                                                    SettingsButton(
                                                      controller: controller,
                                                    ),
                                                  ],
                                                ),
                                                WalletBadge(
                                                  key: _walletKey,
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
                                              Expanded(child: levelLabel),
                                              const SizedBox(width: 16),
                                              extrasButton,
                                            ],
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
                                          playArea(wheelSize, bounded: false)
                                        else
                                          Expanded(
                                            child: LayoutBuilder(
                                              builder: (context, space) {
                                                final style =
                                                    DefaultTextStyle.of(context)
                                                        .style
                                                        .copyWith(fontSize: 14);
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
                                                        maxWidth:
                                                            space.maxWidth,
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
                                                        (44 *
                                                                math.max(
                                                                  1,
                                                                  scale,
                                                                ) +
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
            ),
            Positioned.fill(
              child: CoinCollectionLayer(
                controller: controller,
                layerKey: _effectsKey,
                explorerSourceKey: _extraSourceKey,
                completionSourceKey: _completionCoinSourceKey,
                walletKey: _walletKey,
              ),
            ),
            if (controller.state.phase == RoundPhase.completed)
              Positioned.fill(
                child: VictoryConfetti(
                  key: ValueKey(
                    'victory-${controller.state.session}-${controller.victorySerial}',
                  ),
                  celebrate: controller.freshVictory,
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

class _HintTools extends StatelessWidget {
  const _HintTools({
    required this.controller,
    required this.onHint,
    required this.onSuperHint,
    this.horizontal = false,
  });
  final GameController controller;
  final VoidCallback onHint, onSuperHint;
  final bool horizontal;
  @override
  Widget build(BuildContext context) {
    Widget button(
      String key,
      String label,
      int price,
      IconData icon,
      VoidCallback action,
      bool gold,
    ) => IconButton.filledTonal(
      key: ValueKey(key),
      tooltip: '$label · $price moedas',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      style: IconButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        backgroundColor: const Color(0xFAFFF9EE),
        foregroundColor: gold ? const Color(0xFF795100) : GameTheme.teal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: Color(0xFFE8CBA2)),
      ),
      onPressed: controller.interactive && !controller.dragging ? action : null,
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$price',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.monetization_on_rounded, size: 11),
            ],
          ),
        ],
      ),
    );
    final children = [
      button(
        'hint',
        'Dica',
        Economy.hintPrice,
        Icons.lightbulb_outline_rounded,
        onHint,
        false,
      ),
      button(
        'super-hint',
        'Super Dica',
        Economy.superHintPrice,
        Icons.auto_fix_high_rounded,
        onSuperHint,
        true,
      ),
    ];
    return horizontal
        ? Wrap(alignment: WrapAlignment.center, spacing: 12, children: children)
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              children.first,
              const SizedBox(height: 4),
              children.last,
            ],
          );
  }
}

class _WideRound extends StatelessWidget {
  const _WideRound({
    required this.controller,
    required this.sourceKey,
    required this.targetKey,
    required this.walletKey,
    required this.onExtras,
    required this.onHint,
    required this.onSuperHint,
    required this.onMascotWord,
  });
  final GameController controller;
  final GlobalKey sourceKey, targetKey, walletKey;
  final VoidCallback onExtras, onHint, onSuperHint;
  final ValueChanged<WordEntry> onMascotWord;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final contentHeight = math.max(box.maxHeight, 300.0);
      return SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: SizedBox(
              height: contentHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Início',
                          onPressed: controller.leaveToHome,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        SettingsButton(controller: controller),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            controller.isDaily
                                ? 'Desafio diário'
                                : 'Nível ${controller.state.level.id}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        WalletBadge(
                          key: walletKey,
                          balance: controller.balance,
                          onPressed: () => openShop(context, controller),
                        ),
                      ],
                    ),
                    SaveStatus(controller: controller),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Encontre ${controller.state.level.words.length} palavras',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    ExtrasButton(
                                      key: targetKey,
                                      controller: controller,
                                      onPressed: onExtras,
                                    ),
                                  ],
                                ),
                                Expanded(
                                  child: ThemedReadingPage(
                                    child: ListView(
                                      key: ValueKey(
                                        'answers-${controller.state.session}',
                                      ),
                                      children: [
                                        for (final word
                                            in controller.state.level.words)
                                          MascotWordLine(
                                            controller: controller,
                                            word: word,
                                            onSelect: () => onMascotWord(word),
                                            child: WordSlots(
                                              word: word,
                                              celebrate:
                                                  controller.feedback?.kind ==
                                                      SubmissionKind
                                                          .targetFound &&
                                                  controller
                                                          .feedback
                                                          ?.completed ==
                                                      false &&
                                                  controller
                                                          .feedback
                                                          ?.word
                                                          ?.key ==
                                                      word.key,
                                              found: controller.state.targets
                                                  .contains(word.key),
                                              revealed:
                                                  controller
                                                      .state
                                                      .revealedLetters[word
                                                      .key] ??
                                                  const {},
                                              pulse:
                                                  controller
                                                              .feedback
                                                              ?.word
                                                              ?.key ==
                                                          word.key ||
                                                      controller
                                                              .paidReveal
                                                              ?.targetKey ==
                                                          word.key ||
                                                      controller
                                                              .feedback
                                                              ?.revealedLetter
                                                              ?.targetKey ==
                                                          word.key
                                                  ? controller.feedbackSerial
                                                  : 0,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                Text(
                                  '${controller.state.targets.length} de ${controller.state.level.words.length} palavras',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, right) {
                                final size = math.min(
                                  320.0,
                                  math.min(
                                    right.maxWidth,
                                    math.max(224.0, right.maxHeight - 64),
                                  ),
                                );
                                return SingleChildScrollView(
                                  child: Stack(
                                    children: [
                                      Column(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 56,
                                            ),
                                            child: SelectionFeedback(
                                              controller: controller,
                                              extraIconKey: sourceKey,
                                            ),
                                          ),
                                          LetterWheel(
                                            controller: controller,
                                            size: size,
                                          ),
                                        ],
                                      ),
                                      Positioned(
                                        left: 0,
                                        top: 0,
                                        child: AdFreeButton(
                                          controller: controller,
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: _HintTools(
                                          controller: controller,
                                          onHint: onHint,
                                          onSuperHint: onSuperHint,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
    },
  );
}

class _Completion extends StatelessWidget {
  const _Completion({
    required this.controller,
    required this.walletKey,
    required this.rewardSourceKey,
  });
  final GlobalKey walletKey, rewardSourceKey;
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
                    if (controller.coordinator != null) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: WalletBadge(
                          key: walletKey,
                          balance: controller.balance,
                          onPressed: () => openShop(context, controller),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin:
                            controller.freshVictory &&
                                !MediaQuery.disableAnimationsOf(context)
                            ? .9
                            : 1,
                        end: 1,
                      ),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 350),
                      builder: (context, value, child) =>
                          Transform.scale(scale: value, child: child),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF92C96F), Color(0xFF43975D)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x225B9D5C),
                              offset: Offset(0, 5),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 62,
                          color: Colors.white,
                        ),
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
                        key: rewardSourceKey,
                        controller.coordinator!.freshCompletion
                            ? '+${controller.completionReward} moedas!'
                            : 'Recompensa de ${controller.completionReward} moedas já recebida',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
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
                      child: VolumeButton(
                        key: const ValueKey('next-level'),
                        onPressed:
                            controller.busy || controller.saveError != null
                            ? null
                            : controller.nextLevel,
                        child: Text(
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
