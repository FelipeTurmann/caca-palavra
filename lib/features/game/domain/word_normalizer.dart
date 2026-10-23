/// A single comparison policy for assets, targets, lexicon and submissions.
abstract final class WordNormalizer {
  static const _accented = 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  static const _plain = 'AAAAAEEEEIIIIOOOOOUUUUC';

  static String normalizeClue(String value) {
    final output = StringBuffer();
    for (final rune in value.toUpperCase().runes) {
      if (rune >= 0x300 && rune <= 0x36f) continue;
      final char = String.fromCharCode(rune);
      final index = _accented.indexOf(char);
      output.write(index >= 0 ? _plain[index] : char);
    }
    return output.toString();
  }

  static String normalize(String value) {
    final upper = value.trim().toUpperCase();
    final output = StringBuffer();
    for (final rune in upper.runes) {
      if (rune >= 0x300 && rune <= 0x36f) continue;
      final char = String.fromCharCode(rune);
      final index = _accented.indexOf(char);
      if (index >= 0) {
        output.write(_plain[index]);
      } else if (rune >= 65 && rune <= 90) {
        output.write(char);
      } else {
        throw FormatException('Caractere não suportado na palavra: $value');
      }
    }
    final result = output.toString();
    if (result.isEmpty) throw const FormatException('Palavra vazia.');
    return result;
  }

  /// Portuguese combining marks stay attached to their base visual letter.
  static List<String> visualLetters(String display) {
    final result = <String>[];
    for (final rune in display.runes) {
      final char = String.fromCharCode(rune);
      if (rune >= 0x300 && rune <= 0x36f && result.isNotEmpty) {
        result[result.length - 1] += char;
      } else {
        result.add(char);
      }
    }
    return List.unmodifiable(result);
  }
}
