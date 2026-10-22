// Isolated process-recovery fixture. Production saves are never opened here.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/features/game/application/campaign_models.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/data/daily_catalog.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getDatabasesPath();
  final control = File(path.join(dir, 'stage4_phase.txt')),
      marker = File(path.join(dir, 'stage4_event.txt')),
      expected = File(path.join(dir, 'stage4_expected.json'));
  final phase = await control.exists()
      ? (await control.readAsString()).trim()
      : 'seed';
  final database = path.join(dir, 'stage4_recovery.db');
  var time = phase == 'prepare_uncommitted'
      ? DateTime(2026, 1, 2, 23, 59)
      : phase == 'verify_expired'
      ? DateTime(2026, 1, 3)
      : DateTime(2026, 1, 1, 12);
  void check(bool value, String message) {
    if (!value) throw StateError(message);
  }

  try {
    if (phase == 'seed') await deleteDatabase(database);
    final data = await GameData.load();
    final repo = await SqliteProgressRepository.open(databasePath: database);
    final c = await GameSessionCoordinator.create(
      data,
      repo,
      dailyCatalog: await DailyCatalog.load(),
      now: () => time,
    );
    Future<void> word(String value) async {
      final available = c.engine.state.level.tiles.toList();
      final ids = [
        for (final letter in value.split(''))
          available
              .removeAt(available.indexWhere((t) => t.letter == letter))
              .id,
      ];
      await c.submitWord(ids, session: c.engine.state.session);
    }

    Future<void> leaveLast() async {
      final remaining = c.engine.state.level.words
          .where((w) => !c.engine.state.targets.contains(w.key))
          .toList();
      for (final w in remaining.take(remaining.length - 1)) {
        await word(w.key);
      }
    }

    switch (phase) {
      case 'seed':
        await c.simulatePurchase('coins_500', id: 'recovery-package');
        await c.simulateAd(id: 'recovery-ad');
        await c.startOrContinue();
        await c.purchaseSuperHint(operationId: 'campaign-super');
        await word('TOGA');
        await c.startDaily();
        await word('TOGA');
        await c.purchaseHint(operationId: 'daily-hint');
        await c.purchaseSuperHint(operationId: 'daily-super');
        await c.shuffle();
        check(c.profile.balance == 355, 'seed balance');
        await expected.writeAsString(
          canonicalJson(c.profile.toPayload()),
          flush: true,
        );
      case 'verify_partial':
        check(
          canonicalJson(c.profile.toPayload()) == await expected.readAsString(),
          'snapshot changed across process',
        );
        await c.simulatePurchase('coins_500', id: 'recovery-package');
        await c.simulateAd(id: 'recovery-ad');
        check(c.profile.balance == 355, 'duplicate shop credit');
        check(
          c.profile.currentRound!.superHintUses == 1 &&
              c.profile.daily['2026-01-01']!.round.superHintUses == 1,
          'assisted resolution lost',
        );
        await c.startDaily();
        check(c.profile.balance == 355, 'restore debit');
      case 'complete':
        await c.startDaily();
        await leaveLast();
        await c.purchaseSuperHint(operationId: 'final-daily-super');
        check(
          c.profile.balance == 305 && c.todayProgress!.pendingResult,
          'final daily balance',
        );
        await marker.writeAsString(
          '$phase OK balance=305 before-animation',
          flush: true,
        );
        await Completer<void>().future;
      case 'verify_completed':
        await c.startDaily();
        check(
          c.profile.balance == 305 &&
              c.todayProgress!.completed &&
              !c.freshCompletion,
          'restored daily result',
        );
        await c.advance();
        check(
          c.profile.balance == 305 && !c.todayProgress!.pendingResult,
          'daily acknowledgment',
        );
      case 'prepare_uncommitted':
        await c.startDaily();
        await leaveLast();
        repo.fault = (point) {
          if (point == StorageFaultPoint.beforeCommit) {
            throw StateError('stop before commit');
          }
        };
        try {
          await c.purchaseSuperHint(operationId: 'uncommitted-old-date');
          throw StateError('fault not triggered');
        } catch (_) {
          check(
            c.profile.balance == 305 && (await repo.pending()).isNotEmpty,
            'pending proposal missing',
          );
        }
        await marker.writeAsString(
          '$phase OK balance=305 prepared-without-commit',
          flush: true,
        );
        await Completer<void>().future;
      case 'verify_expired':
        check(
          c.profile.balance == 305 && c.profile.daily['2026-01-02']!.expired,
          'old prepared operation was applied',
        );
        check(
          (await repo.resolveOperation(
                'uncommitted-old-date',
              ))!.result['rejected'] ==
              true,
          'old date operation not rejected',
        );
        check(
          c.profile.daily['2026-01-01']!.completed,
          'confirmed history lost',
        );
        await c.startDaily();
        check(c.activeDailyDate == '2026-01-03', 'new challenge missing');
      default:
        throw StateError('Unknown phase $phase');
    }
    await marker.writeAsString(
      '$phase OK balance=${c.profile.balance} campaignSuper=${c.profile.currentRound?.superHintUses} days=${c.profile.daily.length}',
      flush: true,
    );
    runApp(WordGameApp(loader: () async => c));
  } catch (error, stack) {
    await marker.writeAsString('$phase FAILED $error\n$stack', flush: true);
    runApp(MaterialApp(home: Scaffold(body: Text('$error'))));
  }
}
