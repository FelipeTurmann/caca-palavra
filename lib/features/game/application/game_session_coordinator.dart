import 'dart:async';
import 'dart:math';

import '../data/game_data.dart';
import '../data/progress_repository.dart';
import '../domain/game_engine.dart';
import 'campaign_models.dart';

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

/// The only production writer: candidates are isolated until SQLite commits.
class GameSessionCoordinator {
  GameSessionCoordinator._(
    this.data,
    this.repository,
    this.engine,
    this.profile,
  );
  final GameData data;
  final ProgressRepository repository;
  final GameEngine engine;
  CampaignProfile profile;
  SaveProposal? _failed;
  Future<void> _tail = Future.value();
  bool freshCompletion = false;
  bool get hasFailedCommand => _failed != null;
  int? get nextLevelId {
    final index = data.levels.indexWhere((l) => l.id == profile.currentLevelId);
    return index + 1 < data.levels.length ? data.levels[index + 1].id : null;
  }

  static Future<GameSessionCoordinator> create(
    GameData data,
    ProgressRepository repository, {
    Random? random,
  }) async {
    var profile = await repository.initialize(data);
    for (final pending in await repository.pending()) {
      try {
        profile = await repository.commit(pending, data);
      } on RevisionConflict {
        await repository.discardPending(pending.id);
        profile = await repository.load(data);
      } catch (_) {
        if (await repository.resolveOperation(pending.id) == null) rethrow;
        profile = await repository.load(data);
      }
    }
    final coordinator = GameSessionCoordinator._(
      data,
      repository,
      GameEngine(levels: data.levels, lexicon: data.lexicon, random: random),
      profile,
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
      final candidate = profile.copyWith(
        catalogIds: catalog,
        catalogVersion: data.catalogVersion,
        currentLevelId: next,
        unlocked: {
          ...profile.unlocked,
          if (profile.completed.length < catalog.length)
            catalog[profile.completed.length],
        },
        revision: profile.revision + 1,
      );
      await coordinator._save(
        SaveProposal(
          id: operationId('catalog'),
          expectedRevision: profile.revision,
          request: {
            'kind': 'catalog',
            'ids': catalog,
            'version': data.catalogVersion,
          },
          profile: candidate,
          result: {'kind': 'catalog'},
        ),
      );
    }
    coordinator._restore();
    return coordinator;
  }

