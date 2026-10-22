import 'dart:math';
import 'dart:convert';

import 'word_normalizer.dart';
import 'round_snapshot.dart';

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
  String get fingerprint => jsonEncode({
    'id': id,
    'letters': letters,
    'words': words.map((w) => w.display).toList(),
    'extraGoal': extraGoal,
  });

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
  superResolved,
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
    List<RevealRecord> revealOrigins = const [],
    List<SuperResolution> superHints = const [],
    this.phase = RoundPhase.playing,
  }) : order = List.unmodifiable(order),
       targets = Set.unmodifiable(targets),
       extras = Map.unmodifiable(extras),
       revealOrigins = List.unmodifiable(revealOrigins),
       superHints = List.unmodifiable(superHints),
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
  final List<RevealRecord> revealOrigins;
  final List<SuperResolution> superHints;
  final RoundPhase phase;
  int get explorerProgress => min(extras.length, level.extraGoal);
  bool get explorerUnlocked => extras.length >= level.extraGoal;

  GameState copyWith({
    List<String>? order,
    Set<String>? targets,
    Map<String, WordEntry>? extras,
    Map<String, Set<int>>? revealedLetters,
    List<RevealRecord>? revealOrigins,
    List<SuperResolution>? superHints,
    RoundPhase? phase,
  }) => GameState(
    level: level,
    session: session,
    order: order ?? this.order,
    targets: targets ?? this.targets,
    extras: extras ?? this.extras,
    revealedLetters: revealedLetters ?? this.revealedLetters,
    revealOrigins: revealOrigins ?? this.revealOrigins,
    superHints: superHints ?? this.superHints,
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
    startLevel(levels.first.id);
  }
  final List<LevelDefinition> levels;
  final Map<String, WordEntry> lexicon;
  final Random _random;
  Random get randomSource => _random;
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
        revealedLetter: repeated
            ? null
            : _revealRandomLetter(RevealSource.extra, key),
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

  LetterReveal? revealPaidHint(String operationId) =>
      state.phase == RoundPhase.playing
      ? _revealRandomLetter(RevealSource.paid, operationId)
      : null;

  SubmissionResult resolveSuperHint(String operationId) {
    if (state.phase != RoundPhase.playing) {
      return const SubmissionResult(SubmissionKind.ignored);
    }
    final remaining = state.level.words
        .where((w) => !state.targets.contains(w.key))
        .toList();
    if (remaining.isEmpty) {
      return const SubmissionResult(SubmissionKind.ignored);
    }
    int hidden(WordEntry w) =>
        w.letters.length - (state.revealedLetters[w.key]?.length ?? 0);
    final largest = remaining.map(hidden).reduce(max);
    final tied = remaining.where((w) => hidden(w) == largest).toList();
    final word = tied[tied.length == 1 ? 0 : _random.nextInt(tied.length)];
    final previous = state.revealedLetters[word.key] ?? const <int>{};
    final indices = [
      for (var i = 0; i < word.letters.length; i++)
        if (!previous.contains(i)) i,
    ];
    final targets = {...state.targets, word.key};
    final complete = targets.length == state.level.words.length;
    _state = state.copyWith(
      targets: targets,
      phase: complete ? RoundPhase.completing : RoundPhase.playing,
      revealedLetters: {
        ...state.revealedLetters,
        word.key: {...previous, ...indices},
      },
      revealOrigins: [
        ...state.revealOrigins,
        for (final i in indices)
          RevealRecord(
            targetKey: word.key,
            index: i,
            source: RevealSource.superHint,
            sourceKey: operationId,
          ),
      ],
      superHints: [
        ...state.superHints,
        SuperResolution(operationId, word.key, indices),
      ],
    );
    return SubmissionResult(
      SubmissionKind.superResolved,
      word: word,
      completed: complete,
    );
  }

  bool get canReveal =>
      state.phase == RoundPhase.playing &&
      state.level.words.any(
        (word) =>
            !state.targets.contains(word.key) &&
            (state.revealedLetters[word.key]?.length ?? 0) <
                word.letters.length - 1,
      );

  LetterReveal? _revealRandomLetter(RevealSource source, String sourceKey) {
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
      revealOrigins: [
        ...state.revealOrigins,
        RevealRecord(
          targetKey: word.key,
          index: index,
          source: source,
          sourceKey: sourceKey,
        ),
      ],
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

  RoundSnapshot snapshot(String roundId) => RoundSnapshot(
    levelId: state.level.id,
    fingerprint: state.level.fingerprint,
    roundId: roundId,
    status: state.phase == RoundPhase.playing ? 'in_progress' : 'completed',
    order: state.order,
    targets: state.targets.toList(),
    extras: state.extras.keys.toList(),
    reveals: state.revealOrigins,
    superHints: state.superHints,
  );

  GameEngine fork(RoundSnapshot snapshot) {
    final result = GameEngine(
      levels: levels,
      lexicon: lexicon,
      random: _random,
    );
    result.restoreRound(snapshot);
    return result;
  }

  /// Validation reconstructs durable state without submissions or random draws.
  void restoreRound(
    RoundSnapshot snapshot, {
    bool showCompletion = false,
    bool preserveSession = false,
  }) {
    final matches = levels.where((l) => l.id == snapshot.levelId);
    if (matches.length != 1) {
      throw const FormatException('Nível salvo não existe no catálogo.');
    }
    final level = matches.single;
    void invalid(String message) =>
        throw FormatException('Progresso do nível ${level.id}: $message');
    if (snapshot.fingerprint != level.fingerprint) {
      invalid('conteúdo incompatível com o progresso salvo.');
    }
    if (snapshot.roundId.isEmpty ||
        !['in_progress', 'completed'].contains(snapshot.status)) {
      invalid('rodada inválida.');
    }
    final ids = level.tiles.map((t) => t.id).toSet();
    if (snapshot.order.length != ids.length ||
        snapshot.order.toSet().length != ids.length ||
        !snapshot.order.toSet().containsAll(ids)) {
      invalid('ordem de fichas inválida.');
    }
    final targetKeys = level.words.map((w) => w.key).toSet();
    if (snapshot.targets.toSet().length != snapshot.targets.length ||
        !targetKeys.containsAll(snapshot.targets)) {
      invalid('alvos inválidos.');
    }
    if ((snapshot.targets.length == targetKeys.length) !=
        (snapshot.status == 'completed')) {
      invalid('conclusão inconsistente.');
    }
    if (snapshot.extras.toSet().length != snapshot.extras.length ||
        snapshot.extras.any(
          (key) =>
              targetKeys.contains(key) ||
              !lexicon.containsKey(key) ||
              !level.canForm(key),
        )) {
      invalid('extras inválidas.');
    }
    final assisted = <String, SuperResolution>{};
    final assistedIds = <String>{};
    for (final resolution in snapshot.superHints) {
      if (resolution.operationId.isEmpty ||
          !assistedIds.add(resolution.operationId) ||
          assisted.containsKey(resolution.targetKey) ||
          !snapshot.targets.contains(resolution.targetKey) ||
          resolution.indices.isEmpty ||
          resolution.indices.toSet().length != resolution.indices.length) {
        invalid('resolução de Super Dica inválida.');
      }
      assisted[resolution.targetKey] = resolution;
    }
    final reveals = <String, Set<int>>{};
    final origins = <String>{};
    for (final reveal in snapshot.reveals) {
      final words = level.words.where((w) => w.key == reveal.targetKey);
      if (words.length != 1 || reveal.sourceKey.isEmpty) {
        invalid('origem da revelação inválida.');
      }
      final word = words.single;
      final indices = reveals.putIfAbsent(word.key, () => <int>{});
      if (reveal.index < 0 ||
          reveal.index >= word.letters.length ||
          !indices.add(reveal.index) ||
          (indices.length >= word.letters.length &&
              !assisted.containsKey(word.key))) {
        invalid('posição revelada inválida.');
      }
      if (reveal.source != RevealSource.superHint &&
          !origins.add('${reveal.source.name}:${reveal.sourceKey}')) {
        invalid('origem repetida.');
      }
      if (reveal.source == RevealSource.extra &&
          !snapshot.extras.contains(reveal.sourceKey)) {
        invalid('extra de origem ausente.');
      }
    }
    for (final entry in reveals.entries) {
      final normal = snapshot.reveals
          .where(
            (r) =>
                r.targetKey == entry.key && r.source != RevealSource.superHint,
          )
          .length;
      if (normal >=
          level.words.firstWhere((w) => w.key == entry.key).letters.length) {
        invalid('dica comum resolveu palavra.');
      }
    }
    for (final resolution in snapshot.superHints) {
      final word = level.words
          .where((w) => w.key == resolution.targetKey)
          .firstOrNull;
      final records = snapshot.reveals
          .where(
            (r) =>
                r.source == RevealSource.superHint &&
                r.sourceKey == resolution.operationId,
          )
          .toList();
      if (word == null ||
          reveals[word.key]?.length != word.letters.length ||
          records.length != resolution.indices.length ||
          records.any(
            (r) =>
                r.targetKey != word.key ||
                !resolution.indices.contains(r.index),
          )) {
        invalid('revelação assistida inconsistente.');
      }
    }
    if (snapshot.reveals.any(
      (r) =>
          r.source == RevealSource.superHint &&
          (!assistedIds.contains(r.sourceKey) ||
              assisted[r.targetKey]?.operationId != r.sourceKey),
    )) {
      invalid('origem de Super Dica ausente.');
    }
    _state = GameState(
      level: level,
      session: preserveSession ? state.session : ++_session,
      order: snapshot.order,
      targets: snapshot.targets.toSet(),
      extras: {for (final key in snapshot.extras) key: lexicon[key]!},
      revealedLetters: reveals,
      revealOrigins: snapshot.reveals,
      superHints: snapshot.superHints,
      phase: snapshot.status == 'completed'
          ? (showCompletion ? RoundPhase.completing : RoundPhase.completed)
          : RoundPhase.playing,
    );
  }

  void emitCommitted(SubmissionResult result) {
    onEvent?.call(
      GameEvent(
        GameEventKind.submission,
        state.session,
        state.level.id,
        result,
      ),
    );
    if (result.explorerUnlocked) {
      onEvent?.call(
        GameEvent(
          GameEventKind.explorerUnlocked,
          state.session,
          state.level.id,
          result,
        ),
      );
    }
    if (result.completed) {
      onEvent?.call(
        GameEvent(
          GameEventKind.completion,
          state.session,
          state.level.id,
          result,
        ),
      );
    }
  }
}
