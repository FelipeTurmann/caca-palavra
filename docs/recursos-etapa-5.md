# Recursos locais e origem — etapa 5

## Arte

- `assets/mascot-cat.png`: gatinho estático original gerado com a ferramenta integrada `image_gen` em 22/10/2026 para este projeto, pela skill imagegen. PNG com transparência; sem imagem externa, marca-d’água ou texto embutido. O uso segue os termos aplicáveis da ferramenta. O arquivo final está incluído no aplicativo; não depende do cache do Codex.
- Cenário: desenho vetorial original do projeto em `lib/core/widgets/garden.dart` (`_GardenPainter`): gradiente, três camadas de paisagem e plantas laterais. Separado do mascote e dos controles, sem imagens de telas ou molduras de celular.
- Ícones: Material Icons, distribuídos com Flutter (Apache-2.0), incluídos localmente por `uses-material-design`.

Prompt final utilizado na ferramenta integrada (sem CLI):

> Use case: stylized-concept. Asset type: final transparent PNG mascot illustration for a cozy Portuguese word puzzle mobile game. Create ONE adorable static sitting cream-and-orange kitten, closed smiling eyes, rosy cheeks, small coral pink nose, tiny front paws together and a curled orange tail. Polished soft hand-painted 2.5D casual mobile-game illustration, warm creamy highlights and delicate clean contour shading, teal/cream/coral game palette. Full-body isolated centered character with comfortable transparent margins, viewed front slightly three-quarter, no scenery, no plants, no letters, no words, no UI, no phone frame, no watermark. True transparent alpha background. Rounded friendly proportions, professional finished artwork, matching a warm cream and petrol teal botanical puzzle game.

## Fonte

- Nunito variável: `assets/fonts/Nunito.ttf`, empacotada localmente, com acentos e cedilha.
- Origem oficial: https://github.com/google/fonts/tree/main/ofl/nunito
- Arquivo obtido de https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/Nunito%5Bwght%5D.ttf
- Licença SIL Open Font License 1.1, preservada em `assets/fonts/OFL-Nunito.txt`. Consultar esse arquivo para direitos, atribuições e condições de redistribuição.
- Os testes de widget carregam a mesma fonte local em `test/flutter_test_config.dart`, usando as métricas reais da interface.

## Áudio e vibração

Nove arquivos WAV mono originais gerados por síntese matemática, sem gravações de terceiros: `select`, `undo`, `shuffle`, `correct`, `extra`, `invalid`, `reveal`, `victory`, `coins`, em `assets/audio/`. Gerador reproduzível em `tool/generate_audio.py`; esses efeitos originais são disponibilizados pelo projeto sob CC0-1.0. Sem música ou locução.

Reprodução Android por SoundPool, no máximo duas vozes, com assets pré-carregados, sem fila de gestos, respeitando volume, silêncio, foco de áudio e desconexão de saída. A abstração Flutter é substituível por fakes. Vibração usa `View.performHapticFeedback`, respeitando o controle do sistema; não exige forçar motor ou volume. Plataformas sem implementação e falhas de mídia são toleradas sem bloquear o jogo.

Referências técnicas consultadas:

- https://developer.android.com/reference/android/media/SoundPool
- https://developer.android.com/develop/ui/views/haptics/haptic-feedback
- https://docs.flutter.dev/platform-integration/platform-channels

## Pontos de configuração

| Área | Arquivo |
|---|---|
| Cores, fonte, raios, temas | `lib/core/theme/game_theme.dart` |
| Cenário, cartões, botões com volume, confetes | `lib/core/widgets/garden.dart` |
| Política do sistema para movimento | `lib/core/widgets/motion_policy.dart` e builder de `lib/app.dart` |
| Tempos de seleção/acerto/embaralhamento/extras | `GameTiming` em `game_controller.dart` e widgets correspondentes |
| Sons, limitação de seleção (50 ms), prioridades | `lib/core/feedback/game_feedback.dart` |
| SoundPool, foco de áudio e haptics Android | `android/app/src/main/kotlin/br/com/conectepalavras/caca_palavra/MainActivity.kt` |
| Preferências, fila de gravação e introdução | `lib/core/preferences/player_preferences.dart` |
| Migração SQLite 3 → 4 | `lib/features/game/data/progress_repository.dart` |
| Conteúdo e sessão de demonstração | `lib/features/game/presentation/tutorial_screen.dart` |
| Composição retrato/paisagem e preços laterais | `lib/features/game/presentation/game_screen.dart` |

Não foram produzidos ou armazenados screenshots de validação. A imagem do mascote é um recurso funcional do aplicativo.