  Future<T> _serial<T>(Future<T> Function() command) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await command());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  String? _activeRoundId;
  void _restore({bool completing = false}) {
    final round = profile.currentRound;
    if (round != null) {
      engine.restoreRound(
        round,
        showCompletion: completing,
        preserveSession: _activeRoundId == round.roundId,
      );
      _activeRoundId = round.roundId;
    } else {
      engine.startLevel(profile.currentLevelId);
    }
  }

  Future<Map<String, dynamic>> _save(SaveProposal proposal) async {
    try {
      await repository.prepare(proposal);
      profile = await repository.commit(proposal, data);
      _failed = null;
      return proposal.result;
    } on RevisionConflict {
      await repository.discardPending(proposal.id);
      profile = await repository.load(data);
      _failed = null;
      _restore();
      rethrow;
    } catch (_) {
      _failed = proposal;
      final resolved = await repository.resolveOperation(proposal.id);
      if (resolved != null && resolved.result['rejected'] != true) {
        if (canonicalJson(resolved.request) !=
            canonicalJson(proposal.request)) {
          throw OperationMismatch();
        }
        profile = await repository.load(data);
        _failed = null;
        return resolved.result;
      }
      _failed = proposal;
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> retry() => _serial(() async {
    final failed = _failed;
    if (failed == null) {
      profile = await repository.load(data);
      _restore();
      return null;
    }
    final result = await _save(failed);
    _restore(completing: result['completed'] == true);
    freshCompletion = result['completed'] == true;
    if (result['kind'] == 'submission') {
      engine.emitCommitted(submissionFromJson(result));
    }
    return result;
  });

  Future<void> startOrContinue() => _serial(() async {
    if (_failed != null) throw StateError('Resolva o salvamento pendente.');
    if (profile.campaignComplete) return;
    if (profile.currentRound == null) {
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

  Future<SubmissionResult> submitWord(
    List<String> ids, {
    required int session,
  }) => _serial(() async {
    if (_failed != null) throw StateError('Resolva o salvamento pendente.');
    final round = profile.currentRound;
    if (round == null ||
        session != engine.state.session ||
        round.status != 'in_progress') {
      return const SubmissionResult(SubmissionKind.ignored);
    }
    final candidate = engine.fork(round);
    final result = candidate.submit(ids, session: candidate.state.session);
    if (result.kind != SubmissionKind.targetFound &&
        result.kind != SubmissionKind.extraFound) {
      return result;
    }
    final snapshot = candidate.snapshot(round.roundId);
    var proposed = profile.copyWith(
      rounds: {...profile.rounds, round.levelId: snapshot},
      revision: profile.revision + 1,
    );
    CoinOperation? coin;
    final id = result.completed
        ? 'level-completion:${round.levelId}'
        : result.explorerUnlocked
        ? 'explorer-reward:${round.levelId}'
        : operationId('word');
    if (result.completed) {
      coin = CoinOperation(
        id: id,
        kind: 'level_completion',
        amount: Economy.levelReward,
        levelId: round.levelId,
        roundId: round.roundId,
      );
      proposed = proposed.copyWith(
        balance: profile.balance + Economy.levelReward,
        completed: {...profile.completed, round.levelId},
        unlocked: {...profile.unlocked, ?nextLevelId},
        pendingCompletion: PendingCompletion(
          levelId: round.levelId,
          roundId: round.roundId,
          reward: Economy.levelReward,
        ),
      );
    }
    if (result.explorerUnlocked) {
      coin = CoinOperation(
        id: id,
        kind: 'explorer_reward',
        amount: Economy.explorerReward,
        levelId: round.levelId,
        roundId: round.roundId,
      );
      proposed = proposed.copyWith(
        balance: profile.balance + Economy.explorerReward,
        explorerRewardedLevels: {
          ...profile.explorerRewardedLevels,
          round.levelId,
        },
      );
    }
    final saved = await _save(
      SaveProposal(
        id: id,
        expectedRevision: profile.revision,
        request: {
          'kind': coin?.kind ?? 'word',
          'roundId': round.roundId,
          'levelId': round.levelId,
          'ids': ids,
        },
        profile: proposed,
        result: submissionJson(result),
        coin: coin,
      ),
    );
    final confirmed = submissionFromJson(saved);
    freshCompletion = confirmed.completed;
    _restore(completing: confirmed.completed);
    engine.emitCommitted(confirmed);
    return confirmed;
  });

  Future<bool> shuffle() => _serial(() async {
    if (_failed != null) throw StateError('Resolva o salvamento pendente.');
    final round = profile.currentRound;
    if (round == null || round.status != 'in_progress') return false;
    final candidate = engine.fork(round);
    if (!candidate.shuffle()) return false;
    await _save(
      SaveProposal(
        id: operationId('shuffle'),
        expectedRevision: profile.revision,
        request: {'kind': 'shuffle', 'roundId': round.roundId},
        profile: profile.copyWith(
          rounds: {
            ...profile.rounds,
            round.levelId: candidate.snapshot(round.roundId),
          },
          revision: profile.revision + 1,
        ),
        result: {'kind': 'shuffle'},
      ),
    );
    _restore();
    return true;
  });

  Future<HintOutcome> purchaseHint({String? operationId, String? roundId}) {
    final requestedRound = roundId ?? profile.currentRound?.roundId;
    final id = operationId ?? createHintId();
    final levelId = profile.currentLevelId;
    return _serial(() async {
      final request = <String, dynamic>{
        'kind': 'paid_hint',
        'roundId': requestedRound,
        'levelId': levelId,
        'price': Economy.hintPrice,
      };
      final resolved = await repository.resolveOperation(id);
      if (resolved != null) {
        if (canonicalJson(resolved.request) != canonicalJson(request) ||
            resolved.result['rejected'] == true) {
          throw OperationMismatch();
        }
        profile = await repository.load(data);
        _restore();
        return HintOutcome(
          'purchased',
          revealFromJson(resolved.result['reveal']),
        );
      }
      if (_failed != null) throw StateError('Resolva o salvamento pendente.');
      final round = profile.currentRound;
      if (round == null ||
          round.roundId != requestedRound ||
          round.status != 'in_progress') {
        return const HintOutcome('inactive');
      }
      final candidate = engine.fork(round);
      if (!candidate.canReveal) return const HintOutcome('unavailable');
      if (profile.balance < Economy.hintPrice) {
        return const HintOutcome('insufficient');
      }
      final reveal = candidate.revealPaidHint(id)!;
      final result = await _save(
        SaveProposal(
          id: id,
          expectedRevision: profile.revision,
          request: request,
          profile: profile.copyWith(
            balance: profile.balance - Economy.hintPrice,
            rounds: {
              ...profile.rounds,
              round.levelId: candidate.snapshot(round.roundId),
            },
            revision: profile.revision + 1,
          ),
          coin: CoinOperation(
            id: id,
            kind: 'paid_hint',
            amount: -Economy.hintPrice,
            levelId: round.levelId,
            roundId: round.roundId,
          ),
          result: {
            'kind': 'hint',
            'status': 'purchased',
            'reveal': revealJson(reveal),
          },
        ),
      );
      _restore();
      return HintOutcome('purchased', revealFromJson(result['reveal']));
    });
  }

  String createHintId() =>
      operationId('hint:${profile.currentRound?.roundId ?? 'none'}');

  Future<bool> advance() {
    final requestedRound = profile.pendingCompletion?.roundId;
    return _serial(() async {
      if (_failed != null) throw StateError('Resolva o salvamento pendente.');
      final pending = profile.pendingCompletion;
      if (pending == null || pending.roundId != requestedRound) return false;
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
