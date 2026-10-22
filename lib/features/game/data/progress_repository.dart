import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../application/campaign_models.dart';
import '../application/daily_models.dart';
import '../application/shop_models.dart';
import '../domain/game_engine.dart';
import '../domain/round_snapshot.dart';
import 'game_data.dart';

enum StorageFaultPoint {
  beforeLedger,
  afterLedger,
  afterLedgerEntry,
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
  static const version = 5;
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
            'CREATE TABLE coin_transactions (operation_id TEXT PRIMARY KEY, profile_id TEXT NOT NULL REFERENCES profiles(profile_id), kind TEXT NOT NULL, amount INTEGER NOT NULL, level_id INTEGER, round_id TEXT, metadata_json TEXT NOT NULL, created_at TEXT NOT NULL, parent_operation_id TEXT NOT NULL)',
          );
          await createRequests(db);
          await createSettings(db, legacy: false);
          await createAdFreePlan(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 5) await createAdFreePlan(db);
          if (oldVersion < 4) {
            final existing = await db.query('profiles', limit: 1);
            await createSettings(db, legacy: existing.isNotEmpty);
          }
          if (oldVersion < 2) await createRequests(db);
          if (oldVersion < 3) {
            final columns = await db.rawQuery(
              'PRAGMA table_info(coin_transactions)',
            );
            if (!columns.any((c) => c['name'] == 'parent_operation_id')) {
              await db.execute(
                'ALTER TABLE coin_transactions ADD COLUMN parent_operation_id TEXT',
              );
              await db.execute(
                'UPDATE coin_transactions SET parent_operation_id = operation_id',
              );
            }
          }
        },
      ),
    );
  }

  static Future<void> createAdFreePlan(DatabaseExecutor db) => db.execute(
    'CREATE TABLE IF NOT EXISTS simulated_entitlements (id TEXT PRIMARY KEY, activated_at TEXT NOT NULL)',
  );

  static Future<void> createSettings(
    DatabaseExecutor db, {
    required bool legacy,
  }) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS app_settings (id TEXT PRIMARY KEY, sound INTEGER NOT NULL CHECK(sound IN (0,1)), haptics INTEGER NOT NULL CHECK(haptics IN (0,1)), reduce_motion INTEGER NOT NULL CHECK(reduce_motion IN (0,1)), introduction TEXT NOT NULL)',
    );
    await db.insert('app_settings', {
      'id': 'local',
      'sound': 1,
      'haptics': 1,
      'reduce_motion': 0,
      'introduction': legacy ? 'exempted' : 'unseen',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
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
  DateTime Function() now = DateTime.now;
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
        'parent_operation_id': 'welcome:v1',
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
    if (profile.lastDailyDate != null) {
      parseCalendarDate(profile.lastDailyDate!);
    }
    final dailyCompleted = <String>{};
    final allRounds = <({RoundSnapshot round, String mode, String? date})>[
      for (final round in profile.rounds.values)
        (round: round, mode: 'campaign', date: null),
    ];
    for (final entry in profile.daily.entries) {
      final day = entry.value;
      parseCalendarDate(day.date);
      if (entry.key != day.date ||
          profile.lastDailyDate == null ||
          day.date.compareTo(profile.lastDailyDate!) > 0 ||
          day.catalogVersion < 1 ||
          !roundIds.add(day.round.roundId) ||
          (day.pendingResult && !day.completed) ||
          (day.expired && day.completed)) {
        invalid('histórico diário inconsistente');
      }
      GameData.validateLevel(day.definition, day.lexicon);
      GameEngine(
        levels: [day.definition],
        lexicon: day.lexicon,
      ).restoreRound(day.round);
      if (day.completed) dailyCompleted.add(day.date);
      allRounds.add((round: day.round, mode: 'daily', date: day.date));
    }
    final ledger = await db.query(
      'coin_transactions',
      where: 'profile_id = ?',
      whereArgs: ['local'],
    );
    final rewards = <int>{}, explorerRewards = <int>{};
    final dailyRewards = <String>{},
        paidLedger = <String>{},
        superLedger = <String>{};
    final paid =
        <
          String,
          ({
            RevealRecord reveal,
            RoundSnapshot round,
            String mode,
            String? date,
          })
        >{};
    final supers =
        <
          String,
          ({
            SuperResolution resolution,
            RoundSnapshot round,
            String mode,
            String? date,
          })
        >{};
    for (final scope in allRounds) {
      for (final r in scope.round.reveals.where(
        (r) => r.source == RevealSource.paid,
      )) {
        if (paid.containsKey(r.sourceKey)) invalid('dica paga duplicada');
        paid[r.sourceKey] = (
          reveal: r,
          round: scope.round,
          mode: scope.mode,
          date: scope.date,
        );
      }
      for (final r in scope.round.superHints) {
        if (supers.containsKey(r.operationId)) invalid('Super Dica duplicada');
        supers[r.operationId] = (
          resolution: r,
          round: scope.round,
          mode: scope.mode,
          date: scope.date,
        );
      }
    }
    var sum = 0, welcome = 0;
    for (final row in ledger) {
      final amount = row['amount'] as int, id = row['operation_id'] as String;
      final parent = row['parent_operation_id'] as String?;
      if (parent == null || parent.isEmpty) {
        invalid('operação financeira sem vínculo');
      }
      sum += amount;
      final metadata = Map<String, dynamic>.from(
        jsonDecode(row['metadata_json'] as String) as Map,
      );
      final request = Map<String, dynamic>.from(metadata['request'] as Map);
      final result = Map<String, dynamic>.from(metadata['result'] as Map);
      final mode = request['mode'] ?? 'campaign';
      switch (row['kind']) {
        case 'welcome':
          if (id != 'welcome:v1' || amount < 0) {
            invalid('crédito inicial inválido');
          }
          welcome++;
        case 'level_completion':
          final level = row['level_id'] as int;
          if (mode != 'campaign' ||
              id != 'level-completion:$level' ||
              amount != Economy.levelReward ||
              !profile.completed.contains(level) ||
              row['round_id'] != profile.rounds[level]?.roundId ||
              !rewards.add(level)) {
            invalid('recompensa inválida');
          }
          if (completion?.levelId == level && completion!.reward != amount) {
            invalid('recompensa pendente inválida');
          }
        case 'daily_completion':
          final date = request['date'] as String?;
          if (mode != 'daily' ||
              date == null ||
              id != 'daily-completion:$date' ||
              amount != Economy.dailyReward ||
              !dailyCompleted.contains(date) ||
              row['round_id'] != profile.daily[date]?.round.roundId ||
              !dailyRewards.add(date)) {
            invalid('recompensa diária inválida');
          }
        case 'explorer_reward':
          final level = row['level_id'] as int, round = profile.rounds[level];
          final definition = data.levels
              .where((l) => l.id == level)
              .firstOrNull;
          if (mode != 'campaign' ||
              id != 'explorer-reward:$level' ||
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
          final source = paid[parent];
          if (amount != -Economy.hintPrice ||
              source == null ||
              mode != source.mode ||
              request['date'] != source.date ||
              row['round_id'] != source.round.roundId ||
              row['level_id'] != source.round.levelId) {
            invalid('dica sem débito ou revelação');
          }
          final saved = Map<String, dynamic>.from(result['reveal'] as Map);
          if (saved['targetKey'] != source!.reveal.targetKey ||
              saved['index'] != source.reveal.index ||
              !paidLedger.add(parent!)) {
            invalid('posição de dica inconsistente');
          }
        case 'super_hint':
          final source = supers[parent];
          if (amount != -Economy.superHintPrice ||
              source == null ||
              mode != source.mode ||
              request['date'] != source.date ||
              row['round_id'] != source.round.roundId ||
              row['level_id'] != source.round.levelId ||
              result['targetKey'] != source.resolution.targetKey ||
              canonicalJson(result['indices']) !=
                  canonicalJson(source.resolution.indices) ||
              !superLedger.add(parent!)) {
            invalid('resolução de Super Dica inconsistente');
          }
        case 'simulated_purchase':
          if (request['simulated'] != true ||
              result['simulated'] != true ||
              result['source'] != 'simulated_purchase' ||
              amount !=
                  ShopCatalog.find(request['packageId'] as String).amount ||
              result['amount'] != amount) {
            invalid('compra simulada inconsistente');
          }
        case 'simulated_ad':
          if (request['simulated'] != true ||
              result['simulated'] != true ||
              result['source'] != 'simulated_ad' ||
              amount != Economy.adReward ||
              result['amount'] != amount) {
            invalid('anúncio simulado inconsistente');
          }
        default:
          invalid('tipo de transação desconhecido');
      }
    }
    if (sum != profile.balance ||
        welcome != 1 ||
        rewards.length != profile.completed.length ||
        explorerRewards.length != profile.explorerRewardedLevels.length ||
        dailyRewards.length != dailyCompleted.length ||
        paidLedger.length != paid.length ||
        superLedger.length != supers.length) {
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
          current.balance +
              proposal.entries.fold<int>(0, (sum, c) => sum + c.amount)) {
        throw const FormatException('Saldo da proposta inválido.');
      }
      if (proposal.request['mode'] == 'daily' &&
          proposal.request['date'] != calendarDate(now())) {
        throw DailyExpired();
      }
      final price = switch (proposal.request['kind']) {
        'paid_hint' => Economy.hintPrice,
        'super_hint' => Economy.superHintPrice,
        _ => 0,
      };
      if (current.balance < price) {
        throw const FormatException('Saldo anterior insuficiente.');
      }
      await fault?.call(StorageFaultPoint.beforeLedger);
      for (final coin in proposal.entries) {
        await txn.insert('coin_transactions', {
          'operation_id': coin.id,
          'parent_operation_id': proposal.id,
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
        await fault?.call(StorageFaultPoint.afterLedgerEntry);
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
