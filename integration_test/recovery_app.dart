// Standalone Android fixture driven by ADB. Never opens the production database.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/features/game/application/campaign_models.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getDatabasesPath();
  final control = File(path.join(directory, 'stage3_phase.txt'));
  final phase = await control.exists()
      ? (await control.readAsString()).trim()
      : 'seed';
  final marker = File(path.join(directory, 'stage3_event.txt'));
  final snapshot = File(path.join(directory, 'stage3_expected.json'));
  final database = path.join(directory, 'stage3_recovery.db');
  void check(bool value, String text) {
    if (!value) throw StateError(text);
  }

  try {
    if (phase == 'seed') await deleteDatabase(database);
    final data = await GameData.load();
    final c = await GameSessionCoordinator.create(
      data,
      await SqliteProgressRepository.open(databasePath: database),
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

    Future<void> finish() async {
      for (final wordEntry in c.engine.state.level.words) {
        await word(wordEntry.key);
      }
    }

    switch (phase) {
      case 'seed':
        await c.startOrContinue();
        await word('GATO');
        await word('TOGA');
        await c.shuffle();
        await c.purchaseHint(operationId: 'android-recovery-hint');
        check(
          c.profile.balance == 40 &&
              c.profile.currentRound!.reveals.length == 2,
          'partial state',
        );
        await snapshot.writeAsString(
          canonicalJson(c.profile.toPayload()),
          flush: true,
        );
      case 'verify_partial':
        check(
          canonicalJson(c.profile.toPayload()) == await snapshot.readAsString(),
          'partial snapshot changed',
        );
        check(c.profile.balance == 40, 'partial balance');
        check(
          c.engine.state.targets.contains('GATO') &&
              c.engine.state.extras.containsKey('TOGA'),
          'discoveries',
        );
      case 'complete':
        await c.startOrContinue();
        await finish();
        check(
          c.profile.balance == 60 && c.profile.pendingCompletion?.levelId == 1,
          'completion',
        );
        await marker.writeAsString(
          '$phase OK balance=${c.profile.balance} before-animation',
          flush: true,
        );
        // Stop here after commit, before mounting the result or playing an animation.
        await Completer<void>().future;
      case 'verify_completed':
        check(
          c.profile.balance == 60 && c.profile.pendingCompletion?.levelId == 1,
          'pending result',
        );
        check(
          !c.freshCompletion && c.engine.state.phase == RoundPhase.completed,
          'restored result',
        );
        await c.startOrContinue();
        check(c.profile.balance == 60, 'duplicate reward');
      case 'advance':
        check(await c.advance(), 'advance');
        check(
          c.profile.currentLevelId == 2 && c.profile.balance == 60,
          'next level',
        );
      case 'verify_advance':
        check(
          c.profile.currentLevelId == 2 &&
              c.profile.balance == 60 &&
              c.profile.pendingCompletion == null,
          'restored next',
        );
        check(
          c.profile.rounds[1]!.reveals.length == 2 &&
              c.profile.currentRound!.reveals.isEmpty,
          'history',
        );
      case 'finish':
        while (!c.profile.campaignComplete) {
          await c.startOrContinue();
          await finish();
          await c.advance();
        }
        check(
          c.profile.balance == 240 &&
              c.profile.completed.length == data.levels.length,
          'campaign',
        );
      case 'verify_final':
        check(
          c.profile.campaignComplete &&
              c.profile.balance == 240 &&
              c.profile.rounds.length == data.levels.length,
          'restored campaign',
        );
      default:
        throw StateError('Unknown test phase $phase');
    }
    await marker.writeAsString(
      '$phase OK balance=${c.profile.balance} level=${c.profile.currentLevelId} completed=${c.profile.completed.length}',
      flush: true,
    );
    runApp(WordGameApp(loader: () async => c));
  } catch (error, stack) {
    await marker.writeAsString('$phase FAILED $error\n$stack', flush: true);
    runApp(
      MaterialApp(
        home: Scaffold(body: Text('Recovery fixture failed: $error')),
      ),
    );
  }
}
