import 'dart:async';

import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/core/widgets/game_loading.dart';
import 'package:caca_palavra/core/widgets/garden.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/application/campaign_models.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';
import 'package:caca_palavra/features/game/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'campaign_widget_test.dart' show MemoryProgressRepository;
import 'helpers.dart';
import 'widget_test.dart' show dragWord;

class _SlowRepository extends MemoryProgressRepository {
  _SlowRepository() : super(60);
  Completer<void>? completionGate;
  bool failCompletion = false;
  int completionCommits = 0;

  @override
  Future<CampaignProfile> commit(SaveProposal proposal, GameData data) async {
    if (proposal.result['completed'] == true) {
      await completionGate?.future;
      if (failCompletion) throw StateError('Unavailable');
      completionCommits++;
    }
    return super.commit(proposal, data);
  }
}

void main() {
  testWidgets('startup shows a friendly wait until the real profile is ready', (
    tester,
  ) async {
    final loading = Completer<GameSessionCoordinator>();
    await tester.pumpWidget(WordGameApp(loader: () => loading.future));
    expect(find.text('Preparando seu jogo…'), findsOneWidget);
    expect(find.text('Jogar'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Preparando seu jogo…'), findsOneWidget);
    loading.complete(
      await GameSessionCoordinator.create(
        loadData(),
        MemoryProgressRepository(80),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('80 moedas'), findsOneWidget);
    expect(find.byType(GameLoadingScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'account reload hides the previous progress until the new account is ready',
    (tester) async {
      final next = Completer<GameSessionCoordinator>();
      final first = await GameSessionCoordinator.create(
        loadData(),
        MemoryProgressRepository(80),
      );
      var loads = 0;
      await tester.pumpWidget(
        WordGameApp(loader: () async => ++loads == 1 ? first : next.future),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<HomeScreen>(find.byType(HomeScreen))
          .controller;
      await controller.onSessionChanged!();
      await tester.pump();
      expect(find.text('Carregando seu progresso…'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      next.complete(
        await GameSessionCoordinator.create(
          loadData(),
          MemoryProgressRepository(120),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('120 moedas'), findsOneWidget);
      expect(find.text('80 moedas'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final fail in [false, true]) {
    testWidgets(
      'completion celebrates while saving and ${fail ? 'retries after failure' : 'unlocks on confirmation'}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(412, 915);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _SlowRepository();
        final game = await GameSessionCoordinator.create(
          loadData(),
          repository,
        );
        await game.startOrContinue();
        final words = game.engine.state.level.words;
        for (final word in words.take(words.length - 1)) {
          await game.submitWord(
            idsFor(game.engine, word.key),
            session: game.engine.state.session,
          );
        }
        final controller = GameController(game.engine, coordinator: game);
        addTearDown(controller.dispose);
        repository.completionGate = Completer<void>();
        repository.failCompletion = fail;
        await tester.pumpWidget(
          MaterialApp(home: GameScreen(controller: controller)),
        );
        await tester.pumpAndSettle();
        final balance = controller.balance;
        final next = find.byKey(const ValueKey('next-level'));
        final message = find.byKey(const ValueKey('completion-message'));
        final coins = find.byKey(
          const ValueKey('coin-flight-level-completion:1'),
        );
        await dragWord(tester, controller, words.last.key);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Salvando progresso…'), findsOneWidget);
        expect(message, findsOneWidget);
        expect(coins, findsOneWidget);
        expect(tester.widget<VolumeButton>(next).onPressed, isNull);
        expect(
          controller.completionState.targets,
          words.map((word) => word.key).toSet(),
        );
        final phrase = tester.widget<Text>(message).data;
        await tester.pump(
          GameTiming.coinCollect + const Duration(milliseconds: 100),
        );
        await tester.pump();
        expect(coins, findsNothing);
        expect(controller.balance, balance);
        expect(game.profile.completed, isEmpty);
        // A system back press must not queue a navigation after saving.
        await tester.binding.handlePopRoute();
        expect(controller.completionSaving, true);
        repository.completionGate!.complete();
        await tester.pumpAndSettle();
        if (fail) {
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(tester.widget<Text>(message).data, phrase);
          expect(tester.widget<VolumeButton>(next).onPressed, isNull);
          expect(find.text('Tentar novamente'), findsOneWidget);
          expect(game.profile.completed, isEmpty);
          repository.failCompletion = false;
          repository.completionGate = Completer<void>();
          await tester.tap(find.text('Tentar novamente'));
          await tester.pump();
          expect(find.text('Salvando progresso…'), findsOneWidget);
          expect(coins, findsNothing);
          repository.completionGate!.complete();
          await tester.pumpAndSettle();
        }
        expect(tester.widget<Text>(message).data, phrase);
        expect(tester.widget<VolumeButton>(next).onPressed, isNotNull);
        expect(coins, findsNothing);
        expect(repository.completionCommits, 1);
        expect(game.profile.completed, {1});
        expect(controller.balance, balance + 20);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('loading fits small screens, large text and reduced motion', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: const GameLoadingScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Preparando seu jogo…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
