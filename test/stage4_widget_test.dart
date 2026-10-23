import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/core/theme/game_theme.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/home_screen.dart';
import 'package:caca_palavra/features/game/presentation/shop_screen.dart';
import 'campaign_widget_test.dart' show MemoryProgressRepository;
import 'helpers.dart';

void main() {
  late DateTime time;
  Future<(GameSessionCoordinator, GameController)> mount(
    WidgetTester tester, {
    int balance = 60,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    time = DateTime(2026, 1, 1, 12);
    final c = await GameSessionCoordinator.create(
      loadData(),
      MemoryProgressRepository(balance),
      now: () => time,
    );
    await tester.pumpWidget(WordGameApp(loader: () async => c));
    await tester.pumpAndSettle();
    return (c, tester.widget<HomeScreen>(find.byType(HomeScreen)).controller);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets(
    'wallet opens one shop, cancel does not credit, package and ad are explicitly simulated',
    (tester) async {
      final (c, _) = await mount(tester);
      await tester.tap(find.byType(WalletBadge));
      await tester.tap(find.byType(WalletBadge));
      await tester.pumpAndSettle();
      expect(find.byType(ShopScreen), findsOneWidget);
      expect(
        find.text('Loja em teste: compras simuladas, sem cobrança real.'),
        findsOneWidget,
      );
      await tap(tester, find.byKey(const ValueKey('coins_500')));
      expect(find.textContaining('sem cobrança real'), findsWidgets);
      await tap(tester, find.text('Cancelar'));
      expect(c.profile.balance, 60);
      await tap(tester, find.byKey(const ValueKey('coins_500')));
      await tap(tester, find.byKey(const ValueKey('confirm-package')));
      expect(c.profile.balance, 560);
      expect(find.textContaining('Compra simulada: +500'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('simulated-ad')));
      expect(c.profile.balance, 575);
      await tap(tester, find.byTooltip('Fechar loja'));
      expect(find.byType(ShopScreen), findsNothing);
      expect(c.profile.balance, 575);
      await close(tester);
    },
  );
  testWidgets(
    'insufficient Super Dica opens store and returning requires a new confirmation',
    (tester) async {
      final (c, _) = await mount(tester);
      await tap(tester, find.byKey(const ValueKey('play')));
      final round = c.activeRound!.roundId;
      await tap(tester, find.byKey(const ValueKey('super-hint')));
      expect(find.textContaining('Faltam 60'), findsOneWidget);
      await tap(tester, find.text('Ir à loja'));
      await tap(tester, find.byKey(const ValueKey('coins_500')));
      await tap(tester, find.byKey(const ValueKey('confirm-package')));
      await tap(tester, find.byTooltip('Fechar loja'));
      expect(c.profile.balance, 560);
      expect(c.activeRound!.roundId, round);
      expect(c.activeRound!.superHintUses, 0);
      await tap(tester, find.byKey(const ValueKey('super-hint')));
      await tap(tester, find.byKey(const ValueKey('confirm-super-hint')));
      expect(c.profile.balance, 440);
      expect(c.activeRound!.superHintUses, 1);
      await close(tester);
    },
  );
  testWidgets(
    'Super Dica confirmation hides selected answer and cancel costs nothing',
    (tester) async {
      final (c, _) = await mount(tester, balance: 120);
      await tap(tester, find.byKey(const ValueKey('play')));
      await tap(tester, find.byKey(const ValueKey('super-hint')));
      expect(find.text('Resolver uma palavra por 120 moedas?'), findsOneWidget);
      expect(find.text('GATO'), findsNothing);
      await tap(tester, find.text('Agora não'));
      expect(c.profile.balance, 120);
      expect(c.activeRound!.superHintUses, 0);
      await close(tester);
    },
  );
  testWidgets(
    'daily home starts separate round and midnight closes old confirmation without charging',
    (tester) async {
      final (c, controller) = await mount(tester, balance: 120);
      await tap(tester, find.byKey(const ValueKey('daily-play')));
      expect(find.text('Desafio diário'), findsOneWidget);
      expect(c.profile.currentRound, isNull);
      await tap(tester, find.byKey(const ValueKey('super-hint')));
      time = DateTime(2026, 1, 2);
      await controller.refreshCalendar();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Um novo desafio diário está disponível.'),
        findsOneWidget,
      );
      expect(c.profile.balance, 120);
      await tap(tester, find.text('Jogar novo desafio'));
      expect(c.activeDailyDate, '2026-01-02');
      await close(tester);
    },
  );
  testWidgets(
    'shop credit at midnight survives and returning expires old daily',
    (tester) async {
      final (c, _) = await mount(tester);
      await tap(tester, find.byKey(const ValueKey('daily-play')));
      await tap(tester, find.byType(WalletBadge));
      time = DateTime(2026, 1, 2);
      await tap(tester, find.byKey(const ValueKey('simulated-ad')));
      expect(c.profile.balance, 75);
      await tap(tester, find.byTooltip('Fechar loja'));
      expect(
        find.text('Um novo desafio diário está disponível.'),
        findsOneWidget,
      );
      expect(c.profile.daily['2026-01-01']!.expired, true);
      await close(tester);
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(568, 320),
    const Size(412, 915),
  ]) {
    testWidgets(
      'shop and simulated purchase dialog scroll at $size with 2x text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = await GameSessionCoordinator.create(
          loadData(),
          MemoryProgressRepository(60),
        );
        final controller = GameController(c.engine, coordinator: c);
        await tester.pumpWidget(
          MaterialApp(
            theme: GameTheme.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: ShopScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tap(tester, find.byKey(const ValueKey('coins_5000')));
        expect(find.text('Simular compra?'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tap(tester, find.text('Cancelar'));
        expect(c.profile.balance, 60);
        await close(tester);
        controller.dispose();
      },
    );
  }
  testWidgets(
    'daily extras sheet never promises the campaign Explorer coin reward',
    (tester) async {
      final (c, _) = await mount(tester);
      await tap(tester, find.byKey(const ValueKey('daily-play')));
      await tap(tester, find.byKey(const ValueKey('extras')));
      expect(find.textContaining('Conquiste o selo e ganhe'), findsNothing);
      expect(find.textContaining('moedas recebidas pelo selo'), findsNothing);
      expect(c.profile.balance, 60);
      await tap(tester, find.text('Fechar'));
      await close(tester);
    },
  );
}
