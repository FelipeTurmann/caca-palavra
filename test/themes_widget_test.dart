import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/core/feedback/game_feedback.dart';
import 'package:caca_palavra/core/preferences/player_preferences.dart';
import 'package:caca_palavra/core/theme/visual_theme_catalog.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/daily_catalog.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';
import 'package:caca_palavra/features/game/presentation/home_screen.dart';
import 'package:caca_palavra/features/game/presentation/settings_screen.dart';
import 'package:caca_palavra/features/game/presentation/shop_screen.dart';
import 'package:caca_palavra/features/game/presentation/themes_screen.dart';
import 'package:caca_palavra/features/game/presentation/tutorial_screen.dart';
import 'campaign_widget_test.dart' show MemoryProgressRepository;
import 'experience_test.dart' show FaultyPreferencesStore;
import 'helpers.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  Future<GameSessionCoordinator> session() => GameSessionCoordinator.create(
    loadData(),
    MemoryProgressRepository(600),
    now: () => DateTime(2026, 10, 22, 12),
  );

  testWidgets(
    'select, resume both modes, auxiliary routes and return without resetting the game',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = await session();
      await c.startOrContinue();
      await c.submitWord(
        idsFor(c.engine, 'GATO'),
        session: c.engine.state.session,
      );
      final before = c.profile.toPayload();
      final store = MemoryPreferencesStore();
      await tester.pumpWidget(
        WordGameApp(
          loader: () async => c,
          preferencesStore: store,
          feedbackOutput: SilentFeedbackOutput(),
        ),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<HomeScreen>(find.byType(HomeScreen))
          .controller;
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('home-themes'))).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const ValueKey('daily-play'))).dy,
        ),
      );
      await tap(tester, find.byKey(const ValueKey('home-themes')));
      await tap(tester, find.byKey(const ValueKey('use-theme-capivara_lagoa')));
      expect(find.byType(ThemesScreen), findsOneWidget);
      expect(find.text('Tema aplicado'), findsOneWidget);
      expect(store.value.visualTheme, VisualTheme.lagoon);
      expect(
        VisualThemeScope.of(tester.element(find.byType(ThemesScreen))),
        VisualTheme.lagoon,
      );
      await tap(tester, find.byTooltip('Fechar temas'));
      expect(find.text('Atual: Capivara na lagoa'), findsOneWidget);
      expect(
        tester.widget<HomeScreen>(find.byType(HomeScreen)).controller,
        same(controller),
      );
      expect(c.profile.toPayload(), before);
      await tap(tester, find.byKey(const ValueKey('play')));
      expect(
        VisualThemeScope.of(tester.element(find.byType(GameScreen))),
        VisualTheme.lagoon,
      );
      expect(c.engine.state.targets, contains('GATO'));
      await tap(tester, find.byKey(const ValueKey('settings')));
      expect(
        VisualThemeScope.of(tester.element(find.byType(SettingsScreen))),
        VisualTheme.lagoon,
      );
      await tap(tester, find.byKey(const ValueKey('review-tutorial')));
      expect(
        VisualThemeScope.of(tester.element(find.byType(TutorialScreen))),
        VisualTheme.lagoon,
      );
      await tap(tester, find.byKey(const ValueKey('skip-tutorial')));
      await tap(tester, find.byTooltip('Fechar configurações'));
      controller.leaveToHome();
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('daily-play')));
      expect(
        VisualThemeScope.of(tester.element(find.byType(GameScreen))),
        VisualTheme.lagoon,
      );
      final dailyBefore = c.profile.toPayload();
      controller.leaveToHome();
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('home-themes')));
      await tap(tester, find.byKey(const ValueKey('use-theme-jardim_gatinho')));
      await tap(tester, find.byTooltip('Fechar temas'));
      expect(c.profile.toPayload(), dailyBefore);
      expect(find.text('Atual: Jardim do Gatinho'), findsOneWidget);
      // Opening and dismissing without another selection keeps the choice.
      await tap(tester, find.byKey(const ValueKey('home-themes')));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ThemesScreen), findsNothing);
      expect(store.value.visualTheme, VisualTheme.garden);
      await tap(tester, find.byType(WalletBadge));
      expect(
        VisualThemeScope.of(tester.element(find.byType(ShopScreen))),
        VisualTheme.garden,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'failed theme save can be retried from home after dismissing selector',
    (tester) async {
      final c = await session();
      final store = FaultyPreferencesStore()..fail = true;
      await tester.pumpWidget(
        WordGameApp(
          loader: () async => c,
          preferencesStore: store,
          feedbackOutput: SilentFeedbackOutput(),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('home-themes')));
      await tap(tester, find.byKey(const ValueKey('use-theme-capivara_lagoa')));
      expect(find.text('Tema aplicado'), findsNothing);
      expect(
        find
            .text('Não foi possível salvar o tema. Tente novamente.')
            .hitTestable(),
        findsOneWidget,
      );
      await tap(tester, find.byTooltip('Fechar temas'));
      expect(find.text('Atual: Capivara na lagoa'), findsOneWidget);
      expect(store.value.visualTheme, VisualTheme.garden);
      store.fail = false;
      await tap(tester, find.text('Tentar novamente'));
      expect(store.value.visualTheme, VisualTheme.lagoon);
      expect(
        find.text('Não foi possível salvar o tema. Tente novamente.'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

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
      testWidgets(
        'all themes fit home, selector and live wheel: $size text $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final c = await session();
          await tester.pumpWidget(
            WordGameApp(
              loader: () async => c,
              preferencesStore: MemoryPreferencesStore(),
              feedbackOutput: SilentFeedbackOutput(),
            ),
          );
          await tester.pumpAndSettle();
          final controller = tester
              .widget<HomeScreen>(find.byType(HomeScreen))
              .controller;
          for (final theme in [
            VisualTheme.lagoon,
            VisualTheme.garden,
            VisualTheme.library,
            VisualTheme.ocean,
            VisualTheme.bees,
            VisualTheme.magic,
            VisualTheme.snow,
          ]) {
            await tap(tester, find.byKey(const ValueKey('home-themes')));
            await tap(tester, find.byKey(ValueKey('use-theme-${theme.id}')));
            expect(tester.takeException(), isNull);
            await tap(tester, find.byTooltip('Fechar temas'));
            await tap(tester, find.byKey(const ValueKey('play')));
            await tester.ensureVisible(
              find.byKey(const ValueKey('letter-wheel')),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              VisualThemeScope.of(tester.element(find.byType(GameScreen))),
              theme,
            );
            controller.leaveToHome();
            await tester.pumpAndSettle();
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets('blocked daily date leaves theme selection available', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 22, 12);
    final c = await GameSessionCoordinator.create(
      loadData(),
      MemoryProgressRepository(60),
      dailyCatalog: DailyCatalog.fixture(loadData()),
      now: () => now,
    );
    await c.startDaily();
    now = DateTime(2026, 10, 21, 12);
    await tester.pumpWidget(
      WordGameApp(
        loader: () async => c,
        feedbackOutput: SilentFeedbackOutput(),
      ),
    );
    await tester.pumpAndSettle();
    expect(c.clockReversed, true);
    await tap(tester, find.byKey(const ValueKey('home-themes')));
    await tap(tester, find.byKey(const ValueKey('use-theme-capivara_lagoa')));
    expect(find.byType(ThemesScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
