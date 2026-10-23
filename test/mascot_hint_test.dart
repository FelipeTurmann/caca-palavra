import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:caca_palavra/features/game/application/campaign_models.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/daily_catalog.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'package:caca_palavra/features/game/domain/word_normalizer.dart';
import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String location;
  late SqliteProgressRepository repo;
  late GameSessionCoordinator c;
  late GameData data;
  var now = DateTime(2026, 10, 23, 12);

  Future<void> open({int balance = 140}) async {
    repo = await SqliteProgressRepository.open(
      factory: databaseFactoryFfi,
      databasePath: location,
      initialBalance: balance,
    );
    c = await GameSessionCoordinator.create(
      data,
      repo,
      now: () => now,
      dailyCatalog: DailyCatalog(
        version: 1,
        baseDate: '2026-01-01',
        levels: [data.levels.first],
        lexicon: data.lexicon,
      ),
    );
  }

  Future<void> reopen() async {
    await c.close();
    await open();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mascot-hints-');
    location = '${directory.path}/game.db';
    now = DateTime(2026, 10, 23, 12);
    data = loadData();
    await open();
    await c.startOrContinue();
  });
  tearDown(() async {
    await c.close();
    await directory.delete(recursive: true);
  });

  test(
    'all 61 local clues are short, complete and do not contain the answer',
    () {
      expect(data.lexicon, hasLength(61));
      for (final word in data.lexicon.values) {
        expect(word.clue, isNotNull);
        expect(word.clue!.length, inInclusiveRange(1, 120));
        expect(
          RegExp(
            '(^|[^A-Z])${word.key}([^A-Z]|\$)',
          ).hasMatch(WordNormalizer.normalizeClue(word.clue!)),
          false,
        );
      }
    },
  );

  test(
    'selected equal-length words retain different clues, no letters or progress',
    () async {
      final order = c.engine.state.order;
      final first = await c.purchaseMascotHint('GATO', operationId: 'cat');
      final second = await c.purchaseMascotHint('GOTA', operationId: 'drop');
      expect(first.hint!.clue, data.lexicon['GATO']!.clue);
      expect(second.hint!.clue, data.lexicon['GOTA']!.clue);
      expect(first.hint!.clue, isNot(second.hint!.clue));
      expect(c.profile.balance, 0);
      expect(c.engine.state.order, order);
      expect(c.engine.state.targets, isEmpty);
      expect(c.activeRound!.reveals, isEmpty);
      expect(c.activeRound!.superHints, isEmpty);
      final ledger = await repo.database.query('coin_transactions');
      expect(
        ledger
            .where((row) => row['kind'] == 'mascot_hint')
            .map((row) => row['amount']),
        [-70, -70],
      );
      await reopen();
      expect(c.profile.balance, 0);
      expect(
        (await c.purchaseMascotHint('GATO', operationId: 'reread')).status,
        'available',
      );
      expect(await repo.database.query('coin_transactions'), ledger);
    },
  );

  test('different operation IDs racing for one word charge once', () async {
    final results = await Future.wait(
      List.generate(
        8,
        (i) => c.purchaseMascotHint('GATO', operationId: 'race-$i'),
      ),
    );
    expect(results.where((r) => r.status == 'purchased'), hasLength(1));
    expect(results.map((r) => r.hint!.operationId).toSet(), hasLength(1));
    expect(c.profile.balance, 70);
    expect(c.activeRound!.mascotHints, hasLength(1));
    expect(await repo.database.query('coin_transactions'), hasLength(2));
  });

  test(
    'receipt retry is free and rejects a different target or round',
    () async {
      final first = await c.purchaseMascotHint('GATO', operationId: 'same');
      final again = await c.purchaseMascotHint('GATO', operationId: 'same');
      expect(again.hint!.toJson(), first.hint!.toJson());
      expect(c.profile.balance, 70);
      await expectLater(
        c.purchaseMascotHint('GOTA', operationId: 'same'),
        throwsA(isA<OperationMismatch>()),
      );
      await c.startDaily();
      await expectLater(
        c.purchaseMascotHint('GATO', operationId: 'same'),
        throwsA(isA<OperationMismatch>()),
      );
    },
  );

  test(
    '69 cannot buy; exactly 70 can and zero can reread a resolved line',
    () async {
      await c.close();
      await databaseFactoryFfi.deleteDatabase(location);
      await open(balance: 69);
      await c.startOrContinue();
      expect(
        (await c.purchaseMascotHint('GATO', operationId: 'no')).status,
        'insufficient',
      );
      expect(c.profile.balance, 69);
      expect(await repo.pending(), isEmpty);
      await c.close();
      await databaseFactoryFfi.deleteDatabase(location);
      await open(balance: 70);
      await c.startOrContinue();
      await c.purchaseMascotHint('GATO', operationId: 'yes');
      expect(c.profile.balance, 0);
      await c.submitWord(
        idsFor(c.engine, 'GATO'),
        session: c.engine.state.session,
      );
      expect(
        (await c.purchaseMascotHint('GATO', operationId: 'free')).status,
        'available',
      );
      await c.submitWord(
        idsFor(c.engine, 'GOTA'),
        session: c.engine.state.session,
      );
      expect(
        (await c.purchaseMascotHint('GOTA', operationId: 'resolved')).status,
        'resolved',
      );
      expect(
        (await c.purchaseMascotHint('TOGA', operationId: 'extra')).status,
        'inactive',
      );
      expect(c.profile.balance, 0);
    },
  );

  test(
    'campaign and daily purchases are independent and survive reopen',
    () async {
      await c.purchaseMascotHint('GATO', operationId: 'campaign');
      await c.startDaily();
      expect(c.mascotHintFor('GATO'), isNull);
      await c.purchaseMascotHint('GATO', operationId: 'daily');
      expect(c.profile.balance, 0);
      await reopen();
      await c.startDaily();
      expect(
        (await c.purchaseMascotHint('GATO', operationId: 'daily-free')).status,
        'available',
      );
      await c.startOrContinue();
      expect(
        (await c.purchaseMascotHint(
          'GATO',
          operationId: 'campaign-free',
        )).status,
        'available',
      );
      expect(c.profile.balance, 0);
    },
  );

  test('paid text is frozen across catalog updates', () async {
    final old = (await c.purchaseMascotHint(
      'GATO',
      operationId: 'frozen',
    )).hint!;
    await c.close();
    final words = {...data.lexicon};
    words.remove('GATO');
    data = GameData(data.levels, words);
    await open();
    expect(c.mascotHintFor('GATO')!.clue, old.clue);
    expect(
      (await c.purchaseMascotHint('GATO', operationId: 'read')).hint!.clue,
      old.clue,
    );
  });

  test(
    'legacy daily without clue metadata uses the local compatible catalog',
    () async {
      await c.startDaily();
      final row = (await repo.database.query('profiles')).single;
      final payload =
          jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
      payload['daily']['2026-10-23'].remove('clues');
      await repo.database.update('profiles', {
        'payload_json': jsonEncode(payload),
      });
      await reopen();
      await c.startDaily();
      expect(c.activeDay!.hasClueCatalog, false);
      expect(
        (await c.purchaseMascotHint(
          'GATO',
          operationId: 'legacy-daily',
        )).hint!.clue,
        data.lexicon['GATO']!.clue,
      );
      expect(c.profile.balance, 70);
    },
  );

  test(
    'missing catalog clue never charges and a finished round cannot buy',
    () async {
      await c.close();
      final words = {...data.lexicon}..remove('GATO');
      data = GameData(data.levels, words);
      await open();
      expect(
        (await c.purchaseMascotHint('GATO', operationId: 'missing')).status,
        'unavailable',
      );
      expect(c.profile.balance, 140);
      expect(await repo.database.query('coin_transactions'), hasLength(1));
    },
  );

  for (final point in [
    StorageFaultPoint.afterLedgerEntry,
    StorageFaultPoint.beforeCommit,
  ]) {
    test(
      'rollback at ${point.name} preserves balance, restart grants exact prepared clue once',
      () async {
        final before = c.profile.toPayload();
        repo.fault = (p) {
          if (p == point) throw StateError('disk failure');
        };
        await expectLater(
          c.purchaseMascotHint('GATO', operationId: 'recover'),
          throwsStateError,
        );
        expect(c.profile.balance, 140);
        expect(c.profile.toPayload(), before);
        expect(await repo.database.query('coin_transactions'), hasLength(1));
        final saved = (await repo.pending()).single.result['hint'];
        await reopen();
        expect(c.profile.balance, 70);
        expect(c.mascotHintFor('GATO')!.toJson(), saved);
        expect(await repo.pending(), isEmpty);
        expect(await repo.database.query('coin_transactions'), hasLength(2));
      },
    );
  }

  test(
    'lost commit response recovers the receipt without a second debit',
    () async {
      repo.fault = (p) {
        if (p == StorageFaultPoint.afterCommit) throw StateError('lost ack');
      };
      final outcome = await c.purchaseMascotHint('GATO', operationId: 'lost');
      expect(outcome.status, 'purchased');
      expect(c.profile.balance, 70);
      repo.fault = null;
      await c.purchaseMascotHint('GATO', operationId: 'lost');
      expect(await repo.database.query('coin_transactions'), hasLength(2));
    },
  );

  test(
    'expired daily rejects confirmation and discards an uncommitted purchase at restart',
    () async {
      await c.startDaily();
      final expected = c.context;
      repo.fault = (p) {
        if (p == StorageFaultPoint.beforeCommit) throw StateError('stop');
      };
      await expectLater(
        c.purchaseMascotHint(
          'GATO',
          operationId: 'expired',
          expected: expected,
        ),
        throwsStateError,
      );
      now = now.add(const Duration(days: 1));
      await reopen();
      await c.startDaily();
      expect(c.profile.balance, 140);
      expect(c.mascotHintFor('GATO'), isNull);
      expect(await repo.pending(), isEmpty);
      await expectLater(
        c.purchaseMascotHint('GATO', operationId: 'stale', expected: expected),
        throwsStateError,
      );
      expect(c.profile.balance, 140);
    },
  );

  test(
    'legacy 30/100 paid receipts and prepared hints coexist with new 50/120 prices',
    () async {
      // Prepare a real legacy hint and leave it pending across an application update.
      final round = c.activeRound!;
      final engine = c.engine.fork(round);
      final reveal = engine.revealPaidHint('legacy-30')!;
      final proposed = c.profile.copyWith(
        balance: 110,
        revision: c.profile.revision + 1,
        rounds: {
          ...c.profile.rounds,
          round.levelId: engine.snapshot(round.roundId),
        },
      );
      final legacy = SaveProposal(
        id: 'legacy-30',
        expectedRevision: c.profile.revision,
        request: {
          'kind': 'paid_hint',
          'mode': 'campaign',
          'roundId': round.roundId,
          'levelId': round.levelId,
          'price': 30,
        },
        profile: proposed,
        result: {'kind': 'hint', 'reveal': revealJson(reveal)},
        coins: [
          CoinOperation(
            id: 'legacy-30',
            kind: 'paid_hint',
            amount: -30,
            levelId: round.levelId,
            roundId: round.roundId,
          ),
        ],
      );
      await repo.prepare(legacy);
      await reopen();
      expect(c.profile.balance, 110);
      await c.purchaseHint(operationId: 'legacy-30');
      expect(c.profile.balance, 110);
      final superEngine = c.engine.fork(c.activeRound!);
      final result = superEngine.resolveSuperHint('legacy-100');
      final resolution = superEngine.state.superHints.last;
      final legacySuper = SaveProposal(
        id: 'legacy-100',
        expectedRevision: c.profile.revision,
        request: {
          'kind': 'super_hint',
          'mode': 'campaign',
          'roundId': round.roundId,
          'levelId': round.levelId,
          'price': 100,
        },
        profile: c.profile.copyWith(
          balance: 10,
          revision: c.profile.revision + 1,
          rounds: {
            ...c.profile.rounds,
            round.levelId: superEngine.snapshot(round.roundId),
          },
        ),
        result: {
          ...submissionJson(result),
          'kind': 'super_hint',
          'targetKey': resolution.targetKey,
          'indices': resolution.indices,
        },
        coins: [
          CoinOperation(
            id: 'legacy-100:debit',
            kind: 'super_hint',
            amount: -100,
            levelId: round.levelId,
            roundId: round.roundId,
          ),
        ],
      );
      await repo.prepare(legacySuper);
      await repo.commit(legacySuper, data);
      await reopen();
      expect(c.profile.balance, 10);
      await c.purchaseSuperHint(operationId: 'legacy-100');
      expect(c.profile.balance, 10);
      expect((await c.purchaseHint()).status, 'insufficient');
      expect(Economy.hintPrice, 50);
      expect(Economy.superHintPrice, 120);
      expect(Economy.confirmedPrice({'kind': 'paid_hint', 'price': 30}), 30);
      expect(
        () => Economy.confirmedPrice({
          'kind': 'paid_hint',
          'price': 30,
          'pricingVersion': 2,
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'purchased clue without matching ledger metadata is rejected without clearing the profile',
    () async {
      await c.purchaseMascotHint('GATO', operationId: 'original');
      final row = (await repo.database.query('profiles')).single;
      final payload =
          jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
      payload['levels']['1']['mascotHints'][0]['clue'] = 'Texto adulterado.';
      await repo.database.update('profiles', {
        'payload_json': jsonEncode(payload),
      });
      await expectLater(repo.load(data), throwsFormatException);
      expect((await repo.database.query('profiles')).single['balance'], 70);
    },
  );
}
