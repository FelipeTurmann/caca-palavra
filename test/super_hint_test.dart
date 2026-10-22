import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';
import 'package:caca_palavra/features/game/domain/round_snapshot.dart';

class TieRandom implements Random {
  TieRandom(this.index);
  final int index;
  final List<int> bounds = [];
  @override
  int nextInt(int max) {
    bounds.add(max);
    return index % max;
  }

  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

void main() {
  test('Super Dica ranks hidden positions, not total word length', () {
    final level = LevelDefinition(
      id: 1,
      difficulty: 'test',
      letters: 'ABCDEFG'.split(''),
      words: [WordEntry('ABCDEFG'), WordEntry('ABCDE')],
    );
    final random = TieRandom(0),
        engine = GameEngine(levels: [level], lexicon: {}, random: random);
    engine.restoreRound(
      RoundSnapshot(
        levelId: 1,
        fingerprint: level.fingerprint,
        roundId: 'round',
        status: 'in_progress',
        order: engine.state.order,
        targets: [],
        extras: [],
        reveals: [
          for (var i = 0; i < 5; i++)
            RevealRecord(
              targetKey: 'ABCDEFG',
              index: i,
              source: RevealSource.paid,
              sourceKey: 'hint-$i',
            ),
        ],
      ),
    );
    expect(engine.resolveSuperHint('super').word!.key, 'ABCDE');
    expect(random.bounds, isEmpty);
    final restored = engine.fork(engine.snapshot('round'));
    expect(restored.state.targets, {'ABCDE'});
    expect(restored.state.revealedLetters['ABCDE'], hasLength(5));
    expect(restored.state.superHints, hasLength(1));
  });
  test(
    'Super Dica randomizes only maximum ties, skips found words and keeps canonical accents',
    () {
      final level = LevelDefinition(
        id: 1,
        difficulty: 'test',
        letters: ['A', 'C', 'A', 'O'],
        words: [WordEntry('AÇÃO'), WordEntry('CÃO'), WordEntry('AÇO')],
      );
      final random = TieRandom(1),
          engine = GameEngine(levels: [level], lexicon: {}, random: random);
      expect(engine.resolveSuperHint('one').word!.display, 'AÇÃO');
      expect(random.bounds, isEmpty);
      expect(engine.resolveSuperHint('two').word!.display, 'AÇO');
      expect(random.bounds, [2]);
      expect(engine.state.targets, {'ACAO', 'ACO'});
      expect(engine.state.revealedLetters['ACAO'], hasLength(4));
      expect(
        engine.fork(engine.snapshot('round')).state.superHints,
        hasLength(2),
      );
    },
  );
}
