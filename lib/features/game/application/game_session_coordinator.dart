import 'dart:async';
import 'dart:math';

import '../data/game_data.dart';
import '../data/progress_repository.dart';
import '../domain/game_engine.dart';
import '../domain/round_snapshot.dart';
import 'campaign_models.dart';
import 'daily_models.dart';
import 'shop_models.dart';
import 'theme_unlocks.dart';
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
  if (result.resolvedWord != null)
    'resolvedDisplay': result.resolvedWord!.display,
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
      resolvedWord: json['resolvedDisplay'] == null
          ? null
          : WordEntry(json['resolvedDisplay'] as String),
    );

class HintOutcome {
  const HintOutcome(this.status, [this.reveal, this.submission]);
  final String status;
  final LetterReveal? reveal;
  final SubmissionResult? submission;

  factory HintOutcome.fromSaved(Map<String, dynamic> saved) => HintOutcome(
    'purchased',
    revealFromJson(saved['reveal']),
    saved['submission'] == null ? null : submissionFromJson(saved),
  );
}

class SuperHintOutcome {
  const SuperHintOutcome(this.status, [this.submission]);
  final String status;
  final SubmissionResult? submission;
}

class MascotHintOutcome {
  const MascotHintOutcome(this.status, [this.hint]);
  final String status;
  final MascotHint? hint;
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

  bool isThemeUnlocked(String id) =>
      ThemeUnlocks.available(id, profile.purchasedThemes, profile.unlocked);

