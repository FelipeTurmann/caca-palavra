import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/catalog_data.dart';
import 'package:caca_palavra/features/game/data/daily_catalog.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';
import 'package:caca_palavra/features/game/domain/round_snapshot.dart';
import 'package:caca_palavra/features/game/domain/word_normalizer.dart';
import 'helpers.dart';

class CatalogAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final levelsText = File('assets/data/levels.json').readAsStringSync();
  final lexiconText = File('assets/data/lexicon_pt_br.json').readAsStringSync();
  late GameData production;
  setUpAll(() {
    production = GameData.parse(levelsText, lexiconText);
  });

  test(
    'all 2500 shipped levels pass the same checks as application loading',
    () async {
      final data = await GameData.load(bundle: CatalogAssets());
      expect(data.catalogVersion, 2);
      expect(data.levels.map((l) => l.id), List.generate(2500, (i) => i + 1));
      expect(data.lexicon.length, greaterThan(1000));
      expect(
        data.lexicon.values.every((w) => w.clue != null && w.clue!.isNotEmpty),
        isTrue,
      );
      final seen = <String>{};
      final last = <String, int>{};
      for (final level in data.levels) {
        expect(level.words.length, inInclusiveRange(3, 6));
        expect(level.letters.length, inInclusiveRange(4, 6));
        expect(seen.add(CatalogData.contentKey(level)), isTrue);
        final rack = CatalogData.rackKey(level);
        if (last.containsKey(rack)) {
          expect(level.id - last[rack]!, greaterThanOrEqualTo(100));
        }
        last[rack] = level.id;
        for (final word in level.words) {
          expect(
            level.canForm(word.key),
            isTrue,
            reason: '${level.id}: ${word.display}',
          );
        }
      }
      for (final key in ['TOPA', 'PARE', 'OPTA', 'COA', 'ARDE', 'ODE']) {
        expect(data.lexicon.containsKey(key), isFalse, reason: key);
      }
      expect(data.lexicon['CANTO']!.clue, contains('paredes'));
      expect(data.lexicon['AVO']!.display, 'AVÓ');
    },
  );

  test(
    'every supplied answer actually completes its level using tile identities',
    () {
      final engine = GameEngine(
        levels: production.levels,
        lexicon: production.lexicon,
      );
      for (final level in production.levels) {
        engine.startLevel(level.id);
        for (final word in level.words) {
          expect(submitWord(engine, word.key).kind, SubmissionKind.targetFound);
        }
        expect(engine.state.phase, RoundPhase.completing);
        expect(engine.finishCompletion(engine.state.session), isTrue);
      }
    },
  );

  test(
    'N-A-O is accepted as the canonical extra NÃO in every compatible level',
    () {
      expect(WordNormalizer.normalize('NÃO'), 'NAO');
      expect(WordNormalizer.normalize('NAO'), 'NAO');
      expect(WordNormalizer.normalize('NA\u0303O'), 'NAO');
      expect(production.lexicon['NAO']!.display, 'NÃO');
      expect(production.lexicon['NAO']!.clue, isNotEmpty);
      final levels = production.levels
          .where((level) => level.canForm('NAO'))
          .toList();
      expect(levels, isNotEmpty);
      final engine = GameEngine(
        levels: production.levels,
        lexicon: production.lexicon,
      );
      for (final level in levels) {
        engine.startLevel(level.id);
        final found = submitWord(engine, 'NAO');
        expect(
          found.kind,
          SubmissionKind.extraFound,
          reason: 'Nível ${level.id}',
        );
        expect(found.word!.display, 'NÃO');
        expect(engine.state.extras['NAO']!.display, 'NÃO');
        expect(submitWord(engine, 'NAO').kind, SubmissionKind.extraRepeated);
        expect(engine.state.extras, hasLength(1));
      }
    },
  );

  test(
    'difficulty grows across bands and all 500 fifth levels are lighter',
    () {
      final raw = jsonDecode(levelsText) as Map;
      final levels = raw['levels'] as List;
      final means = <double>[];
      var from = 0;
      for (final end in [100, 500, 1000, 1750, 2500]) {
        final band = levels.sublist(from, end);
        means.add(
          band.fold<int>(0, (n, l) => n + (l['difficultyScore'] as int)) /
              band.length,
        );
        from = end;
      }
      for (var i = 1; i < means.length; i++) {
        expect(means[i], greaterThan(means[i - 1]));
      }
      for (var i = 4; i < levels.length; i += 5) {
        expect(levels[i]['rest'], isTrue);
        for (var j = i - 4; j < i; j++) {
          expect(
            levels[i]['difficultyScore'],
            lessThan(levels[j]['difficultyScore'] as int),
          );
        }
      }
    },
  );

  test(
    'seven revised daily definitions remain valid and distinct across cycles',
    () {
      final text = File('assets/data/daily_levels.json').readAsStringSync();
      final data = GameData.parse(text, lexiconText);
      final daily = DailyCatalog(
        version: data.catalogVersion,
        baseDate: '2026-01-01',
        levels: data.levels,
        lexicon: data.lexicon,
      );
      expect(data.levels, hasLength(7));
      expect(data.levels.map(CatalogData.contentKey).toSet(), hasLength(7));
      for (var day = 1; day < 14; day++) {
        final a = DateTime(2026, 1, day).toIso8601String().substring(0, 10);
        final b = DateTime(2026, 1, day + 1).toIso8601String().substring(0, 10);
        expect(
          CatalogData.contentKey(daily.forDate(a)),
          isNot(CatalogData.contentKey(daily.forDate(b))),
        );
      }
    },
  );

  test('audit collects independent errors with file, level, word and rule', () {
    final root = jsonDecode(levelsText) as Map<String, dynamic>;
    root['levels'][1]['letters'] = ['G', 'A', 'T', 'A'];
    root['levels'][2]['words'].addAll(List.filled(5, {'display': 'GATO'}));
    root['levels'][3]['extraGoal'] = 9999;
    root['levels'][4]['words'][0]['display'] = 'A-TO';
    root['levels'][5]['words'][0]['display'] = 'A TO';
    final result = CatalogData.inspect(
      jsonEncode(root),
      lexiconText,
      levelsFile: 'invalid.json',
    );
    expect(
      result.issues.map((i) => i.level).toSet(),
      containsAll([2, 3, 4, 5, 6]),
    );
    expect(
      result.issues.where((i) => i.word == 'A-TO').single.toJson(),
      containsPair('file', 'invalid.json'),
    );
    expect(
      result.issues.any((i) => i.detail.contains('fichas insuficientes')),
      isTrue,
    );
    expect(
      result.issues.any((i) => i.detail.contains('três a seis respostas')),
      isTrue,
    );
    expect(
      result.issues.any((i) => i.detail.contains('meta de extras')),
      isTrue,
    );
  });

  test(
    'audit catches duplicate content even with reordered tiles and a different ID',
    () {
      final root = jsonDecode(levelsText) as Map<String, dynamic>;
      root['levels'][104] = {
        ...root['levels'][0],
        'id': 105,
        'letters': List.from(root['levels'][0]['letters']).reversed.toList(),
      };
      final result = CatalogData.inspect(jsonEncode(root), lexiconText);
      expect(
        result.issues.any(
          (i) => i.rule == 'duplicate_content' && i.level == 105,
        ),
        isTrue,
      );
      root['levels'][1] = {...root['levels'][0], 'id': 2};
      expect(
        CatalogData.inspect(
          jsonEncode(root),
          lexiconText,
        ).issues.any((i) => i.rule == 'rack_distance' && i.level == 2),
        isTrue,
      );
    },
  );

  test('accent collisions, missing clues and false scoring are rejected', () {
    final lex = jsonDecode(lexiconText) as Map;
    lex['words'].add({
      ...lex['words'].first,
      'display': 'AVÔ',
      'clue': 'Pai de um dos seus pais.',
    });
    lex['words'][0]['clue'] = '';
    final root = jsonDecode(levelsText) as Map;
    root['levels'][0]['difficultyScore'] = 999;
    final result = CatalogData.inspect(jsonEncode(root), jsonEncode(lex));
    expect(result.issues.any((i) => i.rule == 'collision'), isTrue);
    expect(
      result.issues.any(
        (i) => i.file == 'lexicon_pt_br.json' && i.detail.contains('Dica'),
      ),
      isTrue,
    );
    expect(result.issues.any((i) => i.rule == 'score'), isTrue);
  });

  test('repeated letters cannot be substituted by one tile', () {
    final level = LevelDefinition(
      id: 1,
      difficulty: 'teste',
      letters: ['A', 'C', 'O', 'R'],
      words: [WordEntry('AÇÃO'), WordEntry('ARO'), WordEntry('ORCA')],
    );
    expect(
      CatalogData.levelIssues(level, production.lexicon).any(
        (i) => i.word == 'AÇÃO' && i.detail.contains('fichas insuficientes'),
      ),
      isTrue,
    );
  });

  test(
    'new catalog SQLite round restores purchased clue without another debit',
    () async {
      final dir = await Directory.systemTemp.createTemp('expanded-round-');
      final location = '${dir.path}/progress.db';
      GameSessionCoordinator? session;
      Future<GameSessionCoordinator> open() async =>
          GameSessionCoordinator.create(
            production,
            await SqliteProgressRepository.open(
              factory: databaseFactoryFfi,
              databasePath: location,
              initialBalance: 200,
            ),
          );
      try {
        session = await open();
        await session.startOrContinue();
        final target = session.engine.state.level.words.first;
        await session.purchaseMascotHint(
          target.key,
          operationId: 'expanded-clue',
        );
        await session.shuffle();
        final balance = session.profile.balance,
            order = session.engine.state.order.toList(),
            roundId = session.profile.currentRound!.roundId;
        await session.close();
        session = await open();
        expect(session.profile.catalogIds, hasLength(2500));
        expect(session.profile.balance, balance);
        expect(session.profile.currentRound!.roundId, roundId);
        expect(session.engine.state.order, order);
        final result = await session.purchaseMascotHint(
          target.key,
          operationId: 'reread-clue',
        );
        expect(
          result.hint!.clue,
          target.clue ?? production.lexicon[target.key]!.clue,
        );
        expect(session.profile.balance, balance);
      } finally {
        await session?.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'real milestone levels unlock themes and final 2500 rewards only once',
    () async {
      // Boundary slices use actual shipped definitions; unrelated earlier progress
      // is omitted so this test concentrates on transitions and reward identity.
      for (final ids in [
        [49, 50],
        [99, 100],
        [2499, 2500],
      ]) {
        final slice = GameData(
          [for (final id in ids) production.levels[id - 1]],
          production.lexicon,
          catalogVersion: 2,
        );
        final session = await GameSessionCoordinator.create(
          slice,
          await SqliteProgressRepository.open(
            factory: databaseFactoryFfi,
            databasePath: inMemoryDatabasePath,
          ),
        );
        try {
          await session.startOrContinue();
          final before = session.profile.balance;
          for (final w in session.engine.state.level.words) {
            await session.submitWord(
              idsFor(session.engine, w.key),
              session: session.engine.state.session,
            );
          }
          expect(await session.advance(), isTrue);
          expect(session.profile.currentLevelId, ids.last);
          if (ids.last == 50) {
            expect(session.isThemeUnlocked('escola_magia'), isTrue);
          }
          if (ids.last == 100) {
            expect(session.isThemeUnlocked('refugio_neve'), isTrue);
          }
          for (final w in session.engine.state.level.words) {
            await session.submitWord(
              idsFor(session.engine, w.key),
              session: session.engine.state.session,
            );
          }
          expect(await session.advance(), isFalse);
          expect(session.profile.campaignComplete, isTrue);
          expect(session.profile.balance, before + 40);
          await session.startOrContinue();
          expect(session.profile.balance, before + 40);
        } finally {
          await session.close();
        }
      }
    },
  );

  test(
    'SQLite restores 2499 completed rounds and finishes the full catalog',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'full-campaign-history-',
      );
      final location = '${directory.path}/history.db';
      SqliteProgressRepository? repository;
      GameSessionCoordinator? session;
      try {
        repository = await SqliteProgressRepository.open(
          factory: databaseFactoryFfi,
          databasePath: location,
        );
        final initial = await repository.initialize(production);
        final engine = GameEngine(
          levels: production.levels,
          lexicon: production.lexicon,
        );
        final rounds = <int, RoundSnapshot>{};
        final completed = <int>{};
        for (final level in production.levels) {
          engine.startLevel(level.id);
          if (level.id < 2500) {
            for (final word in level.words) {
              submitWord(engine, word.key);
            }
            engine.finishCompletion(engine.state.session);
            completed.add(level.id);
          }
          rounds[level.id] = engine.snapshot('history-round-${level.id}');
        }
        final profile = initial.copyWith(
          currentLevelId: 2500,
          hasStarted: true,
          revision: 1,
          unlocked: production.levels.map((l) => l.id).toSet(),
          completed: completed,
          rounds: rounds,
          balance: 60 + 2499 * 20,
        );
        final payload = jsonEncode(profile.toPayload());
        await repository.database.transaction((txn) async {
          final batch = txn.batch();
          for (final id in completed) {
            batch.insert('coin_transactions', {
              'operation_id': 'level-completion:$id',
              'parent_operation_id': 'history-operation-$id',
              'profile_id': 'local',
              'kind': 'level_completion',
              'amount': 20,
              'level_id': id,
              'round_id': rounds[id]!.roundId,
              'metadata_json': jsonEncode({
                'request': {'mode': 'campaign'},
                'result': {'completed': true},
              }),
              'created_at': '2026-10-23T00:00:00.000Z',
            });
          }
          await batch.commit(noResult: true);
          await txn.update(
            'profiles',
            {
              'balance': profile.balance,
              'revision': 1,
              'payload_json': payload,
            },
            where: 'profile_id = ?',
            whereArgs: ['local'],
          );
        });
        await repository.close();
        repository = null;
        final watch = Stopwatch()..start();
        session = await GameSessionCoordinator.create(
          production,
          await SqliteProgressRepository.open(
            factory: databaseFactoryFfi,
            databasePath: location,
          ),
        );
        watch.stop();
        // A synthetic complete history exercises real SQLite validation at scale,
        // without pretending 2499 economic operations were played by a person.
        // ignore: avoid_print
        print(
          'FULL_HISTORY_LOAD_MS=${watch.elapsedMilliseconds}; PAYLOAD_BYTES=${utf8.encode(payload).length}',
        );
        expect(session.profile.rounds, hasLength(2500));
        expect(session.profile.currentLevelId, 2500);
        for (final word in session.engine.state.level.words) {
          await session.submitWord(
            idsFor(session.engine, word.key),
            session: session.engine.state.session,
          );
        }
        expect(session.profile.balance, 50060);
        await session.advance();
        expect(session.profile.campaignComplete, isTrue);
        await session.close();
        session = null;
        repository = await SqliteProgressRepository.open(
          factory: databaseFactoryFfi,
          databasePath: location,
        );
        final restored = await repository.load(production);
        expect(restored.campaignComplete, isTrue);
        expect(restored.balance, 50060);
        expect(
          await repository.database.query('coin_transactions'),
          hasLength(2501),
        );
      } finally {
        await session?.close();
        await repository?.close();
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
