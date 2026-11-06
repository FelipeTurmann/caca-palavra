import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../domain/game_engine.dart';
import '../domain/round_snapshot.dart';
import '../../../core/api/api_client.dart';
import 'catalog_data.dart';

class GameData {
  GameData(
    List<LevelDefinition> levels,
    Map<String, WordEntry> lexicon, {
    this.catalogVersion = 1,
    this.previous,
  }) : levels = List.unmodifiable(levels),
       lexicon = Map.unmodifiable(lexicon);
  final List<LevelDefinition> levels;
  final Map<String, WordEntry> lexicon;
  final int catalogVersion;
  final GameData? previous;

  static Future<GameData> load({AssetBundle? bundle, int version = 2}) async {
    final assets = bundle ?? rootBundle;
    if (version != 2 && version != 3) {
      throw const ApiFailure('CATALOG_VERSION_MISMATCH');
    }
    final directory = version == 3 ? 'tool/content/catalog-v3' : 'assets/data';
    final json = await Future.wait([
      assets.loadString('$directory/levels.json'),
      assets.loadString('$directory/lexicon_pt_br.json'),
    ]);
    // Keep full-catalog parsing and validation away from Android's UI isolate.
    final data = await compute(_parseBundle, json);
    if (version == 2) return data;
    return GameData(
      data.levels,
      data.lexicon,
      catalogVersion: data.catalogVersion,
      previous: await load(bundle: assets),
    );
  }

  GameData forRound(RoundSnapshot snapshot) {
    final old = previous;
    if (old == null) return this;
    final level = levels.firstWhere((level) => level.id == snapshot.levelId);
    if (level.fingerprint == snapshot.fingerprint) return this;
    return old.levels.any(
          (level) =>
              level.id == snapshot.levelId &&
              level.fingerprint == snapshot.fingerprint,
        )
        ? old
        : this;
  }

  GameEngine createEngine({RoundSnapshot? round, Random? random}) {
    final data = round == null ? this : forRound(round);
    return GameEngine(
      levels: data.levels,
      lexicon: data.lexicon,
      random: random,
    );
  }

  static GameData _parseBundle(List<String> json) => parse(json[0], json[1]);

  static GameData parse(String levelsJson, String lexiconJson) {
    final data = CatalogData.parse(levelsJson, lexiconJson);
    return GameData(
      data.levels,
      data.lexicon,
      catalogVersion: data.catalogVersion,
    );
  }

  static void validateLevel(
    LevelDefinition level,
    Map<String, WordEntry> lexicon,
  ) => CatalogData.validateLevel(level, lexicon);
}