  Future<Map<String, dynamic>> purchaseTheme(String themeId) =>
      _serial(() async {
        final rule = ThemeUnlocks.rule(themeId);
        if (rule.price == null) {
          return {
            'kind': 'theme_unlock',
            'status': isThemeUnlocked(themeId) ? 'available' : 'locked',
            'themeId': themeId,
          };
        }
        final id = 'theme-unlock:$themeId';
        final request = <String, dynamic>{
          'kind': 'theme_unlock',
          'themeId': themeId,
          'price': rule.price,
          'themePriceVersion': ThemeUnlocks.priceVersion,
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
        if (isThemeUnlocked(themeId)) {
          return {
            'kind': 'theme_unlock',
            'status': 'available',
            'themeId': themeId,
          };
        }
        if (profile.balance < rule.price!) {
          return {
            'kind': 'theme_unlock',
            'status': 'insufficient',
            'themeId': themeId,
          };
        }
        return _save(
          SaveProposal(
            id: id,
            expectedRevision: profile.revision,
            request: request,
            profile: profile.copyWith(
              balance: profile.balance - rule.price!,
              revision: profile.revision + 1,
              purchasedThemes: {...profile.purchasedThemes, themeId},
            ),
            coins: [
              CoinOperation(id: id, kind: 'theme_unlock', amount: -rule.price!),
            ],
            result: {
              'kind': 'theme_unlock',
              'status': 'purchased',
              'themeId': themeId,
            },
          ),
        );
      });
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
    if (result['kind'] == 'submission' ||
        result['kind'] == 'super_hint' ||
        (result['kind'] == 'hint' && result['submission'] != null)) {
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
      }
      if (result.explorerUnlocked && mode == GameMode.campaign) {
        final explorerId = 'explorer-reward:${round.levelId}';
        if (!result.completed) id = explorerId;
        coins = [
          ...coins,
          CoinOperation(
            id: explorerId,
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
            ..._request(coins.length == 1 ? coins.single.kind : 'word', ctx),
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

  Map<String, dynamic> _priceFields(String kind, SavedOperation? receipt) {
    if (receipt == null) {
      return {
        'price': Economy.currentPrice(kind),
        'pricingVersion': Economy.pricingVersion,
      };
    }
    Economy.confirmedPrice(receipt.request);
    return {
      if (receipt.request.containsKey('price'))
        'price': receipt.request['price'],
      if (receipt.request.containsKey('pricingVersion'))
        'pricingVersion': receipt.request['pricingVersion'],
    };
  }

  MascotHint? mascotHintFor(String key) => activeRound?.mascotHints
      .where((hint) => hint.targetKey == key)
      .firstOrNull;

  WordEntry? clueWordFor(String key) {
    if (mode != GameMode.daily) return data.lexicon[key];
    final saved = activeDay?.lexicon[key];
    if (activeDay?.hasClueCatalog == true) return saved;
    final current = data.lexicon[key];
    return saved?.display == current?.display ? current : null;
  }

  Future<MascotHintOutcome> purchaseMascotHint(
    String targetKey, {
    required String operationId,
    RoundContext? expected,
  }) {
    final ctx = expected ?? context;
    return _serial(() async {
      if (ctx == null) return const MascotHintOutcome('inactive');
      final request = {
        ..._request('mascot_hint', ctx),
        'targetKey': targetKey,
        'price': Economy.mascotHintPrice,
        'pricingVersion': Economy.pricingVersion,
      };
      final receipt = await repository.resolveOperation(operationId);
      if (receipt != null) {
        if (!_sameRequest(receipt.request, request) ||
            receipt.result['rejected'] == true) {
          throw OperationMismatch();
        }
        profile = await repository.load(data);
        _restore();
        return MascotHintOutcome(
          'purchased',
          MascotHint.fromJson(
            Map<String, dynamic>.from(receipt.result['hint'] as Map),
          ),
        );
      }
      await _guard(ctx);
      if (activeRound?.status != 'in_progress' ||
          !engine.state.level.words.any((w) => w.key == targetKey)) {
        return const MascotHintOutcome('inactive');
      }
      final existing = mascotHintFor(targetKey);
      if (existing != null) return MascotHintOutcome('available', existing);
      if (engine.state.targets.contains(targetKey)) {
        return const MascotHintOutcome('resolved');
      }
      final word = clueWordFor(targetKey);
      if (word?.clue == null ||
          word!.clue!.trim().isEmpty ||
          word.clue!.length > 120) {
        return const MascotHintOutcome('unavailable');
      }
      if (profile.balance < Economy.mascotHintPrice) {
        return const MascotHintOutcome('insufficient');
      }
      final hint = MascotHint(
        targetKey: targetKey,
        operationId: operationId,
        clue: word.clue!,
        clueVersion: word.clueVersion,
        price: Economy.mascotHintPrice,
        pricingVersion: Economy.pricingVersion,
      );
      final saved = await _save(
        SaveProposal(
          id: operationId,
          expectedRevision: profile.revision,
          request: request,
          profile: _withRound(
            activeRound!.withMascotHint(hint),
          ).copyWith(balance: profile.balance - Economy.mascotHintPrice),
          coins: [
            CoinOperation(
              id: operationId,
              kind: 'mascot_hint',
              amount: -Economy.mascotHintPrice,
              levelId: ctx.levelId,
              roundId: ctx.roundId,
            ),
          ],
          result: {'kind': 'mascot_hint', 'hint': hint.toJson()},
        ),
      );
      _restore();
      return MascotHintOutcome(
        'purchased',
        MascotHint.fromJson(Map<String, dynamic>.from(saved['hint'] as Map)),
      );
    });
  }

  Future<HintOutcome> purchaseHint({
    String? operationId,
    String? roundId,
    RoundContext? expected,
  }) {
    final ctx = expected ?? context, id = operationId ?? createHintId();
    return _serial(() async {
      if (ctx == null) return const HintOutcome('inactive');
      final receipt = await repository.resolveOperation(id);
      final request = {
        ..._request('paid_hint', ctx),
        'roundId': roundId ?? ctx.roundId,
        ..._priceFields('paid_hint', receipt),
      };
      if (receipt != null) {
        if (!_sameRequest(receipt.request, request) ||
            receipt.result['rejected'] == true) {
          throw OperationMismatch();
        }
        profile = await repository.load(data);
        _restore();
        return HintOutcome.fromSaved(receipt.result);
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
      final resolved = candidate.state.targets.contains(reveal.targetKey)
          ? candidate.state.level.words.firstWhere(
              (w) => w.key == reveal.targetKey,
            )
          : null;
      final result = resolved == null
          ? null
          : SubmissionResult(
              SubmissionKind.hintResolved,
              word: resolved,
              revealedLetter: reveal,
              completed: candidate.state.phase == RoundPhase.completing,
            );
      var proposed = _withRound(
        candidate.snapshot(ctx.roundId),
      ).copyWith(balance: profile.balance - Economy.hintPrice);
      final coins = [
        CoinOperation(
          id: id,
          kind: 'paid_hint',
          amount: -Economy.hintPrice,
          levelId: ctx.levelId,
          roundId: ctx.roundId,
        ),
      ];
      if (result?.completed == true) {
        final outcome = _completion(proposed, ctx);
        proposed = outcome.$1;
        coins.addAll(outcome.$2);
      }
      final saved = await _save(
        SaveProposal(
          id: id,
          expectedRevision: profile.revision,
          request: request,
          profile: proposed,
          coins: coins,
          result: {
            if (result != null) ...submissionJson(result),
            'kind': 'hint',
            'reveal': revealJson(reveal),
          },
        ),
      );
      final confirmed = HintOutcome.fromSaved(saved);
      freshCompletion = confirmed.submission?.completed == true;
      _restore(completing: freshCompletion);
      if (confirmed.submission != null) {
        engine.emitCommitted(confirmed.submission!);
      }
      return confirmed;
    });
  }

  Future<SuperHintOutcome> purchaseSuperHint({
    String? operationId,
    RoundContext? expected,
  }) {
    final ctx = expected ?? context, id = operationId ?? createHintId();
    return _serial(() async {
      if (ctx == null) return const SuperHintOutcome('inactive');
      final receipt = await repository.resolveOperation(id);
      final request = {
        ..._request('super_hint', ctx),
        ..._priceFields('super_hint', receipt),
      };
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
    final isAd = kind == 'simulated_ad' || kind == 'admob_test';
    final isTestAd = kind == 'admob_test';
    final request = <String, dynamic>{
      'kind': kind,
      'simulated': !isTestAd,
      if (isTestAd) 'testAd': true,
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
    final provided = isAd
        ? await adProvider.reward(id)
        : await purchaseProvider.purchase(id, ShopCatalog.find(packageId!));
    final amount = isAd
        ? Economy.adReward
        : ShopCatalog.find(packageId!).amount;
    if (provided.orderId != id ||
        provided.source != kind ||
        provided.amount != amount ||
        provided.packageId != packageId ||
        provided.simulated != !isTestAd ||
        provided.testAd != isTestAd) {
      throw StateError('Recibo da loja inválido.');
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

  bool get usesAdMobTestAds => adProvider.source == 'admob_test';

  Future<Map<String, dynamic>> watchRewardAd({String? id}) =>
      _credit(adProvider.source, id ?? operationId('ad'));

  // Kept for existing simulation fixtures and saved-operation tests.
  Future<Map<String, dynamic>> simulateAd({String? id}) =>
      watchRewardAd(id: id);
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
