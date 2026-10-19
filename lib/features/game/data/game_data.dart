import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/game_engine.dart';

class GameData {
  GameData(List<LevelDefinition> levels, Map<String, WordEntry> lexicon)
    : levels = List.unmodifiable(levels),
      lexicon = Map.unmodifiable(lexicon);
  final List<LevelDefinition> levels;
  final Map<String, WordEntry> lexicon;

  static Future<GameData> load({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final json = await Future.wait([
      assets.loadString('assets/data/levels.json'),
      assets.loadString('assets/data/lexicon_pt_br.json'),
    ]);
    return parse(json[0], json[1]);
  }

  static GameData parse(String levelsJson, String lexiconJson) {
    try {
      final lexiconRoot = jsonDecode(lexiconJson) as Map<String, dynamic>;
      final levelRoot = jsonDecode(levelsJson) as Map<String, dynamic>;
      if (levelRoot['schemaVersion'] != 1 ||
          lexiconRoot['schemaVersion'] != 1) {
        throw const FormatException('Versão dos dados não suportada.');
      }
      final lexicon = <String, WordEntry>{};
      for (final raw in lexiconRoot['words'] as List) {
        final word = _word(raw);
        lexicon.putIfAbsent(word.key, () => word);
      }
      final levels = <LevelDefinition>[];
      for (final raw in levelRoot['levels'] as List) {
        final level = LevelDefinition(
          id: raw['id'] as int,
          difficulty: raw['difficulty'] as String,
          letters: List<String>.from(raw['letters'] as List),
          words: (raw['words'] as List).map(_word).toList(),
          extraGoal: raw['extraGoal'] as int? ?? 1,
        );
        validateLevel(level, lexicon);
        if (level.id != levels.length + 1) {
          throw const FormatException(
            'IDs devem ser únicos e sequenciais de 1 a 10.',
          );
        }
        levels.add(level);
      }
      if (levels.length != 10) {
        throw const FormatException('São necessários exatamente dez níveis.');
      }
      return GameData(levels, lexicon);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Estrutura inválida nos arquivos de níveis ou léxico.',
      );
    }
  }

  static WordEntry _word(dynamic raw) {
    final display = raw['display'] as String;
    if (display != display.trim() || display != display.toUpperCase()) {
      throw FormatException('Use grafia em maiúsculas e sem espaços: $display');
    }
    final word = WordEntry(display);
    if (word.key.length < 3) {
      throw FormatException('Palavra com menos de três letras: $display');
    }
    return word;
  }

  static void validateLevel(
    LevelDefinition level,
    Map<String, WordEntry> lexicon,
  ) {
    void invalid(String message) =>
        throw FormatException('Nível ${level.id}: $message');
    if (level.id < 1 || level.difficulty.trim().isEmpty) {
      invalid('metadados inválidos.');
    }
    if (level.letters.length < 4 ||
        level.letters.length > 6 ||
        level.letters.any((letter) => !RegExp(r'^[A-Z]$').hasMatch(letter))) {
      invalid('use de quatro a seis fichas A–Z.');
    }
    if (level.words.length < 3 || level.words.length > 6) {
      invalid('use de três a seis respostas.');
    }
    final seen = <String>{};
    for (final word in level.words) {
      if (!seen.add(word.key)) {
        invalid('respostas ambíguas ou duplicadas: ${word.display}.');
      }
      if (word.key.length < 3) {
        invalid('resposta curta: ${word.display}.');
      }
      if (!lexicon.containsKey(word.key)) {
        invalid('alvo ausente no léxico: ${word.display}.');
      }
      final remaining = level.letters.toList();
      for (final letter in word.key.split('')) {
        if (!remaining.remove(letter)) {
          invalid('fichas insuficientes para ${word.display}.');
        }
      }
    }
    final availableExtras = lexicon.keys
        .where((key) => !seen.contains(key) && level.canForm(key))
        .length;
    if (level.extraGoal < 1 || level.extraGoal > availableExtras) {
      invalid(
        'meta de extras ${level.extraGoal} inválida: há $availableExtras extras possíveis no léxico.',
      );
    }
  }
}
