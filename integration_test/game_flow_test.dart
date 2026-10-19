import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android: real drags, extra, accents and ten-level restart', (
    tester,
  ) async {
    final data = await GameData.load();
    await tester.pumpWidget(const WordGameApp());
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
      await tester.pump();
    }

    await drag(data.levels.first, 'TOGA');
    expect(find.text('Extras: 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('extras')));
    await tester.pumpAndSettle();
    expect(find.text('TOGA'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();

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
      if (level.id == 10) {
        expect(
          find.text('Você concluiu os 10 níveis de teste.'),
          findsOneWidget,
        );
      }
      await tester.tap(find.byKey(const ValueKey('next-level')));
      await tester.pumpAndSettle();
      expect(find.text('Extras: 0'), findsOneWidget);
    }
    expect(find.text('Nível 1'), findsOneWidget);
    expect(find.text('0 de 3 palavras'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
