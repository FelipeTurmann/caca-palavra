# Recursos e configuração dos temas

Data: 22/10/2026. Versão: 0.3.1+5.

Registro das artes anteriores. A versão atual usa as variantes e os prompts em [recursos-cartoon.md](recursos-cartoon.md).

## Arte local

- `assets/mascot-cat.png`: mascote existente do Jardim do Gatinho, preservado. Origem e condições documentadas em [recursos da etapa 5](../recursos-etapa-5.md).
- `assets/themes/capivara_lagoa/mascot.png`: capivara estática original, PNG com transparência, criada nesta entrega com a ferramenta integrada `image_gen`, pela skill imagegen. O uso segue os termos aplicáveis da ferramenta. O arquivo final está no projeto e no pacote Android; não depende do cache de geração.
- `assets/themes/capivara_lagoa/scenery.png`: cenário de lagoa ao pôr do sol, com reflexos, vegetação e vitórias-régias, criado no refinamento visual com `image_gen` integrado. Arte sem interface, textos ou personagens, com o uso sujeito aos termos aplicáveis da ferramenta.
- `assets/themes/capivara_lagoa/island.png`: ilha com grama, pedras, flores e borda de água, criada no refinamento com `image_gen` integrado e fundo transparente, sob os mesmos termos aplicáveis. A decoração é redimensionada para a área existente do círculo, sem alterar os alvos de toque.
- Desenho nativo original em `lib/core/widgets/lagoon.dart`: alternativa em falha de imagem, trilha decorativa das letras e ondulação do mascote. Não usa capturas de telas ou textos rasterizados.
- Miniaturas: composições de `ThemePreview` usando cenário e mascote locais de cada tema. Não precisam de arquivos duplicados.
- Fonte Nunito, ícones Material e sons existentes: preservados, conforme o documento da etapa 5. Não foram acrescentados áudio ambiente, música ou animação do mascote.

Referência de direção visual: `docs/prototipos-temas/01-capivara-na-lagoa.png`. O protótipo não é carregado na interface do aplicativo.

Prompt final usado no modo integrado, sem CLI/API:

> Use case: stylized-concept. Asset type: final transparent PNG static mascot for a cozy Brazilian Portuguese Flutter word puzzle game, Capivara na lagoa theme. Create ONE adorable relaxed brown capybara sitting, full body isolated with generous transparent margins. Rounded long snout, small round ears, short legs, gentle closed smiling eyes, warm cinnamon fur with fine soft illustrated texture and warm peach sunset rim light. Three-quarter view facing slightly left. Charming polished soft hand-painted casual mobile game illustration, natural capybara proportions made friendly and rounded, tiny sage-green leaf resting on its head. True transparent alpha background. No water, no ground, no scenery, no props except the leaf, no cat, no UI, no text, no watermark. Body fully within canvas and easily readable at 120px.

## Prompts das artes do refinamento

Modo utilizado: ferramenta integrada `image_gen`, sem CLI/API. Os dois arquivos finais estão no projeto e no pacote Android; não dependem do cache da ferramenta.

**Cenário — `assets/themes/capivara_lagoa/scenery.png`:**

> Use case: stylized-concept. Asset type: production portrait background ONLY for the Brazilian cozy word game Capivara na lagoa. Create ONE seamless full-bleed tall portrait illustration, approximately 1024x2048, no border. Match a polished softly painted casual mobile game: warm peach sunset over a serene Brazilian lagoon, buttery golden sunlight, delicate reflected ripples, sage green reeds and lush plants, pink water lilies and broad glossy vitoria-regia pads, detailed natural painterly texture rather than flat vector art. Composition for real UI overlays: TOP 35 percent is softly glowing peach/cream sky with wispy coral clouds and an uncluttered bright center, far shoreline and small hazy tree silhouettes at about 40 percent height, low sun centered just above that horizon. LOWER 60 percent is lagoon water with soft warm horizontal reflections, no land in the middle. Frame with richly illustrated aquatic reeds and tiny stones along the far left and right edges, and broad lily pads with pink flowers at the bottom corners. Keep the central 70 percent width softly lit and quiet, especially upper half, with no large dark shapes, so dark text and cream UI cards can be placed above. Detailed foliage restricted to edges and lower corners. Charming warm professionally illustrated mobile game aesthetic, inviting and tranquil, with depth and soft golden-hour glow. This is an independent usable scenery asset, NOT a mockup. ABSOLUTELY no text, no letters, no controls, no buttons, no panels, no icons, no UI, no phone, no frames, no watermarks, no animal, no capybara, no cat, no central island.

**Ilha — `assets/themes/capivara_lagoa/island.png`:**

> Use case: stylized-concept. Asset type: final transparent PNG decorative letter-wheel base for a cozy Brazilian mobile word game, Capivara na lagoa. ONE circular grassy islet viewed almost from directly overhead with only a tiny perspective of the lower rocky edge, matching a friendly sophisticated softly painted casual mobile game at warm peach sunset. The island must read as a true CIRCLE, not a flattened ellipse, centered in a square canvas. Island fills approximately 86 percent of canvas diameter. Large smooth sage and golden olive grass center, subtle delicate grass texture, completely EMPTY usable central 75 percent diameter, no objects in center. At the very OUTER RIM only: scattered tiny rounded grey warm stones, few blades of grass, a few tiny white daisies and small yellow flowers, very restrained botanical detail. Thin ring of shallow clear lagoon water with delicate white-gold concentric ripples just OUTSIDE the island, fading to true alpha transparency. Warm soft side lighting and subtle edge shadows give the grassy island a natural raised thickness. Professional storybook-quality hand-painted mobile-game artwork, polished natural textures without photorealism, warm grass green cream peach teal palette. No letters, no tokens, no controls, no UI, no animals, no characters, no mushrooms, no trees, no large flowers or objects, no text, no frame, no watermark, no full scenery, no solid background. Preserve transparent margins so it layers over a lagoon scene.

## Pontos de configuração

| Área | Arquivo/componente |
|---|---|
| IDs, nomes, recursos e alternativa segura | `lib/core/theme/visual_theme_catalog.dart`, `VisualTheme` |
| Escopo global acima do navegador | `VisualThemeScope`, aplicado em `lib/app.dart` |
| Preferência, fila, erro e retry | `lib/core/preferences/player_preferences.dart` |
| Schema 6 e migração de `visual_theme_id` | `lib/features/game/data/progress_repository.dart` |
| Cartão abaixo do diário | `lib/features/game/presentation/home_screen.dart` |
| Seleção, miniaturas e retorno de salvamento | `lib/features/game/presentation/themes_screen.dart` |
| Cenário, vegetação, reflexos e ilustração inicial | `lib/core/widgets/lagoon.dart` |
| Artes de cenário e ilha | `assets/themes/capivara_lagoa/scenery.png` e `island.png` |
| Decoração compartilhada de telas auxiliares | `lib/core/widgets/garden.dart` |
| Variante da home e preservação do jardim | `lib/features/game/presentation/widgets/home_art.dart` |
| Ilha e acabamento das fichas, sem mudar geometria | `lib/features/game/presentation/widgets/letter_wheel.dart` |

IDs persistidos: `jardim_gatinho` e `capivara_lagoa`. Não renomeá-los ao alterar textos ou arquivos. ID ausente/desconhecido usa Jardim do Gatinho. Falha de imagem dispensa o mascote, sem mostrar gato na lagoa nem bloquear controles.

A ilha, os reflexos e o cenário são estáticos. Os efeitos de acerto existentes continuam seguindo a política comum de movimento reduzido; mudar tema não reproduz efeitos de uma rodada antiga.
