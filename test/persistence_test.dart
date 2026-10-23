import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:caca_palavra/features/game/application/campaign_models.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';
import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String location;
  late SqliteProgressRepository repo;
  late GameSessionCoordinator c;
  late GameData data;
  Future<void> open({GameData? catalog, int welcome = 60}) async {
    repo = await SqliteProgressRepository.open(
      factory: databaseFactoryFfi,
      databasePath: location,
      initialBalance: welcome,
    );
    c = await GameSessionCoordinator.create(
      catalog ?? data,
      repo,
      random: Random(7),
    );
  }

  Future<SubmissionResult> word(String value) =>
      c.submitWord(idsFor(c.engine, value), session: c.engine.state.session);
  Future<void> resetBalance(int balance) async {
    await c.close();
    await databaseFactoryFfi.deleteDatabase(location);
    await open(welcome: balance);
  }

  Future<void> finish() async {
    for (final target in c.engine.state.level.words) {
      await word(target.key);
    }
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('word-game-test-');
    location = '${directory.path}/progress.db';
    data = loadData();
    await open();
  });
  tearDown(() async {
    await c.close();
    await directory.delete(recursive: true);
  });

  test(
    'welcome is once, authoritative balance not duplicated in payload',
    () async {
      expect(c.profile.balance, 60);
      expect(c.profile.toPayload().containsKey('balance'), false);
      await c.close();
      await open(welcome: 999);
      expect(c.profile.balance, 60);
      expect(await repo.database.query('coin_transactions'), hasLength(1));
    },
  );
  test(
    'target, extra origin, shuffle and round survive reopening without events',
    () async {
      await c.startOrContinue();
      final id = c.profile.currentRound!.roundId;
      await word('GATO');
      await word('TOGA');
      await c.shuffle();
      final saved = canonicalJson(c.profile.toPayload());
      final order = c.engine.state.order;
      await c.close();
      await open();
      expect(canonicalJson(c.profile.toPayload()), saved);
      expect(c.engine.state.order, order);
      expect(c.profile.currentRound!.roundId, id);
      expect(c.profile.currentRound!.freeHints, 1);
      expect(c.engine.state.extras.keys, ['TOGA']);
      expect(c.engine.state.targets, {'GATO'});
      final repeat = await word('TOGA');
      expect(repeat.kind, SubmissionKind.extraRepeated);
      expect(c.profile.currentRound!.freeHints, 1);
    },
  );
  test(
    'two paid hints, duplicate retry at zero, mismatched ID rejected',
    () async {
      await resetBalance(100);
      await c.startOrContinue();
      final first = await c.purchaseHint(operationId: 'hint-1');
      await c.purchaseHint(operationId: 'hint-2');
      expect(c.profile.balance, 0);
      final duplicate = await c.purchaseHint(operationId: 'hint-1');
      expect(revealJson(duplicate.reveal), revealJson(first.reveal));
      expect(c.profile.balance, 0);
      expect(c.profile.currentRound!.paidHints, 2);
      expect((await c.purchaseHint()).status, 'insufficient');
      await expectLater(
        c.purchaseHint(operationId: 'hint-1', roundId: 'other'),
        throwsA(isA<OperationMismatch>()),
      );
      expect(await repo.database.query('coin_transactions'), hasLength(3));
    },
  );
  test('parallel purchases are serialized and never overspend', () async {
    await resetBalance(100);
    await c.startOrContinue();
    final results = await Future.wait(
      List.generate(5, (i) => c.purchaseHint(operationId: 'parallel-$i')),
    );
    expect(results.where((r) => r.status == 'purchased'), hasLength(2));
    expect(c.profile.balance, 0);
    expect(c.profile.currentRound!.paidHints, 2);
  });
  test('double confirmation with same ID reveals and charges once', () async {
    await c.startOrContinue();
    final results = await Future.wait([
      c.purchaseHint(operationId: 'same'),
      c.purchaseHint(operationId: 'same'),
    ]);
    expect(revealJson(results[0].reveal), revealJson(results[1].reveal));
    expect(c.profile.balance, 10);
    expect(c.profile.currentRound!.paidHints, 1);
  });
  for (final point in StorageFaultPoint.values.where(
    (p) => p != StorageFaultPoint.afterCommit,
  )) {
    test('rollback at ${point.name}; retry uses same ID and letter', () async {
      await c.startOrContinue();
      repo.fault = (p) {
        if (p == point) throw StateError('injected');
      };
      await expectLater(
        c.purchaseHint(operationId: 'rollback'),
        throwsStateError,
      );
      expect(c.profile.balance, 60);
      expect(c.engine.state.revealedLetters, isEmpty);
      expect((await repo.load(data)).balance, 60);
      expect(await repo.database.query('coin_transactions'), hasLength(1));
      final prepared = (await repo.pending()).single;
      final reveal = prepared.result['reveal'];
      repo.fault = null;
      await c.retry();
      expect(c.profile.balance, 10);
      expect(
        (await repo.resolveOperation('rollback'))!.result['reveal'],
        reveal,
      );
      expect(c.profile.currentRound!.paidHints, 1);
    });
  }
  test(
    'commit confirmation lost resolves receipt without duplicate debit',
    () async {
      await c.startOrContinue();
      repo.fault = (point) {
        if (point == StorageFaultPoint.afterCommit) {
          throw StateError('lost ack');
        }
      };
      final result = await c.purchaseHint(operationId: 'lost');
      expect(result.status, 'purchased');
      expect(c.profile.balance, 10);
      repo.fault = null;
      await c.purchaseHint(operationId: 'lost');
      expect(c.profile.balance, 10);
      expect(await repo.database.query('coin_transactions'), hasLength(2));
    },
  );
  test(
    'process restart resumes prepared hint with exact proposed letter',
    () async {
      await c.startOrContinue();
      repo.fault = (p) {
        if (p == StorageFaultPoint.beforeCommit) throw StateError('stop');
      };
      await expectLater(
        c.purchaseHint(operationId: 'restart'),
        throwsStateError,
      );
      final saved = (await repo.pending()).single.result['reveal'];
      await c.close();
      await open();
      expect(c.profile.balance, 10);
      expect((await repo.resolveOperation('restart'))!.result['reveal'], saved);
      expect(await repo.pending(), isEmpty);
    },
  );
  test(
    'last target completion reward unlock and pending result are atomic',
    () async {
      await c.startOrContinue();
      await word('GATO');
      await word('GOTA');
      repo.fault = (p) {
        if (p == StorageFaultPoint.afterLedger) throw StateError('stop');
      };
      await expectLater(word('ATO'), throwsStateError);
      expect(c.profile.balance, 60);
      expect(c.profile.completed, isEmpty);
      expect((await repo.load(data)).pendingCompletion, isNull);
      repo.fault = null;
      await c.retry();
      expect(c.profile.balance, 80);
      expect(c.profile.unlocked, {1, 2});
      expect(c.profile.pendingCompletion!.reward, 20);
      await c.close();
      await open();
      expect(c.freshCompletion, false);
      expect(c.engine.state.phase, RoundPhase.completed);
      await c.startOrContinue();
      expect(c.profile.balance, 80);
      final next = await Future.wait([c.advance(), c.advance()]);
      expect(next.where((v) => v), hasLength(1));
      expect(c.profile.currentLevelId, 2);
      expect(c.profile.balance, 80);
      expect(await repo.database.query('coin_transactions'), hasLength(2));
    },
  );
  test(
    'all catalog levels yield 260 and final acknowledgment preserves campaign',
    () async {
      await c.startOrContinue();
      for (final level in data.levels) {
        expect(c.profile.currentLevelId, level.id);
        await finish();
        await c.advance();
      }
      expect(c.profile.balance, 260);
      expect(c.profile.campaignComplete, true);
      expect(c.profile.rounds, hasLength(10));
      await c.close();
      await open();
      expect(c.profile.campaignComplete, true);
      expect(c.profile.balance, 260);
      await c.startOrContinue();
      expect(c.profile.currentLevelId, data.levels.last.id);
      expect(await repo.database.query('coin_transactions'), hasLength(11));
    },
  );
  test(
    'append catalog preserves completion IDs, balance and unlocks next',
    () async {
      final small = GameData(data.levels.take(1).toList(), data.lexicon);
      await c.close();
      await databaseFactoryFfi.deleteDatabase(location);
      await open(catalog: small);
      await c.startOrContinue();
      await finish();
      await c.advance();
      await c.close();
      await open();
      expect(c.profile.currentLevelId, 2);
      expect(c.profile.balance, 80);
      expect(c.profile.completed, {1});
      expect(c.profile.unlocked, {1, 2});
    },
  );
  test(
    'malformed save fails without recreating welcome or clearing data',
    () async {
      final row = (await repo.database.query('profiles')).single;
      final payload =
          jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
      payload['schemaVersion'] = 999;
      await repo.database.update('profiles', {
        'payload_json': jsonEncode(payload),
      });
      await expectLater(repo.initialize(data), throwsFormatException);
      expect(await repo.database.query('coin_transactions'), hasLength(1));
      expect(
        (await repo.database.query('profiles')).single['payload_json'],
        jsonEncode(payload),
      );
    },
  );
  test('fingerprint changes fail restoration and preserve database', () async {
    await c.startOrContinue();
    final first = data.levels.first;
    final changed = LevelDefinition(
      id: first.id,
      difficulty: first.difficulty,
      letters: first.letters.reversed.toList(),
      words: first.words,
      extraGoal: first.extraGoal,
    );
    await expectLater(
      repo.load(GameData([changed, ...data.levels.skip(1)], data.lexicon)),
      throwsFormatException,
    );
    expect((await repo.load(data)).balance, 60);
  });
  test('SQLite v1 migration preserves welcome and profile', () async {
    await repo.database.execute('DROP TABLE operation_requests');
    await repo.database.setVersion(1);
    await c.close();
    await open();
    expect(await repo.database.getVersion(), LocalGameDatabase.version);
    expect(c.profile.balance, 60);
    expect(await repo.pending(), isEmpty);
    expect(await repo.database.query('coin_transactions'), hasLength(1));
  });
  test(
    '50 coins allow only one concurrent distinct purchase; 49 cannot buy',
    () async {
      await c.close();
      await databaseFactoryFfi.deleteDatabase(location);
      await open(welcome: 50);
      await c.startOrContinue();
      final result = await Future.wait([
        c.purchaseHint(operationId: 'a'),
        c.purchaseHint(operationId: 'b'),
      ]);
      expect(result.map((r) => r.status).toList(), [
        'purchased',
        'insufficient',
      ]);
      expect(c.profile.balance, 0);
      await c.close();
      await databaseFactoryFfi.deleteDatabase(location);
      await open(welcome: 49);
      await c.startOrContinue();
      expect((await c.purchaseHint()).status, 'insufficient');
      expect(c.profile.balance, 49);
      expect(c.profile.currentRound!.reveals, isEmpty);
    },
  );
  test(
    'paid and free reveals share positions, skip found words and complete the round',
    () async {
      await c.close();
      await databaseFactoryFfi.deleteDatabase(location);
      await open(welcome: 999);
      await c.startOrContinue();
      await word('GATO');
      final paid = await c.purchaseHint(operationId: 'first');
      expect(paid.reveal!.targetKey, isNot('GATO'));
      await word('TOGA');
      expect(c.profile.balance, 959);
      while ((await c.purchaseHint()).status == 'purchased') {}
      final saved = c.profile.balance;
      expect((await c.purchaseHint()).status, 'unavailable');
      expect(c.profile.balance, saved);
      final records = c.profile.currentRound!.reveals;
      expect(
        records.map((r) => '${r.targetKey}:${r.index}').toSet(),
        hasLength(records.length),
      );
      expect(c.engine.state.revealedLetters['GATO'], isNull);
      expect(c.engine.state.revealedLetters['GOTA'], hasLength(4));
      expect(c.engine.state.revealedLetters['ATO'], hasLength(3));
      expect(c.profile.completed, {1});
    },
  );
  test(
    'competing coordinators detect stale revision and cannot overwrite confirmed wallet',
    () async {
      await resetBalance(100);
      await c.startOrContinue();
      final secondRepo = await SqliteProgressRepository.open(
        factory: databaseFactoryFfi,
        databasePath: location,
      );
      final second = await GameSessionCoordinator.create(data, secondRepo);
      try {
        await c.purchaseHint(operationId: 'one');
        await expectLater(
          second.purchaseHint(operationId: 'two'),
          throwsA(isA<RevisionConflict>()),
        );
        expect(second.profile.balance, 50);
        expect(second.profile.currentRound!.paidHints, 1);
        expect(await secondRepo.pending(), isEmpty);
        await second.purchaseHint(operationId: 'three');
        expect(second.profile.balance, 0);
      } finally {
        await second.close();
      }
    },
  );
  test('concurrent final submissions credit once', () async {
    await c.startOrContinue();
    await word('GATO');
    await word('GOTA');
    final ids = idsFor(c.engine, 'ATO');
    final session = c.engine.state.session;
    final result = await Future.wait([
      c.submitWord(ids, session: session),
      c.submitWord(ids, session: session),
    ]);
    expect(result.where((r) => r.completed), hasLength(1));
    expect(c.profile.balance, 80);
    expect(await repo.database.query('coin_transactions'), hasLength(2));
  });
  test(
    'catalog appended while last result is pending keeps reward and allows next',
    () async {
      await c.close();
      await databaseFactoryFfi.deleteDatabase(location);
      await open(catalog: GameData(data.levels.take(1).toList(), data.lexicon));
      await c.startOrContinue();
      await finish();
      await c.close();
      await open();
      expect(c.profile.currentLevelId, 1);
      expect(c.profile.pendingCompletion?.levelId, 1);
      expect(c.profile.unlocked, {1, 2});
      expect(c.profile.balance, 80);
      expect(await c.advance(), true);
      expect(c.profile.currentLevelId, 2);
    },
  );
  test(
    'Explorer threshold pays 10 once and survives repeat, shuffle, completion and reopen',
    () async {
      await c.startOrContinue();
      final earned = await word('TOGA');
      expect(earned.explorerUnlocked, true);
      expect(c.profile.balance, 70);
      expect(c.profile.explorerRewardedLevels, {1});
      final reveal = revealJson(earned.revealedLetter);
      await word('TOGA');
      await c.shuffle();
      expect(c.profile.balance, 70);
      await c.close();
      await open();
      expect(c.profile.balance, 70);
      expect(c.profile.explorerRewardedLevels, {1});
      expect(c.profile.currentRound!.freeHints, 1);
      expect(
        (await repo.resolveOperation('explorer-reward:1'))!.result['reveal'],
        reveal,
      );
      await finish();
      expect(c.profile.balance, 90);
      await c.advance();
      final targetKeys = c.engine.state.level.words.map((w) => w.key).toSet();
      final extras = c.data.lexicon.keys
          .where(
            (k) => !targetKeys.contains(k) && c.engine.state.level.canForm(k),
          )
          .toList();
      expect(c.engine.state.level.extraGoal, 2);
      expect((await word(extras[0])).explorerUnlocked, false);
      expect(c.profile.balance, 90);
      expect((await word(extras[1])).explorerUnlocked, true);
      expect(c.profile.balance, 100);
      for (final extra in extras.skip(2)) {
        await word(extra);
      }
      expect(c.profile.balance, 100);
      expect(c.profile.explorerRewardedLevels, {1, 2});
      expect(
        await repo.database.query(
          'coin_transactions',
          where: 'kind = ?',
          whereArgs: ['explorer_reward'],
        ),
        hasLength(2),
      );
    },
  );
  for (final point in StorageFaultPoint.values.where(
    (p) => p != StorageFaultPoint.afterCommit,
  )) {
    test(
      'Explorer reward rollback at ${point.name} resumes exact extra and reveal after reopen',
      () async {
        await c.startOrContinue();
        repo.fault = (p) {
          if (p == point) {
            throw StateError('injected explorer fault');
          }
        };
        await expectLater(word('TOGA'), throwsStateError);
        expect(c.profile.balance, 60);
        expect(c.engine.state.explorerUnlocked, false);
        expect(c.engine.state.revealedLetters, isEmpty);
        expect(c.profile.explorerRewardedLevels, isEmpty);
        expect((await repo.load(data)).balance, 60);
        expect(await repo.database.query('coin_transactions'), hasLength(1));
        final proposal = (await repo.pending()).single;
        final reveal = proposal.result['reveal'];
        await c.close();
        await open();
        expect(c.profile.balance, 70);
        expect(c.engine.state.explorerUnlocked, true);
        expect(c.profile.explorerRewardedLevels, {1});
        expect(
          (await repo.resolveOperation(proposal.id))!.result['reveal'],
          reveal,
        );
        await word('TOGA');
        expect(c.profile.balance, 70);
        expect(await repo.database.query('coin_transactions'), hasLength(2));
      },
    );
  }
  test(
    'Explorer lost commit confirmation and concurrent submissions grant only one reward',
    () async {
      await c.startOrContinue();
      repo.fault = (p) {
        if (p == StorageFaultPoint.afterCommit) {
          throw StateError('lost explorer receipt');
        }
      };
      final ids = idsFor(c.engine, 'TOGA');
      final session = c.engine.state.session;
      final results = await Future.wait([
        c.submitWord(ids, session: session),
        c.submitWord(ids, session: session),
      ]);
      expect(results.where((r) => r.explorerUnlocked), hasLength(1));
      expect(c.profile.balance, 70);
      expect(c.profile.explorerRewardedLevels, {1});
      repo.fault = null;
      await c.close();
      await open();
      expect(c.profile.balance, 70);
      expect(await repo.database.query('coin_transactions'), hasLength(2));
    },
  );
  test(
    'legacy visual badge loads without retroactive credit; next level can earn reward',
    () async {
      await c.startOrContinue();
      final round = c.profile.currentRound!;
      final legacyEngine = c.engine.fork(round);
      submitWord(legacyEngine, 'TOGA');
      final legacy = c.profile.copyWith(
        rounds: {1: legacyEngine.snapshot(round.roundId)},
        revision: c.profile.revision + 1,
      );
      final payload = legacy.toPayload()..remove('explorerRewardedLevelIds');
      await repo.database.update('profiles', {
        'revision': legacy.revision,
        'payload_json': canonicalJson(payload),
      });
      await c.close();
      await open();
      expect(c.profile.balance, 60);
      expect(c.engine.state.explorerUnlocked, true);
      expect(c.profile.explorerRewardedLevels, isEmpty);
      await word('TOGA');
      expect(c.profile.balance, 60);
      await finish();
      await c.advance();
      final targets = c.engine.state.level.words.map((w) => w.key).toSet();
      final extras = c.data.lexicon.keys
          .where((k) => !targets.contains(k) && c.engine.state.level.canForm(k))
          .take(c.engine.state.level.extraGoal)
          .toList();
      for (final extra in extras) {
        await word(extra);
      }
      expect(c.profile.balance, 90);
      expect(c.profile.explorerRewardedLevels, {2});
    },
  );
  test(
    'prepared legacy operation resumes without changing original economy or random letter',
    () async {
      await c.startOrContinue();
      final round = c.profile.currentRound!;
      final candidate = c.engine.fork(round);
      final result = submitWord(candidate, 'TOGA');
      final proposal = SaveProposal(
        id: 'legacy-word',
        expectedRevision: c.profile.revision,
        request: {
          'kind': 'word',
          'roundId': round.roundId,
          'levelId': 1,
          'ids': idsFor(c.engine, 'TOGA'),
        },
        profile: c.profile.copyWith(
          rounds: {1: candidate.snapshot(round.roundId)},
          revision: c.profile.revision + 1,
        ),
        result: submissionJson(result),
      );
      final serialized = proposal.toJson();
      (serialized['payload'] as Map).remove('explorerRewardedLevelIds');
      await repo.database.insert('operation_requests', {
        'operation_id': proposal.id,
        'request_json': canonicalJson(proposal.request),
        'proposal_json': canonicalJson(serialized),
        'committed': 0,
      });
      await c.close();
      await open();
      expect(c.profile.balance, 60);
      expect(c.profile.explorerRewardedLevels, isEmpty);
      expect(c.engine.state.explorerUnlocked, true);
      expect(
        (await repo.resolveOperation(proposal.id))!.result['reveal'],
        revealJson(result.revealedLetter),
      );
      expect(await repo.pending(), isEmpty);
    },
  );
  test(
    'reward marker without ledger is rejected without resetting wallet',
    () async {
      await c.startOrContinue();
      await word('TOGA');
      await repo.database.delete(
        'coin_transactions',
        where: 'kind = ?',
        whereArgs: ['explorer_reward'],
      );
      await repo.database.update('profiles', {'balance': 60});
      await expectLater(repo.load(data), throwsFormatException);
      expect((await repo.database.query('profiles')).single['balance'], 60);
    },
  );
  test(
    'all ten new Explorer badges add 100 coins to completed campaign',
    () async {
      await c.startOrContinue();
      for (final level in c.data.levels) {
        final targets = level.words.map((w) => w.key).toSet();
        final extras = c.data.lexicon.keys
            .where((k) => !targets.contains(k) && level.canForm(k))
            .take(level.extraGoal)
            .toList();
        for (final extra in extras) {
          await word(extra);
        }
        await finish();
        await c.advance();
      }
      expect(c.profile.balance, 360);
      expect(c.profile.explorerRewardedLevels, hasLength(10));
      await c.close();
      await open();
      expect(c.profile.balance, 360);
      expect(
        await repo.database.query(
          'coin_transactions',
          where: 'kind = ?',
          whereArgs: ['explorer_reward'],
        ),
        hasLength(10),
      );
    },
  );
  test(
    'finished rounds reject extras without issuing a new Explorer bonus',
    () async {
      await c.close();
      await databaseFactoryFfi.deleteDatabase(location);
      await open(welcome: 999);
      await c.startOrContinue();
      while ((await c.purchaseHint()).status == 'purchased') {}
      final balance = c.profile.balance;
      final result = await word('TOGA');
      expect(result.revealedLetter, isNull);
      expect(result.kind, SubmissionKind.ignored);
      expect(result.explorerUnlocked, false);
      expect(c.profile.balance, balance);
      expect(c.profile.explorerRewardedLevels, isEmpty);
    },
  );
}
