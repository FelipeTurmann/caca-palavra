import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:caca_palavra/features/game/application/campaign_models.dart';
import 'package:caca_palavra/features/game/application/daily_models.dart';
import 'package:caca_palavra/features/game/application/shop_models.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/daily_catalog.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';
import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late String location;
  late SqliteProgressRepository repo;
  late GameSessionCoordinator c;
  late DateTime time;
  late GameData data;
  Future<void> open({int balance = 60, DailyCatalog? catalog}) async {
    repo = await SqliteProgressRepository.open(
      factory: databaseFactoryFfi,
      databasePath: location,
      initialBalance: balance,
    );
    try {
      c = await GameSessionCoordinator.create(
        data,
        repo,
        now: () => time,
        dailyCatalog: catalog,
        random: Random(3),
      );
    } catch (_) {
      await repo.close();
      rethrow;
    }
  }

  Future<void> reset(int balance) async {
    await c.close();
    await databaseFactoryFfi.deleteDatabase(location);
    await open(balance: balance);
  }

  Future<SubmissionResult> word(String key) =>
      c.submitWord(idsFor(c.engine, key), session: c.engine.state.session);
  Future<void> finish() async {
    for (final w in c.engine.state.level.words) {
      if (!c.engine.state.targets.contains(w.key)) await word(w.key);
    }
  }

  Future<void> leaveLast() async {
    for (final w in c.engine.state.level.words.take(
      c.engine.state.level.words.length - 1,
    )) {
      await word(w.key);
    }
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('stage4-');
    location = '${dir.path}/game.db';
    data = loadData();
    time = DateTime(2026, 1, 1, 12);
    await open();
  });
  tearDown(() async {
    await c.close();
    await dir.delete(recursive: true);
  });

  for (final package in ShopCatalog.packages) {
    test(
      'simulated ${package.id} credits configured amount once per order',
      () async {
        final result = await c.simulatePurchase(package.id, id: 'order');
        expect(c.profile.balance, 60 + package.amount);
        expect(result['simulated'], true);
        expect(result['source'], 'simulated_purchase');
        await c.simulatePurchase(package.id, id: 'order');
        expect(c.profile.balance, 60 + package.amount);
        await c.simulatePurchase(package.id, id: 'order-2');
        expect(c.profile.balance, 60 + package.amount * 2);
        await expectLater(
          c.simulatePurchase(
            ShopCatalog.packages.firstWhere((p) => p.id != package.id).id,
            id: 'order',
          ),
          throwsA(isA<OperationMismatch>()),
        );
        await c.close();
        await open();
        expect(c.profile.balance, 60 + package.amount * 2);
      },
    );
  }
  test(
    'simulated ad coalesces concurrent taps but allows later intentional uses',
    () async {
      final results = await Future.wait(
        List.generate(10, (_) => c.simulateAd()),
      );
      expect(c.profile.balance, 75);
      expect(results.map((r) => r['orderId']).toSet(), hasLength(1));
      await c.simulateAd(id: 'next');
      expect(c.profile.balance, 90);
      await c.close();
      await open();
      expect(c.profile.balance, 90);
    },
  );
  test(
    'shop leaves campaign and daily snapshots untouched and shares wallet',
    () async {
      await c.startOrContinue();
      await word('GATO');
      final campaign = canonicalJson(c.profile.currentRound!.toJson());
      await c.startDaily();
      await word('TOGA');
      final daily = canonicalJson(c.activeRound!.toJson());
      await c.simulatePurchase('coins_500');
      await c.simulateAd();
      expect(c.profile.balance, 575);
      expect(canonicalJson(c.activeRound!.toJson()), daily);
      expect(canonicalJson(c.profile.currentRound!.toJson()), campaign);
      await c.startOrContinue();
      expect(c.engine.state.targets, {'GATO'});
      expect(c.profile.balance, 575);
    },
  );
  test(
    'Super Dica 100 to zero records one use and full assisted resolution',
    () async {
      await reset(100);
      await c.startOrContinue();
      final result = await c.purchaseSuperHint(operationId: 'super');
      expect(result.status, 'purchased');
      expect(c.profile.balance, 0);
      final round = c.profile.currentRound!;
      expect(round.superHintUses, 1);
      expect(round.paidHints, 0);
      final resolved = round.superHints.single;
      expect(round.targets, contains(resolved.targetKey));
      final target = c.engine.state.level.words.firstWhere(
        (w) => w.key == resolved.targetKey,
      );
      expect(
        c.engine.state.revealedLetters[resolved.targetKey],
        hasLength(target.letters.length),
      );
      await c.close();
      await open();
      expect(c.profile.balance, 0);
      expect(c.profile.currentRound!.superHintUses, 1);
      await c.purchaseSuperHint(operationId: 'super');
      expect(c.profile.balance, 0);
    },
  );
  test(
    'Super Dica final campaign 100 to 20 has separate linked debit and reward',
    () async {
      await reset(100);
      await c.startOrContinue();
      await leaveLast();
      final result = await c.purchaseSuperHint(operationId: 'final-super');
      expect(result.submission!.completed, true);
      expect(c.profile.balance, 20);
      expect(c.profile.pendingCompletion!.reward, 20);
      expect(c.profile.unlocked, {1, 2});
      final ledger = await repo.database.query(
        'coin_transactions',
        where: 'parent_operation_id = ?',
        whereArgs: ['final-super'],
      );
      expect(ledger.map((r) => r['amount']).toList(), [-100, 20]);
      expect(ledger.map((r) => r['operation_id']).toSet(), hasLength(2));
      await c.close();
      await open();
      expect(c.profile.balance, 20);
      expect(c.freshCompletion, false);
    },
  );
  test('Super Dica final daily 100 to 50 with no campaign rewards', () async {
    await reset(100);
    await c.startDaily();
    await leaveLast();
    await c.purchaseSuperHint(operationId: 'daily-final');
    expect(c.profile.balance, 50);
    expect(c.profile.daily['2026-01-01']!.pendingResult, true);
    expect(c.profile.completed, isEmpty);
    expect(c.profile.explorerRewardedLevels, isEmpty);
    final ledger = await repo.database.query(
      'coin_transactions',
      where: 'parent_operation_id = ?',
      whereArgs: ['daily-final'],
    );
    expect(ledger.map((r) => r['amount']).toList(), [-100, 50]);
    await c.close();
    await open();
    await c.startDaily();
    expect(c.profile.balance, 50);
    expect(c.engine.state.phase, RoundPhase.completed);
    await c.advance();
    await expectLater(c.startDaily(), throwsStateError);
    expect(c.profile.balance, 50);
  });
  test(
    '99 coins cannot fund a final Super Dica using its own reward',
    () async {
      await reset(99);
      await c.startDaily();
      await leaveLast();
      expect((await c.purchaseSuperHint()).status, 'insufficient');
      expect(c.profile.balance, 99);
      expect(c.activeRound!.superHintUses, 0);
      expect(c.todayProgress!.completed, false);
    },
  );
  test('simultaneous Super Dicas cannot spend twice from 100', () async {
    await reset(100);
    await c.startOrContinue();
    final results = await Future.wait([
      c.purchaseSuperHint(operationId: 'one'),
      c.purchaseSuperHint(operationId: 'two'),
    ]);
    expect(results.where((r) => r.status == 'purchased'), hasLength(1));
    expect(c.profile.balance, 0);
    expect(c.profile.currentRound!.superHintUses, 1);
  });
  test(
    'same Super Dica ID repeated concurrently resolves same word and charges once',
    () async {
      await reset(100);
      await c.startOrContinue();
      final results = await Future.wait([
        c.purchaseSuperHint(operationId: 'same'),
        c.purchaseSuperHint(operationId: 'same'),
      ]);
      expect(
        results[0].submission!.word!.key,
        results[1].submission!.word!.key,
      );
      expect(c.profile.balance, 0);
    },
  );
  for (final point in StorageFaultPoint.values.where(
    (p) => p != StorageFaultPoint.afterCommit,
  )) {
    test(
      'multi-entry Super Dica rollback ${point.name} recovers same choice',
      () async {
        await reset(100);
        await c.startOrContinue();
        await leaveLast();
        repo.fault = (p) {
          if (p == point) throw StateError('injected');
        };
        await expectLater(
          c.purchaseSuperHint(operationId: 'atomic-super'),
          throwsStateError,
        );
        expect(c.profile.balance, 100);
        expect(c.profile.completed, isEmpty);
        expect(c.activeRound!.superHintUses, 0);
        expect((await repo.load(data)).balance, 100);
        expect(await repo.database.query('coin_transactions'), hasLength(1));
        final chosen = (await repo.pending()).single.result['targetKey'];
        await c.close();
        await open();
        expect(c.profile.balance, 20);
        expect(c.profile.currentRound!.superHints.single.targetKey, chosen);
      },
    );
  }
  test(
    'after-commit failure resolves super receipt and never repeats reward or debit',
    () async {
      await reset(100);
      await c.startOrContinue();
      await leaveLast();
      repo.fault = (p) {
        if (p == StorageFaultPoint.afterCommit) throw StateError('lost');
      };
      await c.purchaseSuperHint(operationId: 'lost-super');
      expect(c.profile.balance, 20);
      repo.fault = null;
      await c.purchaseSuperHint(operationId: 'lost-super');
      expect(c.profile.balance, 20);
      expect(await repo.database.query('coin_transactions'), hasLength(3));
    },
  );
  test(
    'daily selection is deterministic and does not repeat consecutive days across cycle',
    () async {
      final catalog = await DailyCatalog.load();
      final fingerprints = <String>[];
      for (var day = 1; day <= 15; day++) {
        final date = calendarDate(DateTime(2026, 1, day));
        final level = catalog.forDate(date);
        fingerprints.add(level.fingerprint);
        expect(catalog.forDate(date).fingerprint, level.fingerprint);
      }
      expect(fingerprints.take(7).toSet(), hasLength(7));
      for (var i = 1; i < fingerprints.length; i++) {
        expect(fingerprints[i], isNot(fingerprints[i - 1]));
      }
      expect(catalog.forDate('2028-02-29').words, isNotEmpty);
      expect(catalog.forDate('2027-01-01').words, isNotEmpty);
    },
  );
  test(
    'daily extra grants free reveal and visual badge without ten-coin bonus',
    () async {
      await c.startDaily();
      final extra = await word('TOGA');
      expect(extra.explorerUnlocked, true);
      expect(extra.revealedLetter, isNotNull);
      expect(c.profile.balance, 60);
      expect(c.profile.explorerRewardedLevels, isEmpty);
      await finish();
      expect(c.profile.balance, 110);
      expect(c.profile.completed, isEmpty);
      expect(c.profile.currentRound, isNull);
    },
  );
  test(
    'campaign pending result and daily result coexist with shared wallet',
    () async {
      await c.startOrContinue();
      await finish();
      final pending = c.profile.pendingCompletion!.roundId;
      await c.startDaily();
      await finish();
      expect(c.profile.balance, 130);
      expect(c.profile.pendingCompletion!.roundId, pending);
      expect(c.todayProgress!.pendingResult, true);
      await c.advance();
      await c.startOrContinue();
      expect(c.profile.pendingCompletion!.roundId, pending);
      expect(c.engine.state.phase, RoundPhase.completed);
      await c.advance();
      expect(c.profile.currentLevelId, 2);
      expect(c.profile.balance, 130);
      expect(c.todayProgress!.completed, true);
    },
  );
  test(
    'daily round restores shuffle, paid hint and extras on same date',
    () async {
      await c.startDaily();
      await word('GATO');
      await word('TOGA');
      await c.purchaseHint(operationId: 'daily-hint');
      await c.shuffle();
      final payload = canonicalJson(c.todayProgress!.toJson());
      await c.close();
      await open();
      await c.startDaily();
      expect(canonicalJson(c.todayProgress!.toJson()), payload);
      expect(c.profile.balance, 30);
    },
  );
  test(
    'daily embeds definition so catalog update mid-day cannot replace it or reward twice',
    () async {
      await c.startDaily();
      final fingerprint = c.activeRound!.fingerprint;
      await finish();
      final replacement = DailyCatalog(
        version: 99,
        baseDate: '2026-01-01',
        levels: data.levels.reversed.toList(),
        lexicon: data.lexicon,
      );
      await c.close();
      await open(catalog: replacement);
      await c.startDaily();
      expect(c.activeRound!.fingerprint, fingerprint);
      expect(c.profile.balance, 110);
      await c.advance();
      await expectLater(c.startDaily(), throwsStateError);
      expect(c.profile.balance, 110);
    },
  );
  test(
    'midnight expires old daily, rejects stale confirmation and keeps purchases',
    () async {
      time = DateTime(2026, 12, 31, 23, 59);
      await c.startDaily();
      final ctx = c.context!;
      final oldBalance = c.profile.balance;
      time = DateTime(2027, 1, 1);
      await expectLater(
        c.purchaseHint(operationId: 'stale-dialog', expected: ctx),
        throwsA(isA<DailyExpired>()),
      );
      expect(c.profile.balance, oldBalance);
      expect(c.profile.daily['2026-12-31']!.expired, true);
      await c.simulateAd();
      expect(c.profile.balance, 75);
      await c.startDaily();
      expect(c.activeDailyDate, '2027-01-01');
      expect(c.activeRound!.targets, isEmpty);
    },
  );
  test(
    'prepared uncommitted daily Super Dica expires on process reopen without debit or reward',
    () async {
      await reset(100);
      await c.startDaily();
      await leaveLast();
      repo.fault = (p) {
        if (p == StorageFaultPoint.beforeCommit) throw StateError('stopped');
      };
      await expectLater(
        c.purchaseSuperHint(operationId: 'expired-super'),
        throwsStateError,
      );
      time = DateTime(2026, 1, 2);
      await c.close();
      await open();
      expect(c.profile.balance, 100);
      expect(c.profile.daily['2026-01-01']!.expired, true);
      expect(c.profile.daily['2026-01-01']!.completed, false);
      expect(await repo.pending(), isEmpty);
      expect(
        (await repo.resolveOperation('expired-super'))!.result['rejected'],
        true,
      );
    },
  );
  test(
    'daily committed before midnight keeps receipt when confirmation arrives next date',
    () async {
      await reset(100);
      await c.startDaily();
      await leaveLast();
      repo.fault = (p) {
        if (p == StorageFaultPoint.afterCommit) {
          time = DateTime(2026, 1, 2);
          throw StateError('late response');
        }
      };
      await c.purchaseSuperHint(operationId: 'committed-old-day');
      expect(c.profile.balance, 50);
      expect(c.profile.daily['2026-01-01']!.completed, true);
      repo.fault = null;
      await c.startDaily();
      expect(c.activeDailyDate, '2026-01-02');
      expect(c.profile.balance, 50);
    },
  );
  test(
    'clock rollback blocks old dates but campaign and store remain usable',
    () async {
      time = DateTime(2026, 3, 1);
      await c.startDaily();
      time = DateTime(2026, 2, 28);
      await expectLater(c.startDaily(), throwsA(isA<ClockReversed>()));
      expect(c.clockReversed, true);
      await c.startOrContinue();
      await word('GATO');
      await c.simulateAd();
      expect(c.profile.balance, 75);
      expect(c.profile.daily.keys, {'2026-03-01'});
    },
  );
  test(
    'calendar leap year, skipped days and new month do not grant retroactive rewards',
    () async {
      time = DateTime(2028, 2, 28);
      await c.startDaily();
      time = DateTime(2028, 2, 29);
      await c.startDaily();
      time = DateTime(2028, 3, 4);
      await c.startDaily();
      expect(c.profile.daily.length, 3);
      expect(c.profile.balance, 60);
      expect(c.profile.daily['2028-02-28']!.expired, true);
      expect(c.profile.daily['2028-02-29']!.expired, true);
      expect(() => parseCalendarDate('2027-02-29'), throwsFormatException);
    },
  );
  test('daily remains available after complete campaign', () async {
    await c.startOrContinue();
    for (final _ in data.levels) {
      await finish();
      await c.advance();
    }
    expect(c.profile.campaignComplete, true);
    await c.startDaily();
    await finish();
    expect(c.profile.balance, 310);
    expect(c.profile.campaignComplete, true);
  });
  test(
    'migrates v2 file preserving old payload, welcome, paid hint, badge and pending result',
    () async {
      await c.startOrContinue();
      await word('TOGA');
      await c.purchaseHint(operationId: 'old-hint');
      await finish();
      final balance = c.profile.balance, revision = c.profile.revision;
      final rows = await repo.database.query('coin_transactions');
      final payload = c.profile.toPayload()
        ..['schemaVersion'] = 1
        ..remove('daily')
        ..remove('lastDailyDate');
      for (final round in (payload['levels'] as Map).values) {
        (round as Map).remove('superHints');
      }
      await repo.database.update('profiles', {
        'payload_json': canonicalJson(payload),
      });
      await repo.database.execute(
        'ALTER TABLE coin_transactions DROP COLUMN parent_operation_id',
      );
      await repo.database.setVersion(2);
      await c.close();
      await open();
      expect(await repo.database.getVersion(), LocalGameDatabase.version);
      expect(c.profile.balance, balance);
      expect(c.profile.revision, revision);
      expect(c.profile.explorerRewardedLevels, {1});
      expect(c.profile.pendingCompletion, isNotNull);
      expect(
        await repo.database.query('coin_transactions'),
        hasLength(rows.length),
      );
    },
  );
  for (final point in [
    StorageFaultPoint.beforeLedger,
    StorageFaultPoint.afterLedgerEntry,
    StorageFaultPoint.beforeProfile,
    StorageFaultPoint.beforeCommit,
  ]) {
    test(
      'simulated credit rollback ${point.name} retries the same order',
      () async {
        repo.fault = (p) {
          if (p == point) throw StateError('shop fault');
        };
        await expectLater(
          c.simulatePurchase('coins_500', id: 'retry-shop'),
          throwsStateError,
        );
        expect(c.profile.balance, 60);
        expect((await repo.load(data)).balance, 60);
        expect(await repo.database.query('coin_transactions'), hasLength(1));
        repo.fault = null;
        await c.retry();
        expect(c.profile.balance, 560);
        await c.simulatePurchase('coins_500', id: 'retry-shop');
        expect(c.profile.balance, 560);
      },
    );
  }
  test(
    'simulated ad lost commit confirmation resolves once after reopen',
    () async {
      repo.fault = (p) {
        if (p == StorageFaultPoint.afterCommit) {
          throw StateError('lost ad response');
        }
      };
      await c.simulateAd(id: 'ad-receipt');
      expect(c.profile.balance, 75);
      await c.close();
      await open();
      await c.simulateAd(id: 'ad-receipt');
      expect(c.profile.balance, 75);
    },
  );
  test(
    'stale campaign context cannot spend or submit into a daily round with matching numeric level ID',
    () async {
      await c.startOrContinue();
      final context = c.context!;
      final ids = idsFor(c.engine, 'GATO');
      await c.startDaily();
      expect(c.engine.state.level.id, context.levelId);
      expect(
        (await c.submitWord(
          ids,
          session: context.session,
          expected: context,
        )).kind,
        SubmissionKind.ignored,
      );
      await expectLater(
        c.purchaseSuperHint(expected: context),
        throwsStateError,
      );
      expect(c.profile.balance, 60);
      expect(c.activeRound!.targets, isEmpty);
    },
  );
  test(
    'observing midnight blocks clock rollback even before starting the next challenge',
    () async {
      await c.startDaily();
      time = DateTime(2026, 1, 2);
      await c.refreshDaily();
      expect(c.profile.lastDailyDate, '2026-01-02');
      expect(c.profile.daily.keys, {'2026-01-01'});
      time = DateTime(2026, 1, 1, 23);
      await c.close();
      await open();
      expect(c.clockReversed, true);
      await expectLater(c.startDaily(), throwsA(isA<ClockReversed>()));
      expect(c.profile.daily['2026-01-01']!.expired, true);
      expect(c.profile.balance, 60);
      await c.simulateAd();
      expect(c.profile.balance, 75);
    },
  );
}
