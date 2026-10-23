import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';
import 'package:caca_palavra/features/game/domain/round_snapshot.dart';
import 'helpers.dart';

class RevealRandom implements Random {
  RevealRandom([List<int> values = const []]) : _values = values.toList();
  final List<int> _values;
  @override
  int nextInt(int max) => _values.isEmpty ? 0 : _values.removeAt(0) % max;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

int hintCount(GameState state) => state.revealedLetters.values.fold(
  0,
  (total, indices) => total + indices.length,
);

List<String> permutations(String value) => value.isEmpty
    ? ['']
    : [
        for (var i = 0; i < value.length; i++)
          for (final suffix in permutations(
            value.substring(0, i) + value.substring(i + 1),
          ))
            '${value[i]}$suffix',
      ];

GameEngine crowdedLevel() {
  final targets = [WordEntry('ABC'), WordEntry('ABD'), WordEntry('ACD')];
  final extras = permutations('ABCD').map(WordEntry.new).toList();
  return GameEngine(
    levels: [
      LevelDefinition(
        id: 1,
        difficulty: 'fixture',
        letters: ['A', 'B', 'C', 'D'],
        words: targets,
        extraGoal: 2,
      ),
    ],
    lexicon: {
      for (final word in [...targets, ...extras]) word.key: word,
    },
    random: RevealRandom(),
  );
}

void main() {
  test(
    'new extra reveals one cell, keeps target counter empty and grants visual badge',
    () {
      final engine = makeEngine(random: RevealRandom());
      final result = submitWord(engine, 'TOGA');
      expect(result.revealedLetter!.targetKey, 'GATO');
      expect(result.revealedLetter!.index, 0);
      expect(result.revealedLetter!.letter, 'G');
      expect(engine.state.revealedLetters, {
        'GATO': {0},
      });
      expect(hintCount(engine.state), 1);
      expect(engine.state.targets, isEmpty);
      expect(engine.state.phase, RoundPhase.playing);
      expect(engine.state.explorerUnlocked, isTrue);
    },
  );

  test(
    'revealed letter need not occur in the extra and uses canonical accent',
    () {
      final engine = makeEngine(random: RevealRandom([0, 1]))..startLevel(8);
      final result = submitWord(engine, 'PAR');
      expect(result.revealedLetter!.targetKey, 'PEDRA');
      expect(result.revealedLetter!.letter, 'E');
      expect('PAR'.contains(result.revealedLetter!.letter), isFalse);
      final accented = makeEngine(random: RevealRandom([0, 1, 0, 1]))
        ..startLevel(4);
      expect(submitWord(accented, 'CAO').revealedLetter!.letter, 'Ç');
      expect(submitWord(accented, 'COA').revealedLetter!.letter, 'Ã');
      expect(accented.state.revealedLetters['ACAO'], {1, 2});
      expect(accented.state.targets, isEmpty);
    },
  );

  test(
    'repeats, invalid submissions and unknown words grant no additional cells',
    () {
      final engine = makeEngine(random: RevealRandom());
      submitWord(engine, 'TOGA');
      final previous = engine.state.revealedLetters;
      expect(submitWord(engine, 'TOGA').revealedLetter, isNull);
      expect(submitWord(engine, 'GTAO').revealedLetter, isNull);
      final ids = idsFor(engine, 'GATO');
      expect(
        engine.submit([
          ...ids,
          ids.first,
        ], session: engine.state.session).revealedLetter,
        isNull,
      );
      expect(
        engine.submit(ids, session: engine.state.session - 1).revealedLetter,
        isNull,
      );
      expect(engine.state.revealedLetters, previous);
      expect(hintCount(engine.state), 1);
    },
  );

  test(
    'eligible word is chosen before a cell; solved words and old hints are excluded',
    () {
      final engine = makeEngine(random: RevealRandom());
      submitWord(engine, 'GATO');
      final result = submitWord(engine, 'TOGA');
      expect(result.revealedLetter!.targetKey, 'GOTA');
      expect(engine.state.revealedLetters.containsKey('GATO'), isFalse);
      final secondWord = makeEngine(random: RevealRandom([1, 2]));
      final another = submitWord(secondWord, 'TOGA');
      expect(another.revealedLetter!.targetKey, 'GOTA');
      expect(another.revealedLetter!.index, 2);
      final fixture = crowdedLevel();
      for (final extra in permutations('ABCD').take(4)) {
        submitWord(fixture, extra);
      }
      expect(fixture.state.revealedLetters['ABC'], {0, 1, 2});
      expect(fixture.state.revealedLetters['ABD'], {0});
      expect(fixture.state.targets, {'ABC'});
    },
  );

  test('extras complete words and the last cell locks the finished round', () {
    final engine = crowdedLevel();
    for (final extra in permutations('ABCD')) {
      final count = hintCount(engine.state);
      final result = submitWord(engine, extra);
      expect(
        result.kind,
        count < 9 ? SubmissionKind.extraFound : SubmissionKind.ignored,
      );
      expect(hintCount(engine.state), count < 9 ? count + 1 : 9);
      expect(result.revealedLetter == null, count >= 9);
      expect(result.completed, count == 8);
      if (count < 9 && count % 3 == 2) {
        expect(result.resolvedWord, isNotNull);
        expect(engine.state.targets, contains(result.resolvedWord!.key));
      }
      expect(
        engine.state.phase,
        count < 8 ? RoundPhase.playing : RoundPhase.completing,
      );
    }
    expect(engine.state.extras.length, 9);
    expect(engine.state.explorerUnlocked, isTrue);
    expect(engine.state.targets, {'ABC', 'ABD', 'ACD'});
    expect(
      engine.fork(engine.snapshot('round')).state.targets,
      engine.state.targets,
    );
    expect(engine.state.phase, RoundPhase.completing);
  });

  test(
    'fully revealed words must be saved as found; partial legacy hints still restore',
    () {
      final engine = crowdedLevel();
      final extras = permutations('ABCD');
      for (final extra in extras.take(2)) {
        submitWord(engine, extra);
      }
      expect(engine.fork(engine.snapshot('round')).state.targets, isEmpty);
      final result = submitWord(engine, extras[2]);
      expect(result.resolvedWord!.key, 'ABC');
      expect(result.completed, false);
      final saved = engine.snapshot('round');
      expect(engine.fork(saved).state.targets, {'ABC'});
      final invalid = RoundSnapshot.fromJson({
        ...saved.toJson(),
        'targets': <String>[],
      });
      expect(() => engine.restoreRound(invalid), throwsFormatException);
    },
  );

  test(
    'hints are immutable snapshots, persist through shuffle and clear for new rounds',
    () {
      final engine = crowdedLevel();
      final initial = engine.state;
      final extraWords = permutations('ABCD');
      submitWord(engine, extraWords[0]);
      final previous = engine.state;
      expect(
        () => previous.revealedLetters['ABC']!.add(2),
        throwsUnsupportedError,
      );
      expect(
        () => previous.revealedLetters['ABC'] = {2},
        throwsUnsupportedError,
      );
      submitWord(engine, extraWords[1]);
      expect(hintCount(previous), 1);
      expect(hintCount(engine.state), 2);
      expect(initial.revealedLetters, isEmpty);
      engine.shuffle();
      expect(hintCount(engine.state), 2);
      engine.startLevel(1);
      expect(engine.state.revealedLetters, isEmpty);
      expect(submitWord(engine, extraWords[0]).revealedLetter, isNotNull);
    },
  );
}
