# Recursos cartoon — Capivara na lagoa

Data: 22/10/2026. Versão: 0.3.2+6.

As três artes foram transformadas com a ferramenta integrada `image_gen`, usando os respectivos arquivos anteriores como alvos de edição. O uso segue os termos aplicáveis da ferramenta. Não houve uso de CLI/API, download de arte externa ou alteração programática dos pixels.

Arquivos finais locais, declarados no `pubspec.yaml`:

- `assets/themes/capivara_lagoa/scenery-cartoon.png`: cenário vertical opaco.
- `assets/themes/capivara_lagoa/island-cartoon.png`: ilha isolada com transparência.
- `assets/themes/capivara_lagoa/mascot-cartoon.png`: capivara isolada com transparência.

Todos estão incluídos no pacote Android e independem do cache da ferramenta. Os originais `scenery.png`, `island.png` e `mascot.png` foram preservados como fontes no projeto e deixaram de ser declarados como recursos do pacote. As origens anteriores estão em [recursos.md](recursos.md).

Direção visual comum: cartoon 2D, formas arredondadas, contornos definidos, cores suaves, sombreamento simples, água e vegetação simplificadas, sem textura fotográfica. Câmera, composição, áreas livres para controles e transparência foram preservadas.

## Prompt do cenário

Alvo: `assets/themes/capivara_lagoa/scenery.png`. Saída: `scenery-cartoon.png`. Fundo transparente: não.

> Use case: style-transfer. Edit target: the supplied tall lagoon scenery asset. Redraw it in a clearly CARTOON 2D casual mobile-game illustration style. Preserve its exact portrait composition, horizon near 40 percent height, centered sunset, open central lake, clouds, trees at the distant banks, reeds and lily pads at side edges and bottom corners. Change the visual treatment completely: large clean rounded shapes, simplified puffy clouds, rounded bush-like tree canopies, a few smooth rounded water ripple bands, broad readable lily pads with simple pink lotus blossoms. Clean confident warm brown/green contours, flat pastel color areas with only gentle two-tone cel shading. Cozy friendly storybook cartoon, light peach and coral sky, buttery cream sunlight, soft muted turquoise and sage lagoon, sage plants with warm accents. Calm uncluttered center for real text/buttons to overlay. NOT photorealistic, NOT 3D, NOT oil painting, no fine grass/fur/leaf texture, no dense tiny details, no photographic highlights. Keep the same scene objects and camera, add no animals or island. No UI, no letters, no text, no frames or watermark. Full-bleed background, no transparency.

## Prompt da ilha

Alvo: `assets/themes/capivara_lagoa/island.png`. Saída: `island-cartoon.png`. Fundo transparente: sim.

> Use case: style-transfer. Edit target: supplied transparent circular grassy island asset. Redraw in clearly CARTOON 2D casual mobile-game style, coordinating with a pastel peach sunset lagoon. Preserve the isolated centered circular shape, near-overhead camera, transparent surroundings, empty center and thin water ring. Replace realistic texture with large smooth rounded shapes and clean warm dark-green/brown contour lines. Smooth light sage-green grassy top with a subtle flat highlight, no individual grass texture. A small handful of round pebble shapes around the very outer edge, a few simple tiny white daisies and yellow cartoon flowers at the edge only. Empty central 75 percent diameter for real interactive letter tokens. Water ring pale turquoise with two or three simple cream ripple curves. Friendly cozy polished storybook cartoon, flat pastel colors and gentle two-tone cel shading, no 3D render, no photorealism, no painterly noise or tiny details. True transparent alpha outside the island and water ring. No letters, no tokens, no controls, no text, no animals, no scenery or solid background.

## Prompt da capivara

Alvo: `assets/themes/capivara_lagoa/mascot.png`. Saída: `mascot-cartoon.png`. Fundo transparente: sim.

> Use case: style-transfer. Edit target: supplied isolated capybara mascot. Redraw this SAME happy sitting capybara pose, facing slightly left in three-quarter view with closed smiling eyes and a sage leaf on its head, as a clearly CARTOON 2D casual mobile-game character. Strong recognizable capybara silhouette: long rounded broad snout, small round ears, chunky pear-shaped seated body, short legs and little rounded feet. Cute friendly rounded proportions, soft rosy cheeks, simple curved smile. Clean confident dark warm-brown outlines, flat warm cinnamon and caramel color shapes, only gentle two-tone cel shading. Smooth fur as color areas with at most a few tiny graphic tufts; absolutely NO realistic individual fur strands, photographic texture, 3D rendering, glossy fur or realistic lighting. Polished charming cozy storybook cartoon art matching pastel peach sunset, sage green plants and turquoise lagoon. Full body isolated centered on TRUE transparent alpha with comfortable margins; preserve feet and ears entirely within canvas, similar framing and pose to input. No scenery, ground, water, background, text, UI, frame, watermark, extra animal or extra prop. Exactly one capybara with its small green leaf.
