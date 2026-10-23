import '../domain/game_engine.dart';
import '../domain/round_snapshot.dart';

String calendarDate(DateTime time) =>
    '${time.year.toString().padLeft(4, '0')}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
DateTime parseCalendarDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Data diária inválida.');
  }
  final parts = value.split('-').map(int.parse).toList();
  final parsed = DateTime(parts[0], parts[1], parts[2]);
  if (calendarDate(parsed) != value) {
    throw const FormatException('Data diária inválida.');
  }
  return parsed;
}

enum GameMode { campaign, daily }

class RoundContext {
  const RoundContext(
    this.mode,
    this.roundId,
    this.levelId,
    this.session, [
    this.date,
  ]);
  final GameMode mode;
  final String roundId;
  final int levelId, session;
  final String? date;
  String get identity => '${mode.name}:${date ?? ''}:$roundId:$session';
}

class DailyExpired implements Exception {
  @override
  String toString() => 'Um novo desafio diário está disponível.';
}

class ClockReversed implements Exception {
  @override
  String toString() =>
      'Ajuste a data do aparelho para acessar o desafio diário.';
}

class DailyProgress {
  DailyProgress({
    required this.date,
    required this.catalogVersion,
    required this.definition,
    required Map<String, WordEntry> lexicon,
    required this.round,
    this.pendingResult = false,
    this.expired = false,
    this.hasClueCatalog = true,
  }) : lexicon = Map.unmodifiable(lexicon);
  final String date;
  final int catalogVersion;
  final LevelDefinition definition;
  final Map<String, WordEntry> lexicon;
  final RoundSnapshot round;
  final bool pendingResult, expired;
  final bool hasClueCatalog;
  bool get completed => round.status == 'completed';
  DailyProgress copyWith({
    RoundSnapshot? round,
    bool? pendingResult,
    bool? expired,
  }) => DailyProgress(
    date: date,
    catalogVersion: catalogVersion,
    definition: definition,
    lexicon: lexicon,
    round: round ?? this.round,
    pendingResult: pendingResult ?? this.pendingResult,
    expired: expired ?? this.expired,
    hasClueCatalog: hasClueCatalog,
  );
  Map<String, Object?> toJson() => {
    'date': date,
    'catalogVersion': catalogVersion,
    'definition': {
      'id': definition.id,
      'letters': definition.letters,
      'words': definition.words.map((w) => w.display).toList(),
      'extraGoal': definition.extraGoal,
      'difficulty': definition.difficulty,
    },
    'lexicon': lexicon.values.map((w) => w.display).toList(),
    if (hasClueCatalog)
      'clues': {
        for (final word in lexicon.values)
          if (word.clue != null)
            word.key: {'clue': word.clue, 'version': word.clueVersion},
      },
    'round': round.toJson(),
    'pendingResult': pendingResult,
    'expired': expired,
  };
  factory DailyProgress.fromJson(Map<String, dynamic> json) {
    final definition = Map<String, dynamic>.from(json['definition'] as Map);
    final clues = json['clues'] as Map<String, dynamic>? ?? {};
    final lexicon = (json['lexicon'] as List).cast<String>().map((display) {
      final word = WordEntry(display);
      final clue = clues[word.key] as Map<String, dynamic>?;
      return WordEntry(
        display,
        clue: clue?['clue'] as String?,
        clueVersion: clue?['version'] as int? ?? 1,
      );
    });
    return DailyProgress(
      date: json['date'] as String,
      catalogVersion: json['catalogVersion'] as int,
      definition: LevelDefinition(
        id: definition['id'] as int,
        difficulty: definition['difficulty'] as String,
        letters: List<String>.from(definition['letters'] as List),
        words: (definition['words'] as List)
            .cast<String>()
            .map(WordEntry.new)
            .toList(),
        extraGoal: definition['extraGoal'] as int,
      ),
      lexicon: {for (final word in lexicon) word.key: word},
      round: RoundSnapshot.fromJson(
        Map<String, dynamic>.from(json['round'] as Map),
      ),
      pendingResult: json['pendingResult'] as bool,
      expired: json['expired'] as bool,
      hasClueCatalog: json.containsKey('clues'),
    );
  }
}
