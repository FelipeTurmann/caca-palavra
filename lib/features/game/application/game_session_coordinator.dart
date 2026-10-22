import 'dart:async';
import 'dart:math';

import '../data/game_data.dart';
import '../data/progress_repository.dart';
import '../domain/game_engine.dart';
import '../domain/round_snapshot.dart';
import 'campaign_models.dart';
import 'daily_models.dart';
import 'shop_models.dart';
import '../data/daily_catalog.dart';

String operationId(String prefix) {
  final random = Random.secure();
  return '$prefix:${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

Map<String, dynamic>? revealJson(LetterReveal? reveal) => reveal == null
    ? null
    : {
        'targetKey': reveal.targetKey,
        'index': reveal.index,
        'letter': reveal.letter,
      };
LetterReveal? revealFromJson(dynamic value) => value == null
    ? null
    : LetterReveal(
        targetKey: value['targetKey'] as String,
        index: value['index'] as int,
        letter: value['letter'] as String,
      );
Map<String, dynamic> submissionJson(SubmissionResult result) => {
  'kind': 'submission',
  'submission': result.kind.name,
  'display': result.word?.display,
  'completed': result.completed,
  'explorerUnlocked': result.explorerUnlocked,
  'reveal': revealJson(result.revealedLetter),
};
SubmissionResult submissionFromJson(Map<String, dynamic> json) =>
    SubmissionResult(
      SubmissionKind.values.byName(json['submission'] as String),
      word: json['display'] == null
          ? null
          : WordEntry(json['display'] as String),
      completed: json['completed'] == true,
      explorerUnlocked: json['explorerUnlocked'] == true,
      revealedLetter: revealFromJson(json['reveal']),
    );

class HintOutcome {
  const HintOutcome(this.status, [this.reveal]);
  final String status;
  final LetterReveal? reveal;
}

class SuperHintOutcome {
  const SuperHintOutcome(this.status, [this.submission]);
  final String status;
  final SubmissionResult? submission;
}

/// One serial writer for campaign, daily rounds and the shared wallet.
class GameSessionCoordinator {
  GameSessionCoordinator._(
    this.data,
    this.repository,
    this.engine,
    this.profile,
    this.dailyCatalog,
    this.now,
    this.purchaseProvider,
    this.adProvider,
  );
  final GameData data;
  final ProgressRepository repository;
  GameEngine engine;
  CampaignProfile profile;
  final DailyCatalog dailyCatalog;
  final DateTime Function() now;
  final PurchaseProvider purchaseProvider;
  final RewardAdProvider adProvider;
  GameMode mode = GameMode.campaign;
  String? activeDailyDate;
  String? _restoredIdentity;
  SaveProposal? _failed;
  Future<void> _tail = Future.value();
  Future<Map<String, dynamic>>? _shopInFlight;
  bool freshCompletion = false;
  bool get hasFailedCommand => _failed != null;
  String get today => calendarDate(now());
  bool get clockReversed =>
      profile.lastDailyDate != null &&
      today.compareTo(profile.lastDailyDate!) < 0;
  DailyProgress? get todayProgress => profile.daily[today];
  DailyProgress? get activeDay => profile.daily[activeDailyDate];
  bool get dailyInvalid =>
      mode == GameMode.daily &&
      (clockReversed ||
          activeDailyDate != today ||
          activeDay?.expired != false);
  RoundSnapshot? get activeRound =>
      mode == GameMode.campaign ? profile.currentRound : activeDay?.round;
  RoundContext? get context {
    final round = activeRound;
    return round == null
        ? null
        : RoundContext(
            mode,
            round.roundId,
            round.levelId,
            engine.state.session,
            mode == GameMode.daily ? activeDailyDate : null,
          );
  }

  int get completionReward => mode == GameMode.daily
      ? Economy.dailyReward
      : profile.pendingCompletion?.reward ?? Economy.levelReward;
  int? get nextLevelId {
    final index = data.levels.indexWhere((l) => l.id == profile.currentLevelId);
    return index + 1 < data.levels.length ? data.levels[index + 1].id : null;
  }

  static Future<GameSessionCoordinator> create(
    GameData data,
    ProgressRepository repository, {
    Random? random,
    DailyCatalog? dailyCatalog,
    DateTime Function()? now,
    PurchaseProvider? purchaseProvider,
    RewardAdProvider? adProvider,
  }) async {
    final clock = now ?? DateTime.now;
    if (repository is SqliteProgressRepository) repository.now = clock;
    var profile = await repository.initialize(data);
    for (final pending in await repository.pending()) {
      if (pending.request['mode'] == 'daily' &&
          pending.request['date'] != calendarDate(clock())) {
        await repository.discardPending(pending.id);
        continue;
      }
      try {
        profile = await repository.commit(pending, data);
      } on RevisionConflict {
        await repository.discardPending(pending.id);
        profile = await repository.load(data);
      } on DailyExpired {
        await repository.discardPending(pending.id);
        profile = await repository.load(data);
      } catch (_) {
        if (await repository.resolveOperation(pending.id) == null) rethrow;
        profile = await repository.load(data);
      }
    }
    final c = GameSessionCoordinator._(
      data,
      repository,
      GameEngine(levels: data.levels, lexicon: data.lexicon, random: random),
      profile,
      dailyCatalog ?? DailyCatalog.fixture(data),
      clock,
      purchaseProvider ?? SimulatedPurchaseProvider(),
      adProvider ?? SimulatedRewardAdProvider(),
    );
    final catalog = data.levels.map((l) => l.id).toList();
    if (catalog.length != profile.catalogIds.length ||
        data.catalogVersion != profile.catalogVersion) {
      final extend =
          catalog.length > profile.catalogIds.length &&
          profile.completed.length == profile.catalogIds.length &&
          profile.pendingCompletion == null;
      final next = extend
          ? catalog[profile.catalogIds.length]
          : profile.currentLevelId;
      await c._save(
        SaveProposal(
          id: operationId('catalog'),
          expectedRevision: profile.revision,
          request: {
            'kind': 'catalog',
            'ids': catalog,
            'version': data.catalogVersion,
          },
          profile: profile.copyWith(
            catalogIds: catalog,
            catalogVersion: data.catalogVersion,
            currentLevelId: next,
            unlocked: {
              ...profile.unlocked,
              if (profile.completed.length < catalog.length)
                catalog[profile.completed.length],
            },
            revision: profile.revision + 1,
          ),
          result: {'kind': 'catalog'},
        ),
      );
    }
    await c._refreshDate();
    c._restore();
    return c;
  }

  Future<T> _serial<T>(Future<T> Function() command) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await command());
      } catch (e, s) {
        result.completeError(e, s);
      }
    });
    return result.future;
  }

  void _restore({bool completing = false}) {
    final round = activeRound;
    final identity = '${mode.name}:${activeDailyDate ?? ''}:${round?.roundId}';
    if (_restoredIdentity != identity) {
      if (mode == GameMode.daily && activeDay != null) {
        engine = GameEngine(
          levels: [activeDay!.definition],
          lexicon: activeDay!.lexicon,
          random: engine.randomSource,
        );
      } else {
        engine = GameEngine(
          levels: data.levels,
          lexicon: data.lexicon,
          random: engine.randomSource,
        );
      }
    }
    if (round != null) {
      engine.restoreRound(
        round,
        showCompletion: completing,
        preserveSession: _restoredIdentity == identity,
      );
    } else {
      engine.startLevel(profile.currentLevelId);
    }
    _restoredIdentity = identity;
  }

  bool _sameRequest(Map<String, dynamic> a, Map<String, dynamic> b) {
    Map<String, dynamic> normalize(Map<String, dynamic> v) => {
      ...v,
      if (v.containsKey('roundId')) 'mode': v['mode'] ?? 'campaign',
    };
    return canonicalJson(normalize(a)) == canonicalJson(normalize(b));
  }

  Future<Map<String, dynamic>> _save(SaveProposal proposal) async {
    try {
      await repository.prepare(proposal);
      if (proposal.request['mode'] == 'daily' &&
          proposal.request['date'] != today) {
        throw DailyExpired();
      }
      profile = await repository.commit(proposal, data);
      _failed = null;
      return proposal.result;
    } on RevisionConflict {
      await repository.discardPending(proposal.id);
      profile = await repository.load(data);
      _failed = null;
      _restore();
      rethrow;
    } catch (error) {
      _failed = proposal;
      final resolved = await repository.resolveOperation(proposal.id);
      if (resolved != null && resolved.result['rejected'] != true) {
        if (!_sameRequest(resolved.request, proposal.request)) {
          throw OperationMismatch();
        }
        profile = await repository.load(data);
        _failed = null;
        return resolved.result;
      }
      if (error is DailyExpired) {
        await repository.discardPending(proposal.id);
        _failed = null;
        await _refreshDate();
      }
      rethrow;
    }
  }

  Future<void> _refreshDate() async {
    final date = today;
    final advance =
        profile.lastDailyDate != null &&
        date.compareTo(profile.lastDailyDate!) > 0;
    final expired = <String, DailyProgress>{};
    for (final day in profile.daily.values) {
      if (day.date.compareTo(date) < 0 && !day.completed && !day.expired) {
        expired[day.date] = day.copyWith(expired: true);
      }
    }
    if (expired.isNotEmpty || advance) {
      await _save(
        SaveProposal(
          id: operationId('expire'),
          expectedRevision: profile.revision,
          request: {'kind': 'expire', 'today': date},
          profile: profile.copyWith(
            daily: {...profile.daily, ...expired},
            lastDailyDate: advance ? date : profile.lastDailyDate,
            revision: profile.revision + 1,
          ),
          result: {'kind': 'expire'},
        ),
      );
    }
  }

  Future<void> refreshDaily() => _serial(() async {
    if (_failed == null) await _refreshDate();
  });
  Future<void> _guard(RoundContext? expected) async {
    if (_failed != null) throw StateError('Resolva o salvamento pendente.');
    await _refreshDate();
    if (mode == GameMode.daily && dailyInvalid) {
      if (clockReversed) throw ClockReversed();
      throw DailyExpired();
    }
    if (expected == null || context?.identity != expected.identity) {
      throw StateError('Esta rodada já mudou.');
    }
  }

  Map<String, dynamic> _request(String kind, RoundContext ctx) => {
    'kind': kind,
    'mode': ctx.mode.name,
    'roundId': ctx.roundId,
    'levelId': ctx.levelId,
    if (ctx.date != null) 'date': ctx.date,
  };
  CampaignProfile _withRound(RoundSnapshot round) => mode == GameMode.campaign
      ? profile.copyWith(
          rounds: {...profile.rounds, round.levelId: round},
          revision: profile.revision + 1,
        )
      : profile.copyWith(
          daily: {
            ...profile.daily,
            activeDailyDate!: activeDay!.copyWith(round: round),
          },
          revision: profile.revision + 1,
        );
  (CampaignProfile, List<CoinOperation>) _completion(
    CampaignProfile candidate,
    RoundContext ctx,
  ) {
    if (mode == GameMode.daily) {
      final day = candidate.daily[ctx.date]!;
      return (
        candidate.copyWith(
          balance: candidate.balance + Economy.dailyReward,
          daily: {
            ...candidate.daily,
            ctx.date!: day.copyWith(pendingResult: true),
          },
        ),
        [
          CoinOperation(
            id: 'daily-completion:${ctx.date}',
            kind: 'daily_completion',
            amount: Economy.dailyReward,
            levelId: ctx.levelId,
            roundId: ctx.roundId,
          ),
        ],
      );
    }
    return (
      candidate.copyWith(
        balance: candidate.balance + Economy.levelReward,
        completed: {...candidate.completed, ctx.levelId},
        unlocked: {...candidate.unlocked, ?nextLevelId},
        pendingCompletion: PendingCompletion(
          levelId: ctx.levelId,
          roundId: ctx.roundId,
          reward: Economy.levelReward,
        ),
      ),
      [
        CoinOperation(
          id: 'level-completion:${ctx.levelId}',
          kind: 'level_completion',
          amount: Economy.levelReward,
          levelId: ctx.levelId,
          roundId: ctx.roundId,
        ),
      ],
    );
  }

  Future<Map<String, dynamic>?> retry() => _serial(() async {
    final failed = _failed;
    if (failed == null) {
      profile = await repository.load(data);
      await _refreshDate();
      _restore();
      return null;
    }
    final result = await _save(failed);
    _restore(completing: result['completed'] == true);
    freshCompletion = result['completed'] == true;
    if (result['kind'] == 'submission' || result['kind'] == 'super_hint') {
      engine.emitCommitted(submissionFromJson(result));
    }
    return result;
  });
  Future<void> startOrContinue() => _serial(() async {
    if (_failed != null) throw StateError('Resolva o salvamento pendente.');
    await _refreshDate();
    mode = GameMode.campaign;
    activeDailyDate = null;
    if (profile.currentRound == null && !profile.campaignComplete) {
      final candidate = GameEngine(levels: data.levels, lexicon: data.lexicon)
        ..startLevel(profile.currentLevelId);
      final round = candidate.snapshot(operationId('round'));
      await _save(
        SaveProposal(
          id: operationId('start'),
          expectedRevision: profile.revision,
          request: {'kind': 'start', 'levelId': profile.currentLevelId},
          profile: profile.copyWith(
            hasStarted: true,
            rounds: {...profile.rounds, round.levelId: round},
            revision: profile.revision + 1,
          ),
          result: {'kind': 'start'},
        ),
      );
    }
    freshCompletion = false;
    _restore();
  });
  Future<void> startDaily() => _serial(() async {
    if (_failed != null) throw StateError('Resolva o salvamento pendente.');
    await _refreshDate();
    if (clockReversed) throw ClockReversed();
    final date = today;
    final old = profile.daily[date];
    if (old?.completed == true && old?.pendingResult == false) {
      throw StateError('Desafio de hoje concluído.');
    }
    if (old == null) {
      final definition = dailyCatalog.forDate(date);
      final candidate = GameEngine(
        levels: [definition],
        lexicon: dailyCatalog.lexicon,
        random: engine.randomSource,
      );
      final day = DailyProgress(
        date: date,
        catalogVersion: dailyCatalog.version,
        definition: definition,
        lexicon: dailyCatalog.lexicon,
        round: candidate.snapshot(operationId('daily:$date')),
      );
      await _save(
        SaveProposal(
          id: operationId('start-daily'),
          expectedRevision: profile.revision,
          request: {'kind': 'start_daily', 'mode': 'daily', 'date': date},
          profile: profile.copyWith(
            daily: {...profile.daily, date: day},
            lastDailyDate: date,
            revision: profile.revision + 1,
          ),
          result: {'kind': 'start_daily'},
        ),
      );
    }
    mode = GameMode.daily;
    activeDailyDate = date;
    freshCompletion = false;
    _restore();
  });
  Future<SubmissionResult> submitWord(
    List<String> ids, {
    required int session,
    RoundContext? expected,
  }) {
    final ctx = expected ?? context;
    return _serial(() async {
      if (ctx == null ||
          session != ctx.session ||
          context?.identity != ctx.identity ||
          activeRound?.status != 'in_progress') {
        return const SubmissionResult(SubmissionKind.ignored);
      }
      await _guard(ctx);
      final round = activeRound!, candidate = engine.fork(activeRound!);
      final result = candidate.submit(ids, session: candidate.state.session);
      if (result.kind != SubmissionKind.targetFound &&
          result.kind != SubmissionKind.extraFound) {
        return result;
      }
      var proposed = _withRound(candidate.snapshot(round.roundId));
      var coins = <CoinOperation>[];
      var id = operationId('word');
      if (result.completed) {
        final outcome = _completion(proposed, ctx);
        proposed = outcome.$1;
        coins = outcome.$2;
        id = coins.single.id;
      } else if (result.explorerUnlocked && mode == GameMode.campaign) {
        id = 'explorer-reward:${round.levelId}';
        coins = [
          CoinOperation(
            id: id,
            kind: 'explorer_reward',
            amount: Economy.explorerReward,
            levelId: round.levelId,
            roundId: round.roundId,
          ),
        ];
        proposed = proposed.copyWith(
          balance: proposed.balance + Economy.explorerReward,
          explorerRewardedLevels: {
            ...proposed.explorerRewardedLevels,
            round.levelId,
          },
        );
      }
      final saved = await _save(
        SaveProposal(
          id: id,
          expectedRevision: profile.revision,
          request: {
            ..._request(coins.isEmpty ? 'word' : coins.single.kind, ctx),
            'ids': ids,
          },
          profile: proposed,
          result: submissionJson(result),
          coins: coins,
        ),
      );
      final confirmed = submissionFromJson(saved);
      freshCompletion = confirmed.completed;
      _restore(completing: confirmed.completed);
      engine.emitCommitted(confirmed);
      return confirmed;
    });
  }

  Future<bool> shuffle({RoundContext? expected}) {
    final ctx = expected ?? context;
    return _serial(() async {
      if (ctx == null ||
          context?.identity != ctx.identity ||
          activeRound?.status != 'in_progress') {
        return false;
      }
      await _guard(ctx);
      final candidate = engine.fork(activeRound!);
      if (!candidate.shuffle()) return false;
      await _save(
        SaveProposal(
          id: operationId('shuffle'),
          expectedRevision: profile.revision,
          request: _request('shuffle', ctx),
          profile: _withRound(candidate.snapshot(ctx.roundId)),
          result: {'kind': 'shuffle'},
        ),
      );
      _restore();
      return true;
    });
  }

  String createHintId() =>
      operationId('hint:${activeRound?.roundId ?? 'none'}');
  Future<HintOutcome> purchaseHint({
    String? operationId,
    String? roundId,
    RoundContext? expected,
  }) {
    final ctx = expected ?? context, id = operationId ?? createHintId();
    return _serial(() async {
      if (ctx == null) return const HintOutcome('inactive');
      final request = {
        ..._request('paid_hint', ctx),
        'roundId': roundId ?? ctx.roundId,
        'price': Economy.hintPrice,
      };
      final receipt = await repository.resolveOperation(id);
      if (receipt != null) {
        if (!_sameRequest(receipt.request, request) ||
            receipt.result['rejected'] == true) {
          throw OperationMismatch();
        }
        profile = await repository.load(data);
        _restore();
        return HintOutcome(
          'purchased',
          revealFromJson(receipt.result['reveal']),
        );
      }
      await _guard(ctx);
      if (roundId != null && roundId != ctx.roundId) {
        return const HintOutcome('inactive');
      }
      final candidate = engine.fork(activeRound!);
      if (!candidate.canReveal) return const HintOutcome('unavailable');
      if (profile.balance < Economy.hintPrice) {
        return const HintOutcome('insufficient');
      }
      final reveal = candidate.revealPaidHint(id)!;
      final saved = await _save(
        SaveProposal(
          id: id,
          expectedRevision: profile.revision,
          request: request,
          profile: _withRound(
            candidate.snapshot(ctx.roundId),
          ).copyWith(balance: profile.balance - Economy.hintPrice),
          coins: [
            CoinOperation(
              id: id,
              kind: 'paid_hint',
              amount: -Economy.hintPrice,
              levelId: ctx.levelId,
              roundId: ctx.roundId,
            ),
          ],
          result: {'kind': 'hint', 'reveal': revealJson(reveal)},
        ),
      );
      _restore();
      return HintOutcome('purchased', revealFromJson(saved['reveal']));
    });
  }

  Future<SuperHintOutcome> purchaseSuperHint({
    String? operationId,
    RoundContext? expected,
  }) {
    final ctx = expected ?? context, id = operationId ?? createHintId();
    return _serial(() async {
      if (ctx == null) return const SuperHintOutcome('inactive');
      final request = {
        ..._request('super_hint', ctx),
        'price': Economy.superHintPrice,
      };
      final receipt = await repository.resolveOperation(id);
      if (receipt != null) {
        if (!_sameRequest(receipt.request, request) ||
            receipt.result['rejected'] == true) {
          throw OperationMismatch();
        }
        profile = await repository.load(data);
        _restore();
        return SuperHintOutcome(
          'purchased',
          submissionFromJson(receipt.result),
        );
      }
      await _guard(ctx);
      if (activeRound?.status != 'in_progress') {
        return const SuperHintOutcome('unavailable');
      }
      if (profile.balance < Economy.superHintPrice) {
        return const SuperHintOutcome('insufficient');
      }
      final candidate = engine.fork(activeRound!);
      final result = candidate.resolveSuperHint(id);
      if (result.kind == SubmissionKind.ignored) {
        return const SuperHintOutcome('unavailable');
      }
      var proposed = _withRound(
        candidate.snapshot(ctx.roundId),
      ).copyWith(balance: profile.balance - Economy.superHintPrice);
      var coins = <CoinOperation>[
        CoinOperation(
          id: '$id:debit',
          kind: 'super_hint',
          amount: -Economy.superHintPrice,
          levelId: ctx.levelId,
          roundId: ctx.roundId,
        ),
      ];
      if (result.completed) {
        final outcome = _completion(proposed, ctx);
        proposed = outcome.$1;
        coins.addAll(outcome.$2);
      }
      final resolution = candidate.state.superHints.last;
      final saved = await _save(
        SaveProposal(
          id: id,
          expectedRevision: profile.revision,
          request: request,
          profile: proposed,
          coins: coins,
          result: {
            ...submissionJson(result),
            'kind': 'super_hint',
            'targetKey': resolution.targetKey,
            'indices': resolution.indices,
          },
        ),
      );
      final confirmed = submissionFromJson(saved);
      freshCompletion = confirmed.completed;
      _restore(completing: confirmed.completed);
      engine.emitCommitted(confirmed);
      return SuperHintOutcome('purchased', confirmed);
    });
  }

  Future<Map<String, dynamic>> _shop(
    String kind,
    String id, {
    String? packageId,
  }) async {
    final request = <String, dynamic>{
      'kind': kind,
      'simulated': true,
      'packageId': ?packageId,
    };
    final receipt = await repository.resolveOperation(id);
    if (receipt != null) {
      if (!_sameRequest(receipt.request, request) ||
          receipt.result['rejected'] == true) {
        throw OperationMismatch();
      }
      profile = await repository.load(data);
      return receipt.result;
    }
    if (_failed != null) throw StateError('Resolva o salvamento pendente.');
    final provided = kind == 'simulated_ad'
        ? await adProvider.reward(id)
        : await purchaseProvider.purchase(id, ShopCatalog.find(packageId!));
    final amount = kind == 'simulated_ad'
        ? Economy.adReward
        : ShopCatalog.find(packageId!).amount;
    if (provided.orderId != id ||
        provided.source != kind ||
        provided.amount != amount ||
        provided.packageId != packageId) {
      throw StateError('Recibo simulado inválido.');
    }
    return _save(
      SaveProposal(
        id: id,
        expectedRevision: profile.revision,
        request: request,
        profile: profile.copyWith(
          balance: profile.balance + amount,
          revision: profile.revision + 1,
        ),
        coins: [CoinOperation(id: id, kind: kind, amount: amount)],
        result: {'kind': 'shop', ...provided.toJson()},
      ),
    );
  }

  Future<Map<String, dynamic>> _credit(
    String kind,
    String id, {
    String? packageId,
  }) {
    if (_shopInFlight != null) return _shopInFlight!;
    final future = _serial(() => _shop(kind, id, packageId: packageId));
    _shopInFlight = future;
    return future.whenComplete(() => _shopInFlight = null);
  }

  Future<Map<String, dynamic>> simulatePurchase(
    String packageId, {
    String? id,
  }) {
    ShopCatalog.find(packageId);
    return _credit(
      'simulated_purchase',
      id ?? operationId('purchase'),
      packageId: packageId,
    );
  }

  Future<Map<String, dynamic>> simulateAd({String? id}) =>
      _credit('simulated_ad', id ?? operationId('ad'));
  Future<bool> advance() {
    final ctx = context, requested = profile.pendingCompletion?.roundId;
    return _serial(() async {
      if (_failed != null) throw StateError('Resolva o salvamento pendente.');
      if (ctx == null || context?.identity != ctx.identity) return false;
      if (mode == GameMode.daily) {
        await _guard(ctx);
        final day = activeDay!;
        if (!day.pendingResult) return false;
        await _save(
          SaveProposal(
            id: operationId('ack-daily'),
            expectedRevision: profile.revision,
            request: _request('ack_daily', ctx),
            profile: profile.copyWith(
              daily: {
                ...profile.daily,
                ctx.date!: day.copyWith(pendingResult: false),
              },
              revision: profile.revision + 1,
            ),
            result: {'kind': 'advance', 'home': true},
          ),
        );
        freshCompletion = false;
        _restore();
        return false;
      }
      final pending = profile.pendingCompletion;
      if (pending == null || pending.roundId != requested) return false;
      final next = nextLevelId;
      var proposed = profile.copyWith(
        clearPending: true,
        revision: profile.revision + 1,
      );
      if (next != null) {
        final candidate = GameEngine(levels: data.levels, lexicon: data.lexicon)
          ..startLevel(next);
        proposed = proposed.copyWith(
          currentLevelId: next,
          rounds: {
            ...profile.rounds,
            next: candidate.snapshot(operationId('round')),
          },
        );
      }
      await _save(
        SaveProposal(
          id: operationId('advance'),
          expectedRevision: profile.revision,
          request: {'kind': 'advance', 'roundId': pending.roundId},
          profile: proposed,
          result: {'kind': 'advance', 'home': next == null},
        ),
      );
      freshCompletion = false;
      _restore();
      return next != null;
    });
  }

  Future<void> close() async {
    await _tail;
    await repository.close();
  }
}
