# Biblioteca encantada — artes e configuração

Data: 22/10/2026. Versão: 0.4.0+8.

O usuário aprovou a [composição cartoon](biblioteca-encantada-aprovado.png) e autorizou a implementação. As artes são locais e empacotadas no Android. A imagem de prévia não é usada como tela do aplicativo: botões, letras, respostas e valores continuam widgets reais.

| Recurso | Uso e origem |
|---|---|
| `assets/themes/biblioteca_encantada/scenery-cartoon.png` | Fundo aprovado, copiado de `01-fundo-biblioteca-cartoon.png` da proposta. |
| `assets/themes/biblioteca_encantada/mascot-cartoon.png` | Coruja de óculos com livro aberto, com transparência, copiada de `02-coruja-cartoon.png` da proposta. |
| `assets/themes/biblioteca_encantada/book-seal-cartoon.png` | Base transparente preparada após aprovação, derivada do livro e selo da composição aprovada. |

As três artes foram criadas pela skill imagegen, com a ferramenta integrada `image_gen`, sem CLI/API. Uso sujeito aos termos aplicáveis da ferramenta. Arquivos finais no projeto, independentes do cache de geração. Os prompts do fundo, coruja e prévia estão em [prompts aprovados](biblioteca-encantada-prompts-aprovados.md).

Prompt final da base, com a composição aprovada como referência de estilo e composição:

> Use case: stylized-concept. Asset type: transparent decorative game wheel base. Reference image: approved Biblioteca encantada cartoon UI board, use ONLY the open book and circular teal gold seal behind the letter wheel on the right screen as visual style/composition reference. Generate ONE isolated square PNG asset on genuinely transparent background, no UI. A warm pale open antique book viewed straight-on slightly overhead, pages spreading behind a large perfectly circular flat dark petrol teal seal, honey gold raised rim and restrained gold curling botanical embossing around outer edge. Same charming polished 2D cartoon, bold soft contours and simple warm shading as reference, no realistic textures. Circular seal centered at 50% x 50%, diameter about 87% of canvas, book pages just outside circle within canvas, 3% safe margin. Interior central 75% of circle should be calm empty teal for live letter tokens. IMPORTANT remove ALL letter tokens, letters, shuffle buttons, icons, owl, shelves, lanterns, scenery, text, watermarks; decorative base only. Keep full object within bounds. Transparent alpha outside book and circle; no white or checkerboard painted background.

## Pontos de configuração

- `lib/core/theme/visual_theme_catalog.dart`: identidade estável `biblioteca_encantada`, título e mascote.
- `lib/core/widgets/cartoon_library.dart`: cenário, variante discreta para painéis auxiliares, proteção de legibilidade, selo e superfície clara de respostas sem mudar dimensões.
- `lib/core/widgets/garden.dart`: aplicação do cenário ativo e mascote de canto quando houver espaço.
- `lib/features/game/presentation/widgets/home_art.dart`: fundo e fichas decorativas creme na home.
- `lib/features/game/presentation/widgets/letter_wheel.dart`: base sob as letras e acabamento do botão central. Geometria e eventos existentes preservados.
- `lib/features/game/presentation/themes_screen.dart`: catálogo completo em uma ou duas colunas; miniaturas compostas das mesmas artes locais.
- `pubspec.yaml`: inclusão explícita das três artes.

Na versão 0.4.1+9, a base passou a usar o centro medido do selo dentro do PNG (626,5 × 534,5, em uma imagem de 1254 × 1254) para se alinhar ao centro da roda. A proporção vertical compensa a leve elipse da arte. A imagem original, as fichas e a geometria de toque são preservadas.

Os IDs anteriores `jardim_gatinho` e `capivara_lagoa` continuam válidos; tema ausente ou desconhecido usa o jardim. Todas as ilustrações ignoram toque e leitura semântica. Falha de imagem usa uma alternativa clara ou base simples e dispensa o mascote, sem bloquear o jogo. Não foram adicionados sons, dependências, compras, animação do mascote ou migrações de banco.
