import 'dart:convert';

import '../domain/game_engine.dart';
import '../domain/word_normalizer.dart';

class CatalogIssue {
  const CatalogIssue(
    this.file,
    this.rule,
    this.detail, {
    this.level,
    this.word,
  });
  final String file, rule, detail;
  final int? level;
  final String? word;
  Map<String, Object?> toJson() => {
    'file': file,
    'level': level,
    'word': word,
    'rule': rule,
    'detail': detail,
  };
  @override
  String toString() =>
      '$file${level == null ? '' : ' · Nível $level'}${word == null ? '' : ' · $word'} [$rule]: $detail';
}

class CatalogInspection {
  const CatalogInspection(this.data, this.issues);
  final CatalogData data;
  final List<CatalogIssue> issues;
}

class CatalogData {
  CatalogData(
    List<LevelDefinition> levels,
    Map<String, WordEntry> lexicon, {
    this.catalogVersion = 1,
  }) : levels = List.unmodifiable(levels),
       lexicon = Map.unmodifiable(lexicon);
  final List<LevelDefinition> levels;
  final Map<String, WordEntry> lexicon;
  final int catalogVersion;

  static CatalogData parse(String levelsJson, String lexiconJson) {
    final inspection = inspect(levelsJson, lexiconJson);
    if (inspection.issues.isNotEmpty) {
      throw FormatException(inspection.issues.join('\n'));
    }
    return inspection.data;
  }

  static CatalogInspection inspect(
    String levelsJson,
    String lexiconJson, {
    String levelsFile = 'levels.json',
    String lexiconFile = 'lexicon_pt_br.json',
  }) {
    final issues = <CatalogIssue>[];
    final lexicon = <String, WordEntry>{};
    final levels = <LevelDefinition>[];
    var version = 1;
    try {
      final lexiconRoot = jsonDecode(lexiconJson) as Map<String, dynamic>;
      final levelRoot = jsonDecode(levelsJson) as Map<String, dynamic>;
      if (levelRoot['schemaVersion'] != 1 ||
          lexiconRoot['schemaVersion'] != 1) {
        throw const FormatException('Versão dos dados não suportada.');
      }
      for (final raw in lexiconRoot['words'] as List) {
        try {
          final word = _word(
            raw,
            clueVersion: lexiconRoot['clueVersion'] as int? ?? 1,
          );
          if (lexiconRoot['clueVersion'] != null) {
            final clue = word.clue;
            if (clue == null ||
                clue.trim().isEmpty ||
                clue.length > 120 ||
                word.clueVersion < 1) {
              throw FormatException(
                'Dica ausente ou inválida: ${word.display}.',
              );
            }
            final normalized = WordNormalizer.normalizeClue(clue);
            if (RegExp(
              '(^|[^A-Z])${word.key}([^A-Z]|\$)',
            ).hasMatch(normalized)) {
              throw FormatException(
                'A dica contém sua resposta: ${word.display}.',
              );
            }
          }
          if (lexicon.containsKey(word.key)) {
            issues.add(
              CatalogIssue(
                lexiconFile,
                'collision',
                'Grafias ambíguas ou duplicadas: ${lexicon[word.key]!.display} / ${word.display}.',
                word: word.display,
              ),
            );
            continue;
          }
          lexicon[word.key] = word;
          if (lexiconRoot['editorialPolicy'] != null &&
              (word.key.length > 6 ||
                  ![
                    'substantivo',
                    'adjetivo',
                    'verbo_infinitivo',
                    'outra',
                  ].contains(raw['partOfSpeech']) ||
                  ![1, 2, 3].contains(raw['familiarity']) ||
                  raw['source'] is! String ||
                  raw['referenceLemma'] is! String)) {
            issues.add(
              CatalogIssue(
                lexiconFile,
                'editorial',
                'Classificação, familiaridade, origem ou comprimento inválido.',
                word: word.display,
              ),
            );
          }
        } catch (e) {
          issues.add(
            CatalogIssue(
              lexiconFile,
              'word',
              '$e',
              word: raw is Map ? raw['display']?.toString() : null,
            ),
          );
        }
      }
      for (final raw in levelRoot['levels'] as List) {
        try {
          final words = <WordEntry>[];
          for (final value in raw['words'] as List) {
            try {
              words.add(_word(value));
            } catch (e) {
              issues.add(
                CatalogIssue(
                  levelsFile,
                  'word',
                  '$e',
                  level: raw['id'] is int ? raw['id'] as int : null,
                  word: value is Map ? value['display']?.toString() : null,
                ),
              );
            }
          }
          final level = LevelDefinition(
            id: raw['id'] as int,
            difficulty: raw['difficulty'] as String,
            letters: List<String>.from(raw['letters'] as List),
            words: words,
            extraGoal: raw['extraGoal'] as int? ?? 1,
          );
          issues.addAll(levelIssues(level, lexicon, file: levelsFile));
          if (levels.isNotEmpty && level.id <= levels.last.id) {
            issues.add(
              CatalogIssue(
                levelsFile,
                'ids',
                'IDs devem ser únicos e estar em ordem crescente.',
                level: level.id,
              ),
            );
          }
          levels.add(level);
        } catch (e) {
          issues.add(
            CatalogIssue(
              levelsFile,
              'structure',
              '$e',
              level: raw is Map && raw['id'] is int ? raw['id'] as int : null,
            ),
          );
        }
      }
      if (levels.isEmpty) {
        issues.add(
          CatalogIssue(levelsFile, 'empty', 'O catálogo não pode estar vazio.'),
        );
      }
      version = levelRoot['catalogVersion'] as int? ?? 1;
      if (version < 1) {
        issues.add(
          CatalogIssue(levelsFile, 'version', 'Versão do catálogo inválida.'),
        );
      }
      if (levelRoot['policy'] is Map) {
        issues.addAll(
          policyIssues(levels, lexiconRoot, levelRoot, file: levelsFile),
        );
      }
    } catch (e) {
      issues.add(
        CatalogIssue(
          '$levelsFile / $lexiconFile',
          'structure',
          'Estrutura inválida nos arquivos de níveis ou léxico: $e',
        ),
      );
    }
    return CatalogInspection(
      CatalogData(levels, lexicon, catalogVersion: version),
      issues,
    );
  }

