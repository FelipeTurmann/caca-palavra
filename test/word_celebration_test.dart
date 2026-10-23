import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/home_screen.dart';
import 'package:caca_palavra/features/game/presentation/widgets/word_slots.dart';
import 'package:caca_palavra/features/game/presentation/widgets/word_success_feedback.dart';
import 'campaign_widget_test.dart' show MemoryProgressRepository;
import 'widget_test.dart' show mount, dragWord;
import 'helpers.dart';

void main() {
  testWidgets(
    'a newly formed answer receives inline praise and a shine on only its own row',
    (tester) async {
      final controller = await mount(tester);
      await tester.pumpAndSettle();
      await dragWord(tester, controller, 'GATO');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(WordSuccessFeedback), findsOneWidget);
      expect(find.text('Muito bem!'), findsOneWidget);
      expect(
        tester
            .widget<WordSuccessFeedback>(find.byType(WordSuccessFeedback))
            .word,
        'GATO',
      );
      expect(find.byKey(const ValueKey('word-shine-GATO')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('word-celebration-burst')),
        findsOneWidget,
      );
      final rows = tester.widgetList<WordSlots>(find.byType(WordSlots));
      expect(rows.where((row) => row.celebrate).map((row) => row.word.key), [
        'GATO',
      ]);
      expect(controller.state.targets, {'GATO'});
      expect(find.byType(SnackBar), findsNothing);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('word-shine-GATO')), findsNothing);
      expect(
        find.byKey(const ValueKey('word-celebration-burst')),
        findsNothing,
      );
      controller.refresh();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('word-celebration-burst')),
        findsNothing,
      );
      expect(controller.state.targets, {'GATO'});
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'extras, invalid words and repeated answers keep their own feedback without congratulations',
    (tester) async {
      final controller = await mount(tester);
      await tester.pumpAndSettle();
      for (final word in ['TOGA', 'GTO']) {
        await dragWord(tester, controller, word);
        expect(find.byType(WordSuccessFeedback), findsNothing);
        expect(
          tester
              .widgetList<WordSlots>(find.byType(WordSlots))
              .any((row) => row.celebrate),
          false,
        );
        await tester.pumpAndSettle();
      }
      await dragWord(tester, controller, 'GATO');
      await tester.pumpAndSettle();
      await dragWord(tester, controller, 'GATO');
      expect(find.text('Você já encontrou essa palavra.'), findsOneWidget);
      expect(find.byType(WordSuccessFeedback), findsNothing);
      expect(find.byKey(const ValueKey('word-shine-GATO')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'the last answer uses the existing victory instead of a second word celebration',
    (tester) async {
      final controller = await mount(tester);
      await tester.pumpAndSettle();
      final words = controller.state.level.words;
      for (final word in words.take(words.length - 1)) {
        await dragWord(tester, controller, word.key);
        await tester.pumpAndSettle();
      }
      await dragWord(tester, controller, words.last.key);
      expect(find.byType(WordSuccessFeedback), findsNothing);
      expect(
        tester
            .widgetList<WordSlots>(find.byType(WordSlots))
            .any((row) => row.celebrate),
        false,
      );
      await tester.pump(GameTiming.completion);
      await tester.pump();
      expect(find.text('Muito bem!'), findsOneWidget);
      expect(controller.freshVictory, true);
      expect(
        find.byKey(const ValueKey('word-celebration-burst')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reduced motion shows the same praise without movement, shine or sparkles',
    (tester) async {
      final controller = await mount(tester, reduceMotion: true);
      await tester.pumpAndSettle();
      await dragWord(tester, controller, 'GATO');
      await tester.pump();
      expect(find.byType(WordSuccessFeedback), findsOneWidget);
      expect(find.text('Muito bem!'), findsOneWidget);
      expect(find.byKey(const ValueKey('word-shine-GATO')), findsNothing);
      expect(
        find.byKey(const ValueKey('word-celebration-burst')),
        findsNothing,
      );
      expect(controller.state.targets, {'GATO'});
      controller.cancelTransientPresentation();
      await tester.pump();
      expect(find.byType(WordSuccessFeedback), findsNothing);
      expect(controller.state.targets, {'GATO'});
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Super Dica keeps assisted resolution feedback instead of congratulating a manual answer',
    (tester) async {
      final session = await GameSessionCoordinator.create(
        loadData(),
        MemoryProgressRepository(300),
      );
      await tester.pumpWidget(WordGameApp(loader: () async => session));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<HomeScreen>(find.byType(HomeScreen))
          .controller;
      await tester.tap(find.byKey(const ValueKey('play')));
      await tester.pumpAndSettle();
      await controller.buySuperHint('assisted-feedback', session.context);
      await tester.pump();
      expect(find.text('Palavra resolvida pela Super Dica!'), findsOneWidget);
      expect(find.byType(WordSuccessFeedback), findsNothing);
      expect(
        tester
            .widgetList<WordSlots>(find.byType(WordSlots))
            .any((row) => row.celebrate),
        false,
      );
      expect(session.profile.balance, 180);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [const Size(320, 568), const Size(915, 412)]) {
    testWidgets('praise stays readable with 2x text at $size', (tester) async {
      final controller = await mount(tester, size: size, textScale: 2);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('letter-wheel')));
      await tester.pumpAndSettle();
      await dragWord(tester, controller, 'GATO');
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.byType(WordSuccessFeedback), findsOneWidget);
      expect(controller.state.targets, {'GATO'});
      await tester.pumpWidget(const SizedBox());
    });
  }
}
