import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/features/game/application/campaign_models.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';
import 'package:caca_palavra/features/game/presentation/home_screen.dart';
import 'package:caca_palavra/features/game/presentation/wheel_gesture.dart';
import 'package:caca_palavra/features/game/presentation/widgets/coin_collection_layer.dart';
import 'campaign_widget_test.dart' show MemoryProgressRepository;
import 'helpers.dart';

class FailingRewardRepository extends MemoryProgressRepository {
  FailingRewardRepository() : super(60);
  bool fail = false;
  @override
  Future<CampaignProfile> commit(SaveProposal proposal, GameData data) async {
    if (fail) throw StateError('simulated write failure');
    return super.commit(proposal, data);
  }
}

void main() {
  Future<(GameSessionCoordinator, GameController)> mount(
    WidgetTester tester, {
    bool daily = false,
    int balance = 60,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final session = await GameSessionCoordinator.create(
      loadData(),
      MemoryProgressRepository(balance),
      now: () => DateTime(2026, 1, 1, 12),
    );
    await tester.pumpWidget(WordGameApp(loader: () async => session));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<HomeScreen>(find.byType(HomeScreen))
        .controller;
    final play = find.byKey(ValueKey(daily ? 'daily-play' : 'play'));
    await tester.ensureVisible(play);
    await tester.pumpAndSettle();
    await tester.tap(play);
    await tester.pumpAndSettle();
    return (session, controller);
  }

  Future<void> drag(
    WidgetTester tester,
    GameController controller,
    String word,
  ) async {
    final ids = idsFor(controller.engine, word);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ValueKey(ids.first))),
    );
    for (final id in ids.skip(1)) {
      await gesture.moveTo(tester.getCenter(find.byKey(ValueKey(id))));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'Explorer coins fly to the wallet alongside the existing extra star, once per earned badge',
    (tester) async {
      final (session, controller) = await mount(tester);
      await drag(tester, controller, 'TOGA');
      expect(session.profile.balance, 70);
      expect(controller.coinRewards.single.amount, 10);
      expect(controller.coinRewards.single.origin, CoinRewardOrigin.explorer);
      expect(
        find.byKey(const ValueKey('coin-flight-explorer-reward:1')),
        findsOneWidget,
      );
      expect(controller.discoveries, hasLength(1));
      final coin = find.byKey(
        const ValueKey('flying-coin-explorer-reward:1-0'),
      );
      await tester.pump(const Duration(milliseconds: 120));
      final initial = tester.getCenter(coin);
      final layer = tester.widget<CoinCollectionLayer>(
        find.byType(CoinCollectionLayer),
      );
      final wallet = tester.getCenter(find.byKey(layer.walletKey));
      await tester.pump(const Duration(milliseconds: 400));
      final moved = tester.getCenter(coin);
      expect((moved - wallet).distance, lessThan((initial - wallet).distance));
      expect(moved.dy, lessThan(initial.dy));
      await tester.pumpAndSettle();
      expect(controller.coinRewards, isEmpty);
      expect(session.profile.balance, 70);
      await drag(tester, controller, 'TOGA');
      expect(controller.coinRewards, isEmpty);
      expect(session.profile.balance, 70);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'rotation cancels flying coins and preserves the committed Explorer reward',
    (tester) async {
      final (session, controller) = await mount(tester);
      await drag(tester, controller, 'TOGA');
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.coinRewards, hasLength(1));
      tester.view.physicalSize = const Size(915, 412);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(controller.coinRewards, isEmpty);
      expect(session.profile.balance, 70);
      expect(controller.state.extras.keys, contains('TOGA'));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'campaign reward flies upward after the result opens, including a final Super Dica debit',
    (tester) async {
      final (session, controller) = await mount(tester, balance: 300);
      final words = controller.state.level.words;
      for (final word in words.take(words.length - 1)) {
        await drag(tester, controller, word.key);
        await tester.pumpAndSettle();
      }
      await controller.buySuperHint('coin-final-super', session.context);
      await tester.pump();
      expect(session.profile.balance, 200);
      expect(controller.coinRewards.single.amount, 20);
      expect(
        find.byKey(const ValueKey('coin-flight-level-completion:1')),
        findsNothing,
      );
      await tester.pump(GameTiming.completion);
      await tester.pump();
      expect(find.text('Muito bem!'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('coin-flight-level-completion:1')),
        findsOneWidget,
      );
      final layer = tester.widget<CoinCollectionLayer>(
        find.byType(CoinCollectionLayer),
      );
      expect(
        tester.getCenter(find.byKey(layer.completionSourceKey)).dy,
        greaterThan(tester.getCenter(find.byKey(layer.walletKey)).dy),
      );
      expect(find.byType(WalletBadge), findsOneWidget);
      await tester.pumpAndSettle();
      controller.refresh();
      await tester.pumpAndSettle();
      expect(controller.coinRewards, isEmpty);
      expect(session.profile.balance, 200);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'daily completion flies 50 coins and reopening the saved result does not replay it',
    (tester) async {
      final (session, controller) = await mount(tester, daily: true);
      final words = controller.state.level.words;
      for (final word in words.take(words.length - 1)) {
        await drag(tester, controller, word.key);
        await tester.pumpAndSettle();
      }
      await drag(tester, controller, words.last.key);
      expect(session.profile.balance, 110);
      expect(session.profile.completed, isEmpty);
      expect(controller.coinRewards.single.amount, 50);
      await tester.pump(GameTiming.completion);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('coin-flight-daily-completion:2026-01-01')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      await controller.leaveToHome();
      await tester.pumpAndSettle();
      final daily = find.byKey(const ValueKey('daily-play'));
      await tester.ensureVisible(daily);
      await tester.pumpAndSettle();
      await tester.tap(daily);
      await tester.pumpAndSettle();
      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.text('Muito bem!'), findsOneWidget);
      expect(controller.coinRewards, isEmpty);
      expect(session.profile.balance, 110);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reduced motion consumes the effect and pausing cancels it without changing the credited amount',
    (tester) async {
      final (session, controller) = await mount(tester);
      await controller.preferences.update(
        controller.preferences.value.copyWith(reduceMotion: true),
      );
      await tester.pumpAndSettle();
      await drag(tester, controller, 'TOGA');
      await tester.pumpAndSettle();
      expect(controller.coinRewards, isEmpty);
      expect(
        find.byKey(const ValueKey('flying-coin-explorer-reward:1-0')),
        findsNothing,
      );
      expect(session.profile.balance, 70);
      controller.cancelTransientPresentation();
      await tester.pumpAndSettle();
      expect(controller.coinRewards, isEmpty);
      expect(session.profile.balance, 70);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'failed completion never flies coins before commit and a recovered receipt queues one reward',
    () async {
      final repo = FailingRewardRepository();
      final session = await GameSessionCoordinator.create(loadData(), repo);
      await session.startOrContinue();
      final words = session.engine.state.level.words;
      for (final word in words.take(words.length - 1)) {
        await session.submitWord(
          idsFor(session.engine, word.key),
          session: session.engine.state.session,
        );
      }
      final controller = GameController(session.engine, coordinator: session);
      final geometry = WheelGeometry(300, controller.state.order);
      controller.configureGeometry(geometry);
      final ids = idsFor(session.engine, words.last.key);
      repo.fail = true;
      controller.down(1, geometry.centers[ids.first]!);
      for (final id in ids.skip(1)) {
        controller.move(1, geometry.centers[id]!);
      }
      controller.up(1, geometry.centers[ids.last]!);
      await controller.waitIdle();
      expect(controller.saveError, isNotNull);
      expect(controller.coinRewards, isEmpty);
      expect(session.profile.balance, 60);
      repo.fail = false;
      await controller.retrySave();
      await controller.retrySave();
      expect(session.profile.balance, 80);
      expect(controller.coinRewards, hasLength(1));
      controller.finishCoinReward(controller.coinRewards.single);
      expect(controller.coinRewards, isEmpty);
      expect(session.profile.balance, 80);
      controller.dispose();
      await session.close();
    },
  );
}
