import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../application/campaign_models.dart';
import '../domain/game_engine.dart';
import '../domain/round_snapshot.dart';
import 'game_data.dart';

enum StorageFaultPoint {
  beforeLedger,
  afterLedger,
  beforeProfile,
  beforeCommit,
  afterCommit,
}

typedef StorageFault = FutureOr<void> Function(StorageFaultPoint point);

abstract interface class ProgressRepository {
  Future<CampaignProfile> initialize(GameData data);
  Future<CampaignProfile> load(GameData data);
  Future<void> prepare(SaveProposal proposal);
  Future<CampaignProfile> commit(SaveProposal proposal, GameData data);
  Future<SavedOperation?> resolveOperation(String id);
  Future<List<SaveProposal>> pending();
  Future<void> discardPending(String id);
  Future<void> close();
}

class LocalGameDatabase {
  static const version = 2;
  static Future<Database> open({
    DatabaseFactory? factory,
    String? databasePath,
  }) async {
    final backend = factory ?? databaseFactory;
    final location =
        databasePath ??
        path.join(await backend.getDatabasesPath(), 'conecte_palavras_v1.db');
    return backend.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: version,
        singleInstance: false,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE profiles (profile_id TEXT PRIMARY KEY, balance INTEGER NOT NULL CHECK(balance >= 0), revision INTEGER NOT NULL, payload_json TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE coin_transactions (operation_id TEXT PRIMARY KEY, profile_id TEXT NOT NULL REFERENCES profiles(profile_id), kind TEXT NOT NULL, amount INTEGER NOT NULL, level_id INTEGER, round_id TEXT, metadata_json TEXT NOT NULL, created_at TEXT NOT NULL)',
          );
          await createRequests(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await createRequests(db);
        },
      ),
    );
  }

  static Future<void> createRequests(DatabaseExecutor db) => db.execute(
    'CREATE TABLE operation_requests (operation_id TEXT PRIMARY KEY, request_json TEXT NOT NULL, proposal_json TEXT, result_json TEXT, committed INTEGER NOT NULL DEFAULT 0 CHECK(committed IN (0,1)))',
  );
}

class SqliteProgressRepository implements ProgressRepository {
  SqliteProgressRepository(
    this.database, {
    this.initialBalance = Economy.initialBalance,
    this.fault,
  });
  final Database database;
  final int initialBalance;
  StorageFault? fault;
  static Future<SqliteProgressRepository> open({
    DatabaseFactory? factory,
    String? databasePath,
    int initialBalance = Economy.initialBalance,
  }) async => SqliteProgressRepository(
    await LocalGameDatabase.open(factory: factory, databasePath: databasePath),
    initialBalance: initialBalance,
  );

