# Escola de magia — artes e configuração

Data: 23/10/2026. Versão: **0.7.0+12**.

O usuário aprovou a [prévia cartoon](escola-magia-aprovado.png) e autorizou a implementação. O nome **Escola de magia** segue o pedido explícito; o antigo protótipo Oficina de magia foi apenas uma referência visual.

| Recurso local | Origem e uso |
|---|---|
| `assets/themes/escola_magia/scenery-cartoon.png` | `01-fundo-escola-magia-cartoon.png`: sala em lavanda e creme, poções, cristais e bancada nas bordas; centro livre para leitura. |
| `assets/themes/escola_magia/mascot-cartoon.png` | `02-dragao-cartoon.png`: dragãozinho verde-menta com asas recolhidas e transparência, usado na home, miniatura e canto da partida quando houver espaço. |
| `assets/themes/escola_magia/cauldron-cartoon.png` | `03-caldeirao-cartoon.png`: abertura de caldeirão transparente, líquido menta e borda lavanda/dourada, somente decoração sob as fichas reais. |

As artes e a prévia foram criadas pela skill imagegen com a ferramenta integrada `image_gen`, sem CLI/API, durante a proposta aprovada. O dragão recebeu um ajuste pontual das asas nessa etapa. Não houve nova geração na implementação. Uso sujeito aos termos aplicáveis da ferramenta. Arquivos finais copiados sem alteração para o projeto, independentes do cache. Prompts completos e referências: [escola-magia-prompts-aprovados.md](escola-magia-prompts-aprovados.md).

A prévia não é embutida como tela: textos, valores, letras e controles continuam widgets reais. As miniaturas usam as mesmas artes locais.

## Configuração

- `lib/core/theme/visual_theme_catalog.dart`: ID estável `escola_magia`, título **Escola de magia** e mascote.
- `lib/core/widgets/cartoon_magic.dart`: cenário e variante discreta em telas auxiliares; base calibrada pelo centro da abertura dentro do PNG (622,5 × 610, em 1254 × 1254 pixels). A compensação vertical 919/898 mantém a abertura circular e concêntrica às fichas, sem mudar geometria de toque.
- `lib/core/widgets/themed_reading_page.dart`: superfície clara com contorno lavanda, sem alterar tamanho ou rolagem das respostas.
- `lib/core/widgets/garden.dart`: cenário ativo e dragão de canto quando houver espaço.
- `lib/features/game/presentation/widgets/home_art.dart`: cenário, fichas decorativas creme e dragão na home; o mascote fica um pouco mais abaixo para afastar os chifres das fichas.
- `lib/features/game/presentation/widgets/letter_wheel.dart`: caldeirão atrás das letras, fichas verde-petróleo com letras brancas e contorno dourado, embaralhamento central. A seleção preserva o destaque, traço e escala existentes.
- `lib/features/game/presentation/themes_screen.dart`: catálogo dinâmico acomoda seis opções em uma ou duas colunas, com rolagem.
- `pubspec.yaml`: versão e inclusão explícita dos três PNGs.

As ilustrações ignoram toque e leitura semântica. Falha de imagem usa fundo claro, base simples ou dispensa o mascote, sem bloquear o jogo. Não foram adicionados música, áudio ambiente, dependências, compras ou animação de mascote.

IDs anteriores preservados: `jardim_gatinho`, `capivara_lagoa`, `biblioteca_encantada`, `fundo_mar`, `jardim_abelhas`. O Jardim do Gatinho permanece padrão para novas instalações e IDs desconhecidos. A escolha usa `app_settings.visual_theme_id`, sem migração adicional: schema 6 e payload 2 continuam válidos.
