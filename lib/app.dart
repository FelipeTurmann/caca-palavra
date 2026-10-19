import 'package:flutter/material.dart';

import 'core/theme/game_theme.dart';
import 'features/game/data/game_data.dart';
import 'features/game/domain/game_engine.dart';
import 'features/game/presentation/game_controller.dart';
import 'features/game/presentation/game_screen.dart';

class WordGameApp extends StatefulWidget {
  const WordGameApp({super.key});
  @override
  State<WordGameApp> createState() => _WordGameAppState();
}

class _WordGameAppState extends State<WordGameApp> {
  late final Future<GameController> _controller = GameData.load().then((data) {
    final controller = GameController(
      GameEngine(levels: data.levels, lexicon: data.lexicon),
    );
    if (!mounted) controller.dispose();
    _loaded = mounted ? controller : null;
    return controller;
  });
  GameController? _loaded;

  @override
  void dispose() {
    _loaded?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Conecte palavras',
    theme: GameTheme.theme,
    home: FutureBuilder<GameController>(
      future: _controller,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Não foi possível abrir os níveis.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return GameScreen(controller: snapshot.requireData);
      },
    ),
  );
}
