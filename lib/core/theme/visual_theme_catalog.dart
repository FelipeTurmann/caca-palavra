import 'package:flutter/material.dart';

/// Stable local identities, independent of word catalogs and saved rounds.
enum VisualTheme {
  garden(
    'jardim_gatinho',
    'Jardim do Gatinho',
    'assets/themes/jardim_gatinho/mascot-cartoon.png',
  ),
  lagoon(
    'capivara_lagoa',
    'Capivara na lagoa',
    'assets/themes/capivara_lagoa/mascot-cartoon.png',
  ),
  library(
    'biblioteca_encantada',
    'Biblioteca encantada',
    'assets/themes/biblioteca_encantada/mascot-cartoon.png',
  ),
  ocean(
    'fundo_mar',
    'Fundo do mar',
    'assets/themes/fundo_mar/mascot-cartoon.png',
  ),
  bees(
    'jardim_abelhas',
    'Jardim das abelhas',
    'assets/themes/jardim_abelhas/mascot-cartoon.png',
  ),
  magic(
    'escola_magia',
    'Escola de magia',
    'assets/themes/escola_magia/mascot-cartoon.png',
  ),
  snow(
    'refugio_neve',
    'Refúgio na neve',
    'assets/themes/refugio_neve/mascot-cartoon.png',
  );

  const VisualTheme(this.id, this.title, this.mascotAsset);
  final String id, title, mascotAsset;
  bool get isLagoon => this == lagoon;
  bool get isLibrary => this == library;
  bool get isOcean => this == ocean;
  bool get isBees => this == bees;
  bool get isMagic => this == magic;
  bool get isSnow => this == snow;

  static VisualTheme resolve(String? id) =>
      values.firstWhere((theme) => theme.id == id, orElse: () => garden);
}

/// Above the navigator so sheets and the isolated tutorial share the choice.
class VisualThemeScope extends InheritedWidget {
  const VisualThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });
  final VisualTheme theme;
  static VisualTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VisualThemeScope>()?.theme ??
      VisualTheme.garden;

  @override
  bool updateShouldNotify(VisualThemeScope oldWidget) =>
      theme != oldWidget.theme;
}

class ThemeMascot extends StatelessWidget {
  const ThemeMascot({super.key, this.theme, this.height, this.width});
  final VisualTheme? theme;
  final double? height, width;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: Image.asset(
        (theme ?? VisualThemeScope.of(context)).mascotAsset,
        height: height,
        width: width,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        errorBuilder: (_, _, _) => SizedBox(height: height, width: width),
      ),
    ),
  );
}
