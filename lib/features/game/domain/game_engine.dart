import 'dart:math';

import 'word_normalizer.dart';

class WordEntry {
  WordEntry(this.display) : key = WordNormalizer.normalize(display);
  final String display;
  final String key;
  List<String> get letters => WordNormalizer.visualLetters(display);
}

class LetterTile {
  const LetterTile(this.id, this.letter);
  final String id;
  final String letter;
}

class LevelDefinition {
  LevelDefinition({
    required this.id,
    required this.difficulty,
    required List<String> letters,
    required List<WordEntry> words,
    this.extraGoal = 1,
  }) : letters = List.unmodifiable(letters),
       words = List.unmodifiable(words),
       tiles = List.unmodifiable([
         for (var i = 0; i < letters.length; i++)
           LetterTile('level${id}_tile$i', letters[i]),
       ]);
  final int id;
  final String difficulty;
  final List<String> letters;
  final List<WordEntry> words;
  final List<LetterTile> tiles;
  final int extraGoal;

  bool canForm(String key) {
    final remaining = letters.toList();
    return key.split('').every(remaining.remove);
  }
}

enum RoundPhase { playing, completing, completed }

enum SubmissionKind {
  ignored,
  tooShort,
  targetFound,
  targetRepeated,
  extraFound,
  extraRepeated,
  unknownWord,
}

class SubmissionResult {
  const SubmissionResult(
    this.kind, {
    this.word,
    this.completed = false,
    this.explorerUnlocked = false,
    this.revealedLetter,
  });
  final SubmissionKind kind;
  final WordEntry? word;
  final bool completed;
  final bool explorerUnlocked;
  final LetterReveal? revealedLetter;
}

class LetterReveal {
  const LetterReveal({
    required this.targetKey,
    required this.index,
    required this.letter,
  });
  final String targetKey;
  final int index;
  final String letter;
}

class GameState {
  GameState({
    required this.level,
    required this.session,
    required List<String> order,
    Set<String> targets = const {},
    Map<String, WordEntry> extras = const {},
    Map<String, Set<int>> revealedLetters = const {},
    this.phase = RoundPhase.playing,
  }) : order = List.unmodifiable(order),
       targets = Set.unmodifiable(targets),
       extras = Map.unmodifiable(extras),
       revealedLetters = Map.unmodifiable({
         for (final entry in revealedLetters.entries)
           entry.key: Set<int>.unmodifiable(entry.value),
       });
  final LevelDefinition level;
  final int session;
  final List<String> order;
  final Set<String> targets;
  final Map<String, WordEntry> extras;
  final Map<String, Set<int>> revealedLetters;
  final RoundPhase phase;
  int get explorerProgress => min(extras.length, level.extraGoal);
  bool get explorerUnlocked => extras.length >= level.extraGoal;

  GameState copyWith({
    List<String>? order,
    Set<String>? targets,
    Map<String, WordEntry>? extras,
    Map<String, Set<int>>? revealedLetters,
    RoundPhase? phase,
  }) => GameState(
    level: level,
    session: session,
    order: order ?? this.order,
    targets: targets ?? this.targets,
    extras: extras ?? this.extras,
    revealedLetters: revealedLetters ?? this.revealedLetters,
    phase: phase ?? this.phase,
  );
}

/// Events are intentionally independent of UI and future reward integrations.
enum GameEventKind { submission, completion, explorerUnlocked }

class GameEvent {
  const GameEvent(this.kind, this.session, this.levelId, [this.result]);
  final GameEventKind kind;
  final int session;
  final int levelId;
  final SubmissionResult? result;
}

class GameEngine {
  GameEngine({
    required List<LevelDefinition> levels,
    required Map<String, WordEntry> lexicon,
    Random? random,
    this.onEvent,
  }) : levels = List.unmodifiable(levels),
       lexicon = Map.unmodifiable(lexicon),
       _random = random ?? Random() {
    startLevel(1);
  }
  final List<LevelDefinition> levels;
  final Map<String, WordEntry> lexicon;
  final Random _random;
  final void Function(GameEvent)? onEvent;
  late GameState _state;
  int _session = 0;
  GameState get state => _state;

  void startLevel(int id) {
    final level = levels.firstWhere((level) => level.id == id);
    _state = GameState(
      level: level,
      session: ++_session,
      order: level.tiles.map((tile) => tile.id).toList(),
    );
  }

