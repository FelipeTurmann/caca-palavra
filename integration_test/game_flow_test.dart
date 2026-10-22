import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';
import 'package:caca_palavra/features/game/presentation/widgets/explorer_progress.dart';
import 'package:caca_palavra/features/game/presentation/widgets/word_slots.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android: home, paid hint, real drags, accents and preserved campaign',
    (tester) async {
      final data = await GameData.load();
      final location = path.join(
        await getDatabasesPath(),
        'stage3_integration.db',
      );
      await deleteDatabase(
        location,
      ); // Only this test fixture, never the user's save.
      final c = await GameSessionCoordinator.create(
        data,
        await SqliteProgressRepository.open(databasePath: location),
      );
      await tester.pumpWidget(WordGameApp(loader: () async => c));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('skip-tutorial')), findsNothing);
      expect(find.text('Jogar'), findsOneWidget);
      expect(find.text('60 moedas'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('play')));
      await tester.pumpAndSettle();

      Future<void> drag(LevelDefinition level, String word) async {
        final available = level.tiles.toList();
        final ids = <String>[];
        for (final letter in word.split('')) {
          ids.add(
            available
                .removeAt(available.indexWhere((tile) => tile.letter == letter))
                .id,
          );
        }
        Offset center(String id) => tester.getCenter(find.byKey(ValueKey(id)));
        final gesture = await tester.startGesture(center(ids.first));
        for (final id in ids.skip(1)) {
          await gesture.moveTo(center(id));
          await tester.pump(const Duration(milliseconds: 45));
        }
        await gesture.up();
        await tester.pumpAndSettle();
      }

      await drag(data.levels.first, 'TOGA');
      expect(find.text('Extras: 1'), findsOneWidget);
      expect(find.text('Meta 1/1'), findsOneWidget);
      expect(c.profile.balance, 70);
      int visibleHints() => tester
          .widgetList<WordSlots>(find.byType(WordSlots))
          .fold(0, (total, row) => total + row.revealed.length);
      expect(visibleHints(), 1);
      expect(find.text('0 de 3 palavras'), findsOneWidget);
      await drag(data.levels.first, 'TOGA');
      expect(visibleHints(), 1);
      expect(find.text('Extras: 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('extras')));
      await tester.pumpAndSettle();
      expect(find.text('TOGA'), findsOneWidget);
      expect(find.byType(ExplorerBadge), findsOneWidget);
      expect(find.text('+10 moedas recebidas pelo selo.'), findsOneWidget);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('hint')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(c.profile.balance, 70);
      await tester.tap(find.byKey(const ValueKey('hint')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-hint')));
      await tester.pumpAndSettle();
      expect(c.profile.balance, 40);
      expect(visibleHints(), 2);

      for (final level in data.levels) {
        expect(find.text('Nível ${level.id}'), findsOneWidget);
        for (final word in level.words) {
          await drag(level, word.key);
          if (level.id == 4 && word.key == 'ACAO') {
            expect(find.text('Ç'), findsOneWidget);
            expect(find.text('Ã'), findsOneWidget);
          }
        }
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pumpAndSettle();
        expect(find.text('Nível ${level.id} concluído.'), findsOneWidget);
        if (level.id == 1) {
          expect(find.text('TOGA'), findsOneWidget);
          expect(find.byType(ExplorerBadge), findsOneWidget);
        } else {
          expect(find.byType(ExplorerBadge), findsNothing);
        }
        if (level.id == 10) {
          expect(
            find.text('Você concluiu todos os níveis desta coleção.'),
            findsOneWidget,
          );
        }
        await tester.tap(find.byKey(const ValueKey('next-level')));
        await tester.pumpAndSettle();
        if (level.id != data.levels.last.id) {
          expect(find.text('Extras: 0'), findsOneWidget);
          expect(visibleHints(), 0);
        }
      }
      expect(find.text('Campanha concluída!'), findsOneWidget);
      expect(find.text('240 moedas'), findsOneWidget);
      expect(c.profile.campaignComplete, true);
      expect(c.profile.rounds.length, data.levels.length);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
