import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

import '../../../core/api/api_client.dart';
import '../../../core/api/auth_session.dart';
import '../application/campaign_models.dart';
import '../application/theme_unlocks.dart';
import '../domain/game_engine.dart';
import 'game_data.dart';
import 'progress_repository.dart';

/// Online state uses separate tables. The legacy local wallet is never imported.
class ApiProgressRepository extends SqliteProgressRepository {
  static Future<ApiProgressRepository> openOnline(AuthSession session) async =>
      ApiProgressRepository(
        await LocalGameDatabase.open(
          databasePath: path.join(
            await getDatabasesPath(),
            'conecte_palavras_online_v1.db',
          ),
        ),
        session,
      );
  ApiProgressRepository(super.database, this.session)
    : userId = session.userId,
      scope = session.api.config.namespace;
  final AuthSession session;
  final String userId, scope;
  Map<String, dynamic> state = {};
  Map<String, dynamic> identity = {};
  Map<String, Map<String, dynamic>> themes = {};
  bool uncertainHint = false;
  String get serverDate => (state['diario'] as Map)['data'] as String;
  bool get dailyCompleted => (state['diario'] as Map)['concluido'] == true;
  bool get adFree => (state['beneficios'] as Map)['semAnuncios'] == true;
  String get name => state['nomeUsuario'] as String? ?? '';
  String get _where => 'scope = ? AND user_id = ?';
  List<Object> get _args => [scope, userId];
  void _requireUser() {
    if (session.userId != userId) {
      throw const ApiFailure('SESSION_RECOVERY_REQUIRED');
    }
  }

  Future<Map<String, dynamic>> call(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) {
    _requireUser();
    return session.authorized(method, path, body: body);
  }

  Future<void> _fetch(
    GameData data, {
    bool initialize = false,
    bool refreshThemes = true,
  }) async {
    final next = await call(
      initialize ? 'POST' : 'GET',
      initialize ? '/api/v1/game/inicializar' : '/api/v1/game/me',
    );
    final progress = next['progresso'] as Map;
    final daily = next['diario'] as Map;
    if (next['idUsuario'] != userId || next['idJogo'] != ApiConfig.gameId) {
      throw const ApiFailure('INVALID_RESPONSE');
    }
    if (progress['versaoCatalogo'] != data.catalogVersion ||
        progress['totalNiveis'] != data.levels.length) {
      throw const ApiFailure('CATALOG_VERSION_MISMATCH');
    }
    if (daily['versaoCatalogo'] is! int ||
        daily['idDesafio'] is! int ||
        (progress['ultimoNivelConcluido'] as int) < 0 ||
        (progress['ultimoNivelConcluido'] as int) > data.levels.length ||
        ((next['moedas'] as Map)['qtdMoedas'] as int) < 0) {
      throw const ApiFailure('INVALID_RESPONSE');
    }
    state = next;
    if (refreshThemes) {
      final catalog = await call('GET', '/api/v1/temas');
      final owned = await call('GET', '/api/v1/temas/me');
      if (catalog['idUsuario'] != userId || owned['idUsuario'] != userId) {
        throw const ApiFailure('INVALID_RESPONSE');
      }
      final ownedIds = (owned['temas'] as List)
          .map((t) => (t as Map)['idTema'])
          .toSet();
      themes = {
        for (final raw in catalog['temas'] as List)
          (raw as Map)['idTema'] as String: {
            ...Map<String, dynamic>.from(raw),
            'desbloqueado': ownedIds.contains(raw['idTema']),
          },
      };
    }
  }

  ThemeUnlockRule themeRule(String id) {
    final theme = themes[id];
    return theme == null
        ? ThemeUnlocks.rule(id)
        : ThemeUnlockRule(
            price: theme['precoMoedas'] as int?,
            level: theme['nivelNecessario'] as int?,
          );
  }

  CampaignProfile _merge(GameData data, CampaignProfile? local) {
    final progress = state['progresso'] as Map;
    final last = progress['ultimoNivelConcluido'] as int;
    final next = progress['proximoNivel'] as int?;
    final pending = local?.pendingCompletion;
    final keepResult =
        pending != null &&
        pending.levelId == last &&
        local?.currentRound?.status == 'completed';
    final current = keepResult ? last : next ?? data.levels.last.id;
    final rounds = {...?local?.rounds}
      ..removeWhere((id, round) => id > last && id != current);
    if (!keepResult && rounds[current]?.status == 'completed' && next != null) {
      rounds.remove(current);
    }
    return CampaignProfile(
      balance: (state['moedas'] as Map)['qtdMoedas'] as int,
      revision: local?.revision ?? 0,
      currentLevelId: current,
      catalogIds: data.levels.map((l) => l.id).toList(),
      catalogVersion: data.catalogVersion,
      unlocked: {for (var i = 1; i <= (next ?? last); i++) i},
      completed: {for (var i = 1; i <= last; i++) i},
      rounds: rounds,
      hasStarted: last > 0 || rounds[current] != null,
      pendingCompletion: keepResult ? pending : null,
      explorerRewardedLevels: {...?local?.explorerRewardedLevels}
        ..removeWhere((id) => id > last),
      purchasedThemes: {
        for (final t in themes.values)
          if (t['desbloqueado'] == true && t['regraDesbloqueio'] == 'MOEDAS')
            t['idTema'] as String,
      },
      daily: local?.daily ?? {},
      lastDailyDate: serverDate,
    );
  }

