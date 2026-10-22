import 'dart:convert';
import 'package:flutter/services.dart';
import '../application/daily_models.dart';
import '../domain/game_engine.dart';
import 'game_data.dart';

class DailyCatalog {
  DailyCatalog({
    required this.version,
    required this.baseDate,
    required List<LevelDefinition> levels,
    required Map<String, WordEntry> lexicon,
  }) : levels = List.unmodifiable(levels),
       lexicon = Map.unmodifiable(lexicon) {
    parseCalendarDate(baseDate);
    if (levels.isEmpty) throw const FormatException('Catálogo diário vazio.');
  }
  final int version;
  final String baseDate;
  final List<LevelDefinition> levels;
  final Map<String, WordEntry> lexicon;
  factory DailyCatalog.fixture(GameData data) => DailyCatalog(
    version: 1,
    baseDate: '2026-01-01',
    levels: data.levels.take(7).toList(),
    lexicon: data.lexicon,
  );
  LevelDefinition forDate(String date) {
    final day = parseCalendarDate(date), base = parseCalendarDate(baseDate);
    final days = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(base.year, base.month, base.day)).inDays;
    return levels[days % levels.length];
  }

  static Future<DailyCatalog> load() async {
    final raw = await rootBundle.loadString('assets/data/daily_levels.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final data = GameData.parse(
      raw,
      await rootBundle.loadString('assets/data/lexicon_pt_br.json'),
    );
    if (data.levels.length < 7 ||
        data.levels.map((l) => l.fingerprint).toSet().length !=
            data.levels.length) {
      throw const FormatException(
        'São necessários sete desafios diários distintos.',
      );
    }
    return DailyCatalog(
      version: data.catalogVersion,
      baseDate: json['baseDate'] as String,
      levels: data.levels,
      lexicon: data.lexicon,
    );
  }
}
