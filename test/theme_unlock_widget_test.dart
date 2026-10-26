import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/core/feedback/game_feedback.dart';
import 'package:caca_palavra/core/preferences/player_preferences.dart';
import 'package:caca_palavra/core/theme/visual_theme_catalog.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/domain/game_engine.dart';
import 'package:caca_palavra/features/game/presentation/home_screen.dart';
import 'campaign_widget_test.dart' show MemoryProgressRepository;
import 'helpers.dart';

void main() {
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> mount(
    WidgetTester tester,
    GameSessionCoordinator session,
    MemoryPreferencesStore store,
  ) async {
    await tester.pumpWidget(
      WordGameApp(
        loader: () async => session,
        preferencesStore: store,
        feedbackOutput: SilentFeedbackOutput(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'locks, confirmation, cancellation, permanent debit and free reuse',
    (tester) async {
      final repo = MemoryProgressRepository(1200);
      var c = await GameSessionCoordinator.create(loadData(), repo);
      final prefs = MemoryPreferencesStore();
      await mount(tester, c, prefs);
      final controller = tester
          .widget<HomeScreen>(find.byType(HomeScreen))
          .controller;
      await controller.useTheme(VisualTheme.lagoon);
      expect(prefs.value.visualTheme, VisualTheme.garden);
      await tap(tester, find.byKey(const ValueKey('home-themes')));
      expect(find.byIcon(Icons.lock_rounded), findsWidgets);
      expect(find.text('Libera no nível 50'), findsOneWidget);
      expect(find.text('Libera no nível 100'), findsOneWidget);
      for (final id in [
        'capivara_lagoa',
        'biblioteca_encantada',
        'fundo_mar',
        'jardim_abelhas',
      ]) {
        expect(find.byKey(ValueKey('theme-lock-$id')), findsOneWidget);
      }
      await tap(
        tester,
        find.byKey(const ValueKey('unlock-theme-capivara_lagoa')),
      );
      await tap(tester, find.text('Cancelar'));
      expect(c.profile.balance, 1200);
      expect(c.profile.purchasedThemes, isEmpty);
      await tap(
        tester,
        find.byKey(const ValueKey('unlock-theme-capivara_lagoa')),
      );
      await tap(
        tester,
        find.byKey(const ValueKey('confirm-unlock-capivara_lagoa')),
      );
      expect(c.profile.balance, 700);
      expect(prefs.value.visualTheme, VisualTheme.lagoon);
      expect(
        find.byKey(const ValueKey('theme-lock-capivara_lagoa')),
        findsNothing,
      );
      await tap(tester, find.byKey(const ValueKey('use-theme-jardim_gatinho')));
      await tap(tester, find.byKey(const ValueKey('use-theme-capivara_lagoa')));
      expect(c.profile.balance, 700);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      c = await GameSessionCoordinator.create(loadData(), repo);
      await mount(tester, c, prefs);
      expect(find.text('Atual: Capivara na lagoa'), findsOneWidget);
      expect(c.isThemeUnlocked('capivara_lagoa'), true);
      expect(c.profile.balance, 700);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'legacy selected theme is locked and returns to free garden; shortfall is exact',
    (tester) async {
      final c = await GameSessionCoordinator.create(
        loadData(),
        MemoryProgressRepository(499),
      );
      final prefs = MemoryPreferencesStore(
        const PlayerPreferences(
          visualThemeId: 'capivara_lagoa',
          introduction: Introduction.exempted,
        ),
      );
      await mount(tester, c, prefs);
      expect(prefs.value.visualTheme, VisualTheme.garden);
      expect(find.text('Atual: Jardim do Gatinho'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('home-themes')));
      await tap(
        tester,
        find.byKey(const ValueKey('unlock-theme-capivara_lagoa')),
      );
      expect(find.text('Moedas insuficientes'), findsOneWidget);
      expect(find.textContaining('Faltam 1 moedas'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('confirm-unlock-capivara_lagoa')),
        findsNothing,
      );
      expect(c.profile.balance, 499);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('milestone themes unlock at campaign 50 and 100 without debit', (
    tester,
  ) async {
    final word = WordEntry('ATO');
    final data = GameData(
      [
        for (final id in [1, 50, 100])
          LevelDefinition(
            id: id,
            difficulty: 'fixture',
            letters: const ['A', 'T', 'O'],
            words: [word],
          ),
      ],
      {'ATO': word},
    );
    final c = await GameSessionCoordinator.create(
      data,
      MemoryProgressRepository(60),
    );
    await c.startOrContinue();
    await c.submitWord(
      idsFor(c.engine, 'ATO'),
      session: c.engine.state.session,
    );
    await c.advance();
    await mount(tester, c, MemoryPreferencesStore());
    await tap(tester, find.byKey(const ValueKey('home-themes')));
    expect(
      find.byKey(const ValueKey('use-theme-escola_magia')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('theme-lock-refugio_neve')),
      findsOneWidget,
    );
    final balance = c.profile.balance;
    await tap(tester, find.byKey(const ValueKey('use-theme-escola_magia')));
    expect(c.profile.balance, balance);
    await tap(tester, find.byTooltip('Fechar temas'));
    await c.submitWord(
      idsFor(c.engine, 'ATO'),
      session: c.engine.state.session,
    );
    tester.widget<HomeScreen>(find.byType(HomeScreen)).controller.refresh();
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('home-themes')));
    expect(
      find.byKey(const ValueKey('use-theme-refugio_neve')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
