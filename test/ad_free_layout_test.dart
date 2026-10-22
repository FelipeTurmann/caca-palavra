import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caca_palavra/core/theme/game_theme.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';
import 'package:caca_palavra/features/game/presentation/shop_screen.dart';
import 'package:caca_palavra/features/game/presentation/widgets/word_success_feedback.dart';
import 'campaign_widget_test.dart' show MemoryProgressRepository;
import 'helpers.dart';
import 'widget_test.dart' show dragWord;

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(412, 915),
    const Size(800, 360),
  ]) {
    testWidgets(
      'selection and praise align with wheel between lateral controls at $size',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = await GameSessionCoordinator.create(
          loadData(),
          MemoryProgressRepository(200),
        );
        await session.startOrContinue();
        final controller = GameController(session.engine, coordinator: session);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: GameTheme.theme,
            home: GameScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        final center = tester
            .getCenter(find.byKey(const ValueKey('letter-wheel')))
            .dx;
        expect(
          tester.getCenter(find.byKey(const ValueKey('ad-free'))).dx,
          lessThan(center),
        );
        for (final key in ['hint', 'super-hint']) {
          final rect = tester.getRect(find.byKey(ValueKey(key)));
          expect(rect.center.dx, greaterThan(center));
          for (final tile in controller.state.level.tiles) {
            expect(
              rect.overlaps(tester.getRect(find.byKey(ValueKey(tile.id)))),
              false,
            );
          }
        }
        final ids = idsFor(controller.engine, 'GATO');
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(ValueKey(ids.first))),
        );
        for (final id in ids.skip(1)) {
          await gesture.moveTo(tester.getCenter(find.byKey(ValueKey(id))));
          await tester.pump();
        }
        expect(
          tester.getCenter(find.byKey(const ValueKey('preview'))).dx,
          closeTo(center, .01),
        );
        expect(
          tester
              .widget<IconButton>(find.byKey(const ValueKey('ad-free')))
              .onPressed,
          isNull,
        );
        await gesture.up();
        await controller.waitIdle();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(WordSuccessFeedback), findsOneWidget);
        expect(
          tester.getCenter(find.byType(WordSuccessFeedback)).dx,
          closeTo(center, .01),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'AD opens the plan, cancellation is free and simulated activation leaves optional ads available',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 915);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = await GameSessionCoordinator.create(
        loadData(),
        MemoryProgressRepository(200),
      );
      await session.startOrContinue();
      final controller = GameController(session.engine, coordinator: session);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: GameTheme.theme,
          home: GameScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(Finder finder) async {
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            finder,
            250,
            scrollable: find.byType(Scrollable).last,
          );
        }
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.byKey(const ValueKey('ad-free')));
      expect(find.byType(ShopScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('ad-free-plan')), findsOneWidget);
      await tap(find.byKey(const ValueKey('activate-ad-free')));
      await tap(find.text('Cancelar'));
      expect(controller.adFreePlan.active, false);
      expect(controller.balance, 200);
      await tap(find.byKey(const ValueKey('activate-ad-free')));
      await tap(find.byKey(const ValueKey('confirm-ad-free')));
      expect(find.byKey(const ValueKey('ad-free-active')), findsOneWidget);
      expect(find.byKey(const ValueKey('activate-ad-free')), findsNothing);
      expect(controller.balance, 200);
      await tap(find.byKey(const ValueKey('simulated-ad')));
      expect(controller.balance, 215);
      await tap(find.byTooltip('Fechar loja'));
      await dragWord(tester, controller, 'GATO');
      await controller.waitIdle();
      expect(controller.state.targets, {'GATO'});
      await tester.pumpWidget(const SizedBox());
    },
  );
}
