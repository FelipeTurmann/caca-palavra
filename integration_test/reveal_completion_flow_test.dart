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
import 'package:caca_palavra/features/game/data/daily_catalog.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android: last cell from extra or paid hint completes campaign and daily',
    (tester) async {
      final data = await GameData.load();
      var converted = false;
      var screenshot = 0;
      for (final daily in [false, true]) {
        for (final extra in [false, true]) {
          final label =
              '${daily ? 'diario' : 'campanha'}-${extra ? 'extra' : 'dica'}';
          final location = path.join(
            await getDatabasesPath(),
            'hint_completion_$label.db',
          );
          // Only the named test fixture is reset; production saves are untouched.
          await deleteDatabase(location);
          final repo = await SqliteProgressRepository.open(
            databasePath: location,
            initialBalance: 120,
          );
          final session = await GameSessionCoordinator.create(
            data,
            repo,
            dailyCatalog: DailyCatalog(
              version: 1,
              baseDate: '2026-01-01',
              levels: [data.levels.first],
              lexicon: data.lexicon,
            ),
          );
          await SqlitePreferencesStore(repo.database).write(
            PlayerPreferences(
              visualThemeId: VisualTheme.snow.id,
              reduceMotion: true,
            ),
          );
          List<String> idsFor(String key) {
            final tiles = session.engine.state.level.tiles.toList();
            return [
              for (final letter in key.split(''))
                tiles
                    .removeAt(tiles.indexWhere((tile) => tile.letter == letter))
                    .id,
            ];
          }

          if (daily) {
            await session.startDaily();
          } else {
            await session.startOrContinue();
          }
          for (final key in ['GOTA', 'ATO']) {
            await session.submitWord(
              idsFor(key),
              session: session.engine.state.session,
            );
          }
          for (var i = 0; i < 3; i++) {
            await session.purchaseHint(operationId: 'prepare-$i');
          }
          await tester.pumpWidget(
            WordGameApp(
              loader: () async => session,
              feedbackOutput: SilentFeedbackOutput(),
            ),
          );
          await tester.pumpAndSettle();
          if (!converted) {
            await binding.convertFlutterSurfaceToImage();
            converted = true;
            await tester.pumpAndSettle();
          }
          Future<void> tap(Finder finder) async {
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            await tester.tap(finder);
            await tester.pumpAndSettle();
          }

          await tap(find.byKey(ValueKey(daily ? 'daily-play' : 'play')));
          final controller = tester
              .widget<GameScreen>(find.byType(GameScreen))
              .controller;
          expect(session.engine.state.targets, {'GOTA', 'ATO'});
          expect(find.text('2 de 3 palavras'), findsOneWidget);
          await binding.takeScreenshot(
            '${(++screenshot).toString().padLeft(2, '0')}-antes-$label',
          );
          if (extra) {
            final ids = idsFor('TOGA');
            final gesture = await tester.startGesture(
              tester.getCenter(find.byKey(ValueKey(ids.first))),
            );
            for (final id in ids.skip(1)) {
              await gesture.moveTo(tester.getCenter(find.byKey(ValueKey(id))));
              await tester.pump(const Duration(milliseconds: 60));
            }
            await gesture.up();
            await tester.pumpAndSettle();
          } else {
            await tap(find.byKey(const ValueKey('hint')));
            expect(
              find.textContaining('Se for a última letra'),
              findsOneWidget,
            );
            await tap(find.byKey(const ValueKey('confirm-hint')));
          }
          await tester.pump(
            GameTiming.completion + const Duration(milliseconds: 100),
          );
          await tester.pumpAndSettle();
          expect(session.engine.state.targets, {'GATO', 'GOTA', 'ATO'});
          expect(session.engine.state.phase, RoundPhase.completed);
          expect(controller.freshVictory, true);
          expect(find.byKey(const ValueKey('next-level')), findsOneWidget);
          expect(
            controller.balance,
            extra ? (daily ? 80 : 60) : (daily ? 50 : 20),
          );
          await binding.takeScreenshot(
            '${(++screenshot).toString().padLeft(2, '0')}-resultado-$label',
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      }
    },
  );
}
