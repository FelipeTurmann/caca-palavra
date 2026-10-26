/// Theme access belongs to the player, independently of the active round.
class ThemeUnlockRule {
  const ThemeUnlockRule({this.price, this.level});
  final int? price, level;
}

abstract final class ThemeUnlocks {
  static const priceVersion = 1;
  static const rules = <String, ThemeUnlockRule>{
    'jardim_gatinho': ThemeUnlockRule(),
    'capivara_lagoa': ThemeUnlockRule(price: 500),
    'biblioteca_encantada': ThemeUnlockRule(price: 750),
    'fundo_mar': ThemeUnlockRule(price: 1000),
    'jardim_abelhas': ThemeUnlockRule(price: 1200),
    'escola_magia': ThemeUnlockRule(level: 50),
    'refugio_neve': ThemeUnlockRule(level: 100),
  };

  static ThemeUnlockRule rule(String id) =>
      rules[id] ?? (throw ArgumentError.value(id, 'themeId'));

  static bool available(String id, Set<String> purchased, Set<int> levels) {
    final access = rule(id);
    if (access.price != null) return purchased.contains(id);
    return access.level == null ||
        levels.any((level) => level >= access.level!);
  }

  static int confirmedPrice(Map<String, dynamic> request) {
    final id = request['themeId'];
    final expected = rules[id]?.price;
    if (request['kind'] != 'theme_unlock' ||
        request['themePriceVersion'] != priceVersion ||
        expected == null ||
        request['price'] != expected) {
      throw const FormatException('Preço de tema inválido.');
    }
    return expected;
  }
}
