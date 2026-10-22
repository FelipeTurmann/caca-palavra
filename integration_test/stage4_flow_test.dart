import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/data/daily_catalog.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'package:caca_palavra/features/game/presentation/home_screen.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android stage 4: simulated shop, both hints, separate daily result and midnight',
    (tester) async {
      final data = await GameData.load(), catalog = await DailyCatalog.load();
      final location = path.join(
        await getDatabasesPath(),
        'stage4_integration.db',
      );
      await deleteDatabase(location);
      var time = DateTime(2026, 1, 1, 12);
      final c = await GameSessionCoordinator.create(
        data,
        await SqliteProgressRepository.open(databasePath: location),
        dailyCatalog: catalog,
        now: () => time,
      );
      await tester.pumpWidget(WordGameApp(loader: () async => c));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<HomeScreen>(find.byType(HomeScreen))
          .controller;
      Future<void> tap(Finder f) async {
        if (f.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            f,
            200,
            scrollable: find.byType(Scrollable).last,
          );
        }
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      Future<void> drag(String key) async {
        final available = c.engine.state.level.tiles.toList();
        final ids = [
          for (final letter in key.split(''))
            available
                .removeAt(available.indexWhere((t) => t.letter == letter))
                .id,
        ];
        await tester.ensureVisible(find.byKey(ValueKey(ids.first)));
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(ValueKey(ids.first))),
        );
        for (final id in ids.skip(1)) {
          await gesture.moveTo(tester.getCenter(find.byKey(ValueKey(id))));
          await tester.pump(const Duration(milliseconds: 45));
        }
        await gesture.up();
        await tester.pumpAndSettle();
      }

      await tap(find.byType(WalletBadge));
      expect(find.text('Loja'), findsOneWidget);
      await tap(find.byKey(const ValueKey('coins_500')));
      await tap(find.byKey(const ValueKey('confirm-package')));
      expect(c.profile.balance, 560);
      await tap(find.byKey(const ValueKey('simulated-ad')));
      expect(c.profile.balance, 575);
      await tap(find.byTooltip('Fechar loja'));
      await tap(find.byKey(const ValueKey('play')));
      await tap(find.byKey(const ValueKey('super-hint')));
      await tap(find.text('Agora não'));
      expect(c.profile.balance, 575);
      await tap(find.byKey(const ValueKey('super-hint')));
      await tap(find.byKey(const ValueKey('confirm-super-hint')));
      expect(c.profile.balance, 475);
      expect(c.activeRound!.superHintUses, 1);
      for (final word in c.engine.state.level.words) {
        if (!c.engine.state.targets.contains(word.key)) await drag(word.key);
      }
      expect(c.profile.balance, 495);
      expect(find.text('Nível 1 concluído.'), findsOneWidget);
      final campaignPending = c.profile.pendingCompletion!.roundId;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tap(find.byKey(const ValueKey('daily-play')));
      await drag('TOGA');
      expect(c.profile.balance, 495);
      expect(c.engine.state.explorerUnlocked, true);
      expect(c.profile.explorerRewardedLevels, isEmpty);
      await tap(find.byKey(const ValueKey('hint')));
      await tap(find.byKey(const ValueKey('confirm-hint')));
      expect(c.profile.balance, 465);
      await tap(find.byKey(const ValueKey('super-hint')));
      await tap(find.byKey(const ValueKey('confirm-super-hint')));
      expect(c.profile.balance, 365);
      for (final word in c.engine.state.level.words) {
        if (!c.engine.state.targets.contains(word.key)) await drag(word.key);
      }
      expect(c.profile.balance, 415);
      expect(find.text('Desafio diário concluído'), findsOneWidget);
      expect(find.text('+50 moedas!'), findsOneWidget);
      expect(c.profile.pendingCompletion!.roundId, campaignPending);
      await tap(find.byType(WalletBadge));
      await tap(find.byKey(const ValueKey('simulated-ad')));
      expect(c.profile.balance, 430);
      await tap(find.byTooltip('Fechar loja'));
      expect(find.text('Desafio diário concluído'), findsOneWidget);
      await tap(find.byKey(const ValueKey('next-level')));
      expect(find.text('Você já recebeu 50 moedas hoje.'), findsOneWidget);
      await tap(find.byKey(const ValueKey('play')));
      expect(find.text('Recompensa de 20 moedas já recebida'), findsOneWidget);
      await tap(find.byKey(const ValueKey('next-level')));
      expect(c.profile.currentLevelId, 2);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      time = DateTime(2026, 1, 2);
      await controller.refreshCalendar();
      await tester.pumpAndSettle();
      await tap(find.byKey(const ValueKey('daily-play')));
      await tap(find.byKey(const ValueKey('super-hint')));
      time = DateTime(2026, 1, 3);
      await controller.refreshCalendar();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Um novo desafio diário está disponível.'),
        findsOneWidget,
      );
      expect(c.profile.balance, 430);
      expect(find.byType(GameScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
