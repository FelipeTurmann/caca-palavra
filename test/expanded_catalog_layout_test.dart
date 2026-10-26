import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caca_palavra/core/theme/game_theme.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';
import 'helpers.dart';

void main() {
  late GameData data;
  setUpAll(() {
    data = loadProductionData();
  });
  for (final size in [
    const Size(320, 568),
    const Size(568, 320),
    const Size(360, 800),
    const Size(800, 360),
    const Size(600, 960),
    const Size(960, 600),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'six shipped answers remain readable with scrolling at $size and $scale text',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final level = data.levels.lastWhere(
            (l) => l.words.length == 6 && l.words.any((w) => w.key.length == 6),
          );
          final engine = GameEngine(levels: [level], lexicon: data.lexicon)
            ..startLevel(level.id);
          final controller = GameController(engine);
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: GameTheme.theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: GameScreen(controller: controller),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final tile in level.tiles) {
            expect(find.byKey(ValueKey(tile.id)), findsOneWidget);
          }
          final answers = find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first;
          for (final word in level.words) {
            final first = find.byKey(ValueKey('slot-${word.key}-0'));
            await tester.scrollUntilVisible(first, 64, scrollable: answers);
            final last = find.byKey(
              ValueKey('slot-${word.key}-${word.letters.length - 1}'),
            );
            await Scrollable.ensureVisible(
              tester.element(last),
              alignment: 0.5,
            );
            await tester.pumpAndSettle();
            expect(last.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
