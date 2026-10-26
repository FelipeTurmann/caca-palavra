import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caca_palavra/core/theme/game_theme.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/daily_catalog.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';
import 'package:caca_palavra/features/game/presentation/widgets/word_slots.dart';
import 'package:caca_palavra/features/game/presentation/widgets/mascot_help.dart';
import 'campaign_widget_test.dart' show MemoryProgressRepository;
import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DailyCatalog catalog;
  setUpAll(() async {
    catalog = await DailyCatalog.load();
  });
  for (final size in [const Size(412, 869), const Size(360, 800)]) {
    testWidgets('daily answers and lateral hints fit $size without scrolling', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final coordinator = await GameSessionCoordinator.create(
        loadData(),
        MemoryProgressRepository(200),
        dailyCatalog: catalog,
        now: () => DateTime(2026, 10, 21, 12),
      );
      await coordinator.startDaily();
      final controller = GameController(
        coordinator.engine,
        coordinator: coordinator,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: GameTheme.theme,
          home: GameScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byType(WordSlots),
        findsNWidgets(controller.state.level.words.length),
      );
      final answers = tester.getRect(find.byType(ListView));
      for (final word in controller.state.level.words) {
        for (var i = 0; i < word.letters.length; i++) {
          final slot = tester.getRect(
            find.byKey(ValueKey('slot-${word.key}-$i')),
          );
          expect(
            answers.contains(slot.topLeft),
            isTrue,
            reason: '$size ${word.key}: $slot outside $answers',
          );
          expect(
            answers.contains(slot.bottomRight),
            isTrue,
            reason: '$size ${word.key}: $slot outside $answers',
          );
        }
      }
      final wheel = tester.getRect(find.byKey(const ValueKey('letter-wheel')));
      for (final key in ['hint', 'mascot-help', 'super-hint']) {
        final button = find.byKey(ValueKey(key));
        final rect = tester.getRect(button);
        expect(rect.width, greaterThanOrEqualTo(48 - 0.001));
        expect(rect.height, greaterThanOrEqualTo(48 - 0.001));
        expect(rect.right, closeTo(size.width - 16, 0.1));
        expect(rect.bottom, lessThan(wheel.center.dy));
        for (final tile in controller.state.level.tiles) {
          expect(
            rect.overlaps(tester.getRect(find.byKey(ValueKey(tile.id)))),
            isFalse,
          );
        }
        await tester.tap(button);
        if (key == 'mascot-help') {
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text(mascotInvitation), findsOneWidget);
          controller.closeMascot();
          await tester.pumpAndSettle();
          continue;
        }
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.byKey(
            ValueKey(key == 'hint' ? 'confirm-hint' : 'confirm-super-hint'),
          ),
          findsOneWidget,
        );
        await tester.tap(find.text(key == 'hint' ? 'Cancelar' : 'Agora não'));
        await tester.pumpAndSettle();
      }
      expect(coordinator.profile.balance, 200);
      expect(find.byType(SingleChildScrollView), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
