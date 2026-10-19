import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/core/theme/game_theme.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';
import 'package:caca_palavra/features/game/presentation/widgets/letter_wheel.dart';
import 'helpers.dart';

Future<GameController> mount(
  WidgetTester tester, {
  int level = 1,
  Size size = const Size(412, 915),
  double textScale = 1,
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
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
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
  testWidgets('production entry loads assets and opens level one directly', (
    tester,
  ) async {
    await tester.pumpWidget(const WordGameApp());
    await tester.pumpAndSettle();
    expect(find.text('Nível 1'), findsOneWidget);
    expect(find.text('0 de 3 palavras'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    'all ten rounds finish once, next and restart clear round state',
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
            find.text('Você concluiu os 10 níveis de teste.'),
            findsOneWidget,
          );
          expect(find.text('Reiniciar teste'), findsOneWidget);
        }
        await tester.tap(find.byKey(const ValueKey('next-level')));
        await tester.pumpAndSettle();
        expect(c.state.level.id, level == 10 ? 1 : level + 1);
        expect(c.state.targets, isEmpty);
        expect(c.state.extras, isEmpty);
        expect(c.preview, isEmpty);
        expect(c.feedback, isNull);
        expect(c.state.phase, RoundPhase.playing);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
