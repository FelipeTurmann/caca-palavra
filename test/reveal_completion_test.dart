import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/daily_catalog.dart';
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
  late GameSessionCoordinator session;
  late GameData data;

  Future<void> open({int balance = 120}) async {
    repo = await SqliteProgressRepository.open(
      factory: databaseFactoryFfi,
      databasePath: location,
      initialBalance: balance,
    );
    session = await GameSessionCoordinator.create(
      data,
      repo,
      random: Random(7),
      now: () => DateTime(2026, 10, 23, 12),
      dailyCatalog: DailyCatalog(
        version: 1,
        baseDate: '2026-10-23',
        levels: [data.levels.first],
        lexicon: data.lexicon,
      ),
    );
  }

  Future<SubmissionResult> word(String key) => session.submitWord(
    idsFor(session.engine, key),
    session: session.engine.state.session,
  );

  Future<void> prepare(bool daily) async {
    if (daily) {
      await session.startDaily();
    } else {
      await session.startOrContinue();
    }
    await word('GOTA');
    await word('ATO');
    for (var i = 0; i < 3; i++) {
      final hint = await session.purchaseHint(operationId: 'prepare-$i');
      expect(hint.submission, isNull);
    }
    expect(session.engine.state.targets, {'GOTA', 'ATO'});
    expect(session.engine.state.revealedLetters['GATO'], hasLength(3));
  }

  Future<void> complete(bool extra) async {
    if (extra) {
      final result = await word('TOGA');
      expect(result.kind, SubmissionKind.extraFound);
      expect(result.word!.key, 'TOGA');
      expect(result.resolvedWord!.key, 'GATO');
      expect(result.completed, true);
      expect(result.explorerUnlocked, true);
    } else {
      final result = await session.purchaseHint(operationId: 'finish-hint');
      expect(result.status, 'purchased');
      expect(result.submission!.kind, SubmissionKind.hintResolved);
      expect(result.submission!.word!.key, 'GATO');
      expect(result.submission!.completed, true);
    }
  }

  int expectedBalance(bool daily, bool extra) =>
      extra ? (daily ? 80 : 60) : (daily ? 50 : 20);

  Future<void> verify(bool daily, bool extra) async {
    expect(session.profile.balance, expectedBalance(daily, extra));
    expect(session.engine.state.targets, {'GATO', 'GOTA', 'ATO'});
    expect(session.engine.state.revealedLetters['GATO'], hasLength(4));
    expect(session.activeRound!.status, 'completed');
    expect(session.activeRound!.superHintUses, 0);
    expect(session.activeRound!.paidHints, extra ? 3 : 4);
    expect(session.activeRound!.freeHints, extra ? 1 : 0);
    expect(session.engine.canReveal, false);
    if (daily) {
      expect(session.activeDay!.pendingResult, true);
      expect(session.profile.completed, isEmpty);
      expect(session.profile.explorerRewardedLevels, isEmpty);
    } else {
      expect(session.profile.completed, {1});
      expect(session.profile.unlocked, contains(2));
      expect(session.profile.pendingCompletion!.reward, 20);
      expect(session.profile.explorerRewardedLevels, extra ? {1} : isEmpty);
    }
    final ledger = await repo.database.query('coin_transactions');
    expect(
      ledger.where((r) => r['kind'] == 'paid_hint'),
      hasLength(extra ? 3 : 4),
    );
    expect(
      ledger.where((r) => r['kind'] == 'explorer_reward'),
      hasLength(extra && !daily ? 1 : 0),
    );
    expect(
      ledger.where(
        (r) => r['kind'] == (daily ? 'daily_completion' : 'level_completion'),
      ),
      hasLength(1),
    );
    final completion = ledger.singleWhere(
      (r) => r['kind'] == (daily ? 'daily_completion' : 'level_completion'),
    );
    final transaction = ledger
        .where(
          (r) => r['parent_operation_id'] == completion['parent_operation_id'],
        )
        .toList();
    // A final paid hint has debit + reward; a campaign extra has both bonuses.
    expect(transaction, hasLength(!extra || !daily ? 2 : 1));
  }

  Future<void> reopen(bool daily) async {
    await session.close();
    await open();
    if (daily) await session.startDaily();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('reveal-completion-');
    location = '${directory.path}/game.db';
    data = loadData();
    await open();
  });

  tearDown(() async {
    await session.close();
    await directory.delete(recursive: true);
  });

  for (final daily in [false, true]) {
    for (final extra in [false, true]) {
      final label =
          '${daily ? 'daily' : 'campaign'} ${extra ? 'extra' : 'paid hint'}';
      test(
        '$label completes last cell, restores and never repeats rewards',
        () async {
          await prepare(daily);
          await complete(extra);
          expect(session.engine.state.phase, RoundPhase.completing);
          await verify(daily, extra);
          final saved = session.profile.toPayload();
          if (extra) {
            expect((await word('TOGA')).kind, SubmissionKind.ignored);
          } else {
            final duplicate = await session.purchaseHint(
              operationId: 'finish-hint',
            );
            expect(duplicate.submission!.completed, true);
          }
          expect(session.profile.toPayload(), saved);
          await verify(daily, extra);
          await reopen(daily);
          expect(session.profile.toPayload(), saved);
          await verify(daily, extra);
        },
      );

      test(
        '$label rolls back final reveal and all rewards, restart commits once',
        () async {
          await prepare(daily);
          final before = session.profile.toPayload();
          final balance = session.profile.balance;
          final ledger = await repo.database.query('coin_transactions');
          repo.fault = (point) {
            if (point == StorageFaultPoint.afterLedgerEntry) {
              throw StateError('stop after first ledger entry');
            }
          };
          await expectLater(complete(extra), throwsStateError);
          expect(session.profile.toPayload(), before);
          expect(session.profile.balance, balance);
          expect(await repo.database.query('coin_transactions'), ledger);
          expect((await repo.load(data)).toPayload(), before);
          expect(await repo.pending(), hasLength(1));
          await reopen(daily);
          await verify(daily, extra);
          expect(await repo.pending(), isEmpty);
        },
      );

      test(
        '$label lost commit response resolves the original receipt once',
        () async {
          await prepare(daily);
          repo.fault = (point) {
            if (point == StorageFaultPoint.afterCommit) {
              throw StateError('lost acknowledgement');
            }
          };
          await complete(extra);
          repo.fault = null;
          await verify(daily, extra);
          await reopen(daily);
          await verify(daily, extra);
        },
      );
    }

    test(
      '${daily ? 'daily' : 'campaign'} final hint needs 30 coins before its reward',
      () async {
        await session.close();
        await databaseFactoryFfi.deleteDatabase(location);
        await open(balance: 119);
        await prepare(daily);
        expect(session.profile.balance, 29);
        final before = session.profile.toPayload();
        final ledger = await repo.database.query('coin_transactions');
        expect(
          (await session.purchaseHint(operationId: 'not-enough')).status,
          'insufficient',
        );
        expect(session.profile.balance, 29);
        expect(session.profile.toPayload(), before);
        expect(await repo.database.query('coin_transactions'), ledger);
        expect(session.engine.state.targets, {'GOTA', 'ATO'});
        expect(session.engine.state.revealedLetters['GATO'], hasLength(3));
      },
    );
  }
}
