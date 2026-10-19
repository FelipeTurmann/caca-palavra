import 'dart:io';
import 'dart:math';

import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';

GameData loadData() => GameData.parse(
  File('assets/data/levels.json').readAsStringSync(),
  File('assets/data/lexicon_pt_br.json').readAsStringSync(),
);

GameEngine makeEngine({void Function(GameEvent)? onEvent, Random? random}) {
  final data = loadData();
  return GameEngine(
    levels: data.levels,
    lexicon: data.lexicon,
    random: random ?? Random(7),
    onEvent: onEvent,
  );
}

List<String> idsFor(GameEngine engine, String word) {
  final available = engine.state.level.tiles.toList();
  return [
    for (final letter in word.split(''))
      available
          .removeAt(available.indexWhere((tile) => tile.letter == letter))
          .id,
  ];
}

SubmissionResult submitWord(GameEngine engine, String word) =>
    engine.submit(idsFor(engine, word), session: engine.state.session);
