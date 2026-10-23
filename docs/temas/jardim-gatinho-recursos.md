# Recursos — Jardim do Gatinho cartoon

Data: 22/10/2026. Versão: 0.3.3+7.

O usuário aprovou a [prévia de início e partida](jardim-gatinho-aprovado.png) antes da implementação. O fundo e o mascote utilizados são os arquivos exatos apresentados para aprovação, copiados para o projeto; o canteiro foi preparado a partir da direção visual aprovada.

## Arquivos finais

- `assets/themes/jardim_gatinho/scenery-cartoon.png`: fundo de jardim florido, PNG opaco.
- `assets/themes/jardim_gatinho/mascot-cartoon.png`: gatinho creme e laranja em cartoon 2D, PNG transparente.
- `assets/themes/jardim_gatinho/flowerbed-cartoon.png`: canteiro circular com pedras, folhas e flores, PNG transparente. Não contém letras ou controles.

Criados com a ferramenta integrada `image_gen`, pela skill imagegen, sem CLI/API ou recursos baixados de terceiros. O uso segue os termos aplicáveis da ferramenta. Os arquivos finais estão incluídos no aplicativo e não dependem do cache da ferramenta. O mascote antigo permanece como fonte em `assets/mascot-cat.png`, sem ser empacotado nesta versão.

Prompts completos do fundo, mascote e prévia: [jardim-gatinho-prompts-aprovados.md](jardim-gatinho-prompts-aprovados.md).

## Prompt final do canteiro

Referência: prévia aprovada. Fundo transparente: sim.

> Use case: compositing. Input is an APPROVED visual proposal for Jardim do Gatinho. Create ONE final isolated transparent PNG of ONLY the circular garden letter-wheel BASE seen in the right-hand screen. Recreate its approved cartoon style and appearance as a reusable decorative game asset, removing EVERY letter token, shuffle button, UI, words, mascots and background. True nearly circular shape, near-overhead view with a small visible lower stone edge, centered square canvas with 4 percent transparent margin. Smooth light sage/lime green circular lawn, empty central 75 percent for real letter controls, simple two-tone cartoon shading and clean warm green contours. At outer edge only, a ring of small round light tan garden stones, a few broad rounded leaves and tiny white daisies, coral-pink and honey-yellow flowers. Matching the supplied approved clean CARTOON 2D art exactly: rounded shapes, warm confident outlines, simplified soft shading, no photorealism, no grass strands or realistic textures. Garden on land: no water, lagoon, ripples, blue ring or island. Absolutely no cat, animals, letters, tokens, control icons, UI, text, frame, watermark, cast background or surrounding full scene. Preserve genuinely transparent alpha outside the flowerbed.

## Integração

- `lib/core/widgets/cartoon_garden.dart`: fundo, canteiro e mascote de canto; arte excluída de eventos de toque e leitura semântica.
- `lib/core/widgets/garden.dart`: escolha do fundo conforme o tema; variante discreta nas telas auxiliares e mascote somente em retrato com espaço e texto padrão.
- `lib/features/game/presentation/widgets/home_art.dart`: preserva a composição e a trilha de letras sobre o novo fundo, dispensando a paisagem vetorial sobreposta. A paisagem antiga fica como alternativa em falha de imagem.
- `lib/features/game/presentation/widgets/letter_wheel.dart`: usa o canteiro do jardim ou a ilha da capivara, com fichas creme e geometria compartilhada existente.
- `lib/core/theme/visual_theme_catalog.dart`: aponta o ID existente `jardim_gatinho` para o mascote cartoon.

Não há novas dependências, schema, ID de tema ou alteração de catálogo de palavras. O fundo e o canteiro são estáticos. A política existente de movimento, som e vibração continua valendo.
