import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/core/feedback/game_feedback.dart';
import 'package:caca_palavra/core/preferences/player_preferences.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/home_screen.dart';
import 'campaign_widget_test.dart' show MemoryProgressRepository;
import 'extra_reveal_test.dart' show RevealRandom;
import 'helpers.dart';
import 'widget_test.dart' show dragWord;

void main() {
  Future<GameController> mount(
    WidgetTester tester, {
    required bool finalWord,
    bool reduced = false,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = await GameSessionCoordinator.create(
      loadData(),
      MemoryProgressRepository(120),
      random: RevealRandom(),
    );
    await session.startOrContinue();
    if (finalWord) {
      for (final key in ['GOTA', 'ATO']) {
        await session.submitWord(
          idsFor(session.engine, key),
          session: session.engine.state.session,
        );
      }
    }
    for (var i = 0; i < 3; i++) {
      await session.purchaseHint(operationId: 'prepare-$i');
    }
    await tester.pumpWidget(
      WordGameApp(
        loader: () async => session,
        preferencesStore: MemoryPreferencesStore(
          PlayerPreferences(reduceMotion: reduced),
        ),
        feedbackOutput: SilentFeedbackOutput(),
      ),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<HomeScreen>(find.byType(HomeScreen))
        .controller;
    await tester.tap(find.byKey(const ValueKey('play')));
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> reveal(
    WidgetTester tester,
    GameController controller,
    bool extra,
  ) async {
    if (extra) {
      await dragWord(tester, controller, 'TOGA');
      await tester.pump();
    } else {
      await tester.tap(find.byKey(const ValueKey('hint')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Se for a última letra'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-hint')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  for (final extra in [false, true]) {
    testWidgets(
      '${extra ? 'extra' : 'hint'} completes one word and shows its own feedback',
      (tester) async {
        final controller = await mount(tester, finalWord: false);
        await reveal(tester, controller, extra);
        expect(controller.state.targets, {'GATO'});
        expect(controller.state.phase, RoundPhase.playing);
        expect(find.text('1 de 3 palavras'), findsOneWidget);
        expect(
          find.text(extra ? 'GATO completada!' : 'Dica completou GATO!'),
          findsOneWidget,
        );
        expect(controller.balance, extra ? 40 : 0);
        expect(controller.freshVictory, false);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    for (final reduced in [false, true]) {
      testWidgets(
        '${extra ? 'extra' : 'hint'} opens the final result and advances, reduced $reduced',
        (tester) async {
          final controller = await mount(
            tester,
            finalWord: true,
            reduced: reduced,
          );
          await reveal(tester, controller, extra);
          expect(controller.state.targets, {'GATO', 'GOTA', 'ATO'});
          await tester.pump(GameTiming.completion);
          await tester.pumpAndSettle();
          expect(controller.state.phase, RoundPhase.completed);
          expect(find.byKey(const ValueKey('next-level')), findsOneWidget);
          expect(find.text('Muito bem!'), findsOneWidget);
          expect(controller.freshVictory, true);
          expect(controller.balance, extra ? 60 : 20);
          await tester.tap(find.byKey(const ValueKey('next-level')));
          await tester.pumpAndSettle();
          expect(controller.state.level.id, 2);
          expect(controller.state.targets, isEmpty);
          expect(controller.balance, extra ? 60 : 20);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
