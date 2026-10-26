import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/core/feedback/game_feedback.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/data/daily_catalog.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'package:caca_palavra/features/game/presentation/widgets/word_slots.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android: 2500 assets, real drags, milestones, final level and restored wallet',
    (tester) async {
      final watch = Stopwatch()..start();
      final full = await GameData.load();
      watch.stop();
      expect(full.levels, hasLength(2500));
      debugPrint('EXPANDED_CATALOG_LOAD_MS=${watch.elapsedMilliseconds}');
      final daily = await DailyCatalog.load();
      var converted = false;
      for (final pair in [
        [1, 2],
        [49, 50],
        [99, 100],
        [2499, 2500],
      ]) {
        final data = GameData(
          [for (final id in pair) full.levels[id - 1]],
          full.lexicon,
          catalogVersion: 2,
        );
        final location = path.join(
          await getDatabasesPath(),
          'expanded_levels_${pair.first}_integration.db',
        );
        // These are dedicated test databases; the player's normal save is untouched.
        await deleteDatabase(location);
        var session = await GameSessionCoordinator.create(
          data,
          await SqliteProgressRepository.open(databasePath: location),
          dailyCatalog: daily,
        );
        Future<void> mount() async {
          await tester.pumpWidget(
            WordGameApp(
              loader: () async => session,
              feedbackOutput: SilentFeedbackOutput(),
            ),
          );
          await tester.pumpAndSettle();
        }

        Future<void> tap(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        Future<void> drag(String word) async {
          final available = session.engine.state.level.tiles.toList();
          final ids = [
            for (final letter in word.split(''))
              available
                  .removeAt(available.indexWhere((t) => t.letter == letter))
                  .id,
          ];
          final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(ValueKey(ids.first))),
          );
          for (final id in ids.skip(1)) {
            await gesture.moveTo(tester.getCenter(find.byKey(ValueKey(id))));
            await tester.pump(const Duration(milliseconds: 70));
          }
          await gesture.up();
          await tester.pumpAndSettle();
        }

        await mount();
        if (!converted) {
          await binding.convertFlutterSurfaceToImage();
          converted = true;
          await tester.pumpAndSettle();
        }
        await tap(find.byKey(const ValueKey('play')));
        expect(find.text('Nível ${pair.first}'), findsOneWidget);
        await binding.takeScreenshot('nivel-${pair.first}');
        for (final word in session.engine.state.level.words) {
          await drag(word.key);
        }
        expect(session.profile.balance, 80);
        await tap(find.byKey(const ValueKey('next-level')));
        expect(session.profile.currentLevelId, pair.last);
        if (pair.last == 50) {
          expect(session.isThemeUnlocked('escola_magia'), isTrue);
        }
        if (pair.last == 100) {
          expect(session.isThemeUnlocked('refugio_neve'), isTrue);
        }
        expect(
          find.byType(WordSlots),
          findsNWidgets(session.engine.state.level.words.length),
        );
        await binding.takeScreenshot('nivel-${pair.last}');
        for (final word in session.engine.state.level.words) {
          await drag(word.key);
        }
        expect(session.profile.balance, 100);
        await tap(find.byKey(const ValueKey('next-level')));
        expect(session.profile.campaignComplete, isTrue);
        if (pair.last == 2500) {
          await binding.takeScreenshot('colecao-2500-concluida');
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        session = await GameSessionCoordinator.create(
          data,
          await SqliteProgressRepository.open(databasePath: location),
          dailyCatalog: daily,
        );
        expect(session.profile.balance, 100);
        expect(session.profile.campaignComplete, isTrue);
        await session.startOrContinue();
        expect(session.profile.balance, 100);
        await session.close();
      }
    },
  );
}
