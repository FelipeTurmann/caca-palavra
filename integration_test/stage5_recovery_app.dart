// Dedicated process-recovery fixture. Never opens the production database.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/core/preferences/player_preferences.dart';
import 'package:caca_palavra/features/game/application/campaign_models.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getDatabasesPath();
  final control = File(path.join(dir, 'stage5_phase.txt'));
  final marker = File(path.join(dir, 'stage5_event.txt'));
  final expected = File(path.join(dir, 'stage5_expected.json'));
  final phase = await control.exists()
      ? (await control.readAsString()).trim()
      : 'seed_incomplete';
  final location = path.join(dir, 'stage5_recovery.db');
  void check(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  try {
    if (phase == 'seed_incomplete') await deleteDatabase(location);
    final repo = await SqliteProgressRepository.open(databasePath: location);
    final c = await GameSessionCoordinator.create(
      await GameData.load(),
      repo,
      now: () => DateTime(2026, 1, 1, 12),
    );
    final preferences = await PreferencesController.load(
      SqlitePreferencesStore(repo.database),
    );
    switch (phase) {
      case 'seed_incomplete':
        await preferences.update(
          preferences.value.copyWith(
            sound: false,
            haptics: false,
            reduceMotion: true,
            introduction: Introduction.inProgress,
          ),
        );
        check(
          c.profile.balance == 60 && !c.profile.hasStarted,
          'tutorial changed the profile',
        );
        await expected.writeAsString(
          canonicalJson(c.profile.toPayload()),
          flush: true,
        );
      case 'verify_incomplete':
        check(
          preferences.value.introduction == Introduction.inProgress,
          'incomplete tutorial lost',
        );
        check(
          preferences.value.needsIntroduction,
          'incomplete tutorial incorrectly completed',
        );
        check(
          !preferences.value.sound &&
              !preferences.value.haptics &&
              preferences.value.reduceMotion,
          'preferences lost',
        );
        check(
          canonicalJson(c.profile.toPayload()) == await expected.readAsString(),
          'profile changed during tutorial',
        );
        check(
          (await repo.database.query('coin_transactions')).length == 1,
          'welcome repeated',
        );
      case 'seed_playing':
        await preferences.update(
          preferences.value.copyWith(
            haptics: true,
            introduction: Introduction.skipped,
          ),
        );
        await c.startOrContinue();
        final word = c.engine.state.level.words.first;
        final tiles = c.engine.state.level.tiles.toList();
        final ids = [
          for (final letter in word.key.split(''))
            tiles.removeAt(tiles.indexWhere((t) => t.letter == letter)).id,
        ];
        await c.submitWord(ids, session: c.engine.state.session);
        await c.purchaseHint(operationId: 'stage5-hint');
        check(c.profile.balance == 30, 'playing balance');
        await expected.writeAsString(
          canonicalJson(c.profile.toPayload()),
          flush: true,
        );
      case 'verify_playing':
        check(
          !preferences.value.needsIntroduction &&
              preferences.value.introduction == Introduction.skipped,
          'skip lost',
        );
        check(
          !preferences.value.sound &&
              preferences.value.haptics &&
              preferences.value.reduceMotion,
          'independent preferences lost',
        );
        check(
          canonicalJson(c.profile.toPayload()) == await expected.readAsString(),
          'playing snapshot changed',
        );
        check(c.profile.balance == 30, 'playing wallet changed');
      case 'prepare_hint':
        await c.startOrContinue();
        repo.fault = (point) {
          if (point == StorageFaultPoint.beforeProfile) {
            throw StateError('simulated power loss');
          }
        };
        try {
          await c.purchaseHint(operationId: 'stage5-prepared-hint');
        } catch (_) {}
        check((await repo.pending()).length == 1, 'prepared operation missing');
        check(c.profile.balance == 30, 'uncommitted hint charged');
      case 'verify_hint':
        check(
          (await repo.pending()).isEmpty,
          'prepared operation not recovered',
        );
        check(c.profile.balance == 0, 'prepared hint charged incorrectly');
        check(
          (await repo.database.query('coin_transactions')).length == 3,
          'hint duplicated',
        );
        check(
          preferences.value.introduction == Introduction.skipped &&
              !preferences.value.sound &&
              preferences.value.haptics &&
              preferences.value.reduceMotion,
          'settings changed during recovery',
        );
      default:
        throw StateError('unknown phase');
    }
    preferences.dispose();
    await marker.writeAsString(
      '$phase OK balance=${c.profile.balance}',
      flush: true,
    );
    runApp(WordGameApp(loader: () async => c));
  } catch (error, stack) {
    await marker.writeAsString('$phase FAIL $error\n$stack', flush: true);
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Falha na fixture da etapa 5')),
        ),
      ),
    );
  }
}