  SubmissionResult submit(List<String> ids, {required int session}) {
    if (session != state.session || state.phase != RoundPhase.playing) {
      return const SubmissionResult(SubmissionKind.ignored);
    }
    final byId = {for (final tile in state.level.tiles) tile.id: tile};
    if (ids.toSet().length != ids.length ||
        ids.any((id) => !byId.containsKey(id))) {
      return const SubmissionResult(SubmissionKind.ignored);
    }
    if (ids.length < 2) return const SubmissionResult(SubmissionKind.ignored);
    if (ids.length < 3) return const SubmissionResult(SubmissionKind.tooShort);
    final key = WordNormalizer.normalize(
      ids.map((id) => byId[id]!.letter).join(),
    );
    final targets = {for (final word in state.level.words) word.key: word};
    late final SubmissionResult result;
    if (targets.containsKey(key)) {
      if (state.targets.contains(key)) {
        result = SubmissionResult(
          SubmissionKind.targetRepeated,
          word: targets[key],
        );
      } else {
        final found = {...state.targets, key};
        final completing = found.length == targets.length;
        _state = state.copyWith(
          targets: found,
          phase: completing ? RoundPhase.completing : RoundPhase.playing,
        );
        result = SubmissionResult(
          SubmissionKind.targetFound,
          word: targets[key],
          completed: completing,
        );
      }
    } else if (lexicon.containsKey(key)) {
      final repeated = state.extras.containsKey(key);
      if (!repeated) {
        _state = state.copyWith(extras: {...state.extras, key: lexicon[key]!});
      }
      result = SubmissionResult(
        repeated ? SubmissionKind.extraRepeated : SubmissionKind.extraFound,
        word: lexicon[key],
        revealedLetter: repeated ? null : _revealRandomLetter(),
        explorerUnlocked:
            !repeated && state.extras.length == state.level.extraGoal,
      );
    } else {
      result = const SubmissionResult(SubmissionKind.unknownWord);
    }
    onEvent?.call(
      GameEvent(GameEventKind.submission, session, state.level.id, result),
    );
    if (result.explorerUnlocked) {
      onEvent?.call(
        GameEvent(
          GameEventKind.explorerUnlocked,
          session,
          state.level.id,
          result,
        ),
      );
    }
    if (result.completed) {
      onEvent?.call(
        GameEvent(GameEventKind.completion, session, state.level.id),
      );
    }
    return result;
  }

  bool finishCompletion(int session) {
    if (state.session != session || state.phase != RoundPhase.completing) {
      return false;
    }
    _state = state.copyWith(phase: RoundPhase.completed);
    return true;
  }

  LetterReveal? _revealRandomLetter() {
    final eligibleWords = state.level.words
        .where(
          (word) =>
              !state.targets.contains(word.key) &&
              (state.revealedLetters[word.key]?.length ?? 0) <
                  word.letters.length - 1,
        )
        .toList();
    if (eligibleWords.isEmpty) return null;
    final word = eligibleWords[_random.nextInt(eligibleWords.length)];
    final revealed = state.revealedLetters[word.key] ?? const <int>{};
    final emptySlots = [
      for (var index = 0; index < word.letters.length; index++)
        if (!revealed.contains(index)) index,
    ];
    final index = emptySlots[_random.nextInt(emptySlots.length)];
    _state = state.copyWith(
      revealedLetters: {
        ...state.revealedLetters,
        word.key: {...revealed, index},
      },
    );
    return LetterReveal(
      targetKey: word.key,
      index: index,
      letter: word.letters[index],
    );
  }

  bool shuffle({bool dragging = false}) {
    if (dragging || state.phase != RoundPhase.playing) return false;
    final tiles = {for (final tile in state.level.tiles) tile.id: tile.letter};
    String visual(List<String> order) => order.map((id) => tiles[id]).join();
    final previous = visual(state.order);
    var next = state.order.toList();
    for (var attempt = 0; attempt < 12; attempt++) {
      next.shuffle(_random);
      if (visual(next) != previous) break;
    }
    if (visual(next) == previous) {
      next = state.order.toList();
      for (var shift = 1; shift < next.length; shift++) {
        final rotated = [...next.skip(shift), ...next.take(shift)];
        if (visual(rotated) != previous) {
          next = rotated;
          break;
        }
      }
    }
    if (visual(next) == previous) return false;
    _state = state.copyWith(order: next);
    return true;
  }
}
