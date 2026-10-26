import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/core/feedback/game_feedback.dart';
import 'package:caca_palavra/core/preferences/player_preferences.dart';
import 'package:caca_palavra/core/theme/visual_theme_catalog.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';
import 'package:caca_palavra/features/game/presentation/home_screen.dart';
import 'package:caca_palavra/features/game/presentation/widgets/mascot_help.dart';
import 'campaign_widget_test.dart' show MemoryProgressRepository;
import 'helpers.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    final choosing = tester
        .widgetList<MascotHelp>(find.byType(MascotHelp))
        .any(
          (help) =>
              help.controller.mascotOpen && help.controller.mascotChoosing,
        );
    // Selection intentionally keeps animating until the player picks a row.
    if (choosing) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await settle(tester);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<(GameSessionCoordinator, GameController)> mount(
    WidgetTester tester, {
    VisualTheme theme = VisualTheme.garden,
    Size size = const Size(412, 915),
    double scale = 1,
    MemoryProgressRepository? repository,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final progress = repository ?? MemoryProgressRepository(70);
    final session = await GameSessionCoordinator.create(loadData(), progress);
    // Artwork fixtures represent a player with every visual already unlocked.
    session.profile = progress.profile = session.profile.copyWith(
      purchasedThemes: {
        'capivara_lagoa',
        'biblioteca_encantada',
        'fundo_mar',
        'jardim_abelhas',
      },
      unlocked: {...session.profile.unlocked, 100},
    );
    await tester.pumpWidget(
      WordGameApp(
        loader: () async => session,
        preferencesStore: MemoryPreferencesStore(
          PlayerPreferences(visualThemeId: theme.id),
        ),
        feedbackOutput: SilentFeedbackOutput(),
      ),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<HomeScreen>(find.byType(HomeScreen))
        .controller;
    await tap(tester, find.byKey(const ValueKey('play')));
    return (session, controller);
  }

  for (final theme in VisualTheme.values) {
    testWidgets(
      '${theme.title}: speech, chosen second row, cancel, buy and free reread at zero',
      (tester) async {
        final (session, controller) = await mount(tester, theme: theme);
        final before = session.profile.toPayload();
        await tap(tester, find.byKey(const ValueKey('mascot-help')));
        expect(find.text(mascotInvitation), findsOneWidget);
        await tap(tester, find.byKey(const ValueKey('mascot-line-GOTA')));
        expect(find.textContaining('2ª palavra'), findsOneWidget);
        expect(find.text('GOTA'), findsNothing);
        expect(find.text(session.clueWordFor('GOTA')!.clue!), findsNothing);
        await tap(tester, find.text('Cancelar'));
        expect(session.profile.balance, 70);
        expect(session.profile.toPayload(), before);
        await tap(tester, find.byKey(const ValueKey('mascot-line-GOTA')));
        await tap(tester, find.byKey(const ValueKey('confirm-mascot-hint')));
        expect(find.text(session.clueWordFor('GOTA')!.clue!), findsOneWidget);
        expect(find.text('Dica liberada'), findsNothing);
        expect(find.byKey(const ValueKey('mascot-clue-GOTA')), findsOneWidget);
        expect(controller.mascotTargetKey, 'GOTA');
        expect(session.profile.balance, 0);
        expect(controller.state.targets, isEmpty);
        expect(controller.state.revealedLetters, isEmpty);
        expect(
          find.byType(CustomPaint),
          findsWidgets,
        ); // The speech has a drawn tail.
        await tap(
          tester,
          find.descendant(
            of: find.byType(MascotHelp),
            matching: find.text('Fechar'),
          ),
        );
        await tap(tester, find.byKey(const ValueKey('mascot-clue-GOTA')));
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text(session.clueWordFor('GOTA')!.clue!), findsOneWidget);
        expect(session.profile.balance, 0);
        await tap(tester, find.text('Escolher outra palavra'));
        final boughtPulse = find.byKey(const ValueKey('mascot-pulse-GOTA'));
        final unpaidPulse = find.byKey(const ValueKey('mascot-pulse-GATO'));
        final unpaidBefore = tester
            .widget<ScaleTransition>(unpaidPulse)
            .scale
            .value;
        expect(tester.widget<ScaleTransition>(boughtPulse).scale.value, 1);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.widget<ScaleTransition>(boughtPulse).scale.value, 1);
        expect(
          tester.widget<ScaleTransition>(unpaidPulse).scale.value,
          isNot(unpaidBefore),
        );
        await tap(tester, find.byKey(const ValueKey('mascot-line-GATO')));
        expect(find.text('Moedas insuficientes'), findsOneWidget);
        expect(find.textContaining('Faltam 70'), findsOneWidget);
        await tap(tester, find.text('Agora não'));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(controller.mascotOpen, false);
        expect(find.byType(GameScreen), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  for (final size in const [
    Size(320, 568),
    Size(568, 320),
    Size(360, 800),
    Size(800, 360),
    Size(412, 915),
    Size(915, 412),
    Size(800, 1280),
    Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('speech and row selection fit $size text $scale', (
        tester,
      ) async {
        final (session, controller) = await mount(
          tester,
          size: size,
          scale: scale,
          theme: VisualTheme.snow,
        );
        final mascot = find.byKey(const ValueKey('mascot-help'));
        await tester.ensureVisible(mascot);
        await settle(tester);
        final wheel = find.byKey(const ValueKey('letter-wheel'));
        final wheelBefore = tester.getRect(wheel);
        final rowBefore = tester.getRect(
          find.byKey(const ValueKey('mascot-line-GATO')),
        );
        expect(tester.getSize(mascot).width, greaterThanOrEqualTo(48));
        await tester.tap(mascot);
        await settle(tester);
        expect(tester.getRect(wheel), wheelBefore);
        expect(
          tester.getRect(find.byKey(const ValueKey('mascot-line-GATO'))),
          rowBefore,
        );
        await tap(tester, find.byKey(const ValueKey('mascot-line-GATO')));
        await tap(tester, find.byKey(const ValueKey('confirm-mascot-hint')));
        expect(find.text(session.clueWordFor('GATO')!.clue!), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(controller.mascotOpen, true);
        expect(session.profile.balance, 0);
        // ensureVisible may scroll the round on compact screens, but opening
        // and purchasing speech never resize the wheel.
        expect(tester.getSize(wheel), wheelBefore.size);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }

  testWidgets('starting a drag closes speech without moving its hit geometry', (
    tester,
  ) async {
    final (session, controller) = await mount(tester);
    await tap(tester, find.byKey(const ValueKey('mascot-help')));
    await tap(tester, find.byKey(const ValueKey('mascot-line-GATO')));
    await tap(tester, find.byKey(const ValueKey('confirm-mascot-hint')));
    final ids = idsFor(controller.engine, 'GATO');
    final geometry = controller.geometry!;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ValueKey(ids.first))),
    );
    await tester.pump();
    expect(controller.mascotOpen, false);
    expect(controller.geometry!.sameAs(geometry), true);
    for (final id in ids.skip(1)) {
      await gesture.moveTo(tester.getCenter(find.byKey(ValueKey(id))));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(session.engine.state.targets, contains('GATO'));
    expect(session.profile.balance, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'rotation closes an unconfirmed purchase without reopening speech or charging',
    (tester) async {
      final (session, controller) = await mount(tester);
      await tap(tester, find.byKey(const ValueKey('mascot-help')));
      await tap(tester, find.byKey(const ValueKey('mascot-line-GATO')));
      expect(find.byType(AlertDialog), findsOneWidget);
      tester.view.physicalSize = const Size(915, 412);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(controller.mascotOpen, false);
      expect(session.profile.balance, 70);
      expect(session.activeRound!.mascotHints, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('reopening the saved campaign rereads the clue without balance', (
    tester,
  ) async {
    final repository = MemoryProgressRepository(70);
    var pair = await mount(tester, repository: repository);
    await tap(tester, find.byKey(const ValueKey('mascot-help')));
    await tap(tester, find.byKey(const ValueKey('mascot-line-GATO')));
    await tap(tester, find.byKey(const ValueKey('confirm-mascot-hint')));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    pair = await mount(tester, repository: repository);
    await tap(tester, find.byKey(const ValueKey('mascot-clue-GATO')));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(pair.$1.clueWordFor('GATO')!.clue!), findsOneWidget);
    expect(pair.$2.balance, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('selection pulses only the fields without outlining the row', (
    tester,
  ) async {
    final (_, controller) = await mount(tester);
    final line = find.byKey(const ValueKey('mascot-line-GATO'));
    final bounds = tester.getRect(line);
    await tap(tester, find.byKey(const ValueKey('mascot-help')));
    final pulse = find.byKey(const ValueKey('mascot-pulse-GATO'));
    final first = tester.widget<ScaleTransition>(pulse).scale.value;
    await tester.pump(const Duration(milliseconds: 200));
    final second = tester.widget<ScaleTransition>(pulse).scale.value;
    expect(first, isNot(second));
    expect(tester.getRect(line), bounds);
    expect(
      find.descendant(of: line, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      find
          .descendant(of: line, matching: find.byType(DecoratedBox))
          .evaluate()
          .map((e) => (e.widget as DecoratedBox).decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.borderRadius == BorderRadius.circular(12)),
      isEmpty,
    );
    controller.closeMascot();
    await tester.pumpAndSettle();
    expect(tester.widget<ScaleTransition>(pulse).scale.value, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('toolbar opens animated larger mascot; character is decoration', (
    tester,
  ) async {
    final (_, controller) = await mount(tester);
    final decoration = find.byKey(const ValueKey('mascot-decoration'));
    final smallSize = tester.getSize(decoration);
    await tester.tap(decoration, warnIfMissed: false);
    await tester.pump();
    expect(controller.mascotOpen, false);
    final letterHint = tester.getCenter(find.byKey(const ValueKey('hint')));
    final mascotHint = tester.getCenter(
      find.byKey(const ValueKey('mascot-help')),
    );
    final superHint = tester.getCenter(
      find.byKey(const ValueKey('super-hint')),
    );
    expect(mascotHint.dx, letterHint.dx);
    expect(mascotHint.dy, greaterThan(letterHint.dy));
    expect(mascotHint.dy, lessThan(superHint.dy));
    await tester.tap(find.byKey(const ValueKey('mascot-help')));
    await tester.pump();
    final character = find.byKey(const ValueKey('mascot-character'));
    expect(tester.getSize(character).width, greaterThan(smallSize.width));
    final fade = find
        .ancestor(
          of: find.byType(MascotHelp),
          matching: find.byType(FadeTransition),
        )
        .first;
    expect(tester.widget<FadeTransition>(fade).opacity.value, lessThan(1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    expect(
      find.descendant(
        of: find.byType(MascotHelp),
        matching: find.byType(InkResponse),
      ),
      findsNothing,
    );
    controller.closeMascot();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('outside tap closes invitation without changing the round', (
    tester,
  ) async {
    final (session, controller) = await mount(tester);
    final before = session.profile.toPayload();
    final wheel = find.byKey(const ValueKey('letter-wheel'));
    final bounds = tester.getRect(wheel);
    await tap(tester, find.byKey(const ValueKey('mascot-help')));
    await tap(tester, find.text(mascotInvitation));
    expect(controller.mascotOpen, true);
    await tap(tester, find.text('Encontre 3 palavras'));
    expect(controller.mascotOpen, false);
    expect(controller.mascotChoosing, false);
    expect(find.text(mascotInvitation), findsNothing);
    expect(session.profile.toPayload(), before);
    expect(tester.getRect(wheel), bounds);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'outside tap closes purchased clue and icon rereads it for free',
    (tester) async {
      final (session, controller) = await mount(tester);
      await tap(tester, find.byKey(const ValueKey('mascot-help')));
      await tap(tester, find.byKey(const ValueKey('mascot-line-GATO')));
      await tap(tester, find.byKey(const ValueKey('confirm-mascot-hint')));
      final clue = session.clueWordFor('GATO')!.clue!;
      final afterPurchase = session.profile.toPayload();
      await tap(tester, find.text(clue));
      expect(controller.mascotOpen, true);
      await tap(tester, find.byKey(const ValueKey('mascot-line-GOTA')));
      expect(controller.mascotOpen, false);
      expect(find.text(clue), findsNothing);
      await tap(tester, find.byKey(const ValueKey('mascot-clue-GATO')));
      expect(find.text(clue), findsOneWidget);
      expect(controller.mascotOpen, true);
      expect(session.profile.balance, 0);
      expect(session.profile.toPayload(), afterPurchase);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('word selection respects reduced animations', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await mount(tester);
    await tap(tester, find.byKey(const ValueKey('mascot-help')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ScaleTransition>(
            find.byKey(const ValueKey('mascot-pulse-GATO')),
          )
          .scale
          .value,
      1,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
