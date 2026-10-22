import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/core/preferences/player_preferences.dart';
import 'package:caca_palavra/core/feedback/game_feedback.dart';
import 'package:caca_palavra/core/theme/game_theme.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';
import 'package:caca_palavra/features/game/presentation/home_screen.dart';
import 'package:caca_palavra/features/game/presentation/settings_screen.dart';
import 'package:caca_palavra/features/game/presentation/shop_screen.dart';
import 'package:caca_palavra/features/game/presentation/tutorial_screen.dart';
import 'package:caca_palavra/features/game/presentation/widgets/letter_wheel.dart';
import 'campaign_widget_test.dart' show MemoryProgressRepository;
import 'helpers.dart';
import 'package:caca_palavra/features/game/presentation/widgets/explorer_progress.dart';

void main() {
  testWidgets(
    'system motion policy stays active when the app switch is off, including settings routes',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final c = await GameSessionCoordinator.create(
        loadData(),
        MemoryProgressRepository(60),
      );
      final store = MemoryPreferencesStore();
      await tester.pumpWidget(
        WordGameApp(
          loader: () async => c,
          preferencesStore: store,
          feedbackOutput: SilentFeedbackOutput(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pumpAndSettle();
      expect(find.text('Redução ativa pelo sistema.'), findsOneWidget);
      expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byType(SettingsScreen)),
        ),
        true,
      );
      await tester.tap(find.byKey(const ValueKey('setting-motion')));
      await tester.pumpAndSettle();
      expect(find.text('Redução ativa pelo sistema.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('setting-motion')));
      await tester.pumpAndSettle();
      expect(store.value.reduceMotion, false);
      expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byType(SettingsScreen)),
        ),
        true,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  Future<void> viewport(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<GameSessionCoordinator> session([int balance = 600]) =>
      GameSessionCoordinator.create(
        loadData(),
        MemoryProgressRepository(balance),
        now: () => DateTime(2026, 1, 1, 12),
      );

  testWidgets(
    'new player opens home directly; optional help and Android back preserve preferences',
    (tester) async {
      await viewport(tester, const Size(412, 915));
      final store = MemoryPreferencesStore(const PlayerPreferences());
      final c = await session();
      await tester.pumpWidget(
        WordGameApp(
          loader: () async => c,
          preferencesStore: store,
          feedbackOutput: SilentFeedbackOutput(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TutorialScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(store.value.introduction, Introduction.unseen);
      await tap(tester, find.byKey(const ValueKey('settings')));
      await tap(tester, find.byKey(const ValueKey('review-tutorial')));
      expect(find.byType(TutorialScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(store.value.introduction, Introduction.unseen);
      await tap(tester, find.byTooltip('Fechar configurações'));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(c.profile.balance, 600);
      await tap(tester, find.byKey(const ValueKey('play')));
      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.byType(TutorialScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'isolated demo supports a real GATO drag, replay, shuffle and finish without touching the campaign',
    (tester) async {
      await viewport(tester, const Size(412, 915));
      final c = await session();
      await c.startOrContinue();
      final source = GameController(c.engine, coordinator: c);
      final before = jsonEncode(c.profile.toPayload());
      Introduction? finished;
      await tester.pumpWidget(
        MaterialApp(
          theme: GameTheme.theme,
          home: TutorialScreen(
            source: source,
            onFinish: (status) async {
              finished = status;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final wheel = tester.widget<LetterWheel>(find.byType(LetterWheel));
      final ids = idsFor(wheel.controller.engine, 'GATO');
      await tester.ensureVisible(find.byKey(const ValueKey('letter-wheel')));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ValueKey(ids.first))),
      );
      for (final id in ids.skip(1)) {
        await gesture.moveTo(tester.getCenter(find.byKey(ValueKey(id))));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Solte para confirmar'), findsOneWidget);
      expect(wheel.controller.state.targets, {'GATO'});
      await tap(tester, find.text('Experimentar novamente'));
      expect(find.text('Arraste para ligar'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('tutorial-continue')));
      await tap(tester, find.byKey(const ValueKey('tutorial-continue')));
      expect(find.text('Experimente embaralhar'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('shuffle')));
      expect(find.textContaining('As letras mudaram'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('tutorial-continue')));
      await tap(tester, find.byKey(const ValueKey('tutorial-finish')));
      expect(finished, Introduction.completed);
      expect(jsonEncode(c.profile.toPayload()), before);
      expect(
        (c.repository as MemoryProgressRepository).receipts.length,
        1,
      ); // Only opening the real round.
      await tester.pumpWidget(const SizedBox());
      source.dispose();
      await c.close();
    },
  );

  testWidgets(
    'settings apply immediately, system motion reduction wins, review revalidates an expired daily',
    (tester) async {
      await viewport(tester, const Size(412, 915));
      var time = DateTime(2026, 1, 1, 23, 59);
      final c = await GameSessionCoordinator.create(
        loadData(),
        MemoryProgressRepository(60),
        now: () => time,
      );
      final store = MemoryPreferencesStore();
      await tester.pumpWidget(
        WordGameApp(
          loader: () async => c,
          preferencesStore: store,
          feedbackOutput: SilentFeedbackOutput(),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('daily-play')));
      final before = jsonEncode(c.activeRound!.toJson());
      await tap(tester, find.byKey(const ValueKey('settings')));
      await tap(tester, find.byKey(const ValueKey('setting-sound')));
      await tap(tester, find.byKey(const ValueKey('setting-haptics')));
      await tap(tester, find.byKey(const ValueKey('setting-motion')));
      expect(store.value.sound, false);
      expect(store.value.haptics, false);
      expect(store.value.reduceMotion, true);
      expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byType(SettingsScreen)),
        ),
        true,
      );
      await tap(tester, find.byKey(const ValueKey('review-tutorial')));
      expect(jsonEncode(c.activeRound!.toJson()), before);
      time = DateTime(2026, 1, 2, 0, 1);
      await tap(tester, find.byKey(const ValueKey('skip-tutorial')));
      await tap(tester, find.byTooltip('Fechar configurações'));
      expect(
        find.text('Um novo desafio diário está disponível.'),
        findsOneWidget,
      );
      expect(c.profile.balance, 60);
      await tester.pumpWidget(const SizedBox());
    },
  );

  const sizes = [
    Size(320, 568),
    Size(568, 320),
    Size(360, 800),
    Size(800, 360),
    Size(412, 915),
    Size(915, 412),
    Size(600, 960),
    Size(960, 600),
    Size(800, 1280),
    Size(1280, 800),
  ];
  for (final size in sizes) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'home, daily, hint dialog, shop, settings, tutorial and result fit $size text $scale',
        (tester) async {
          await viewport(tester, size);
          final c = await session(123456789);
          final controller = GameController(c.engine, coordinator: c);
          addTearDown(controller.dispose);
          Future<void> screen(Widget screen) async {
            await tester.pumpWidget(
              MaterialApp(
                theme: GameTheme.theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: screen,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$screen at $size / $scale',
            );
          }

          await screen(
            HomeScreen(controller: controller, onPlay: () {}, onDaily: () {}),
          );
          await c.startDaily();
          await screen(GameScreen(controller: controller));
          await tap(tester, find.byKey(const ValueKey('hint')));
          expect(tester.takeException(), isNull);
          await tap(tester, find.text('Cancelar'));
          await tap(tester, find.byKey(const ValueKey('extras')));
          expect(tester.takeException(), isNull);
          Navigator.of(tester.element(find.byType(ExtrasSheet))).pop();
          await tester.pumpAndSettle();
          controller.saveError =
              'Não foi possível salvar seu progresso. Seus dados foram preservados. Tente novamente.';
          await screen(
            GameScreen(
              key: const ValueKey('error-state'),
              controller: controller,
            ),
          );
          controller.saveError = null;
          final longEngine = makeEngine()..startLevel(10);
          final longController = GameController(longEngine);
          await screen(
            GameScreen(
              key: const ValueKey('long-word'),
              controller: longController,
            ),
          );
          await screen(ShopScreen(controller: controller));
          longController.dispose();
          await tap(tester, find.byKey(const ValueKey('coins_500')));
          expect(find.textContaining('sem cobrança real'), findsWidgets);
          expect(tester.takeException(), isNull);
          await tap(tester, find.text('Cancelar'));
          await screen(SettingsScreen(controller: controller));
          await screen(
            TutorialScreen(
              source: controller,
              review: true,
              onFinish: (_) async {},
            ),
          );
          for (final word in c.engine.state.level.words) {
            await c.submitWord(
              idsFor(c.engine, word.key),
              session: c.engine.state.session,
            );
          }
          // Restore the saved result, which must be entirely static.
          await c.startDaily();
          await screen(GameScreen(controller: controller));
          expect(find.text('Muito bem!'), findsOneWidget);
          expect(controller.freshVictory, false);
          await screen(const SizedBox());
          await c.close();
        },
      );
    }
  }
}
