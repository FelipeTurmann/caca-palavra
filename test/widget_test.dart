import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caca_palavra/core/theme/game_theme.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';
import 'package:caca_palavra/features/game/presentation/widgets/letter_wheel.dart';
import 'package:caca_palavra/features/game/presentation/widgets/explorer_progress.dart';
import 'package:caca_palavra/features/game/presentation/widgets/word_slots.dart';
import 'helpers.dart';

Future<GameController> mount(
  WidgetTester tester, {
  int level = 1,
  Size size = const Size(412, 915),
  double textScale = 1,
  bool reduceMotion = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = GameController(makeEngine()..startLevel(level));
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: GameTheme.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
        ),
        child: child!,
      ),
      home: GameScreen(controller: controller),
    ),
  );
  return controller;
}

Offset center(WidgetTester tester, String id) =>
    tester.getCenter(find.byKey(ValueKey(id)));

Future<void> dragWord(
  WidgetTester tester,
  GameController controller,
  String word,
) async {
  final ids = idsFor(controller.engine, word);
  final gesture = await tester.startGesture(center(tester, ids.first));
  for (final id in ids.skip(1)) {
    await gesture.moveTo(center(tester, id));
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

ConnectionPainter painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((widget) => widget.painter)
    .whereType<ConnectionPainter>()
    .single;

void main() {
  testWidgets(
    'extra reveals one golden cell, repeats do not reveal and target still needs a drag',
    (tester) async {
      final c = await mount(tester);
      await dragWord(tester, c, 'TOGA');
      final hint = c.feedback!.revealedLetter!;
      expect(find.text('Uma letra revelada!'), findsOneWidget);
      expect(find.text('0 de 3 palavras'), findsOneWidget);
      final slot = find.byKey(ValueKey('slot-${hint.targetKey}-${hint.index}'));
      expect(
        find.descendant(of: slot, matching: find.text(hint.letter)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: slot, matching: find.byIcon(Icons.star_rounded)),
        findsOneWidget,
      );
      final row = tester
          .widgetList<WordSlots>(find.byType(WordSlots))
          .singleWhere((row) => row.word.key == hint.targetKey);
      expect(row.found, isFalse);
      expect(row.revealed, {hint.index});
      final previous = c.state.revealedLetters;
      await dragWord(tester, c, 'TOGA');
      expect(c.feedback!.revealedLetter, isNull);
      expect(c.state.revealedLetters, previous);
      expect(find.text('Uma letra revelada!'), findsNothing);
      await dragWord(tester, c, hint.targetKey);
      expect(c.state.targets, {hint.targetKey});
      final solved = tester
          .widgetList<WordSlots>(find.byType(WordSlots))
          .singleWhere((row) => row.word.key == hint.targetKey);
      expect(solved.found, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'accented hinted letters occupy single cells in both Unicode forms',
    (tester) async {
      for (final display in ['AÇÃO', 'AC\u0327A\u0303O']) {
        final word = WordEntry(display);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WordSlots(
                word: word,
                found: false,
                pulse: 1,
                revealed: const {1, 2},
              ),
            ),
          ),
        );
        for (final index in [1, 2]) {
          expect(
            find.descendant(
              of: find.byKey(ValueKey('slot-ACAO-$index')),
              matching: find.text(word.letters[index]),
            ),
            findsOneWidget,
          );
        }
        expect(find.byKey(const ValueKey('slot-ACAO-4')), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('slot-ACAO-0')),
            matching: find.byType(Text),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'several quick extras each reveal one letter while keeping the explorer goal',
    (tester) async {
      final c = await mount(tester, level: 5);
      for (final extra in ['APTO', 'ARO', 'ATO', 'OPTA']) {
        await dragWord(tester, c, extra);
      }
      expect(c.state.extras.length, 4);
      expect(
        c.state.revealedLetters.values.fold(
          0,
          (sum, indices) => sum + indices.length,
        ),
        4,
      );
      expect(c.state.explorerUnlocked, isTrue);
      expect(c.state.explorerProgress, 3);
      expect(c.state.targets, isEmpty);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'extra flies to counter, celebrates once and repeats do not collect',
    (tester) async {
      final c = await mount(tester);
      expect(find.text('Meta 0/1'), findsOneWidget);
      await dragWord(tester, c, 'TOGA');
      expect(find.text('Palavra extra: TOGA'), findsOneWidget);
      expect(find.text('Extras: 1'), findsOneWidget);
      expect(find.text('Meta 1/1'), findsOneWidget);
      expect(c.discoveries.length, 1);
      final flight = find.byKey(
        ValueKey('extra-flight-${c.state.session}-${c.discoveries.single.id}'),
      );
      expect(flight, findsOneWidget);
      await tester.pump();
      final initial = tester.getCenter(flight);
      await tester.pump(const Duration(milliseconds: 450));
      expect(tester.getCenter(flight).dy, lessThan(initial.dy));
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.discoveries, isEmpty);
      expect(c.collectedSerial, 1);
      expect(find.text('Explorador conquistado!'), findsOneWidget);
      await dragWord(tester, c, 'TOGA');
      expect(
        find.text('Essa palavra extra já foi encontrada.'),
        findsOneWidget,
      );
      expect(c.discoveries, isEmpty);
      expect(c.collectedSerial, 1);
      expect(c.celebratingExplorer, isFalse);
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'collection does not block a new drag or replace newer feedback',
    (tester) async {
      final c = await mount(tester);
      await dragWord(tester, c, 'TOGA');
      final ids = idsFor(c.engine, 'GATO');
      final g = await tester.startGesture(center(tester, ids.first));
      await tester.pump();
      expect(c.dragging, isTrue);
      await tester.pump(const Duration(milliseconds: 850));
      expect(c.preview, 'G');
      expect(c.celebratingExplorer, isFalse);
      for (final id in ids.skip(1)) {
        await g.moveTo(center(tester, id));
      }
      await g.up();
      await tester.pump();
      expect(find.text('Muito bem!'), findsOneWidget);
      expect(c.state.targets, {'GATO'});
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'completion lists extra discoveries and badge; next resets the goal',
    (tester) async {
      final c = await mount(tester);
      await dragWord(tester, c, 'TOGA');
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      for (final word in c.state.level.words) {
        await dragWord(tester, c, word.key);
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Suas descobertas'), findsOneWidget);
      expect(
        find.text('3 palavras obrigatórias\n1 palavra extra descoberta'),
        findsOneWidget,
      );
      expect(find.text('TOGA'), findsOneWidget);
      expect(find.byType(ExplorerBadge), findsOneWidget);
      expect(c.discoveries, isEmpty);
      await tester.tap(find.byKey(const ValueKey('next-level')));
      await tester.pumpAndSettle();
      expect(find.text('Meta 0/2'), findsOneWidget);
      expect(c.state.explorerUnlocked, isFalse);
      expect(c.celebratingExplorer, isFalse);
      expect(c.collectedSerial, 0);
      for (final word in c.state.level.words) {
        await dragWord(tester, c, word.key);
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ExplorerBadge), findsNothing);
      expect(find.byKey(const ValueKey('next-level')), findsOneWidget);
    },
  );

  testWidgets('reduced motion records extra and badge without a flying star', (
    tester,
  ) async {
    final c = await mount(tester, reduceMotion: true);
    await dragWord(tester, c, 'TOGA');
    await tester.pump();
    expect(c.discoveries, isEmpty);
    expect(c.collectedSerial, 1);
    expect(c.state.explorerUnlocked, isTrue);
    expect(find.text('Explorador conquistado!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
    'extras sheet and completion remain scrollable with large text on small screen',
    (tester) async {
      final c = await mount(tester, size: const Size(320, 568), textScale: 2);
      await tester.tap(find.byKey(const ValueKey('extras')));
      await tester.pumpAndSettle();
      expect(find.text('Palavras extras'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('letter-wheel')));
      await dragWord(tester, c, 'TOGA');
      for (final word in c.state.level.words) {
        await dragWord(tester, c, word.key);
      }
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.byKey(const ValueKey('next-level')));
      expect(find.byType(ExplorerBadge), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'resize and detach clear collection callbacks but preserve earned badge',
    (tester) async {
      final c = await mount(tester);
      await dragWord(tester, c, 'TOGA');
      expect(c.discoveries, isNotEmpty);
      tester.view.physicalSize = const Size(640, 480);
      await tester.pump();
      expect(c.discoveries, isEmpty);
      expect(c.state.explorerUnlocked, isTrue);
      expect(
        c.state.revealedLetters.values.fold(
          0,
          (sum, indices) => sum + indices.length,
        ),
        1,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      expect(c.celebratingExplorer, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'real drag fills GATO and rejects repeats, extras have a separate list',
    (tester) async {
      final c = await mount(tester);
      expect(find.text('0 de 3 palavras'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('extras')));
      await tester.pumpAndSettle();
      expect(
        find.text('Você ainda não encontrou palavras extras.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      await dragWord(tester, c, 'GATO');
      expect(c.state.targets, {'GATO'});
      expect(find.text('Muito bem!'), findsOneWidget);
      await dragWord(tester, c, 'GATO');
      expect(find.text('Você já encontrou essa palavra.'), findsOneWidget);
      await dragWord(tester, c, 'TOGA');
      expect(find.text('Palavra extra: TOGA'), findsOneWidget);
      expect(c.state.targets.length, 1);
      await tester.tap(find.byKey(const ValueKey('extras')));
      await tester.pumpAndSettle();
      expect(find.text('TOGA'), findsOneWidget);
      expect(find.text('GOTA'), findsNothing);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'undo updates preview and drawn lines; other used tiles do not repeat',
    (tester) async {
      final c = await mount(tester, level: 4);
      final ids = idsFor(c.engine, 'ACAO');
      final g = await tester.startGesture(center(tester, ids[0]));
      for (final id in ids.skip(1)) {
        await g.moveTo(center(tester, id));
        await tester.pump();
      }
      expect(find.text('ACAO'), findsOneWidget);
      expect(painter(tester).selected.length, 4);
      await g.moveTo(center(tester, ids[0]));
      await tester.pump();
      expect(c.preview, 'ACAO');
      await g.moveTo(center(tester, ids[3]));
      await g.moveTo(center(tester, ids[2]));
      await tester.pump();
      expect(find.text('ACA'), findsOneWidget);
      expect(painter(tester).selected.length, 3);
      await g.moveTo(center(tester, ids[1]));
      await tester.pump();
      expect(c.preview, 'AC');
      expect(painter(tester).selected.length, 2);
      await g.cancel();
      await tester.pump();
      expect(c.state.targets, isEmpty);
    },
  );

  testWidgets('two independent A tiles reveal the accented canonical word', (
    tester,
  ) async {
    final c = await mount(tester, level: 4);
    await dragWord(tester, c, 'ACAO');
    expect(c.state.targets, {'ACAO'});
    final slot = tester.widget<Container>(
      find.byKey(const ValueKey('slot-ACAO-1')),
    );
    expect(
      find.descendant(of: find.byWidget(slot), matching: find.text('Ç')),
      findsOneWidget,
    );
    expect(find.text('Ã'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1300));
  });

  testWidgets('fast outside-to-outside movement detects all crossed tiles', (
    tester,
  ) async {
    final c = await mount(tester);
    final ids = c.state.level.tiles.map((tile) => tile.id).toList();
    final left = center(tester, ids[3]);
    final right = center(tester, ids[1]);
    final g = await tester.startGesture(center(tester, ids[0]));
    await g.moveTo(left - const Offset(80, 0));
    await g.moveTo(right + const Offset(80, 0));
    await tester.pump();
    expect(c.preview, 'GOA');
    await g.cancel();
    await tester.pump();
  });

  testWidgets(
    'crossing connections remain selectable and release outside submits',
    (tester) async {
      final c = await mount(tester);
      final ids = idsFor(c.engine, 'GTAO');
      final g = await tester.startGesture(center(tester, ids[0]));
      for (final id in ids.skip(1)) {
        await g.moveTo(center(tester, id));
      }
      await tester.pump();
      expect(c.preview, 'GTAO');
      expect(painter(tester).selected.length, 4);
      await g.moveTo(center(tester, ids.last) - const Offset(150, 0));
      await g.up();
      await tester.pump();
      expect(c.feedback!.kind, SubmissionKind.unknownWord);
      await dragWord(tester, c, 'GATO');
      expect(c.state.targets, {'GATO'});
      await tester.pump(const Duration(milliseconds: 1300));
    },
  );

  testWidgets(
    'active pointer submits outside, second finger cannot alter or end it',
    (tester) async {
      final c = await mount(tester);
      final ids = idsFor(c.engine, 'GATO');
      final first = await tester.startGesture(
        center(tester, ids[0]),
        pointer: 1,
      );
      final second = await tester.startGesture(
        center(tester, ids[3]),
        pointer: 2,
      );
      await second.moveTo(center(tester, ids[2]));
      await second.up();
      await tester.pump();
      expect(c.preview, 'G');
      expect(c.dragging, isTrue);
      final before = c.state.order.toList();
      c.shuffle();
      expect(c.state.order, before);
      for (final id in ids.skip(1)) {
        await first.moveTo(center(tester, id));
      }
      await first.moveTo(center(tester, ids.last) - const Offset(200, 0));
      await first.up();
      await tester.pump();
      expect(c.state.targets, {'GATO'});
      await tester.pump(const Duration(milliseconds: 1300));
    },
  );

  testWidgets(
    'cancel, app background, Android back and size change discard gestures',
    (tester) async {
      final c = await mount(tester);
      final ids = idsFor(c.engine, 'GATO');
      var g = await tester.startGesture(center(tester, ids[0]));
      await g.moveTo(center(tester, ids[1]));
      await g.cancel();
      await tester.pump();
      expect(c.dragging, isFalse);
      expect(c.feedback, isNull);
      g = await tester.startGesture(center(tester, ids[0]));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(c.dragging, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await g.up();
      await tester.pump();
      g = await tester.startGesture(center(tester, ids[0]));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(c.dragging, isFalse);
      await g.up();
      g = await tester.startGesture(center(tester, ids[0]));
      await tester.pump();
      tester.view.physicalSize = const Size(640, 480);
      await tester.pump();
      expect(c.dragging, isFalse);
      await g.up();
      expect(c.state.targets, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'responses scroll without selecting and shuffle blocks input during transition',
    (tester) async {
      final c = await mount(tester, level: 10, size: const Size(320, 568));
      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(c.dragging, isFalse);
      expect(c.state.targets, isEmpty);
      final order = c.state.order.toList();
      await tester.tap(find.byKey(const ValueKey('shuffle')));
      await tester.pump();
      expect(c.shuffling, isTrue);
      expect(c.state.order, isNot(order));
      final g = await tester.startGesture(center(tester, c.state.order.first));
      expect(c.dragging, isFalse);
      await g.up();
      await tester.pumpAndSettle();
      expect(c.shuffling, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(412, 915),
    const Size(915, 412),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('no overflow at $size with text scale $scale', (
        tester,
      ) async {
        await mount(tester, level: 10, size: size, textScale: scale);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'old feedback timer cannot erase a new result; disposal cancels timers',
    (tester) async {
      final c = await mount(tester);
      await dragWord(tester, c, 'GATO');
      await tester.pump(const Duration(milliseconds: 1000));
      await dragWord(tester, c, 'TOGA');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Palavra extra: TOGA'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      // Detaching the screen cancels all callbacks, even with an external controller.
      await tester.pump(const Duration(milliseconds: 1300));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'large text keeps a six-letter preview usable and detach cancels completion',
    (tester) async {
      final c = await mount(
        tester,
        level: 10,
        size: const Size(320, 568),
        textScale: 2,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('letter-wheel')));
      await tester.pumpAndSettle();
      final ids = idsFor(c.engine, 'ORACAO');
      final g = await tester.startGesture(center(tester, ids.first));
      for (final id in ids.skip(1)) {
        await g.moveTo(center(tester, id));
        await tester.pump();
      }
      expect(c.preview, 'ORACAO');
      expect(tester.takeException(), isNull);
      await g.cancel();
      await tester.pump();
      for (final word in c.state.level.words.take(
        c.state.level.words.length - 1,
      )) {
        submitWord(c.engine, word.key);
      }
      await dragWord(tester, c, c.state.level.words.last.key);
      expect(c.state.phase, RoundPhase.completing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(c.state.phase, RoundPhase.completing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all ten rounds finish once, next clears round and final preserves campaign',
    (tester) async {
      final c = await mount(tester);
      await dragWord(tester, c, 'TOGA');
      for (var level = 1; level <= 10; level++) {
        for (final word in c.state.level.words) {
          await dragWord(tester, c, word.key);
        }
        expect(c.state.phase, RoundPhase.completing);
        expect(c.dragging, isFalse);
        c.shuffle();
        await tester.pump(const Duration(milliseconds: 351));
        expect(c.state.phase, RoundPhase.completed);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byKey(const ValueKey('next-level')), findsOneWidget);
        if (level == 10) {
          expect(
            find.text('Você concluiu todos os níveis desta coleção.'),
            findsOneWidget,
          );
          expect(find.text('Voltar ao início'), findsOneWidget);
        }
        await tester.tap(find.byKey(const ValueKey('next-level')));
        await tester.pumpAndSettle();
        if (level == 10) {
          expect(c.state.level.id, 10);
          expect(c.state.phase, RoundPhase.completed);
          break;
        }
        expect(c.state.level.id, level + 1);
        expect(c.state.targets, isEmpty);
        expect(c.state.extras, isEmpty);
        expect(c.state.revealedLetters, isEmpty);
        expect(c.preview, isEmpty);
        expect(c.feedback, isNull);
        expect(c.state.phase, RoundPhase.playing);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
