import 'package:caca_palavra/features/game/application/campaign_models.dart';
import 'package:caca_palavra/features/game/data/game_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caca_palavra/app.dart';
import 'package:caca_palavra/features/game/application/game_session_coordinator.dart';
import 'package:caca_palavra/features/game/data/progress_repository.dart';
import 'package:caca_palavra/features/game/presentation/game_controller.dart';
import 'package:caca_palavra/features/game/presentation/home_screen.dart';
import 'helpers.dart';
import 'package:caca_palavra/features/game/presentation/game_screen.dart';

void main() {
  Future<GameSessionCoordinator> session(
    WidgetTester tester, {
    int balance = 60,
  }) => GameSessionCoordinator.create(
    loadData(),
    MemoryProgressRepository(balance),
  );
  Future<void> tapAndSave(
    WidgetTester tester,
    Finder finder,
    GameController c,
  ) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'production entry opens home, play, cancel and buy hint, back and continue',
    (tester) async {
      final c = await session(tester);
      await tester.pumpWidget(WordGameApp(loader: () async => c));
      await tester.pumpAndSettle();
      expect(find.text('Jogar'), findsOneWidget);
      expect(find.text('60 moedas'), findsOneWidget);
      final controller = tester
          .widget<HomeScreen>(find.byType(HomeScreen))
          .controller;
      await tapAndSave(tester, find.byKey(const ValueKey('play')), controller);
      expect(find.text('Nível 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('hint')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(c.profile.balance, 60);
      expect(c.profile.currentRound!.reveals, isEmpty);
      await tester.tap(find.byKey(const ValueKey('hint')));
      await tester.pumpAndSettle();
      expect(find.textContaining('anúncio'), findsNothing);
      await tapAndSave(
        tester,
        find.byKey(const ValueKey('confirm-hint')),
        controller,
      );
      expect(find.text('30 moedas'), findsOneWidget);
      expect(c.profile.currentRound!.paidHints, 1);
      await tapAndSave(tester, find.byTooltip('Início'), controller);
      expect(find.text('Continuar · Nível 1'), findsOneWidget);
      await tapAndSave(tester, find.byKey(const ValueKey('play')), controller);
      expect(c.profile.currentRound!.paidHints, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    '29 coins dialog gives exact shortfall, no ad or purchase action',
    (tester) async {
      final c = await session(tester, balance: 29);
      await tester.pumpWidget(WordGameApp(loader: () async => c));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<HomeScreen>(find.byType(HomeScreen))
          .controller;
      await tapAndSave(tester, find.byKey(const ValueKey('play')), controller);
      await tester.tap(find.byKey(const ValueKey('hint')));
      await tester.pumpAndSettle();
      expect(find.text('Moedas insuficientes'), findsOneWidget);
      expect(find.textContaining('Faltam 1 '), findsOneWidget);
      expect(find.byKey(const ValueKey('confirm-hint')), findsNothing);
      expect(find.textContaining('anúncio'), findsNothing);
      expect(c.profile.balance, 29);
      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('initial load error retries while keeping the existing profile', (
    tester,
  ) async {
    final c = await session(tester);
    var attempts = 0;
    await tester.pumpWidget(
      WordGameApp(
        loader: () async {
          if (++attempts == 1) {
            throw const FormatException('Versão de progresso incompatível.');
          }
          return c;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Versão de progresso incompatível.'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Jogar'), findsOneWidget);
    expect(c.profile.balance, 60);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'production home and game fit 320px with large text and a scrollable hint action',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final c = await session(tester);
      await c.startOrContinue();
      final controller = GameController(c.engine, coordinator: c);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: HomeScreen(controller: controller, onPlay: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: GameScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('hint')));
      await tester.tap(find.byKey(const ValueKey('hint')));
      await tester.pumpAndSettle();
      expect(find.text('Revelar uma letra?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'restored result says reward already received and advances only once',
    (tester) async {
      final c = await session(tester);
      await c.startOrContinue();
      for (final word in c.engine.state.level.words) {
        await c.submitWord(
          idsFor(c.engine, word.key),
          session: c.engine.state.session,
        );
      }
      await tester.pumpWidget(WordGameApp(loader: () async => c));
      await tester.pumpAndSettle();
      expect(find.text('Ver resultado · Nível 1'), findsOneWidget);
      final controller = tester
          .widget<HomeScreen>(find.byType(HomeScreen))
          .controller;
      await tapAndSave(tester, find.byKey(const ValueKey('play')), controller);
      expect(find.text('Recompensa de 20 moedas já recebida'), findsOneWidget);
      expect(c.profile.balance, 80);
      await tapAndSave(
        tester,
        find.byKey(const ValueKey('next-level')),
        controller,
      );
      expect(c.profile.currentLevelId, 2);
      expect(c.profile.balance, 80);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('new Explorer badge shows +10 coins and updates wallet once', (
    tester,
  ) async {
    final c = await session(tester);
    await tester.pumpWidget(WordGameApp(loader: () async => c));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<HomeScreen>(find.byType(HomeScreen))
        .controller;
    await tapAndSave(tester, find.byKey(const ValueKey('play')), controller);
    Future<void> dragExtra() async {
      final ids = idsFor(c.engine, 'TOGA');
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ValueKey(ids.first))),
      );
      for (final id in ids.skip(1)) {
        await gesture.moveTo(tester.getCenter(find.byKey(ValueKey(id))));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
    }

    await dragExtra();
    expect(find.text('+10 moedas!'), findsOneWidget);
    expect(find.text('70 moedas'), findsOneWidget);
    await tester.pumpAndSettle();
    await dragExtra();
    expect(c.profile.balance, 70);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('extras')));
    await tester.pumpAndSettle();
    expect(find.text('+10 moedas recebidas pelo selo.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

// UI fixtures use immediate futures; transaction guarantees are covered with real SQLite.
class MemoryProgressRepository implements ProgressRepository {
  MemoryProgressRepository(this.balance);
  final int balance;
  CampaignProfile? profile;
  final Map<String, SaveProposal> prepared = {};
  final Map<String, SavedOperation> receipts = {};
  @override
  Future<CampaignProfile> initialize(GameData data) async =>
      profile ??= CampaignProfile(
        balance: balance,
        revision: 0,
        currentLevelId: data.levels.first.id,
        catalogIds: data.levels.map((l) => l.id).toList(),
        unlocked: {data.levels.first.id},
        completed: {},
        rounds: {},
      );
  @override
  Future<CampaignProfile> load(GameData data) async => profile!;
  @override
  Future<void> prepare(SaveProposal proposal) async {
    prepared[proposal.id] = proposal;
  }

  @override
  Future<CampaignProfile> commit(SaveProposal proposal, GameData data) async {
    receipts[proposal.id] = SavedOperation(proposal.request, proposal.result);
    prepared.remove(proposal.id);
    return profile = proposal.profile;
  }

  @override
  Future<SavedOperation?> resolveOperation(String id) async => receipts[id];
  @override
  Future<List<SaveProposal>> pending() async => prepared.values.toList();
  @override
  Future<void> discardPending(String id) async {
    prepared.remove(id);
  }

  @override
  Future<void> close() async {}
}