  static WordEntry _word(dynamic raw, {int clueVersion = 1}) {
    final display = raw['display'] as String;
    if (display != display.trim() || display != display.toUpperCase()) {
      throw FormatException('Use grafia em maiúsculas e sem espaços: $display');
    }
    final word = WordEntry(
      display,
      clue: raw['clue'] as String?,
      clueVersion: raw['clueVersion'] as int? ?? clueVersion,
    );
    if (word.key.length < 3) {
      throw FormatException('Palavra com menos de três letras: $display');
    }
    return word;
  }

  static void validateLevel(
    LevelDefinition level,
    Map<String, WordEntry> lexicon,
  ) {
    final issues = levelIssues(level, lexicon);
    if (issues.isNotEmpty) throw FormatException(issues.join('\n'));
  }

  static List<CatalogIssue> levelIssues(
    LevelDefinition level,
    Map<String, WordEntry> lexicon, {
    String file = 'levels.json',
  }) {
    final issues = <CatalogIssue>[];
    void invalid(String message, {String? word}) => issues.add(
      CatalogIssue(file, 'level', message, level: level.id, word: word),
    );
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
        invalid(
          'respostas ambíguas ou duplicadas: ${word.display}.',
          word: word.display,
        );
      }
      if (word.key.length < 3) {
        invalid('resposta curta: ${word.display}.', word: word.display);
      }
      if (!lexicon.containsKey(word.key)) {
        invalid('alvo ausente no léxico: ${word.display}.', word: word.display);
      } else if (lexicon[word.key]!.display != word.display) {
        invalid(
          'grafia diferente da forma canônica: ${word.display}.',
          word: word.display,
        );
      }
      final remaining = level.letters.toList();
      for (final letter in word.key.split('')) {
        if (!remaining.remove(letter)) {
          invalid(
            'fichas insuficientes para ${word.display}.',
            word: word.display,
          );
          break;
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
    return issues;
  }

  static String rackKey(LevelDefinition level) =>
      (level.letters.toList()..sort()).join();
  static String contentKey(LevelDefinition level) =>
      '${rackKey(level)}:${(level.words.map((w) => w.key).toList()..sort()).join(',')}';

  static int difficultyScore(
    LevelDefinition level,
    Map<String, int> familiarity,
  ) {
    final groups = level.words
        .map((w) => (w.key.split('')..sort()).join())
        .toSet()
        .length;
    return 20 * (level.letters.length - 4) +
        8 * (level.words.length - 3) +
        level.words.fold<int>(
          0,
          (n, w) =>
              n + 2 * (w.key.length - 3) + 5 * ((familiarity[w.key] ?? 1) - 1),
        ) +
        2 * (level.words.length - groups);
  }

  static List<CatalogIssue> policyIssues(
    List<LevelDefinition> levels,
    Map<String, dynamic> lexiconRoot,
    Map<String, dynamic> root, {
    String file = 'levels.json',
  }) {
    final issues = <CatalogIssue>[];
    void invalid(String rule, String detail, {int? level}) =>
        issues.add(CatalogIssue(file, rule, detail, level: level));
    final policy = root['policy'] as Map;
    if (policy['expectedLevelCount'] != 2500 || levels.length != 2500) {
      invalid('count', 'Esperados exatamente 2500 níveis.');
    }
    final distance = policy['minimumRackDistance'];
    if (distance is! int ||
        distance < 100 ||
        policy['restEvery'] != 5 ||
        policy['scoreVersion'] != 1) {
      invalid(
        'policy',
        'Exigir distância mínima 100, descanso a cada 5 e pontuação versão 1.',
      );
    }
    final familiarity = <String, int>{};
    for (final raw in lexiconRoot['words'] as List) {
      try {
        familiarity[WordNormalizer.normalize(raw['display'] as String)] =
            raw['familiarity'] as int? ?? 1;
      } catch (_) {
        /* Reported by lexical checks. */
      }
    }
    final lastRack = <String, int>{};
    final identities = <String>{};
    final rawLevels = root['levels'] as List;
    final scores = <int>[];
    for (var i = 0; i < levels.length; i++) {
      final l = levels[i];
      if (l.id != i + 1) {
        invalid(
          'ids',
          'IDs contíguos a partir de 1 são obrigatórios.',
          level: l.id,
        );
      }
      final rack = rackKey(l);
      if (lastRack.containsKey(rack) &&
          distance is int &&
          l.id - lastRack[rack]! < distance) {
        invalid(
          'rack_distance',
          'Conjunto $rack repetido antes de $distance níveis.',
          level: l.id,
        );
      }
      lastRack[rack] = l.id;
      if (!identities.add(contentKey(l))) {
        invalid(
          'duplicate_content',
          'Nível duplicado independentemente da ordem das fichas e respostas.',
          level: l.id,
        );
      }
      final raw = rawLevels[i] as Map;
      final score = difficultyScore(l, familiarity);
      scores.add(score);
      if (raw['difficultyScore'] != score) {
        invalid(
          'score',
          'Pontuação declarada difere da calculada ($score).',
          level: l.id,
        );
      }
      final rest = l.id % 5 == 0;
      if (raw['rest'] != rest) {
        invalid(
          'rest',
          'O quinto nível de cada bloco deve ser mais leve.',
          level: l.id,
        );
      }
      if (rest) {
        if (l.words.any((w) => familiarity[w.key] != 1)) {
          invalid(
            'rest_words',
            'Nível leve deve usar palavras familiares.',
            level: l.id,
          );
        }
        if (scores
            .skip(i < 4 ? 0 : i - 4)
            .take(4)
            .any((previous) => score >= previous)) {
          invalid(
            'rest_score',
            'Nível leve precisa ser mais fácil que os quatro anteriores.',
            level: l.id,
          );
        }
      }
      final band = l.id <= 100
          ? 0
          : l.id <= 500
          ? 1
          : l.id <= 1000
          ? 2
          : l.id <= 1750
          ? 3
          : 4;
      const names = [
        'introducao',
        'facil',
        'intermediario',
        'avancado',
        'desafiador',
      ];
      const tiles = [(4, 5), (4, 5), (5, 6), (5, 6), (6, 6)];
      const targets = [(3, 4), (3, 5), (4, 5), (4, 6), (5, 6)];
      const rests = [(3, 3), (3, 3), (3, 4), (3, 4), (4, 5)];
      final counts = rest ? rests[band] : targets[band];
      final minTiles = rest && tiles[band].$1 > 4
          ? tiles[band].$1 - 1
          : tiles[band].$1;
      if (l.difficulty != names[band] ||
          l.letters.length < minTiles ||
          l.letters.length > tiles[band].$2 ||
          l.words.length < counts.$1 ||
          l.words.length > counts.$2) {
        invalid(
          'band',
          'Conteúdo fora dos limites da faixa ${names[band]}.',
          level: l.id,
        );
      }
      if (l.words.any(
        (w) =>
            (familiarity[w.key] ?? 3) > 2 ||
            (l.id <= 100 && familiarity[w.key] != 1),
      )) {
        invalid(
          'familiarity',
          'Respostas devem ser comuns; introdução somente com familiaridade 1.',
          level: l.id,
        );
      }
    }
    return issues;
  }
}
