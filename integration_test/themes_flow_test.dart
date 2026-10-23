import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/core/feedback/game_feedback.dart';
import 'package:caca_palavra/core/preferences/player_preferences.dart';
import 'package:caca_palavra/core/theme/visual_theme_catalog.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/data/daily_catalog.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';
import 'package:caca_palavra/features/game/presentation/home_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android themes: choose all seven, drag, resume both modes and restore snow',
    (tester) async {
      final location = path.join(
        await getDatabasesPath(),
        'themes_integration.db',
      );
      // Dedicated fixture only. Never delete the player's normal database.
      await deleteDatabase(location);
      final data = await GameData.load();
      final daily = await DailyCatalog.load();
      var repo = await SqliteProgressRepository.open(databasePath: location);
      var session = await GameSessionCoordinator.create(
        data,
        repo,
        dailyCatalog: daily,
      );
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      Future<void> mount() async {
        await tester.pumpWidget(
          WordGameApp(
            loader: () async => session,
            feedbackOutput: SilentFeedbackOutput(),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> connectWord(String word) async {
        final tiles = session.engine.state.level.tiles.toList();
        final ids = [
          for (final letter in word.split(''))
            tiles
                .removeAt(tiles.indexWhere((tile) => tile.letter == letter))
                .id,
        ];
        await tester.ensureVisible(find.byKey(const ValueKey('letter-wheel')));
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(ValueKey(ids.first))),
        );
        for (final id in ids.skip(1)) {
          await gesture.moveTo(tester.getCenter(find.byKey(ValueKey(id))));
          await tester.pump(const Duration(milliseconds: 60));
        }
        await gesture.up();
        await tester.pumpAndSettle();
      }

      await mount();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      final before = session.profile.toPayload();
      final ledger = await repo.database.query('coin_transactions');
      await tap(find.byKey(const ValueKey('home-themes')));
      await tap(find.byKey(const ValueKey('use-theme-capivara_lagoa')));
      expect(
        (await SqlitePreferencesStore(repo.database).read()).visualTheme,
        VisualTheme.lagoon,
      );
      await binding.takeScreenshot('01-seletor-capivara');
      await tap(find.byTooltip('Fechar temas'));
      expect(session.profile.toPayload(), before);
      expect(await repo.database.query('coin_transactions'), ledger);
      // Return the scroll to the top to inspect the entire initial composition.
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 1600),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('02-home-capivara');
      await tap(find.byKey(const ValueKey('play')));
      final controller = tester
          .widget<GameScreen>(find.byType(GameScreen))
          .controller;
      final word = session.engine.state.level.words.first;
      await connectWord(word.key);
      expect(session.engine.state.targets, contains(word.key));
      await binding.takeScreenshot('03-partida-capivara');
      controller.leaveToHome();
      await tester.pumpAndSettle();
      await tap(find.byKey(const ValueKey('daily-play')));
      expect(
        VisualThemeScope.of(tester.element(find.byType(GameScreen))),
        VisualTheme.lagoon,
      );
      final snapshot = session.profile.toPayload();
      final confirmedLedger = await repo.database.query('coin_transactions');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      repo = await SqliteProgressRepository.open(databasePath: location);
      session = await GameSessionCoordinator.create(
        data,
        repo,
        dailyCatalog: daily,
      );
      await mount();
      expect(find.text('Atual: Capivara na lagoa'), findsOneWidget);
      expect(session.profile.toPayload(), snapshot);
      expect(await repo.database.query('coin_transactions'), confirmedLedger);
      await tap(find.byKey(const ValueKey('home-themes')));
      await tap(find.byKey(const ValueKey('use-theme-jardim_gatinho')));
      await tap(find.byTooltip('Fechar temas'));
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 1600),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('04-home-jardim');
      expect(session.profile.toPayload(), snapshot);
      expect(
        tester
            .widget<HomeScreen>(find.byType(HomeScreen))
            .controller
            .preferences
            .value
            .visualTheme,
        VisualTheme.garden,
      );
      await tap(find.byKey(const ValueKey('play')));
      final gardenController = tester
          .widget<GameScreen>(find.byType(GameScreen))
          .controller;
      expect(
        VisualThemeScope.of(tester.element(find.byType(GameScreen))),
        VisualTheme.garden,
      );
      final gardenWord = session.engine.state.level.words.firstWhere(
        (word) => !session.engine.state.targets.contains(word.key),
      );
      await connectWord(gardenWord.key);
      expect(session.engine.state.targets, contains(gardenWord.key));
      await binding.takeScreenshot('05-partida-jardim');
      final found = session.engine.state.targets.toSet();
      await tap(find.byKey(const ValueKey('shuffle')));
      expect(session.engine.state.targets, found);
      gardenController.leaveToHome();
      await tester.pumpAndSettle();
      final gardenSnapshot = session.profile.toPayload();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      repo = await SqliteProgressRepository.open(databasePath: location);
      session = await GameSessionCoordinator.create(
        data,
        repo,
        dailyCatalog: daily,
      );
      await mount();
      expect(find.text('Atual: Jardim do Gatinho'), findsOneWidget);
      expect(session.profile.toPayload(), gardenSnapshot);
      final libraryLedgerBefore = await repo.database.query(
        'coin_transactions',
      );
      await tap(find.byKey(const ValueKey('home-themes')));
      await tap(find.byKey(const ValueKey('use-theme-biblioteca_encantada')));
      expect(
        (await SqlitePreferencesStore(repo.database).read()).visualTheme,
        VisualTheme.library,
      );
      await binding.takeScreenshot('06-seletor-biblioteca');
      await tap(find.byTooltip('Fechar temas'));
      expect(session.profile.toPayload(), gardenSnapshot);
      expect(
        await repo.database.query('coin_transactions'),
        libraryLedgerBefore,
      );
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 1600),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('07-home-biblioteca');
      // Resume the existing daily round with the new art, preserving campaign.
      await tap(find.byKey(const ValueKey('daily-play')));
      expect(
        VisualThemeScope.of(tester.element(find.byType(GameScreen))),
        VisualTheme.library,
      );
      final libraryWord = session.engine.state.level.words.firstWhere(
        (word) => !session.engine.state.targets.contains(word.key),
      );
      await connectWord(libraryWord.key);
      expect(session.engine.state.targets, contains(libraryWord.key));
      await binding.takeScreenshot('08-partida-biblioteca');
      final libraryFound = session.engine.state.targets.toSet();
      await tap(find.byKey(const ValueKey('shuffle')));
      expect(session.engine.state.targets, libraryFound);
      tester
          .widget<GameScreen>(find.byType(GameScreen))
          .controller
          .leaveToHome();
      await tester.pumpAndSettle();
      final librarySnapshot = session.profile.toPayload();
      final libraryLedger = await repo.database.query('coin_transactions');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      repo = await SqliteProgressRepository.open(databasePath: location);
      session = await GameSessionCoordinator.create(
        data,
        repo,
        dailyCatalog: daily,
      );
      await mount();
      expect(find.text('Atual: Biblioteca encantada'), findsOneWidget);
      expect(session.profile.toPayload(), librarySnapshot);
      expect(await repo.database.query('coin_transactions'), libraryLedger);
      await tap(find.byKey(const ValueKey('home-themes')));
      await tap(find.byKey(const ValueKey('use-theme-fundo_mar')));
      expect(
        (await SqlitePreferencesStore(repo.database).read()).visualTheme,
        VisualTheme.ocean,
      );
      await binding.takeScreenshot('09-seletor-fundo-mar');
      await tap(find.byTooltip('Fechar temas'));
      expect(session.profile.toPayload(), librarySnapshot);
      expect(await repo.database.query('coin_transactions'), libraryLedger);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 1600),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('10-home-fundo-mar');
      await tap(find.byKey(const ValueKey('play')));
      expect(
        VisualThemeScope.of(tester.element(find.byType(GameScreen))),
        VisualTheme.ocean,
      );
      expect(
        session.engine.state.targets,
        containsAll([word.key, gardenWord.key]),
      );
      tester
          .widget<GameScreen>(find.byType(GameScreen))
          .controller
          .leaveToHome();
      await tester.pumpAndSettle();
      await tap(find.byKey(const ValueKey('daily-play')));
      expect(session.engine.state.targets, contains(libraryWord.key));
      expect(
        VisualThemeScope.of(tester.element(find.byType(GameScreen))),
        VisualTheme.ocean,
      );
      final oceanWord = session.engine.state.level.words.firstWhere(
        (word) => !session.engine.state.targets.contains(word.key),
      );
      await connectWord(oceanWord.key);
      expect(session.engine.state.targets, contains(oceanWord.key));
      await binding.takeScreenshot('11-partida-fundo-mar');
      final oceanFound = session.engine.state.targets.toSet();
      await tap(find.byKey(const ValueKey('shuffle')));
      expect(session.engine.state.targets, oceanFound);
      tester
          .widget<GameScreen>(find.byType(GameScreen))
          .controller
          .leaveToHome();
      await tester.pumpAndSettle();
      final oceanSnapshot = session.profile.toPayload();
      final oceanLedger = await repo.database.query('coin_transactions');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      repo = await SqliteProgressRepository.open(databasePath: location);
      session = await GameSessionCoordinator.create(
        data,
        repo,
        dailyCatalog: daily,
      );
      await mount();
      expect(find.text('Atual: Fundo do mar'), findsOneWidget);
      expect(session.profile.toPayload(), oceanSnapshot);
      expect(await repo.database.query('coin_transactions'), oceanLedger);
      await tap(find.byKey(const ValueKey('daily-play')));
      expect(session.engine.state.targets, oceanFound);
      tester
          .widget<GameScreen>(find.byType(GameScreen))
          .controller
          .leaveToHome();
      await tester.pumpAndSettle();
      final beforeBees = session.profile.toPayload();
      final ledgerBeforeBees = await repo.database.query('coin_transactions');
      await tap(find.byKey(const ValueKey('home-themes')));
      await tap(find.byKey(const ValueKey('use-theme-jardim_abelhas')));
      expect(
        (await SqlitePreferencesStore(repo.database).read()).visualTheme,
        VisualTheme.bees,
      );
      await binding.takeScreenshot('12-seletor-jardim-abelhas');
      await tap(find.byTooltip('Fechar temas'));
      expect(session.profile.toPayload(), beforeBees);
      expect(await repo.database.query('coin_transactions'), ledgerBeforeBees);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 1600),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('13-home-jardim-abelhas');
      await tap(find.byKey(const ValueKey('play')));
      expect(
        VisualThemeScope.of(tester.element(find.byType(GameScreen))),
        VisualTheme.bees,
      );
      expect(
        session.engine.state.targets,
        containsAll([word.key, gardenWord.key]),
      );
      // Finish the existing campaign round, then exercise a fresh live wheel.
      final lastCampaignWord = session.engine.state.level.words.firstWhere(
        (word) => !session.engine.state.targets.contains(word.key),
      );
      await connectWord(lastCampaignWord.key);
      expect(find.byKey(const ValueKey('next-level')), findsOneWidget);
      await tap(find.byKey(const ValueKey('next-level')));
      final beeWord = session.engine.state.level.words.first;
      await connectWord(beeWord.key);
      expect(session.engine.state.targets, contains(beeWord.key));
      await binding.takeScreenshot('14-partida-jardim-abelhas');
      final beeFound = session.engine.state.targets.toSet();
      await tap(find.byKey(const ValueKey('shuffle')));
      expect(session.engine.state.targets, beeFound);
      tester
          .widget<GameScreen>(find.byType(GameScreen))
          .controller
          .leaveToHome();
      await tester.pumpAndSettle();
      await tap(find.byKey(const ValueKey('daily-play')));
      expect(session.engine.state.targets, oceanFound);
      expect(
        VisualThemeScope.of(tester.element(find.byType(GameScreen))),
        VisualTheme.bees,
      );
      tester
          .widget<GameScreen>(find.byType(GameScreen))
          .controller
          .leaveToHome();
      await tester.pumpAndSettle();
      final beeSnapshot = session.profile.toPayload();
      final beeLedger = await repo.database.query('coin_transactions');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      repo = await SqliteProgressRepository.open(databasePath: location);
      session = await GameSessionCoordinator.create(
        data,
        repo,
        dailyCatalog: daily,
      );
      await mount();
      expect(find.text('Atual: Jardim das abelhas'), findsOneWidget);
      expect(session.profile.toPayload(), beeSnapshot);
      expect(await repo.database.query('coin_transactions'), beeLedger);
      await tap(find.byKey(const ValueKey('play')));
      expect(session.engine.state.targets, beeFound);
      tester
          .widget<GameScreen>(find.byType(GameScreen))
          .controller
          .leaveToHome();
      await tester.pumpAndSettle();
      final beforeMagic = session.profile.toPayload();
      final ledgerBeforeMagic = await repo.database.query('coin_transactions');
      await tap(find.byKey(const ValueKey('home-themes')));
      await tap(find.byKey(const ValueKey('use-theme-escola_magia')));
      expect(
        (await SqlitePreferencesStore(repo.database).read()).visualTheme,
        VisualTheme.magic,
      );
      await binding.takeScreenshot('15-seletor-escola-magia');
      await tap(find.byTooltip('Fechar temas'));
      expect(session.profile.toPayload(), beforeMagic);
      expect(await repo.database.query('coin_transactions'), ledgerBeforeMagic);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 1600),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('16-home-escola-magia');
      await tap(find.byKey(const ValueKey('play')));
      expect(session.engine.state.targets, beeFound);
      expect(
        VisualThemeScope.of(tester.element(find.byType(GameScreen))),
        VisualTheme.magic,
      );
      final magicWord = session.engine.state.level.words.firstWhere(
        (word) => !session.engine.state.targets.contains(word.key),
      );
      await connectWord(magicWord.key);
      expect(session.engine.state.targets, contains(magicWord.key));
      await binding.takeScreenshot('17-partida-escola-magia');
      final magicFound = session.engine.state.targets.toSet();
      await tap(find.byKey(const ValueKey('shuffle')));
      expect(session.engine.state.targets, magicFound);
      tester
          .widget<GameScreen>(find.byType(GameScreen))
          .controller
          .leaveToHome();
      await tester.pumpAndSettle();
      await tap(find.byKey(const ValueKey('daily-play')));
      expect(session.engine.state.targets, oceanFound);
      expect(
        VisualThemeScope.of(tester.element(find.byType(GameScreen))),
        VisualTheme.magic,
      );
      tester
          .widget<GameScreen>(find.byType(GameScreen))
          .controller
          .leaveToHome();
      await tester.pumpAndSettle();
      final magicSnapshot = session.profile.toPayload();
      final magicLedger = await repo.database.query('coin_transactions');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      repo = await SqliteProgressRepository.open(databasePath: location);
      session = await GameSessionCoordinator.create(
        data,
        repo,
        dailyCatalog: daily,
      );
      await mount();
      expect(find.text('Atual: Escola de magia'), findsOneWidget);
      expect(session.profile.toPayload(), magicSnapshot);
      expect(await repo.database.query('coin_transactions'), magicLedger);
      await tap(find.byKey(const ValueKey('play')));
      expect(session.engine.state.targets, magicFound);
      tester
          .widget<GameScreen>(find.byType(GameScreen))
          .controller
          .leaveToHome();
      await tester.pumpAndSettle();
      final beforeSnow = session.profile.toPayload();
      final ledgerBeforeSnow = await repo.database.query('coin_transactions');
      await tap(find.byKey(const ValueKey('home-themes')));
      await tap(find.byKey(const ValueKey('use-theme-refugio_neve')));
      expect(
        (await SqlitePreferencesStore(repo.database).read()).visualTheme,
        VisualTheme.snow,
      );
      await binding.takeScreenshot('18-seletor-refugio-neve');
      await tap(find.byTooltip('Fechar temas'));
      expect(session.profile.toPayload(), beforeSnow);
      expect(await repo.database.query('coin_transactions'), ledgerBeforeSnow);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 1600),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('19-home-refugio-neve');
      await tap(find.byKey(const ValueKey('play')));
      expect(session.engine.state.targets, magicFound);
      expect(
        VisualThemeScope.of(tester.element(find.byType(GameScreen))),
        VisualTheme.snow,
      );
      // Finish the resumed campaign round, then drag on a fresh icy wheel.
      final lastSnowRoundWord = session.engine.state.level.words.firstWhere(
        (word) => !session.engine.state.targets.contains(word.key),
      );
      await connectWord(lastSnowRoundWord.key);
      expect(find.byKey(const ValueKey('next-level')), findsOneWidget);
      await tap(find.byKey(const ValueKey('next-level')));
      final snowWord = session.engine.state.level.words.first;
      await connectWord(snowWord.key);
      expect(session.engine.state.targets, contains(snowWord.key));
      await binding.takeScreenshot('20-partida-refugio-neve');
      final snowFound = session.engine.state.targets.toSet();
      await tap(find.byKey(const ValueKey('shuffle')));
      expect(session.engine.state.targets, snowFound);
      tester
          .widget<GameScreen>(find.byType(GameScreen))
          .controller
          .leaveToHome();
      await tester.pumpAndSettle();
      await tap(find.byKey(const ValueKey('daily-play')));
      expect(session.engine.state.targets, oceanFound);
      expect(
        VisualThemeScope.of(tester.element(find.byType(GameScreen))),
        VisualTheme.snow,
      );
      tester
          .widget<GameScreen>(find.byType(GameScreen))
          .controller
          .leaveToHome();
      await tester.pumpAndSettle();
      final snowSnapshot = session.profile.toPayload();
      final snowLedger = await repo.database.query('coin_transactions');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      repo = await SqliteProgressRepository.open(databasePath: location);
      session = await GameSessionCoordinator.create(
        data,
        repo,
        dailyCatalog: daily,
      );
      await mount();
      expect(find.text('Atual: Refúgio na neve'), findsOneWidget);
      expect(session.profile.toPayload(), snowSnapshot);
      expect(await repo.database.query('coin_transactions'), snowLedger);
      await tap(find.byKey(const ValueKey('play')));
      expect(session.engine.state.targets, snowFound);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
