import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:caca_palavra/core/monetization/ad_free_plan.dart';
import 'package:caca_palavra/core/preferences/player_preferences.dart';
import 'package:caca_palavra/core/theme/visual_theme_catalog.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'helpers.dart';

class ControlledThemeStore extends MemoryPreferencesStore {
  final gate = Completer<void>();
  bool fail = false;
  int writes = 0;
  @override
  Future<void> write(PlayerPreferences value) async {
    writes++;
    await gate.future;
    if (fail) throw StateError('disk unavailable');
    await super.write(value);
  }
}

void main() {
  test('all theme IDs round trip while retaining existing preferences', () {
    for (final theme in VisualTheme.values) {
      final row = PlayerPreferences(
        visualThemeId: theme.id,
        sound: false,
        introduction: Introduction.skipped,
      ).toRow();
      final restored = PlayerPreferences.fromRow(row);
      expect(restored.visualTheme, theme);
      expect(restored.sound, false);
      expect(restored.introduction, Introduction.skipped);
    }
    expect(VisualTheme.resolve('jardim_gatinho'), VisualTheme.garden);
    expect(VisualTheme.resolve('capivara_lagoa'), VisualTheme.lagoon);
    expect(VisualTheme.resolve('biblioteca_encantada'), VisualTheme.library);
    expect(VisualTheme.resolve('fundo_mar'), VisualTheme.ocean);
    expect(VisualTheme.resolve('jardim_abelhas'), VisualTheme.bees);
    expect(VisualTheme.resolve('escola_magia'), VisualTheme.magic);
    expect(VisualTheme.resolve('refugio_neve'), VisualTheme.snow);
  });

  test('missing or unknown IDs fall back without losing other preferences', () {
    for (final id in [null, 'removed_theme']) {
      final row = const PlayerPreferences(
        sound: false,
        haptics: false,
        reduceMotion: true,
        introduction: Introduction.skipped,
      ).toRow();
      row.remove('visual_theme_id');
      if (id != null) row['visual_theme_id'] = id;
      final restored = PlayerPreferences.fromRow(row);
      expect(restored.visualTheme, VisualTheme.garden);
      expect(restored.sound, false);
      expect(restored.haptics, false);
      expect(restored.reduceMotion, true);
      expect(restored.introduction, Introduction.skipped);
    }
  });

  test(
    'last choice and other preferences survive serialized rapid changes',
    () async {
      final store = ControlledThemeStore();
      final prefs = await PreferencesController.load(store);
      await prefs.selectTheme(VisualTheme.garden);
      expect(store.writes, 0);
      final first = prefs.selectTheme(VisualTheme.lagoon);
      final sound = prefs.update(prefs.value.copyWith(sound: false));
      final second = prefs.selectTheme(VisualTheme.garden);
      final last = prefs.selectTheme(VisualTheme.snow);
      expect(prefs.savingTheme, true);
      expect(prefs.themeSaved, false);
      store.gate.complete();
      await Future.wait([first, sound, second, last]);
      expect(store.writes, 4);
      final restored = await PreferencesController.load(store);
      expect(restored.value.visualTheme, VisualTheme.snow);
      expect(restored.value.sound, false);
      expect(prefs.savingTheme, false);
      expect(prefs.themeSaved, true);
      expect(prefs.error, isNull);
      prefs.dispose();
      restored.dispose();
    },
  );

  test(
    'save failure keeps session choice; retry confirms without false success',
    () async {
      final store = ControlledThemeStore()..fail = true;
      store.gate.complete();
      final prefs = await PreferencesController.load(store);
      await prefs.selectTheme(VisualTheme.lagoon);
      expect(prefs.value.visualTheme, VisualTheme.lagoon);
      expect(store.value.visualTheme, VisualTheme.garden);
      expect(prefs.error, 'Não foi possível salvar o tema. Tente novamente.');
      expect(prefs.themeSaved, false);
      store.fail = false;
      await prefs.retry();
      expect(prefs.themeSaved, true);
      expect(prefs.error, isNull);
      expect(store.value.visualTheme, VisualTheme.lagoon);
      prefs.dispose();
    },
  );

  for (final legacyVersion in [1, 3, 4, 5]) {
    test(
      'SQLite $legacyVersion → 6 preserves rounds, ledger, preferences and plan',
      () async {
        sqfliteFfiInit();
        final dir = await Directory.systemTemp.createTemp('themes-migration-');
        addTearDown(() => dir.delete(recursive: true));
        final location = '${dir.path}/game.db';
        var repo = await SqliteProgressRepository.open(
          factory: databaseFactoryFfi,
          databasePath: location,
        );
        var session = await GameSessionCoordinator.create(
          loadData(),
          repo,
          now: () => DateTime(2026, 10, 22, 12),
        );
        await session.startOrContinue();
        await session.submitWord(
          idsFor(session.engine, 'GATO'),
          session: session.engine.state.session,
        );
        await session.startDaily();
        final dailyWord = session.engine.state.level.words.first.key;
        await session.submitWord(
          idsFor(session.engine, dailyWord),
          session: session.engine.state.session,
        );
        await SqlitePreferencesStore(repo.database).write(
          const PlayerPreferences(
            sound: false,
            haptics: false,
            reduceMotion: true,
            introduction: Introduction.skipped,
          ),
        );
        await SqliteAdFreePlanStore(repo.database).activate();
        final snapshot = session.profile.toPayload();
        final ledger = await repo.database.query('coin_transactions');
        final requests = await repo.database.query('operation_requests');
        final entitlements = await repo.database.query(
          'simulated_entitlements',
        );
        // Rebuild settings using the exact pre-theme columns, not just a version label.
        await repo.database.execute(
          'ALTER TABLE app_settings RENAME TO old_settings',
        );
        await LocalGameDatabase.createSettings(repo.database, legacy: true);
        await repo.database.execute(
          'UPDATE app_settings SET sound=0, haptics=0, reduce_motion=1, introduction=\'skipped\'',
        );
        await repo.database.execute('DROP TABLE old_settings');
        if (legacyVersion < 4) {
          await repo.database.execute('DROP TABLE app_settings');
        }
        if (legacyVersion < 5) {
          await repo.database.execute('DROP TABLE simulated_entitlements');
        }
        if (legacyVersion < 2) {
          await repo.database.execute('DROP TABLE operation_requests');
        }
        await repo.database.setVersion(legacyVersion);
        await session.close();

        repo = await SqliteProgressRepository.open(
          factory: databaseFactoryFfi,
          databasePath: location,
        );
        session = await GameSessionCoordinator.create(
          loadData(),
          repo,
          now: () => DateTime(2026, 10, 22, 12),
        );
        expect(await repo.database.getVersion(), 6);
        expect(session.profile.toPayload(), snapshot);
        expect(await repo.database.query('coin_transactions'), ledger);
        if (legacyVersion >= 2) {
          expect(await repo.database.query('operation_requests'), requests);
        }
        if (legacyVersion >= 5) {
          expect(
            await repo.database.query('simulated_entitlements'),
            entitlements,
          );
        }
        final prefs = await PreferencesController.load(
          SqlitePreferencesStore(repo.database),
        );
        expect(prefs.value.visualTheme, VisualTheme.garden);
        if (legacyVersion >= 4) {
          expect(prefs.value.sound, false);
          expect(prefs.value.haptics, false);
          expect(prefs.value.reduceMotion, true);
          expect(prefs.value.introduction, Introduction.skipped);
        } else {
          expect(prefs.value.introduction, Introduction.exempted);
        }
        await prefs.selectTheme(VisualTheme.snow);
        prefs.dispose();
        await session.close();
        repo = await SqliteProgressRepository.open(
          factory: databaseFactoryFfi,
          databasePath: location,
        );
        expect(
          (await SqlitePreferencesStore(repo.database).read()).visualTheme,
          VisualTheme.snow,
        );
        expect((await repo.load(loadData())).toPayload(), snapshot);
        expect(await repo.database.query('coin_transactions'), ledger);
        await repo.close();
      },
    );
  }
}