  Future<CampaignProfile?> _read() async {
    final rows = await database.query(
      'online_profiles',
      where: _where,
      whereArgs: _args,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return CampaignProfile.fromStorage(
      row['balance'] as int,
      row['revision'] as int,
      Map<String, dynamic>.from(
        jsonDecode(row['payload_json'] as String) as Map,
      ),
    );
  }

  Future<void> _write(DatabaseExecutor db, CampaignProfile profile) => db
      .insert('online_profiles', {
        'scope': scope,
        'user_id': userId,
        'balance': profile.balance,
        'revision': profile.revision,
        'payload_json': canonicalJson(profile.toPayload()),
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  @override
  Future<CampaignProfile> initialize(GameData data) async {
    uncertainHint = (await database.query(
      'online_operations',
      columns: ['operation_id'],
      where: "$_where AND state = 'rejected' AND result_json LIKE ?",
      whereArgs: [..._args, '%HINT_UNCERTAIN%'],
    )).isNotEmpty;
    await _fetch(data, initialize: true);
    identity = await session.authorized(
      'GET',
      '/api/v1/auth/me',
      authService: true,
    );
    final local = await _read();
    // Recover persisted operations before reconciling their local snapshots.
    final pendingRows = await database.query(
      'online_operations',
      where: '$_where AND committed = 0',
      whereArgs: _args,
    );
    final profile = pendingRows.isNotEmpty && local != null
        ? local
        : _merge(data, local);
    await _write(database, profile);
    for (final round in profile.rounds.values) {
      GameEngine(
        levels: data.levels,
        lexicon: data.lexicon,
      ).restoreRound(round);
    }
    return profile;
  }

  Future<CampaignProfile> synchronize(
    GameData data, {
    bool acknowledgeUncertain = false,
  }) async {
    await _fetch(data);
    // Use the dedicated endpoint too; its date is authoritative for new rounds.
    state = {...state, 'diario': await call('GET', '/api/v1/diario')};
    final profile = _merge(data, await _read());
    await _write(database, profile);
    if (acknowledgeUncertain) {
      await database.update(
        'online_operations',
        {'state': 'acknowledged'},
        where: "$_where AND state = 'rejected' AND result_json LIKE ?",
        whereArgs: [..._args, '%HINT_UNCERTAIN%'],
      );
      uncertainHint = false;
    }
    return profile;
  }

  @override
  Future<CampaignProfile> load(GameData data) async {
    _requireUser();
    return (await _read())!;
  }

  @override
  Future<void> prepare(SaveProposal proposal) async {
    _requireUser();
    await database.insert('online_operations', {
      'scope': scope,
      'user_id': userId,
      'operation_id': proposal.id,
      'proposal_json': canonicalJson(proposal.toJson()),
      'state': 'prepared',
      'committed': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final row = await _operation(proposal.id);
    if (row['proposal_json'] != canonicalJson(proposal.toJson())) {
      throw OperationMismatch();
    }
  }

  Future<Map<String, Object?>> _operation(String id) async =>
      (await database.query(
        'online_operations',
        where: '$_where AND operation_id = ?',
        whereArgs: [..._args, id],
      )).single;
  Future<void> _update(String id, Map<String, Object?> fields) async {
    await database.update(
      'online_operations',
      fields,
      where: '$_where AND operation_id = ?',
      whereArgs: [..._args, id],
    );
  }

  Future<Never> _reject(SaveProposal proposal, String code) async {
    await _update(proposal.id, {
      'committed': 1,
      'state': 'rejected',
      'result_json': canonicalJson({'rejected': true, 'code': code}),
    });
    if (code == 'HINT_UNCERTAIN') uncertainHint = true;
    throw ApiFailure(code);
  }

  @override
  Future<CampaignProfile> commit(SaveProposal proposal, GameData data) async {
    _requireUser();
    var operation = await _operation(proposal.id);
    if (operation['committed'] == 1) {
      if (operation['state'] == 'rejected') {
        throw ApiFailure(
          (jsonDecode(operation['result_json'] as String) as Map)['code']
              as String,
        );
      }
      return load(data);
    }
    final previous = (await _read())!;
    if (previous.revision != proposal.expectedRevision) {
      throw RevisionConflict();
    }
    final kind = proposal.request['kind'];
    if (['simulated_purchase', 'simulated_ad', 'admob_test'].contains(kind)) {
      return _reject(proposal, 'SHOP_UNAVAILABLE');
    }
    final hintType = switch (kind) {
      'paid_hint' => 'LETRA',
      'mascot_hint' => 'MASCOTE',
      'super_hint' => 'SUPER',
      _ => null,
    };
    final daily = proposal.request['mode'] == 'daily';
    final date = proposal.request['date'];
    final level = proposal.request['levelId'];
    final version = daily
        ? proposal.profile.daily[date]!.catalogVersion
        : data.catalogVersion;
    final phasePath = daily
        ? '/api/v1/diario/$date'
        : '/api/v1/game/fases/$level';
    if (hintType != null && operation['hint_receipt'] == null) {
      // Persist this before HTTP. A restart in this state must never buy again.
      if (operation['state'] == 'hint_sending') {
        return _reject(proposal, 'HINT_UNCERTAIN');
      }
      await _update(proposal.id, {'state': 'hint_sending'});
      Map<String, dynamic> receipt;
      try {
        receipt = await call(
          'POST',
          '$phasePath/dicas',
          body: {'tipoDica': hintType, 'versaoCatalogo': version},
        );
      } on ApiFailure catch (e) {
        if (e.requestNotSent ||
            (e.status != null && e.status! >= 400 && e.status! < 500)) {
          await _update(proposal.id, {'state': 'prepared'});
          rethrow;
        }
        return _reject(proposal, 'HINT_UNCERTAIN');
      }
      // Store the known receipt before doing any subsequent network/local work.
      await _update(proposal.id, {
        'hint_receipt': canonicalJson(receipt),
        'state': 'hint_confirmed',
      });
      operation = await _operation(proposal.id);
    }
    final completion = proposal.entries.any(
      (c) => ['level_completion', 'daily_completion'].contains(c.kind),
    );
    if (completion && operation['completion_receipt'] == null) {
      final snapshot = daily
          ? proposal.profile.daily[date]?.round
          : proposal.profile.rounds[level];
      final goal = daily
          ? 0
          : data.levels.firstWhere((l) => l.id == level).extraGoal;
      final receipt = await call(
        'POST',
        '$phasePath/conclusao',
        body: {
          'versaoCatalogo': version,
          if (!daily)
            'explorador': snapshot != null && snapshot.extras.length >= goal,
        },
      );
      await _update(proposal.id, {
        'completion_receipt': canonicalJson(receipt),
        'state': 'completion_confirmed',
      });
    }
    final themePurchase = kind == 'theme_unlock';
    if (themePurchase && operation['completion_receipt'] == null) {
      final receipt = await call(
        'POST',
        '/api/v1/temas/${Uri.encodeComponent(proposal.request['themeId'] as String)}/compra',
      );
      await _update(proposal.id, {
        'completion_receipt': canonicalJson(receipt),
        'state': 'theme_confirmed',
      });
    }
    if (hintType != null || completion || themePurchase) {
      await _fetch(data, refreshThemes: completion || themePurchase);
    }
    final profile = _merge(data, proposal.profile);
    await database.transaction((txn) async {
      await _write(txn, profile);
      await txn.update(
        'online_operations',
        {
          'committed': 1,
          'state': 'applied',
          'result_json': canonicalJson(proposal.result),
        },
        where: '$_where AND operation_id = ?',
        whereArgs: [..._args, proposal.id],
      );
    });
    return profile;
  }

  @override
  Future<SavedOperation?> resolveOperation(String id) async {
    final rows = await database.query(
      'online_operations',
      where: '$_where AND operation_id = ? AND committed = 1',
      whereArgs: [..._args, id],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final proposal = SaveProposal.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(row['proposal_json'] as String) as Map,
      ),
    );
    return SavedOperation(
      proposal.request,
      Map<String, dynamic>.from(
        jsonDecode(row['result_json'] as String) as Map,
      ),
    );
  }

  @override
  Future<List<SaveProposal>> pending() async =>
      (await database.query(
            'online_operations',
            where: '$_where AND committed = 0',
            whereArgs: _args,
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
  Future<void> discardPending(String id) async {
    await database.delete(
      'online_operations',
      where: '$_where AND operation_id = ? AND committed = 0',
      whereArgs: [..._args, id],
    );
  }
}
