import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/preferences/player_preferences.dart';
import '../../../core/widgets/garden.dart';
import '../domain/game_engine.dart';
import 'game_controller.dart';
import 'widgets/letter_wheel.dart';
import 'widgets/word_slots.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({
    super.key,
    required this.source,
    required this.onFinish,
    this.review = false,
  });
  final GameController source;
  final bool review;
  final Future<void> Function(Introduction status) onFinish;
  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with WidgetsBindingObserver {
  late final GameController demo;
  int step = 0;
  bool shuffled = false, leaving = false;
  String initialOrder = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final word = WordEntry('GATO');
    demo = GameController(
      GameEngine(
        levels: [
          LevelDefinition(
            id: 1,
            difficulty: 'demonstração',
            letters: const ['G', 'A', 'T', 'O'],
            words: [word],
          ),
        ],
        lexicon: {'GATO': word},
      ),
      preferences: widget.source.preferences,
      sharedEffects: widget.source.effects,
      ownsPreferences: false,
    );
    demo.addListener(changed);
  }

  void changed() {
    if (!mounted) return;
    if (step == 0 && demo.state.targets.contains('GATO')) step = 1;
    if (step == 2 && demo.state.order.join() != initialOrder) shuffled = true;
    setState(() {});
  }

  void go(int next) {
    demo.cancelGesture(notify: false);
    if (next == 0 || next == 2) {
      demo.engine.startLevel(1);
      demo.resetView();
      initialOrder = demo.state.order.join();
      shuffled = false;
    }
    setState(() => step = next);
  }

  Future<void> finish(Introduction status) async {
    if (leaving) return;
    setState(() => leaving = true);
    demo.detach();
    await widget.onFinish(status);
    if (mounted) setState(() => leaving = false);
  }

  @override
  void didChangeMetrics() {
    demo.cancelGesture();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) demo.suspendPresentation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    demo.removeListener(changed);
    demo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const titles = [
      'Arraste para ligar',
      'Solte para confirmar',
      'Experimente embaralhar',
      'Pronto para descobrir?',
    ];
    final instructions = [
      'Ligue G → A → T → O e solte o dedo.',
      'Isso! GATO foi preenchida. Cada ficha vale uma vez. Volte à letra anterior para desfazer a última seleção.',
      shuffled
          ? 'As letras mudaram de lugar. Você ainda pode formar GATO!'
          : 'Toque nas setas no centro do círculo para mudar a ordem das letras.',
      'Extras revelam letras e ajudam a conquistar o selo Explorador. A Dica custa 30 moedas e a Super Dica, 100. Toque no saldo para abrir a Loja. Na home há um desafio diário. Seu progresso é salvo automaticamente.',
    ];
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) finish(Introduction.skipped);
      },
      child: Scaffold(
        body: Garden(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final wheelSize = math.min(
                  300.0,
                  math.max(224.0, constraints.maxWidth - 48),
                );
                final wheel = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    WordSlots(
                      word: WordEntry('GATO'),
                      found: step == 1 || demo.state.targets.contains('GATO'),
                      pulse: demo.feedbackSerial,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      demo.dragging ? demo.preview : 'G → A → T → O',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    LetterWheel(controller: demo, size: wheelSize),
                  ],
                );
                final content = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Demonstração · ${step + 1} de 4',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      titles[step],
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    GardenCard(
                      child: Text(
                        instructions[step],
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (step == 1)
                      TextButton(
                        onPressed: () => go(0),
                        child: const Text('Experimentar novamente'),
                      ),
                    const SizedBox(height: 14),
                    if (step < 3)
                      VolumeButton(
                        key: const ValueKey('tutorial-continue'),
                        onPressed: leaving ? null : () => go(step + 1),
                        child: Text(
                          step == 0
                              ? 'Ver demonstração / Continuar'
                              : 'Continuar',
                        ),
                      )
                    else
                      VolumeButton(
                        key: const ValueKey('tutorial-finish'),
                        onPressed: leaving
                            ? null
                            : () => finish(Introduction.completed),
                        child: Text(
                          widget.review ? 'Concluir' : 'Começar a jogar',
                        ),
                      ),
                    if (step > 0)
                      TextButton(
                        onPressed: () => go(step - 1),
                        child: const Text('Voltar à instrução anterior'),
                      ),
                  ],
                );
                final wide =
                    constraints.maxWidth >= 700 &&
                    constraints.maxWidth > constraints.maxHeight &&
                    scale <= 1.3;
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1040),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  key: const ValueKey('skip-tutorial'),
                                  onPressed: leaving
                                      ? null
                                      : () => finish(Introduction.skipped),
                                  child: const Text('Pular tutorial'),
                                ),
                              ),
                              if (wide && step < 3)
                                Row(
                                  children: [
                                    Expanded(child: content),
                                    const SizedBox(width: 24),
                                    Expanded(child: wheel),
                                  ],
                                )
                              else ...[
                                content,
                                if (step < 3) wheel,
                              ],
                              const SizedBox(height: 8),
                              const Text(
                                'Área de treino · sem moedas ou progresso reais',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
