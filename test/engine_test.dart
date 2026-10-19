import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';
import 'package:caca_palavra/features/game/domain/word_normalizer.dart';
import 'helpers.dart';

class FixedRandom implements Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => max - 1;
}

void main() {
  test('ten levels and 61 lexicon entries pass all data checks', () {
    final data = loadData();
    expect(
      data.levels.map((level) => level.id),
      List.generate(10, (i) => i + 1),
    );
    expect(data.lexicon.length, 61);
    for (final level in data.levels) {
      expect(
        () => GameData.validateLevel(level, data.lexicon),
        returnsNormally,
      );
      expect(
        level.tiles.map((tile) => tile.id).toSet().length,
        level.letters.length,
      );
    }
  });

  test(
    'normalization accepts both Unicode forms, case and outer whitespace',
    () {
      for (final text in [
        ' ação ',
        'AÇÃO',
        'ac\u0327a\u0303o',
        'AC\u0327A\u0303O',
      ]) {
        expect(WordNormalizer.normalize(text), 'ACAO');
      }
      expect(WordNormalizer.normalize('CAFÉ'), 'CAFE');
      expect(WordNormalizer.normalize('pão'), 'PAO');
      expect(WordNormalizer.normalize('AVÓ'), WordNormalizer.normalize('AVÔ'));
      expect(WordNormalizer.visualLetters('AC\u0327A\u0303O').length, 4);
      for (final text in ['', 'A-TO', 'A TO', 'A🙂TO', '123', 'ÆTO']) {
        expect(() => WordNormalizer.normalize(text), throwsFormatException);
      }
    },
  );

  test('new and repeated target affect only the matching target', () {
    final engine = makeEngine();
    expect(submitWord(engine, 'GATO').kind, SubmissionKind.targetFound);
    expect(engine.state.targets, {'GATO'});
    expect(submitWord(engine, 'GATO').kind, SubmissionKind.targetRepeated);
    expect(engine.state.targets.length, 1);
    expect(engine.state.extras, isEmpty);
  });

  test('extras are separate, canonical, unique and never complete a level', () {
    final engine = makeEngine();
    expect(submitWord(engine, 'TOGA').kind, SubmissionKind.extraFound);
    expect(engine.state.extras['TOGA']!.display, 'TOGA');
    engine.shuffle();
    expect(submitWord(engine, 'TOGA').kind, SubmissionKind.extraRepeated);
    expect(engine.state.extras.length, 1);
    expect(engine.state.targets, isEmpty);
    expect(engine.state.phase, RoundPhase.playing);
    engine.startLevel(1);
    expect(submitWord(engine, 'TOGA').kind, SubmissionKind.extraFound);
  });

  test('invalid IDs, duplicate positions and stale sessions cannot submit', () {
    final engine = makeEngine();
    final ids = idsFor(engine, 'GATO');
    final session = engine.state.session;
    expect(
      engine.submit([...ids, ids.first], session: session).kind,
      SubmissionKind.ignored,
    );
    expect(
      engine.submit(['alien', ...ids], session: session).kind,
      SubmissionKind.ignored,
    );
    expect(
      engine.submit([ids.first], session: session).kind,
      SubmissionKind.ignored,
    );
    expect(
      engine.submit(ids.take(2).toList(), session: session).kind,
      SubmissionKind.tooShort,
    );
    engine.startLevel(2);
    expect(engine.submit(ids, session: session).kind, SubmissionKind.ignored);
    expect(engine.state.targets, isEmpty);
  });

  test('lexicon cannot grant a word needing an unavailable extra tile', () {
    final base = loadData();
    final engine = GameEngine(
      levels: base.levels,
      lexicon: {...base.lexicon, 'GATOO': WordEntry('GATOO')},
    );
    final ids = idsFor(engine, 'GATO');
    expect(
      engine.submit([...ids, ids.last], session: engine.state.session).kind,
      SubmissionKind.ignored,
    );
    expect(engine.state.extras, isEmpty);
  });

  test('two distinct A tiles reveal AÇÃO in four slots and AÇO in three', () {
    final engine = makeEngine()..startLevel(4);
    final ids = idsFor(engine, 'ACAO');
    expect(ids[0], isNot(ids[2]));
    final result = engine.submit(ids, session: engine.state.session);
    expect(result.word!.display, 'AÇÃO');
    expect(result.word!.letters.length, 4);
    expect(submitWord(engine, 'ACO').word!.display, 'AÇO');
    expect(engine.state.extras, isEmpty);
  });

  test('ambiguous targets AVÓ and AVÔ are rejected with a clear error', () {
    final words = [WordEntry('AVÓ'), WordEntry('AVÔ'), WordEntry('OVA')];
    final level = LevelDefinition(
      id: 1,
      difficulty: 'teste',
      letters: ['A', 'V', 'O', 'A'],
      words: words,
    );
    expect(
      () => GameData.validateLevel(level, {for (final w in words) w.key: w}),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('ambíguas'),
        ),
      ),
    );
  });

  test('lexicon groups variants with first canonical spelling', () {
    final levels = File('assets/data/levels.json').readAsStringSync();
    final lexicon =
        jsonDecode(File('assets/data/lexicon_pt_br.json').readAsStringSync())
            as Map<String, dynamic>;
    (lexicon['words'] as List).addAll([
      {'display': 'AVÓ'},
      {'display': 'AVÔ'},
    ]);
    final data = GameData.parse(levels, jsonEncode(lexicon));
    expect(data.lexicon['AVO']!.display, 'AVÓ');
  });

  test('invalid data never opens impossible levels', () {
    final lexicon = File('assets/data/lexicon_pt_br.json').readAsStringSync();
    final original = File('assets/data/levels.json').readAsStringSync();
    for (final mutation in <void Function(Map<String, dynamic>)>[
      (root) => root['levels'][1]['id'] = 1,
      (root) => root['levels'][0]['letters'] = ['G', 'A', 'T', 'A'],
      (root) => root['levels'][0]['words'][0]['display'] = 'G-ATO',
      (root) => root['levels'][0]['words'][0]['display'] = 'XATO',
      (root) => root['levels'][0]['words'][0]['display'] = '',
      (root) => root['levels'].removeLast(),
    ]) {
      final root = jsonDecode(original) as Map<String, dynamic>;
      mutation(root);
      expect(
        () => GameData.parse(jsonEncode(root), lexicon),
        throwsFormatException,
      );
    }
  });

  test('last target emits completion exactly once and locks the round', () {
    final events = <GameEvent>[];
    final engine = makeEngine(onEvent: events.add);
    submitWord(engine, 'GATO');
    submitWord(engine, 'GOTA');
    expect(submitWord(engine, 'ATO').completed, isTrue);
    expect(engine.state.phase, RoundPhase.completing);
    expect(submitWord(engine, 'ATO').kind, SubmissionKind.ignored);
    expect(engine.shuffle(), isFalse);
    expect(engine.finishCompletion(engine.state.session), isTrue);
    expect(engine.finishCompletion(engine.state.session), isFalse);
    expect(
      events.where((event) => event.kind == GameEventKind.completion).length,
      1,
    );
  });

  test(
    'shuffle preserves IDs and discoveries and changes visual order with fallback',
    () {
      final engine = makeEngine(random: FixedRandom())..startLevel(4);
      submitWord(engine, 'ACAO');
      submitWord(engine, 'CAO');
      for (var i = 0; i < 40; i++) {
        final before = engine.state;
        expect(engine.shuffle(dragging: true), isFalse);
        expect(engine.shuffle(), isTrue);
        final byId = {for (final t in engine.state.level.tiles) t.id: t.letter};
        expect(engine.state.order.toSet(), before.order.toSet());
        expect(
          engine.state.order.map((id) => byId[id]).join(),
          isNot(before.order.map((id) => byId[id]).join()),
        );
        expect(engine.state.targets, before.targets);
        expect(engine.state.extras.keys, before.extras.keys);
      }
    },
  );

  test('all ten levels can be completed from the supplied tile identities', () {
    final engine = makeEngine();
    for (final level in engine.levels) {
      engine.startLevel(level.id);
      for (final word in level.words) {
        expect(submitWord(engine, word.key).kind, SubmissionKind.targetFound);
      }
      expect(engine.state.phase, RoundPhase.completing);
      expect(engine.finishCompletion(engine.state.session), isTrue);
    }
  });
}
