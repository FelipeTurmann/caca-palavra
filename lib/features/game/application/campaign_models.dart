import 'dart:convert';

import '../domain/round_snapshot.dart';
import 'daily_models.dart';

abstract final class Economy {
  static const initialBalance = 60;
  static const levelReward = 20;
  static const explorerReward = 10;
  static const hintPrice = 30;
  static const superHintPrice = 100;
  static const dailyReward = 50;
  static const adReward = 15;
}

String canonicalJson(Object? value) {
  Object? canonical(Object? item) {
    if (item is Map) {
      final keys = item.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: canonical(item[key])};
    }
    if (item is List) return item.map(canonical).toList();
    return item;
  }

  return jsonEncode(canonical(value));
}

class PendingCompletion {
  const PendingCompletion({
    required this.levelId,
    required this.roundId,
    required this.reward,
  });
  final int levelId;
  final String roundId;
  final int reward;
  Map<String, Object> toJson() => {
    'levelId': levelId,
    'roundId': roundId,
    'reward': reward,
  };
  factory PendingCompletion.fromJson(Map<String, dynamic> json) =>
      PendingCompletion(
        levelId: json['levelId'] as int,
        roundId: json['roundId'] as String,
        reward: json['reward'] as int,
      );
}

class CampaignProfile {
  CampaignProfile({
    required this.balance,
    required this.revision,
    required this.currentLevelId,
    required List<int> catalogIds,
    required Set<int> unlocked,
    required Set<int> completed,
    required Map<int, RoundSnapshot> rounds,
    Set<int> explorerRewardedLevels = const {},
    this.catalogVersion = 1,
    this.hasStarted = false,
    this.pendingCompletion,
    Map<String, DailyProgress> daily = const {},
    this.lastDailyDate,
  }) : catalogIds = List.unmodifiable(catalogIds),
       unlocked = Set.unmodifiable(unlocked),
       completed = Set.unmodifiable(completed),
       explorerRewardedLevels = Set.unmodifiable(explorerRewardedLevels),
       rounds = Map.unmodifiable(rounds),
       daily = Map.unmodifiable(daily);
  final int balance;
  final int revision;
  final int currentLevelId;
  final int catalogVersion;
  final List<int> catalogIds;
  final bool hasStarted;
  final Set<int> unlocked;
  final Set<int> completed;
  final Set<int> explorerRewardedLevels;
  final Map<int, RoundSnapshot> rounds;
  final PendingCompletion? pendingCompletion;
  final Map<String, DailyProgress> daily;
  final String? lastDailyDate;
  RoundSnapshot? get currentRound => rounds[currentLevelId];
  bool get campaignComplete =>
      completed.length == catalogIds.length && pendingCompletion == null;
  CampaignProfile copyWith({
    int? balance,
    int? revision,
    int? currentLevelId,
    int? catalogVersion,
    List<int>? catalogIds,
    bool? hasStarted,
    Set<int>? unlocked,
    Set<int>? completed,
    Set<int>? explorerRewardedLevels,
    Map<int, RoundSnapshot>? rounds,
    PendingCompletion? pendingCompletion,
    bool clearPending = false,
    Map<String, DailyProgress>? daily,
    String? lastDailyDate,
  }) => CampaignProfile(
    daily: daily ?? this.daily,
    lastDailyDate: lastDailyDate ?? this.lastDailyDate,
    balance: balance ?? this.balance,
    revision: revision ?? this.revision,
    currentLevelId: currentLevelId ?? this.currentLevelId,
    catalogVersion: catalogVersion ?? this.catalogVersion,
    catalogIds: catalogIds ?? this.catalogIds,
    hasStarted: hasStarted ?? this.hasStarted,
    unlocked: unlocked ?? this.unlocked,
    completed: completed ?? this.completed,
    explorerRewardedLevels:
        explorerRewardedLevels ?? this.explorerRewardedLevels,
    rounds: rounds ?? this.rounds,
    pendingCompletion: clearPending
        ? null
        : pendingCompletion ?? this.pendingCompletion,
  );
  Map<String, Object?> toPayload() => {
    'schemaVersion': 2,
    'daily': {
      for (final entry in daily.entries) entry.key: entry.value.toJson(),
    },
    'lastDailyDate': lastDailyDate,
    'catalogVersion': catalogVersion,
    'catalogIds': catalogIds,
    'hasStarted': hasStarted,
    'currentLevelId': currentLevelId,
    'unlockedLevelIds': unlocked.toList()..sort(),
    'completedLevelIds': completed.toList()..sort(),
    'explorerRewardedLevelIds': explorerRewardedLevels.toList()..sort(),
    'levels': {
      for (final entry in rounds.entries) '${entry.key}': entry.value.toJson(),
    },
    'pendingCompletion': pendingCompletion?.toJson(),
  };
  factory CampaignProfile.fromStorage(
    int balance,
    int revision,
    Map<String, dynamic> payload,
  ) {
    if (![1, 2].contains(payload['schemaVersion'])) {
      throw const FormatException(
        'Versão de progresso incompatível. Seus dados foram preservados.',
      );
    }
    if (payload.containsKey('balance') || payload.containsKey('revision')) {
      throw const FormatException('Carteira duplicada no progresso.');
    }
    final unlocked = List<int>.from(payload['unlockedLevelIds'] as List);
    final completed = List<int>.from(payload['completedLevelIds'] as List);
    // Older saves may contain visual badges earned before the coin reward.
    final explorerRewards = List<int>.from(
      payload['explorerRewardedLevelIds'] as List? ?? const [],
    );
    if (unlocked.toSet().length != unlocked.length ||
        completed.toSet().length != completed.length ||
        explorerRewards.toSet().length != explorerRewards.length) {
      throw const FormatException('Progresso duplicado.');
    }
    return CampaignProfile(
      daily: {
        for (final entry
            in (payload['daily'] as Map<String, dynamic>? ?? {}).entries)
          entry.key: DailyProgress.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      },
      lastDailyDate: payload['lastDailyDate'] as String?,
      balance: balance,
      revision: revision,
      currentLevelId: payload['currentLevelId'] as int,
      catalogVersion: payload['catalogVersion'] as int,
      catalogIds: List<int>.from(payload['catalogIds'] as List),
      hasStarted: payload['hasStarted'] as bool,
      unlocked: unlocked.toSet(),
      completed: completed.toSet(),
      explorerRewardedLevels: explorerRewards.toSet(),
      rounds: {
        for (final entry in (payload['levels'] as Map<String, dynamic>).entries)
          int.parse(entry.key): RoundSnapshot.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      },
      pendingCompletion: payload['pendingCompletion'] == null
          ? null
          : PendingCompletion.fromJson(
              Map<String, dynamic>.from(payload['pendingCompletion'] as Map),
            ),
    );
  }
}

