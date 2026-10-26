import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/core/feedback/game_feedback.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';
import 'package:caca_palavra/features/game/presentation/widgets/mascot_help.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android mascot: speech, selected line, payment, free reread, theme and restart',
    (tester) async {
      final location = path.join(
        await getDatabasesPath(),
        'mascot_hint_integration.db',
      );
      // Dedicated fixture only. Never reset the player's production database.
      await deleteDatabase(location);
      final data = await GameData.load();
      var repo = await SqliteProgressRepository.open(
        databasePath: location,
        initialBalance: 890,
      );
      var session = await GameSessionCoordinator.create(data, repo);
      // The library is bought before this hint-only fixture begins.
      await session.purchaseTheme('biblioteca_encantada');
      Future<void> mount() async {
        await tester.pumpWidget(
          WordGameApp(
            loader: () async => session,
            feedbackOutput: SilentFeedbackOutput(),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> settle() async {
        await tester.pump();
        final choosing = tester
            .widgetList<MascotHelp>(find.byType(MascotHelp))
            .any(
              (help) =>
                  help.controller.mascotOpen && help.controller.mascotChoosing,
            );
        if (choosing) {
          await tester.pump(const Duration(milliseconds: 500));
        } else {
          await tester.pumpAndSettle();
        }
      }

      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await settle();
        await tester.tap(finder);
        await settle();
      }

      Future<void> closeSpeech() => tap(
        find.descendant(
          of: find.byType(MascotHelp),
          matching: find.text('Fechar'),
        ),
      );
      await mount();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await tap(find.byKey(const ValueKey('play')));
      GameController controller() =>
          tester.widget<GameScreen>(find.byType(GameScreen)).controller;
      expect(find.byTooltip('Dica · 50 moedas'), findsOneWidget);
      expect(find.byTooltip('Super Dica · 120 moedas'), findsOneWidget);
      expect(find.byTooltip('Dica do mascote · 70 moedas'), findsOneWidget);
      await binding.takeScreenshot('00-botao-dica-mascote');
      final wheelBefore = tester.getRect(
        find.byKey(const ValueKey('letter-wheel')),
      );
      await tap(find.byKey(const ValueKey('mascot-help')));
      expect(find.text(mascotInvitation), findsOneWidget);
      final largeMascot = tester.getSize(
        find.byKey(const ValueKey('mascot-character')),
      );
      expect(largeMascot.width, greaterThan(100));
      expect(
        tester.getRect(find.byKey(const ValueKey('letter-wheel'))),
        wheelBefore,
      );
      await binding.takeScreenshot('01-convite-mascote');
      await tap(find.byKey(const ValueKey('mascot-line-GOTA')));
      expect(find.textContaining('2ª palavra'), findsOneWidget);
      expect(find.text('GOTA'), findsNothing);
      await binding.takeScreenshot('02-confirmacao-linha-escolhida');
      await tap(find.byKey(const ValueKey('confirm-mascot-hint')));
      expect(session.profile.balance, 70);
      expect(find.text(data.lexicon['GOTA']!.clue!), findsOneWidget);
      expect(session.engine.state.targets, isEmpty);
      expect(session.engine.state.revealedLetters, isEmpty);
      expect(
        tester.getSize(find.byKey(const ValueKey('mascot-character'))),
        largeMascot,
      );
      final afterFirstPurchase = session.profile.toPayload();
      await tap(find.text('Encontre 3 palavras'));
      expect(controller().mascotOpen, false);
      await tap(find.byKey(const ValueKey('mascot-clue-GOTA')));
      expect(find.text(data.lexicon['GOTA']!.clue!), findsOneWidget);
      expect(session.profile.toPayload(), afterFirstPurchase);
      await binding.takeScreenshot('03-frase-jardim');
      await tap(find.text('Escolher outra palavra'));
      await tap(find.byKey(const ValueKey('mascot-line-GATO')));
      await tap(find.byKey(const ValueKey('confirm-mascot-hint')));
      expect(session.profile.balance, 0);
      await closeSpeech();
      final saved = session.profile.toPayload();
      final ledger = await repo.database.query('coin_transactions');
      await controller().leaveToHome();
      await tester.pumpAndSettle();
      await tap(find.byKey(const ValueKey('home-themes')));
      await tap(find.byKey(const ValueKey('use-theme-biblioteca_encantada')));
      await tap(find.byTooltip('Fechar temas'));
      await tap(find.byKey(const ValueKey('play')));
      await tap(find.byKey(const ValueKey('mascot-clue-GOTA')));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(data.lexicon['GOTA']!.clue!), findsOneWidget);
      expect(session.profile.toPayload(), saved);
      expect(await repo.database.query('coin_transactions'), ledger);
      await binding.takeScreenshot('04-reconsulta-biblioteca-saldo-zero');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      repo = await SqliteProgressRepository.open(databasePath: location);
      session = await GameSessionCoordinator.create(data, repo);
      await mount();
      await tap(find.byKey(const ValueKey('play')));
      await tap(find.byKey(const ValueKey('mascot-clue-GATO')));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(data.lexicon['GATO']!.clue!), findsOneWidget);
      expect(session.profile.balance, 0);
      expect(await repo.database.query('coin_transactions'), ledger);
      await binding.takeScreenshot('05-reconsulta-apos-reabrir');
      // The gesture closes the speech while preserving wheel coordinates.
      final ids = <String>[];
      final tiles = session.engine.state.level.tiles.toList();
      for (final letter in 'GATO'.split('')) {
        ids.add(tiles.removeAt(tiles.indexWhere((t) => t.letter == letter)).id);
      }
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
      expect(session.engine.state.targets, contains('GATO'));
      expect(session.profile.balance, 0);
      expect(controller().mascotOpen, false);
      await binding.takeScreenshot('06-palavra-formada-apos-dica');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