  @override
  Future<CampaignProfile> initialize(GameData data) async {
    if (initialBalance < 0) throw ArgumentError('Saldo inicial inválido.');
    await database.transaction((txn) async {
      final profiles = await txn.query('profiles');
      if (profiles.isNotEmpty) return;
      if ((await txn.query('coin_transactions')).isNotEmpty ||
          (await txn.query('operation_requests')).isNotEmpty) {
        throw const FormatException(
          'Perfil ausente com histórico existente. Dados preservados.',
        );
      }
      final profile = CampaignProfile(
        balance: initialBalance,
        revision: 0,
        currentLevelId: data.levels.first.id,
        catalogIds: data.levels.map((l) => l.id).toList(),
        catalogVersion: data.catalogVersion,
        unlocked: {data.levels.first.id},
        completed: {},
        rounds: {},
      );
      await txn.insert('profiles', {
        'profile_id': 'local',
        'balance': initialBalance,
        'revision': 0,
        'payload_json': canonicalJson(profile.toPayload()),
      });
      await txn.insert('coin_transactions', {
        'operation_id': 'welcome:v1',
        'profile_id': 'local',
        'kind': 'welcome',
        'amount': initialBalance,
        'level_id': null,
        'round_id': null,
        'metadata_json': canonicalJson({
          'request': {'amount': initialBalance},
          'result': {'balance': initialBalance},
        }),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
    return load(data);
  }

  CampaignProfile _profile(Map<String, Object?> row) =>
      CampaignProfile.fromStorage(
        row['balance'] as int,
        row['revision'] as int,
        Map<String, dynamic>.from(
          jsonDecode(row['payload_json'] as String) as Map,
        ),
      );

  @override
  Future<CampaignProfile> load(GameData data) => database.transaction((
    txn,
  ) async {
    final rows = await txn.query(
      'profiles',
      where: 'profile_id = ?',
      whereArgs: ['local'],
    );
    if (rows.length != 1) {
      throw const FormatException('Não foi possível carregar seu progresso.');
    }
    final profile = _profile(rows.single);
    await _validate(txn, profile, data);
    return profile;
  });

  Future<void> _validate(
    DatabaseExecutor db,
    CampaignProfile profile,
    GameData data,
  ) async {
    void invalid(String text) => throw FormatException(
      'Progresso inválido: $text. Seus dados foram preservados.',
    );
    final catalog = data.levels.map((l) => l.id).toList();
    if (profile.balance < 0 ||
        profile.revision < 0 ||
        profile.catalogVersion > data.catalogVersion ||
        profile.catalogIds.isEmpty ||
        profile.catalogIds.length > catalog.length ||
        !List.generate(
          profile.catalogIds.length,
          (i) => profile.catalogIds[i] == catalog[i],
        ).every((v) => v)) {
      invalid('catálogo incompatível');
    }
    if (!profile.catalogIds.contains(profile.currentLevelId) ||
        !profile.unlocked.contains(profile.currentLevelId) ||
        !profile.catalogIds.toSet().containsAll(profile.unlocked) ||
        !profile.unlocked.containsAll(profile.completed)) {
      invalid('níveis e liberação inconsistentes');
    }
    final expectedUnlocked = <int>{catalog.first};
    var unfinishedSeen = false;
    for (var i = 0; i < profile.catalogIds.length; i++) {
      final id = profile.catalogIds[i];
      if (profile.completed.contains(id)) {
        if (unfinishedSeen) invalid('campanha fora de ordem');
        if (i + 1 < profile.catalogIds.length) {
          expectedUnlocked.add(profile.catalogIds[i + 1]);
        }
      } else {
        unfinishedSeen = true;
      }
    }
    if (profile.unlocked.length != expectedUnlocked.length ||
        !profile.unlocked.containsAll(expectedUnlocked)) {
      invalid('desbloqueio inconsistente');
    }
    if (profile.pendingCompletion != null && profile.completed.isEmpty) {
      invalid('resultado pendente sem conclusão');
    }
    final expectedCurrent =
        profile.pendingCompletion != null ||
            profile.completed.length == profile.catalogIds.length
        ? profile.catalogIds[profile.completed.length - 1]
        : profile.catalogIds[profile.completed.length];
    if (profile.currentLevelId != expectedCurrent ||
        profile.catalogVersion < 1) {
      invalid('nível atual inconsistente');
    }
    final engine = GameEngine(levels: data.levels, lexicon: data.lexicon);
    final roundIds = <String>{};
    for (final entry in profile.rounds.entries) {
      if (entry.key != entry.value.levelId ||
          !profile.unlocked.contains(entry.key) ||
          !roundIds.add(entry.value.roundId)) {
        invalid('rodadas inconsistentes');
      }
      engine.restoreRound(entry.value);
      if ((entry.value.status == 'completed') !=
          profile.completed.contains(entry.key)) {
        invalid('conclusão inconsistente');
      }
      if (entry.value.status != 'completed' &&
          entry.key != profile.currentLevelId) {
        invalid('rodada fora do nível atual');
      }
    }
    if (!profile.rounds.keys.toSet().containsAll(profile.completed) ||
        (!profile.hasStarted && profile.rounds.isNotEmpty)) {
      invalid('histórico inconsistente');
    }
    final completion = profile.pendingCompletion;
    if (completion != null &&
        (completion.levelId != profile.currentLevelId ||
            !profile.completed.contains(completion.levelId) ||
            completion.roundId != profile.currentRound?.roundId ||
            completion.reward <= 0)) {
      invalid('resultado pendente inconsistente');
    }
    if (profile.currentRound?.status == 'completed' &&
        completion == null &&
        profile.completed.length < profile.catalogIds.length) {
      invalid('resultado não reconhecido ausente');
    }
    final ledger = await db.query(
      'coin_transactions',
      where: 'profile_id = ?',
      whereArgs: ['local'],
    );
    var sum = 0;
    var welcome = 0;
    final rewards = <int>{};
    final explorerRewards = <int>{};
    final paid = <String, RevealRecord>{};
    final paidLevels = <String, int>{};
    for (final round in profile.rounds.values) {
      for (final reveal in round.reveals.where(
        (r) => r.source == RevealSource.paid,
      )) {
        if (paid.containsKey(reveal.sourceKey)) invalid('dica paga duplicada');
        paid[reveal.sourceKey] = reveal;
        paidLevels[reveal.sourceKey] = round.levelId;
      }
    }
    final paidLedger = <String>{};
    for (final row in ledger) {
      final amount = row['amount'] as int;
      sum += amount;
      final id = row['operation_id'] as String;
      switch (row['kind']) {
        case 'welcome':
          if (id != 'welcome:v1' || amount < 0) {
            invalid('crédito inicial inválido');
          }
          welcome++;
        case 'level_completion':
          final level = row['level_id'] as int;
          if (id != 'level-completion:$level' ||
              amount != Economy.levelReward ||
              !profile.completed.contains(level) ||
              row['round_id'] != profile.rounds[level]?.roundId ||
              !rewards.add(level)) {
            invalid('recompensa inválida');
          }
          if (completion?.levelId == level && completion!.reward != amount) {
            invalid('recompensa pendente inválida');
          }
        case 'explorer_reward':
          final level = row['level_id'] as int;
          final round = profile.rounds[level];
          final definition = data.levels
              .where((l) => l.id == level)
              .firstOrNull;
          if (id != 'explorer-reward:$level' ||
              amount != Economy.explorerReward ||
              !profile.explorerRewardedLevels.contains(level) ||
              round == null ||
              definition == null ||
              row['round_id'] != round.roundId ||
              round.extras.length < definition.extraGoal ||
              !explorerRewards.add(level)) {
            invalid('recompensa de Explorador inconsistente');
          }
        case 'paid_hint':
          final reveal = paid[id];
          if (amount != -Economy.hintPrice ||
              reveal == null ||
              paidLevels[id] != row['level_id'] ||
              row['round_id'] != profile.rounds[row['level_id']]?.roundId) {
            invalid('dica sem débito ou revelação');
          }
          final metadata = Map<String, dynamic>.from(
            jsonDecode(row['metadata_json'] as String) as Map,
          );
          final saved = Map<String, dynamic>.from(
            (metadata['result'] as Map)['reveal'] as Map,
          );
          if (saved['targetKey'] != reveal!.targetKey ||
              saved['index'] != reveal.index) {
            invalid('posição de dica inconsistente');
          }
          paidLedger.add(id);
        default:
          invalid('tipo de transação desconhecido');
      }
    }
    if (sum != profile.balance ||
        welcome != 1 ||
        rewards.length != profile.completed.length ||
        explorerRewards.length != profile.explorerRewardedLevels.length ||
        paidLedger.length != paid.length) {
      invalid('carteira divergente do histórico');
    }
  }

  // Normalize additive payload fields so prepared operations from older saves
  // can still resume with their original proposal and random reveal.
  bool _sameProposal(Object? stored, SaveProposal proposal) =>
      canonicalJson(
        SaveProposal.fromJson(
          Map<String, dynamic>.from(jsonDecode(stored as String) as Map),
        ).toJson(),
      ) ==
      canonicalJson(proposal.toJson());

  @override
  Future<void> prepare(SaveProposal proposal) async {
    await database.transaction((txn) async {
      final rows = await txn.query(
        'operation_requests',
        where: 'operation_id = ?',
        whereArgs: [proposal.id],
      );
      final request = canonicalJson(proposal.request);
      if (rows.isNotEmpty) {
        if (rows.single['request_json'] != request) throw OperationMismatch();
        if (rows.single['committed'] == 0 &&
            !_sameProposal(rows.single['proposal_json'], proposal)) {
          throw OperationMismatch();
        }
        return;
      }
      await txn.insert('operation_requests', {
        'operation_id': proposal.id,
        'request_json': request,
        'proposal_json': canonicalJson(proposal.toJson()),
        'committed': 0,
      });
    });
  }

  @override
  Future<CampaignProfile> commit(SaveProposal proposal, GameData data) async {
    await database.transaction((txn) async {
      final requests = await txn.query(
        'operation_requests',
        where: 'operation_id = ?',
        whereArgs: [proposal.id],
      );
      if (requests.length != 1 ||
          requests.single['request_json'] != canonicalJson(proposal.request)) {
        throw OperationMismatch();
      }
      if (requests.single['committed'] == 1) return;
      if (!_sameProposal(requests.single['proposal_json'], proposal)) {
        throw OperationMismatch();
      }
      final row = (await txn.query(
        'profiles',
        where: 'profile_id = ?',
        whereArgs: ['local'],
      )).single;
      final current = _profile(row);
      if (current.revision != proposal.expectedRevision ||
          proposal.profile.revision != current.revision + 1) {
        throw RevisionConflict();
      }
      if (proposal.profile.balance !=
          current.balance + (proposal.coin?.amount ?? 0)) {
        throw const FormatException('Saldo da proposta inválido.');
      }
      await fault?.call(StorageFaultPoint.beforeLedger);
      final coin = proposal.coin;
      if (coin != null) {
        if (coin.id != proposal.id) throw OperationMismatch();
        await txn.insert('coin_transactions', {
          'operation_id': coin.id,
          'profile_id': 'local',
          'kind': coin.kind,
          'amount': coin.amount,
          'level_id': coin.levelId,
          'round_id': coin.roundId,
          'metadata_json': canonicalJson({
            'request': proposal.request,
            'result': proposal.result,
          }),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      await fault?.call(StorageFaultPoint.afterLedger);
      await fault?.call(StorageFaultPoint.beforeProfile);
      await txn.update(
        'profiles',
        {
          'balance': proposal.profile.balance,
          'revision': proposal.profile.revision,
          'payload_json': canonicalJson(proposal.profile.toPayload()),
        },
        where: 'profile_id = ? AND revision = ?',
        whereArgs: ['local', current.revision],
      );
      await _validate(txn, proposal.profile, data);
      await txn.update(
        'operation_requests',
        {
          'committed': 1,
          'proposal_json': null,
          'result_json': canonicalJson(proposal.result),
        },
        where: 'operation_id = ?',
        whereArgs: [proposal.id],
      );
      await fault?.call(StorageFaultPoint.beforeCommit);
    });
    await fault?.call(StorageFaultPoint.afterCommit);
    return load(data);
  }

  @override
  Future<SavedOperation?> resolveOperation(String id) async {
    final rows = await database.query(
      'operation_requests',
      where: 'operation_id = ? AND committed = 1',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return SavedOperation(
      Map<String, dynamic>.from(
        jsonDecode(rows.single['request_json'] as String) as Map,
      ),
      Map<String, dynamic>.from(
        jsonDecode(rows.single['result_json'] as String) as Map,
      ),
    );
  }

  @override
  Future<List<SaveProposal>> pending() async =>
      (await database.query(
            'operation_requests',
            where: 'committed = 0',
            orderBy: 'rowid',
          ))
          .map(
            (row) => SaveProposal.fromJson(
              Map<String, dynamic>.from(
                jsonDecode(row['proposal_json'] as String) as Map,
              ),
            ),
          )
          .toList();
  @override
  Future<void> close() => database.close();
  @override
  Future<void> discardPending(String id) async {
    await database.update(
      'operation_requests',
      {
        'committed': 1,
        'proposal_json': null,
        'result_json': canonicalJson({'rejected': true}),
      },
      where: 'operation_id = ? AND committed = 0',
      whereArgs: [id],
    );
  }
}
