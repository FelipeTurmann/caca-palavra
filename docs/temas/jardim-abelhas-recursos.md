# Jardim das abelhas — artes e configuração

Data: 22/10/2026. Versão: **0.6.0+11**.

O usuário aprovou a [prévia cartoon](jardim-abelhas-aprovado.png) e autorizou a implementação. As três artes aprovadas foram copiadas sem alteração para o projeto e incluídas no pacote Android.

| Recurso local | Origem e uso |
|---|---|
| `assets/themes/jardim_abelhas/scenery-cartoon.png` | `01-fundo-jardim-abelhas-cartoon.png`: jardim ensolarado, margaridas, folhas e pequena colmeia nas bordas; centro livre para leitura. |
| `assets/themes/jardim_abelhas/mascot-cartoon.png` | `02-abelha-cartoon.png`: abelhinha sorridente, com transparência, usada na home, miniatura e canto da partida quando houver espaço. |
| `assets/themes/jardim_abelhas/flower-cartoon.png` | `03-flor-cartoon.png`: margarida transparente, com centro dourado circular e pétalas suaves, somente decoração sob as fichas reais. |

As artes e a prévia foram geradas pela skill imagegen usando a ferramenta integrada `image_gen`, sem CLI/API, durante a proposta aprovada. Uso sujeito aos termos aplicáveis da ferramenta. Não houve nova geração nesta implementação. Arquivos finais no projeto, independentes do cache da ferramenta. Prompts completos e referências: [jardim-abelhas-prompts-aprovados.md](jardim-abelhas-prompts-aprovados.md).

A prévia é referência visual e não é embutida como tela. Textos, moedas, letras e controles são widgets reais, alimentados pelo estado da partida. As miniaturas usam as mesmas artes locais.

## Configuração

- `lib/core/theme/visual_theme_catalog.dart`: identidade estável `jardim_abelhas`, título **Jardim das abelhas** e mascote.
- `lib/core/widgets/cartoon_bees.dart`: cenário, variante discreta em telas auxiliares e flor. O centro da arte quadrada coincide com o centro da roda; não desloca fichas ou áreas de toque.
- `lib/core/widgets/themed_reading_page.dart`: superfície clara com contorno em tom de mel, preservando dimensões e rolagem das respostas.
- `lib/core/widgets/garden.dart`: cenário ativo e abelha de canto em telas com espaço suficiente.
- `lib/features/game/presentation/widgets/home_art.dart`: cenário, fichas decorativas creme e abelha na home.
- `lib/features/game/presentation/widgets/letter_wheel.dart`: flor atrás das letras, fichas verde-petróleo com letras brancas e botão central verde-petróleo. Seleção preserva destaque dourado, traço e escala existentes.
- `lib/features/game/presentation/widgets/word_slots.dart`: contorno mel nas células vazias. Células continuam separadas e alinhadas; preenchidas e reveladas mantêm seus estados e indicadores.
- `lib/features/game/presentation/themes_screen.dart`: catálogo dinâmico acomoda a quinta opção em uma ou duas colunas, com rolagem.
- `pubspec.yaml`: versão e inclusão explícita dos três PNGs.

As ilustrações ignoram toque e leitura semântica. Falha de carregamento usa fundo claro, base simples ou dispensa o mascote, sem bloquear o jogo. Não foram adicionados música, áudio ambiente, dependências, compras ou animação de mascote.

IDs anteriores preservados: `jardim_gatinho`, `capivara_lagoa`, `biblioteca_encantada`, `fundo_mar`. O jardim do gatinho permanece padrão para novas instalações e IDs desconhecidos. O novo tema usa `app_settings.visual_theme_id`, sem migração adicional: schema 6 e payload 2 continuam válidos.
