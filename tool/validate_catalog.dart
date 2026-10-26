import 'dart:convert';
import 'dart:io';

import 'package:caca_palavra/features/game/data/catalog_data.dart';

/// Usage: dart run tool/validate_catalog.dart [--levels path] [--lexicon path]
/// [--daily path] [--report path]. A nonzero exit code rejects the content.
void main(List<String> args) {
  String option(String name, String fallback) {
    final index = args.indexOf(name);
    if (index == -1) return fallback;
    if (index + 1 >= args.length) throw ArgumentError('Falta valor para $name');
    return args[index + 1];
  }

  final issues = <CatalogIssue>[];
  final watch = Stopwatch()..start();
  final levelsPath = option('--levels', 'assets/data/levels.json');
  final lexiconPath = option('--lexicon', 'assets/data/lexicon_pt_br.json');
  final dailyPath = option('--daily', 'assets/data/daily_levels.json');
  final reportPath = option('--report', 'docs/niveis/validation-report.json');
  var levelCount = 0, wordCount = 0, rackCount = 0;
  try {
    final levelsText = File(levelsPath).readAsStringSync();
    final lexiconText = File(lexiconPath).readAsStringSync();
    final campaign = CatalogData.inspect(
      levelsText,
      lexiconText,
      levelsFile: levelsPath,
      lexiconFile: lexiconPath,
    );
    issues.addAll(campaign.issues);
    final root = jsonDecode(levelsText) as Map;
    if (root['policy'] is! Map || campaign.data.levels.length != 2500) {
      issues.add(
        CatalogIssue(
          levelsPath,
          'campaign_policy',
          'O catálogo final exige 2500 níveis e política explícita.',
        ),
      );
    }
    final dailyText = File(dailyPath).readAsStringSync();
    final daily = CatalogData.inspect(
      dailyText,
      lexiconText,
      levelsFile: dailyPath,
      lexiconFile: lexiconPath,
    );
    issues.addAll(daily.issues);
    if (daily.data.levels.length != 7 ||
        daily.data.levels.map(CatalogData.contentKey).toSet().length != 7) {
      issues.add(
        CatalogIssue(
          dailyPath,
          'daily_count',
          'São necessários sete desafios diários distintos.',
        ),
      );
    }
    levelCount = campaign.data.levels.length;
    wordCount = campaign.data.lexicon.length;
    rackCount = campaign.data.levels.map(CatalogData.rackKey).toSet().length;
  } catch (e) {
    issues.add(CatalogIssue('catalog', 'io_structure', '$e'));
  }
  watch.stop();
  final report = {
    'valid': issues.isEmpty,
    'levels': levelCount,
    'lexiconEntries': wordCount,
    'distinctRacks': rackCount,
    'elapsedMs': watch.elapsedMilliseconds,
    'errors': issues.map((i) => i.toJson()).toList(),
  };
  File(reportPath)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
  for (final issue in issues) {
    stderr.writeln(issue);
  }
  stdout.writeln(
    '${issues.isEmpty ? 'OK' : 'FALHA'}: $levelCount níveis, $wordCount palavras, ${issues.length} erros em ${watch.elapsedMilliseconds} ms. Relatório: $reportPath',
  );
  exitCode = issues.isEmpty ? 0 : 1;
}