class CoinOperation {
  const CoinOperation({
    required this.id,
    required this.kind,
    required this.amount,
    this.levelId,
    this.roundId,
  });
  final String id;
  final String kind;
  final int amount;
  final int? levelId;
  final String? roundId;
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'amount': amount,
    'levelId': levelId,
    'roundId': roundId,
  };
  factory CoinOperation.fromJson(Map<String, dynamic> json) => CoinOperation(
    id: json['id'] as String,
    kind: json['kind'] as String,
    amount: json['amount'] as int,
    levelId: json['levelId'] as int?,
    roundId: json['roundId'] as String?,
  );
}

class SaveProposal {
  const SaveProposal({
    required this.id,
    required this.expectedRevision,
    required this.request,
    required this.profile,
    required this.result,
    this.coin,
    this.coins = const [],
  });
  final String id;
  final int expectedRevision;
  final Map<String, dynamic> request;
  final CampaignProfile profile;
  final Map<String, dynamic> result;
  final CoinOperation? coin;
  final List<CoinOperation> coins;
  List<CoinOperation> get entries => [?coin, ...coins];
  Map<String, Object?> toJson() => {
    'id': id,
    'expectedRevision': expectedRevision,
    'request': request,
    'payload': profile.toPayload(),
    'balance': profile.balance,
    'revision': profile.revision,
    'result': result,
    'coin': coin?.toJson(),
    'coins': coins.map((c) => c.toJson()).toList(),
  };
  factory SaveProposal.fromJson(Map<String, dynamic> json) => SaveProposal(
    coins: (json['coins'] as List? ?? const [])
        .map((c) => CoinOperation.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList(),
    id: json['id'] as String,
    expectedRevision: json['expectedRevision'] as int,
    request: Map<String, dynamic>.from(json['request'] as Map),
    profile: CampaignProfile.fromStorage(
      json['balance'] as int,
      json['revision'] as int,
      Map<String, dynamic>.from(json['payload'] as Map),
    ),
    result: Map<String, dynamic>.from(json['result'] as Map),
    coin: json['coin'] == null
        ? null
        : CoinOperation.fromJson(
            Map<String, dynamic>.from(json['coin'] as Map),
          ),
  );
}

class SavedOperation {
  const SavedOperation(this.request, this.result);
  final Map<String, dynamic> request;
  final Map<String, dynamic> result;
}

class RevisionConflict implements Exception {
  @override
  String toString() => 'O progresso foi atualizado. Tente novamente.';
}

class OperationMismatch implements Exception {
  @override
  String toString() => 'A operação foi reenviada com parâmetros diferentes.';
}
