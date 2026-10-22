import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/core/preferences/player_preferences.dart';
import 'package:caca_palavra/core/feedback/game_feedback.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/data/daily_catalog.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';
import 'package:caca_palavra/features/game/presentation/home_screen.dart';
import 'package:caca_palavra/features/game/presentation/settings_screen.dart';
import 'package:caca_palavra/features/game/presentation/tutorial_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android stage 5: direct home, optional help, native effects, settings, rotation and database reopen',
    (tester) async {
      final location = path.join(
        await getDatabasesPath(),
        'stage5_integration.db',
      );
      await deleteDatabase(
        location,
      ); // Dedicated fixture; never the production save.
      final data = await GameData.load();
      var repo = await SqliteProgressRepository.open(databasePath: location);
      var c = await GameSessionCoordinator.create(
        data,
        repo,
        dailyCatalog: await DailyCatalog.load(),
      );
      await tester.pumpWidget(WordGameApp(loader: () async => c));
      await tester.pumpAndSettle();
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(TutorialScreen), findsNothing);
      expect(c.profile.balance, 60);
      await tap(find.byKey(const ValueKey('settings')));
      await tap(find.byKey(const ValueKey('review-tutorial')));
      expect(find.byType(TutorialScreen), findsOneWidget);
      await tap(find.byKey(const ValueKey('tutorial-continue')));
      await tap(find.byKey(const ValueKey('tutorial-continue')));
      await tap(find.byKey(const ValueKey('shuffle')));
      await tap(find.byKey(const ValueKey('tutorial-continue')));
      await tap(find.byKey(const ValueKey('tutorial-finish')));
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tap(find.byTooltip('Fechar configurações'));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        (await SqlitePreferencesStore(repo.database).read()).introduction,
        Introduction.unseen,
      );
      expect((await repo.database.query('coin_transactions')).length, 1);
      await tap(find.byKey(const ValueKey('settings')));
      await tap(find.byKey(const ValueKey('setting-sound')));
      await tap(find.byKey(const ValueKey('setting-haptics')));
      await tap(find.byKey(const ValueKey('setting-motion')));
      await tap(find.byTooltip('Fechar configurações'));
      await tap(find.byKey(const ValueKey('play')));
      final controller = tester
          .widget<GameScreen>(find.byType(GameScreen))
          .controller;
      final target = c.engine.state.level.words.first;
      final tiles = c.engine.state.level.tiles.toList();
      final ids = [
        for (final letter in target.key.split(''))
          tiles.removeAt(tiles.indexWhere((t) => t.letter == letter)).id,
      ];
      await tester.ensureVisible(find.byKey(const ValueKey('letter-wheel')));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ValueKey(ids.first))),
      );
      await gesture.moveTo(tester.getCenter(find.byKey(ValueKey(ids[1]))));
      await tester.pump();
      await binding.setSurfaceSize(const Size(915, 412));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.dragging, false);
      expect(c.engine.state.targets, isEmpty);
      await binding.setSurfaceSize(null);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('letter-wheel')));
      await tester.pumpAndSettle();
      final real = await tester.startGesture(
        tester.getCenter(find.byKey(ValueKey(ids.first))),
      );
      for (final id in ids.skip(1)) {
        await real.moveTo(tester.getCenter(find.byKey(ValueKey(id))));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await real.up();
      await tester.pumpAndSettle();
      expect(c.engine.state.targets, {target.key});
      await tap(find.byKey(const ValueKey('settings')));
      final before = c.profile.toPayload();
      await tap(find.byKey(const ValueKey('review-tutorial')));
      await tap(find.byKey(const ValueKey('skip-tutorial')));
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tap(find.byTooltip('Fechar configurações'));
      expect(c.profile.toPayload(), before);
      // Smoke-check native preparation and each cue without asserting perceived sound or vibration.
      final output = AndroidFeedbackOutput();
      await output.prepare();
      for (final cue in FeedbackCue.values) {
        await output.sound(cue);
      }
      await output.haptic(success: true);
      await output.stop();
      final snapshot = c.profile.toPayload();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      repo = await SqliteProgressRepository.open(databasePath: location);
      c = await GameSessionCoordinator.create(data, repo);
      final prefs = await SqlitePreferencesStore(repo.database).read();
      expect(prefs.sound, false);
      expect(prefs.haptics, false);
      expect(prefs.reduceMotion, true);
      expect(prefs.introduction, Introduction.unseen);
      expect(c.profile.toPayload(), snapshot);
      await c.close();
    },
  );
}
