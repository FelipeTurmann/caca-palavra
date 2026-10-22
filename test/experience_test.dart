import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:caca_palavra/core/preferences/player_preferences.dart';
import 'package:caca_palavra/core/feedback/game_feedback.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/wheel_gesture.dart';
import 'campaign_widget_test.dart' show MemoryProgressRepository;
import 'helpers.dart';

class RecordingOutput implements FeedbackOutput {
  final sounds = <FeedbackCue>[];
  final pulses = <bool>[];
  int stops = 0;
  bool unavailable = false;
  @override
  Future<void> prepare() async {
    if (unavailable) throw StateError('asset unavailable');
  }

  @override
  Future<void> sound(FeedbackCue cue) async {
    sounds.add(cue);
    if (unavailable) throw StateError('no audio');
  }

  @override
  Future<void> haptic({required bool success}) async {
    pulses.add(success);
    if (unavailable) throw StateError('no motor');
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {}
}

class FaultyPreferencesStore extends MemoryPreferencesStore {
  FaultyPreferencesStore() : super(const PlayerPreferences());
  bool fail = false;
  final written = <PlayerPreferences>[];
  @override
  Future<void> write(PlayerPreferences value) async {
    await Future<void>.delayed(Duration.zero);
    if (fail) throw StateError('disk full');
    written.add(value);
    await super.write(value);
  }
}

void main() {
  test(
    'preference writes are ordered and a failure keeps the session choice without replacing confirmed data',
    () async {
      final store = FaultyPreferencesStore();
      final preferences = await PreferencesController.load(store);
      final first = preferences.update(
        preferences.value.copyWith(sound: false),
      );
      final second = preferences.update(
        preferences.value.copyWith(haptics: false),
      );
      final third = preferences.update(
        preferences.value.copyWith(reduceMotion: true),
      );
      await Future.wait([first, second, third]);
      expect(store.written.map((v) => v.reduceMotion), [false, false, true]);
      expect((await store.read()).sound, false);
      store.fail = true;
      await preferences.update(preferences.value.copyWith(sound: true));
      expect(preferences.value.sound, true);
      expect(preferences.error, contains('Não foi possível salvar'));
      expect((await store.read()).sound, false);
      store.fail = false;
      await preferences.retry();
      expect((await store.read()).sound, true);
      expect(preferences.error, isNull);
      preferences.dispose();
    },
  );

  test(
    'sound and haptics are independent, selection is throttled and transient feedback is never queued',
    () async {
      final preferences = PreferencesController(
        MemoryPreferencesStore(),
        const PlayerPreferences(),
      );
      final output = RecordingOutput();
      var time = Duration.zero;
      final effects = FeedbackCoordinator(
        preferences,
        output,
        elapsed: () => time,
      );
      effects.emit(FeedbackCue.select);
      effects.emit(FeedbackCue.select);
      expect(output.sounds, [FeedbackCue.select]);
      time += const Duration(milliseconds: 51);
      effects.emit(FeedbackCue.undo);
      expect(output.pulses.length, 1);
      await preferences.update(preferences.value.copyWith(sound: false));
      expect(output.stops, 1);
      effects.emit(FeedbackCue.correct, id: 'target:1');
      effects.emit(FeedbackCue.correct, id: 'target:1');
      expect(output.sounds.length, 2);
      expect(output.pulses.length, 2);
      await preferences.update(
        preferences.value.copyWith(sound: true, haptics: false),
      );
      effects.emit(FeedbackCue.victory, id: 'victory:1');
      effects.emit(FeedbackCue.select);
      expect(output.sounds.last, FeedbackCue.victory);
      expect(output.pulses.length, 2);
      effects.suspend();
      effects.emit(FeedbackCue.coins, id: 'shop:old');
      effects.resume();
      effects.emit(FeedbackCue.coins, id: 'shop:old');
      expect(output.sounds.last, FeedbackCue.victory);
      effects.dispose();
      preferences.dispose();
    },
  );

  test(
    'confirmed commands prioritize final victory, ignore repeats and tolerate missing media',
    () async {
      final c = await GameSessionCoordinator.create(
        loadData(),
        MemoryProgressRepository(500),
      );
      await c.startOrContinue();
      final output = RecordingOutput();
      final controller = GameController(
        c.engine,
        coordinator: c,
        feedbackOutput: output,
      );
      void drag(String word) {
        final geometry = WheelGeometry(300, controller.state.order);
        controller.configureGeometry(geometry);
        final ids = idsFor(c.engine, word);
        controller.down(1, geometry.centers[ids.first]!);
        for (final id in ids.skip(1)) {
          controller.move(1, geometry.centers[id]!);
        }
        controller.up(1, geometry.centers[ids.last]!);
      }

      final first = c.engine.state.level.words.first.key;
      drag(first);
      await controller.waitIdle();
      expect(output.sounds.where((e) => e == FeedbackCue.correct).length, 1);
      drag(first);
      await controller.waitIdle();
      expect(output.sounds.where((e) => e == FeedbackCue.correct).length, 1);
      output.unavailable = true;
      await controller.effects.prepare();
      for (final word in c.engine.state.level.words.skip(1)) {
        drag(word.key);
        await controller.waitIdle();
      }
      expect(output.sounds.where((e) => e == FeedbackCue.victory).length, 1);
      expect(output.sounds.where((e) => e == FeedbackCue.coins), isEmpty);
      expect(c.profile.balance, 520);
      controller.refresh();
      controller.suspendPresentation();
      controller.effects.resume();
      expect(output.sounds.where((e) => e == FeedbackCue.victory).length, 1);
      controller.dispose();
      await c.close();
    },
  );

  test(
    'moving within a tile, second pointers and cancelling never create extra selection effects',
    () {
      final output = RecordingOutput();
      final controller = GameController(makeEngine(), feedbackOutput: output);
      final geometry = WheelGeometry(300, controller.state.order);
      controller.configureGeometry(geometry);
      final point = geometry.centers.values.first;
      controller.down(1, point);
      controller.down(2, point);
      controller.move(1, point);
      controller.move(2, geometry.centers.values.last);
      controller.cancelPointer(2);
      controller.cancelPointer(1);
      expect(output.sounds, [FeedbackCue.select]);
      expect(output.pulses, [false]);
      controller.dispose();
    },
  );

  group('real SQLite preferences and version 3 migration', () {
    late Directory dir;
    late String location;
    setUp(() async {
      sqfliteFfiInit();
      dir = await Directory.systemTemp.createTemp('experience-');
      location = '${dir.path}/game.db';
    });
    tearDown(() async {
      await dir.delete(recursive: true);
    });
    for (final point in [
      StorageFaultPoint.beforeCommit,
      StorageFaultPoint.afterCommit,
    ]) {
      test(
        'success feedback waits for confirmed recovery at $point and retry consumes it once',
        () async {
          final repo = await SqliteProgressRepository.open(
            factory: databaseFactoryFfi,
            databasePath: location,
          );
          final session = await GameSessionCoordinator.create(loadData(), repo);
          await session.startOrContinue();
          final output = RecordingOutput();
          final controller = GameController(
            session.engine,
            coordinator: session,
            feedbackOutput: output,
          );
          var fired = false;
          repo.fault = (p) {
            if (p == point && !fired) {
              fired = true;
              throw StateError('power loss');
            }
          };
          final geometry = WheelGeometry(300, controller.state.order);
          controller.configureGeometry(geometry);
          final ids = idsFor(
            session.engine,
            session.engine.state.level.words.first.key,
          );
          controller.down(1, geometry.centers[ids.first]!);
          for (final id in ids.skip(1)) {
            controller.move(1, geometry.centers[id]!);
          }
          controller.up(1, geometry.centers[ids.last]!);
          await controller.waitIdle();
          if (point == StorageFaultPoint.beforeCommit) {
            expect(controller.saveError, isNotNull);
            expect(
              output.sounds.where((c) => c == FeedbackCue.correct),
              isEmpty,
            );
          } else {
            // The coordinator immediately resolves an already committed receipt.
            expect(controller.saveError, isNull);
            expect(
              output.sounds.where((c) => c == FeedbackCue.correct).length,
              1,
            );
          }
          repo.fault = null;
          await controller.retrySave();
          await controller.retrySave();
          expect(
            output.sounds.where((c) => c == FeedbackCue.correct).length,
            1,
          );
          expect(session.engine.state.targets.length, 1);
          expect(session.profile.balance, 60);
          controller.dispose();
          await session.close();
        },
      );
    }
    test(
      'fresh onboarding persists all states, preferences and a single welcome grant after reopen',
      () async {
        var repo = await SqliteProgressRepository.open(
          factory: databaseFactoryFfi,
          databasePath: location,
        );
        var session = await GameSessionCoordinator.create(loadData(), repo);
        var prefs = await PreferencesController.load(
          SqlitePreferencesStore(repo.database),
        );
        expect(prefs.value.introduction, Introduction.unseen);
        await prefs.update(
          prefs.value.copyWith(
            sound: false,
            haptics: false,
            reduceMotion: true,
            introduction: Introduction.inProgress,
          ),
        );
        prefs.dispose();
        await session.close();
        repo = await SqliteProgressRepository.open(
          factory: databaseFactoryFfi,
          databasePath: location,
        );
        session = await GameSessionCoordinator.create(loadData(), repo);
        prefs = await PreferencesController.load(
          SqlitePreferencesStore(repo.database),
        );
        expect(prefs.value.needsIntroduction, true);
        expect(prefs.value.sound, false);
        expect(prefs.value.haptics, false);
        expect(prefs.value.reduceMotion, true);
        await prefs.update(
          prefs.value.copyWith(introduction: Introduction.skipped),
        );
        expect(
          (await SqlitePreferencesStore(
            repo.database,
          ).read()).needsIntroduction,
          false,
        );
        expect(session.profile.balance, 60);
        expect((await repo.database.query('coin_transactions')).length, 1);
        prefs.dispose();
        await session.close();
      },
    );
    for (final started in [false, true]) {
      test(
        'existing profile (started=$started) is exempted without changing wallet or pending result',
        () async {
          var repo = await SqliteProgressRepository.open(
            factory: databaseFactoryFfi,
            databasePath: location,
          );
          var session = await GameSessionCoordinator.create(loadData(), repo);
          if (started) {
            await session.startOrContinue();
            for (final word in session.engine.state.level.words) {
              await session.submitWord(
                idsFor(session.engine, word.key),
                session: session.engine.state.session,
              );
            }
          }
          final before = session.profile.toPayload();
          final ledger = await repo.database.query('coin_transactions');
          await repo.database.execute('DROP TABLE app_settings');
          await repo.database.setVersion(3);
          await session.close();
          repo = await SqliteProgressRepository.open(
            factory: databaseFactoryFfi,
            databasePath: location,
          );
          session = await GameSessionCoordinator.create(loadData(), repo);
          final prefs = await SqlitePreferencesStore(repo.database).read();
          expect(prefs.introduction, Introduction.exempted);
          expect(session.profile.toPayload(), before);
          expect(await repo.database.query('coin_transactions'), ledger);
          expect(await repo.database.getVersion(), LocalGameDatabase.version);
          await session.close();
        },
      );
    }
  });
}
