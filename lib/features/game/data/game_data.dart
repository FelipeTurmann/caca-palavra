import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../domain/game_engine.dart';
import 'catalog_data.dart';

class GameData {
  GameData(
    List<LevelDefinition> levels,
    Map<String, WordEntry> lexicon, {
    this.catalogVersion = 1,
  }) : levels = List.unmodifiable(levels),
       lexicon = Map.unmodifiable(lexicon);
  final List<LevelDefinition> levels;
  final Map<String, WordEntry> lexicon;
  final int catalogVersion;

  static Future<GameData> load({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final json = await Future.wait([
      assets.loadString('assets/data/levels.json'),
      assets.loadString('assets/data/lexicon_pt_br.json'),
    ]);
    // Keep full-catalog parsing and validation away from Android's UI isolate.
    return compute(_parseBundle, json);
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
