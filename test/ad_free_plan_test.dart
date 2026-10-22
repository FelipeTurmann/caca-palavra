import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:caca_palavra/core/monetization/ad_free_plan.dart';
import 'package:caca_palavra/core/preferences/player_preferences.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'helpers.dart';

class DelayedStore extends MemoryAdFreePlanStore {
  final gate = Completer<void>();
  bool fail = true;
  int writes = 0;
  @override
  Future<void> activate() async {
    writes++;
    await gate.future;
    if (fail) throw StateError('disk full');
    await super.activate();
  }
}

void main() {
  test(
    'activation waits for storage, serializes taps and retries a failed save',
    () async {
      final store = DelayedStore();
      final plan = await AdFreePlanController.load(store);
      final pending = plan.activateSimulated();
      final repeated = plan.activateSimulated();
      expect(plan.busy, true);
      expect(plan.active, false);
      expect(store.writes, 1);
      store.gate.complete();
      await Future.wait([pending, repeated]);
      expect(plan.active, false);
      expect(plan.error, isNotNull);
      store.fail = false;
      await plan.activateSimulated();
      expect(plan.active, true);
      expect(plan.error, isNull);
      await plan.activateSimulated();
      expect(store.writes, 2);
      plan.dispose();
    },
  );

  test(
    'schema 4 migration preserves the round, wallet and preferences; simulated plan survives reopen',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('ad-free-plan-');
      addTearDown(() => dir.delete(recursive: true));
      final location = '${dir.path}/game.db';
      var repo = await SqliteProgressRepository.open(
        factory: databaseFactoryFfi,
        databasePath: location,
      );
      var session = await GameSessionCoordinator.create(loadData(), repo);
      await session.startOrContinue();
      await session.submitWord(
        idsFor(session.engine, 'GATO'),
        session: session.engine.state.session,
      );
      final prefs = SqlitePreferencesStore(repo.database);
      await prefs.write(
        const PlayerPreferences(
          sound: false,
          introduction: Introduction.skipped,
        ),
      );
      final before = session.profile.toPayload();
      final balance = session.profile.balance;
      final ledger = await repo.database.query('coin_transactions');
      await repo.database.execute('DROP TABLE simulated_entitlements');
      await repo.database.setVersion(4);
      await session.close();

      repo = await SqliteProgressRepository.open(
        factory: databaseFactoryFfi,
        databasePath: location,
      );
      session = await GameSessionCoordinator.create(loadData(), repo);
      expect(await repo.database.getVersion(), LocalGameDatabase.version);
      expect(session.profile.toPayload(), before);
      expect(session.profile.balance, balance);
      expect((await SqlitePreferencesStore(repo.database).read()).sound, false);
      var plan = await AdFreePlanController.load(
        SqliteAdFreePlanStore(repo.database),
      );
      expect(plan.active, false);
      await plan.activateSimulated();
      await plan.activateSimulated();
      expect((await repo.database.query('simulated_entitlements')).length, 1);
      expect(await repo.database.query('coin_transactions'), ledger);
      plan.dispose();
      await session.close();

      repo = await SqliteProgressRepository.open(
        factory: databaseFactoryFfi,
        databasePath: location,
      );
      plan = await AdFreePlanController.load(
        SqliteAdFreePlanStore(repo.database),
      );
      expect(plan.active, true);
      expect((await repo.load(loadData())).balance, balance);
      plan.dispose();
      await repo.close();
    },
  );
}
