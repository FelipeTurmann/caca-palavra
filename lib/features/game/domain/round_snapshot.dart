enum RevealSource { extra, paid, superHint }

class RevealRecord {
  const RevealRecord({
    required this.targetKey,
    required this.index,
    required this.source,
    required this.sourceKey,
  });
  final String targetKey;
  final int index;
  final RevealSource source;
  final String sourceKey;
  Map<String, Object> toJson() => {
    'targetKey': targetKey,
    'index': index,
    'source': source == RevealSource.superHint ? 'super_hint' : source.name,
    'sourceKey': sourceKey,
  };
  factory RevealRecord.fromJson(Map<String, dynamic> json) => RevealRecord(
    targetKey: json['targetKey'] as String,
    index: json['index'] as int,
    source: json['source'] == 'super_hint'
        ? RevealSource.superHint
        : RevealSource.values.byName(json['source'] as String),
    sourceKey: json['sourceKey'] as String,
  );
}

class SuperResolution {
  SuperResolution(this.operationId, this.targetKey, List<int> indices)
    : indices = List.unmodifiable(indices);
  final String operationId, targetKey;
  final List<int> indices;
  Map<String, Object> toJson() => {
    'operationId': operationId,
    'targetKey': targetKey,
    'indices': indices,
  };
  factory SuperResolution.fromJson(Map<String, dynamic> json) =>
      SuperResolution(
        json['operationId'] as String,
        json['targetKey'] as String,
        List<int>.from(json['indices'] as List),
      );
}

class RoundSnapshot {
  RoundSnapshot({
    required this.levelId,
    required this.fingerprint,
    required this.roundId,
    required this.status,
    required List<String> order,
    required List<String> targets,
    required List<String> extras,
    required List<RevealRecord> reveals,
    List<SuperResolution> superHints = const [],
  }) : order = List.unmodifiable(order),
       targets = List.unmodifiable(targets),
       extras = List.unmodifiable(extras),
       reveals = List.unmodifiable(reveals),
       superHints = List.unmodifiable(superHints);
  final int levelId;
  final String fingerprint;
  final String roundId;
  final String status;
  final List<String> order;
  final List<String> targets;
  final List<String> extras;
  final List<RevealRecord> reveals;
  final List<SuperResolution> superHints;
  int get superHintUses => superHints.length;
  int get paidHints =>
      reveals.where((r) => r.source == RevealSource.paid).length;
  int get freeHints =>
      reveals.where((r) => r.source == RevealSource.extra).length;
  Map<String, Object> toJson() => {
    'levelId': levelId,
    'fingerprint': fingerprint,
    'roundId': roundId,
    'status': status,
    'order': order,
    'targets': targets,
    'extras': extras,
    'reveals': reveals.map((r) => r.toJson()).toList(),
    'superHints': superHints.map((r) => r.toJson()).toList(),
  };
  factory RoundSnapshot.fromJson(Map<String, dynamic> json) => RoundSnapshot(
    superHints: (json['superHints'] as List? ?? const [])
        .map(
          (r) => SuperResolution.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList(),
    levelId: json['levelId'] as int,
    fingerprint: json['fingerprint'] as String,
    roundId: json['roundId'] as String,
    status: json['status'] as String,
    order: List<String>.from(json['order'] as List),
    targets: List<String>.from(json['targets'] as List),
    extras: List<String>.from(json['extras'] as List),
    reveals: (json['reveals'] as List)
        .map((r) => RevealRecord.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList(),
  );
}
